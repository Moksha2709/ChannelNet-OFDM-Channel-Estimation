classdef User < handle & Elements.Node
%% The User Class (User)
%   (c) 2016 Institute of Telecommunications, TU Wien.
%   www.nt.tuwien.ac.at 
%% User Properties
    properties
        TransmitSignal
        txPower
        nAntennas
        arrayConfiguration
        nAntennaPorts
        analogPrecoder
        analogReceiveFilter
    end
%% The User Functions
%% Initialization
    methods
        function obj = User(name, id, nAntennas, nAntennaPorts, analogPrecoder, analogReceiveFilter, transmitPower, plotResults)
            obj = obj@Elements.Node(name, id, 'User', plotResults);
            obj.nAntennas   = nAntennas;
            obj.arrayConfiguration = [nAntennas, 1];
            obj.nAntennaPorts = nAntennaPorts;
            obj.analogPrecoder = analogPrecoder;
            obj.analogReceiveFilter = analogReceiveFilter;
            obj.txPower     = transmitPower;
        end
    end
%% Transmit Functions
    methods
        function generateTransmitSignal(obj, Links)
            % Uplink from the UE to its primary BS
            primaryLink = Links{obj.ID, obj.ReceiverUL(1)};
            if any(primaryLink.schedule(:))
                primaryLink.isScheduled = 1;
                nStreams                = primaryLink.MIMO.nStreams;
                nCodewords              = length(primaryLink.MIMO.LayerMapping);
                primaryLink.InputBits   = cell(nCodewords, 1);
                codedBits               = cell(nCodewords, 1);
                dataSymbols             = cell(nCodewords, 1);
                symbolsPerStream        = null(1);
                
                primaryMod = primaryLink.Modulator;

                for iCodeword = 1:nCodewords
                    primaryLink.InputBits{iCodeword} = randi([0, 1], primaryLink.NrInputBits(iCodeword), 1);
                    % Channel Coding
                    codedBits{iCodeword} = primaryLink.ChannelCoder{iCodeword}.encode(primaryLink.InputBits{iCodeword});
                    % Symbol Mapping
                    dataSymbols{iCodeword} = primaryMod.SignalConstellation{iCodeword}.Bit2Symbol(codedBits{iCodeword});
                    % Layer mapping
                    symbolsPerStream = [symbolsPerStream; reshape(dataSymbols{iCodeword}, primaryLink.MIMO.LayerMapping(iCodeword), [])];                    
                end
                
                % Data symbol spreading
                spreadSymbolsPerStream = zeros(size(symbolsPerStream));
                for iStream = 1:nStreams
                    spreadSymbolsPerStream(iStream, :) = primaryMod.spreadingTransform(symbolsPerStream(iStream, :), primaryLink.scheduledSubcarriers); 
                end

                % MIMO precoding
                if ismember(primaryLink.multiuserMode,{'ZF-MUMIMO','MMSE-MUMIMO','MRC-MUMIMO'})
                    dataSymbolsPrecoded = spreadSymbolsPerStream.';
                else
                    dataSymbolsPrecoded = primaryLink.MIMO.precoding(spreadSymbolsPerStream.', obj.nAntennaPorts);
                end
                
                % get effective antenna index for channel estimation
                 effeictiveTransmitAntennas = zeros(size(Links, 1), 1);
                for iLink = 1:size(Links, 1)
                    if ~isempty(Links{iLink, obj.ReceiverUL(1)})
                        effeictiveTransmitAntennas(Links{iLink, obj.ReceiverUL(1)}.Transmitter) = Links{iLink, obj.ReceiverUL(1)}.nTxAntennas;
                    end
                end
                sequenceIndexOffset = sum(effeictiveTransmitAntennas(1:obj.ID));
                
                switch primaryMod.Waveform
                    case {'SC', 'OFDM', 'f-OFDM', 'WOLA', 'UFMC', 'FBMC'}
                        modulationMat = zeros(primaryLink.Modulator.WaveformObject.Nr.Subcarriers, primaryLink.Modulator.WaveformObject.Nr.MCSymbols, obj.nAntennas);
                        pilotSymbols = cell(obj.nAntennas, 1);
%                                 qam_constellation_temp = exp(1i * pi / 2 * ((0:3) + 0.5)).';
                        if strcmp(primaryLink.Modulator.Waveform, 'FMBC')
                            % employ real valued pilot symbols only for FBMC
                            orthogonalSequenceType = 'Hadamard';
                        else
                            orthogonalSequenceType = 'Zadoff-Chu';
                        end

                       normFac = sum(primaryMod.ChannelEstimator.PilotMatrix,3);
                        for iAntenna = 1:obj.nAntennaPorts
                            % assemble orthogonal pilot sequence
                            sequenceIndex = sequenceIndexOffset + iAntenna - 1;
                            sequenceLength = primaryLink.Modulator.ChannelEstimator.orthogonalSequenceLength;
                            pilotSymbolsTemp = +Utils.generateOrthogonalSequence(sequenceLength, sequenceIndex, orthogonalSequenceType);
                            currentNumberOfPilots = nnz(logical(primaryLink.Modulator.ChannelEstimator.PilotMatrix(:, :, iAntenna)));
                            if primaryLink.Modulator.ChannelEstimator.OverlappingPilots && mod(currentNumberOfPilots, sequenceLength) > 0
                                error('Number of assigned pilot symbols (%.1f) is not devisible by orthogonal pilot sequence length (%.1f)!', currentNumberOfPilots, sequenceLength);
                            end
                            pilotSymbolSequenceTemp = repmat(pilotSymbolsTemp, [ceil(currentNumberOfPilots / sequenceLength), 1]);           
                            pilotSymbols{iAntenna} = pilotSymbolSequenceTemp(1:currentNumberOfPilots)./ ...
                                sqrt(normFac(logical(primaryMod.ChannelEstimator.PilotMatrix(:, :, iAntenna))));                 

                            % assemble matrix of data and pilot symbols
                            modulationMatTemp = zeros(primaryLink.Modulator.WaveformObject.Nr.Subcarriers, primaryLink.Modulator.WaveformObject.Nr.MCSymbols);
                            modulationMatTemp( logical(primaryMod.ChannelEstimator.PilotMatrix(:, :, iAntenna))) = pilotSymbols{iAntenna};
                            modulationMatTemp(~logical(sum(primaryMod.ChannelEstimator.PilotMatrix, 3)))         = dataSymbolsPrecoded(:, iAntenna);
                            modulationMat(:, :, iAntenna) = modulationMatTemp;
                        end
                        primaryMod.PilotSymbols = pilotSymbols;
                    case 'GFDM'
                        % To be added
                        error('GFDM with channel estimation is not yet implemented!');
                    otherwise
                        error('Waveform unknown!');
                end
                
                transmitSignalUnitPower = zeros(primaryMod.WaveformObject.Nr.SamplesTotal, obj.nAntennaPorts);
                for iAntenna = 1:obj.nAntennaPorts
                    transmitSignalUnitPower(:,iAntenna) = primaryMod.WaveformObject.Modulation(modulationMat(:, :, iAntenna));
                end
                
                % no power scaling required, as the user is alone in its entire allocated bandwidth
                primaryLink.powerScale = 1;
                
                % normalize transmit signal to tranmit power
                transmitSignal = transmitSignalUnitPower * 10^((obj.txPower - 30) / 20);
                
                % Analog precoding
                transmitSignal = transmitSignal * obj.analogPrecoder.';
                % Calculate PAPR of transmitted signal
                calculatePAPR(primaryLink,transmitSignal);
                
                % Check for nonlinear PA model
                if primaryLink.nonlinearity
                    transmitSignal = primaryLink.applyNonlinearity(transmitSignal);
                end
                
                % Just copy it to all connected links. Since they all share the same transmit signal
                for iLink = 1:length(Links)
                    currentLink = Links{obj.ID, iLink};
                    if ~isempty(currentLink)
                        currentLink.isScheduled     = 1;                % For uplink interefence
                        currentLink.EncodedBits     = codedBits;
                        currentLink.TransmitSymbols = dataSymbols;
                        currentLink.TransmitSignal  = transmitSignal;
                        currentLink.transmitPower   = obj.txPower;
                    end
                end  
            end
        end 
    end
%% Receive Functions
    methods
        function processReceiveSignal(obj, totalSignal, Links, params, IN)
            % apply analog receive filter (antennas to port mapping)
            totalSignal = totalSignal*obj.analogReceiveFilter.';
            % Direct processing using the user primary link
            currentLink = Links{obj.TransmitterDL(1), obj.ID};
            pseudoSymbols = currentLink.Modulator.demodulateTimeSignal(totalSignal);
            [scheduledChannel, scheduledPseudoSymbols] = currentLink.estimateScheduledChannel(pseudoSymbols,params, IN);
            noisePower = currentLink.Modulator.estimateNoisePower(totalSignal, params.phy.noisePower);
            currentLink.detect(scheduledChannel, scheduledPseudoSymbols, noisePower);
        end
    end  
end

