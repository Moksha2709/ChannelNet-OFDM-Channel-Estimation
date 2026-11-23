classdef Link < handle
    %% The Link Class (Link)
    %   Authors
    %   (c) 2016 Institute of Telecommunications, TU Wien.
    %   www.nt.tuwien.ac.at
    
    %% The Link Properties
    % The properites are divided into five categories:
    
    % Accessibility
    properties
        ID                          % Link ID.
        Type                        % Link Type: {'Primary', 'Interference'}.
        Direction                   % 'Downlink', 'Uplink', 'D2D'
        Transmitter                 % The transmitting end (node ID).
        Receiver                    % The receiving end (node ID).
        MUSTFarUE                   % ID of the MUST FarUE.
        MUSTNearUE                  % ID of the MUST NearUE.
        frameStructure              % 'TDD' or 'FDD'
        mumimoPrecodingMatrix       % multi-user mimo precoder
        interferPrecodingMatrix     % multi-user mimo iterferer precoder
        channelError                % estimate of the channel error due to the delay between uplink and downlink
        nTxAnalogPrecoder
        nRxAnalogPrecoder
        primaryLink            % indicate the primary link for each secondary link
        secondaryLink         % indicate secondary links of each primary link
    end
    
    % Parameters
    properties
        SNR                     % The SNR at the receiving end
        pathloss                % artificial channel pathloss for the primary link
        secondaryPathloss  % artificial channel pathloss for the secondary link
        transmissionMode        % 'CLSM', 'OLSM' or 'TxD'
        HARQType                % The HARQ type: {'CC', 'IR'}.
        HARQRV = 0;             % The HARQ Redudency Version: {0, 1, 2, ..., max(HARQRV)}
        Velocity = 0;           % The relative velocity between the transmitting and receiving ends
        ChannelEstimationMethod % The channel estimation method: {'Perfect', 'PilotAided'}
        NrInputBits             % Number of the original data bits
        schedule                % schedule for transmission in current frame
        scheduledSubcarriers    % number of total scheduled subcarriers
        firstSubcarrier         % position of the first scheduled subcarrier, ie., the frequency offset in subcarriers
        isScheduled = 0         % Indicates whether the links is Scheduled or not: isScheduled = {0, 1};
        Attenuation = 0         % Scales down the link output power by a factor (in dB). ex: Attenuation = 5;
        transmitPower           % link's transmit power
        powerScale              % power scaling to get a total power of one for all schedules (for downlink)
        nTxAntennaPorts         % number of transmit antenna ports
        nTxAntennas             % number of transmit antennas
        txArrayConfiguration    % N1 and N2 for the 5G codebok
        rxArrayConfiguration
        nRxAntennaPorts         % number of receive antenna ports
        nRxAntennas             % number of receive antennas
        IsMUSTFarUE = 0;        % Indicates if the current link is of a 3GPP MUST far UE
        IsMUSTNearUE = 0;       % Indicates if the current link is of a 3GPP MUST near UE
        MUSTIdx = 0;            % MUST power allocation index for this link (0 for no MUST). This is used by nearUE.
        nonlinearity            % Apply nonlinear model
        smoothnessFactor        % Smoothness factor of the model
        amplifierOBO            % Amplifier Output Back-Off
        multiuserMode           % Multi-user mimo mode
        spatialModelParameters  % Spatial Channel Model Parameters
        plotPAPR
    end
    
    % Functionality
    properties
        ChannelCoder            % The channel coding object.
        Modulator               % The modulation object.
        MIMO                    % The MIMO object.
        Channel                 % The channel between the transmitting and receiving end.
        Feedback                % The Feedback object
    end
    
    % Generated Signals
    properties
        InputBits
        EncodedBits
        TransmitSymbols
        TransmitSignal
        ReceiveSignal
        LLRs
        DecodedBits
        channelEstimationMSE
        PAPR
    end
    
    % Results of current transmission
    properties
        BER                % BER
        FrameError         % FE: {0, 1}
        Throughput         % Throughput
    end
    %% The Link Functions
    % The Link provide functions for both the transmit and receive sides
    
    % Setup
    methods

        function obj = Link(ID, type, Direction, transmitter, receiver, harqType, velocity, attenuation,  nTxAntennaPorts, nTXAntennas, txArrayConfiguration, nRxAntennaPorts, nRXAntennas, rxArrayConfiguration, transmissionMode)
            obj.ID              = ID;
            obj.Type            = type;
            obj.Direction       = Direction;
            obj.Transmitter     = transmitter;
            obj.Receiver        = receiver;
            obj.HARQType        = harqType;
            obj.Velocity        = velocity;
            obj.Attenuation 	= attenuation;
            obj.nTxAntennas     = nTXAntennas;
            obj.nTxAntennaPorts = nTxAntennaPorts;
            obj.nRxAntennaPorts = nRxAntennaPorts;
            obj.nRxAntennas     = nRXAntennas;
            obj.transmissionMode = transmissionMode;
            obj.txArrayConfiguration = txArrayConfiguration;
            obj.rxArrayConfiguration = rxArrayConfiguration;
        end
        
        function updateLink(obj, simParams, Links, IN)
            % In this method, the current link is updated: scheduling and
            % link adaptation, feedback calculation
            
            %% Feedback
            if ismember(obj.multiuserMode,{'ZF-MUMIMO','MMSE-MUMIMO','MRT-MUMIMO','MRC-MUMIMO','BD-MUMIMO'})
                obj.MIMO.setNStreams(simParams.modulation.nStreams(obj.ID));
                % get number of codewords from number of streams
                obj.MIMO.setLayerMapping(obj.Direction);
                nCodewords = length(obj.MIMO.LayerMapping);
                if strcmp(obj.transmissionMode, 'custom')
                    % calculate cqi
                    if ~isempty(obj.Feedback)
                        if obj.Feedback.Cqi.enable
                            noisePower = obj.Modulator.WaveformObject.GetSymbolNoisePower(simParams.phy.noisePower);
                            if strcmp(obj.Direction, 'Uplink')
                                obj.Feedback.updateFeedbackUL(noisePower, [simParams.modulation.mcsValues.modulationOrder]);
                            elseif strcmp(obj.Direction, 'Downlink')
                                obj.Feedback.updateFeedbackDL(noisePower, [simParams.modulation.mcsValues.modulationOrder]);
                            end
                            mcs = simParams.modulation.mcsValues(obj.Feedback.Cqi.cqiArray{1});
                        else
                            mcs = repmat(simParams.modulation.mcsValues(simParams.modulation.mcs(obj.ID)), [nCodewords, 1]);
                        end
                        obj.MIMO.setNStreams(simParams.modulation.nStreams(obj.ID));
                    else
                        % feedback deactivated
                        % apply same cqi for all codewords
                        mcs = repmat(simParams.modulation.mcsValues(simParams.modulation.mcs(obj.ID)), [1, nCodewords]);
                    end
                    
                else
                    error('Currently only custom transmission modes are supported with TDD');
                end
            else
                % FDD
                switch obj.transmissionMode
                    case 'CLSM'
                        % if the feedback delay is 0, the channel for the next transmission is used for the feedback calculation otherwise
                        % the current channel is used
                        if obj.Feedback.delay == 0
                            channel = obj.getTheTotalChannel(simParams, IN);
                            [nSubcarriers,nSymbols,nRx,nTx] = size(channel);
                            channel = permute(reshape(reshape(permute(channel,[1 2 4 3]),[],nTx)*obj.nTxAnalogPrecoder,nSubcarriers,nSymbols,nRx,[]),[1 2 4 3]);
                            channel = permute(reshape(obj.nRxAnalogPrecoder*reshape(permute(channel,[4 1 2 3]),nRx,[]),[],nSubcarriers,nSymbols,obj.nTxAntennaPorts),[2 3 4 1]);
                        else
                            channel = obj.Modulator.Channel;
                        end
                        
                        if obj.IsMUSTNearUE
                            channel = channel * obj.Modulator.SignalConstellation{1}.MUSTNearUEScale;
                        elseif obj.IsMUSTFarUE
                            channel = channel * sqrt(1 - Links{obj.Transmitter, obj.MUSTNearUE}.Modulator.SignalConstellation{1}.MUSTNearUEScale^2);
                        end
                        
                        pilotMatrix = obj.Modulator.ChannelEstimator.PilotMatrix;
                        noisePower = obj.Modulator.WaveformObject.GetSymbolNoisePower(simParams.phy.noisePower);
                        % instead of noisePower simParams.phy.noisePower
                        obj.Feedback.updateFeedback(channel, pilotMatrix, noisePower(1), [simParams.modulation.mcsValues.modulationOrder]);
                        obj.MIMO.setNStreams(obj.Feedback.Ri.riArray(1));
                        obj.MIMO.setPrecodingMatrixIndex(obj.Feedback.Pmi.pmiArray(1));
                        mcs = simParams.modulation.mcsValues(obj.Feedback.Cqi.cqiArray{1});
                        
                    case 'OLSM'
                        if obj.Feedback.delay == 0
                            channel = obj.getTheTotalChannel(simParams, IN);
                            [nSubcarriers,nSymbols,nRx,nTx] = size(channel);
                            channel = permute(reshape(reshape(permute(channel,[1 2 4 3]),[],nTx)*obj.nTxAnalogPrecoder,nSubcarriers,nSymbols,nRx,[]),[1 2 4 3]);
                            channel = permute(reshape(obj.nRxAnalogPrecoder*reshape(permute(channel,[4 1 2 3]),nRx,[]),[],nSubcarriers,nSymbols,obj.nTxAntennaPorts),[2 3 4 1]);
                        else
                            channel = obj.Modulator.Channel;
                        end
                        
                        if obj.IsMUSTNearUE
                            channel = channel * obj.Modulator.SignalConstellation{1}.MUSTNearUEScale;
                        elseif obj.IsMUSTFarUE
                            channel = channel * sqrt(1 - Links{obj.Transmitter, obj.MUSTNearUE}.Modulator.SignalConstellation{1}.MUSTNearUEScale^2);
                        end
                        
                        pilotMatrix = obj.Modulator.ChannelEstimator.PilotMatrix;
                        noisePower  = obj.Modulator.WaveformObject.GetSymbolNoisePower(simParams.phy.noisePower);
                        obj.Feedback.updateFeedback(channel, pilotMatrix, noisePower(1), [simParams.modulation.mcsValues.modulationOrder]);
                        
                        mcs = simParams.modulation.mcsValues(obj.Feedback.Cqi.cqiArray{1});
                        obj.MIMO.setNStreams(obj.Feedback.Ri.riArray(1));
                        
                    case 'TxD'
                        mcs = simParams.modulation.mcsValues(simParams.modulation.mcs(obj.ID));
                        obj.MIMO.setNStreams(simParams.modulation.nStreams(obj.ID));
                        obj.MIMO.setPrecodingMatrix(simParams.modulation.precodingMatrix{obj.ID});
                        obj.MIMO.setLayerMapping(obj.Direction);
                    otherwise
                        % feedback update for the custom transmission mode
                        if ~isempty(obj.Feedback)
                            if obj.Feedback.delay==0
                                channel = obj.getTheTotalChannel(simParams, IN);
                                [nSubcarriers,nSymbols,nRx,nTx] = size(channel);
                                channel = permute(reshape(reshape(permute(channel,[1 2 4 3]),[],nTx)*obj.nTxAnalogPrecoder,nSubcarriers,nSymbols,nRx,[]),[1 2 4 3]);
                                channel = permute(reshape(obj.nRxAnalogPrecoder*reshape(permute(channel,[4 1 2 3]),nRx,[]),[],nSubcarriers,nSymbols,obj.nTxAntennaPorts),[2 3 4 1]);
                            else
                                channel = obj.Modulator.Channel;
                            end
                            
                            if obj.IsMUSTNearUE
                                channel = channel * obj.Modulator.SignalConstellation{1}.MUSTNearUEScale;
                            elseif obj.IsMUSTFarUE
                                channel = channel * sqrt(1 - Links{obj.Transmitter, obj.MUSTNearUE}.Modulator.SignalConstellation{1}.MUSTNearUEScale^2);
                            end
                            
                            pilotMatrix = obj.Modulator.ChannelEstimator.PilotMatrix;
                            
                            % calculate feedback parameters
                            noisePower  = obj.Modulator.WaveformObject.GetSymbolNoisePower(simParams.phy.noisePower);
                            obj.Feedback.updateFeedback(channel, pilotMatrix, noisePower(1), [simParams.modulation.mcsValues.modulationOrder]);
                            
                            % apply PMI and RI
                            if obj.Feedback.Pmi.enable
                                obj.MIMO.setNStreams(obj.Feedback.Ri.riArray(1));
                                obj.MIMO.setPrecodingMatrix(obj.Feedback.getPrecodingMatrix(obj.Feedback.Pmi.pmiArray(1)));
                            else
                                obj.MIMO.setNStreams(simParams.modulation.nStreams(obj.ID));
                                obj.MIMO.setPrecodingMatrix(simParams.modulation.precodingMatrix{obj.ID});
                            end
                            
                            % apply CQI for all codewords
                            obj.MIMO.setLayerMapping(obj.Direction);
                            nCodewords = length(obj.MIMO.LayerMapping);
                            if obj.Feedback.Cqi.enable
                                mcs = simParams.modulation.mcsValues(obj.Feedback.Cqi.cqiArray{1});
                            else
                                mcs = repmat(simParams.modulation.mcsValues(simParams.modulation.mcs(obj.ID)), [nCodewords, 1]);
                            end
                        else
                            % feedback deactivated
                            obj.MIMO.setNStreams(simParams.modulation.nStreams(obj.ID));
                            obj.MIMO.setPrecodingMatrix(simParams.modulation.precodingMatrix{obj.ID});
                            obj.MIMO.setLayerMapping(obj.Direction);
                            nCodewords = length(obj.MIMO.LayerMapping);
                            % apply same cqi for all codewords
                            mcs = repmat(simParams.modulation.mcsValues(simParams.modulation.mcs(obj.ID)), [1, nCodewords]);
                        end
                end
            end
            %% MUST Operation
            if obj.IsMUSTFarUE
                % Forces FarUE to use the same MIMO setting as NearUE.
                obj.MIMO   = copy(Links{obj.Transmitter, obj.MUSTNearUE}.MIMO);
                nCodewords = length(obj.MIMO.LayerMapping);
                
                % If UE is MUSTFarUE then the mapping is limited to QPSK (CQI 6)
                if length(mcs) < nCodewords
                    mcs = repmat(mcs, [1, nCodewords]);
                end
                for iCodeword = 1:nCodewords
                    if mcs(iCodeword).cqi > 6
                        mcs(iCodeword) = simParams.modulation.mcsValues(6);
                    end
                end
            end
            
            %% Link Adaptation
            obj.MIMO.setLayerMapping(obj.Direction);
            nCodewords = length(obj.MIMO.LayerMapping);
            % apply CQI for all codewords
            for iCodeword = 1:nCodewords
                obj.Modulator.setMCS([mcs.modulationOrder], [mcs.cqi], obj.MUSTIdx);
                nCodedBits = obj.Modulator.getNrCodedBits(obj.Modulator.ChannelEstimator.NrPilotSymbolPositions, obj.schedule, iCodeword);
                SoftBufferRatio = obj.ChannelCoder{iCodeword}.SoftBufferRatio; % non-adaptive, stays the same
                obj.NrInputBits(iCodeword) = obj.ChannelCoder{iCodeword}.update('Output', nCodedBits, obj.MIMO.LayerMapping(iCodeword), mcs(iCodeword).codingRateTimes1024/1024, log2(obj.Modulator.SignalConstellation{iCodeword}.ModulationOrder), SoftBufferRatio);
            end
        end
    end
    
    % Transmit and channel side
    methods
        function generateReceiveSignal(obj)
            switch obj.Type
                case 'Primary'
                    obj.ReceiveSignal = 10^(-obj.pathloss/20) * obj.Channel.Convolution( obj.TransmitSignal);
                case 'Secondary'
                    obj.ReceiveSignal = 10^(-obj.pathloss/20) * obj.Channel.Convolution(obj.TransmitSignal);
                case 'Interference'
                    obj.ReceiveSignal = 10^(-obj.Attenuation/20) *  obj.Channel.Convolution(obj.TransmitSignal);
            end
        end
        
        function distortedSignal = applyNonlinearity(obj, transmitSignal)
            meanPowerPerAntenna = mean(abs(transmitSignal).^2,1);
            transmitSignal = reshape(transmitSignal,[],1);                                                                                          % Parallel handling of all nTx streams
            limitingAmplitude = 10.^((obj.amplifierOBO)/20);                                                                                        % Amplifier saturation amplitude in linear units
            inputAmplitude = sqrt(real(transmitSignal).^2 + imag(transmitSignal).^2);                                                               % Calculate each symbol's amplitude
            outputAmplitude = inputAmplitude ./ (1 + (inputAmplitude/limitingAmplitude).^(2*obj.smoothnessFactor)).^(1/(2*obj.smoothnessFactor));   % Apply nonlinear model on the signal
            scalingFactor = outputAmplitude ./ inputAmplitude;                                                                                      % Calculate scaling factor and use it on the signal vector
            scalingFactor(isnan(scalingFactor)) = 0;                                                                                                % Ommit NAN's in case of division by 0 in previous line
            temporaryTransmitSignal = transmitSignal .* scalingFactor;                                                                              % Distort signal vector
            powerLoss = mean(abs(temporaryTransmitSignal).^2);                                                                                      % Calculate mean signal power after distortion
            distortedSignal = reshape(temporaryTransmitSignal,[],obj.nTxAntennas) .* sqrt(meanPowerPerAntenna/powerLoss);                           % Preserve per antenna mean power levels
        end
    end
    
    % Receive-side
    methods
        function [scheduledChannel, scheduledPseudoSymbols] = estimateScheduledChannel(obj, pseudoSymbols, simParams, IN)
            perfectChannel = getTheTotalChannel(obj, simParams, IN);
            [nSubcarriers,nSymbols,nRx,nTx] = size(perfectChannel);
            perfectChannel = reshape(reshape(perfectChannel,[],nTx)*obj.nTxAnalogPrecoder,nSubcarriers,nSymbols,nRx,[]);
            perfectChannel = permute(reshape(obj.nRxAnalogPrecoder*reshape(permute(perfectChannel,[3 1 2 4]),nRx,[]),[],nSubcarriers,nSymbols,obj.nTxAntennaPorts),[2 3 1 4]);
            % channel estimation
            switch obj.ChannelEstimationMethod
                case {'Approximate-Perfect'}
                    % get approximately perfect channel knowledge
                    obj.Modulator.Channel = perfectChannel;
                    pilotMatrix = obj.Modulator.ChannelEstimator.PilotMatrix;
                    dataIndex = ~sum(pilotMatrix, 3);
                    obj.channelEstimationMSE = NaN;
                    
                case {'PilotAided'}
                    pilotMatrix = obj.Modulator.ChannelEstimator.PilotMatrix;
                    pilotsLS    = cell(obj.nRxAntennaPorts, obj.nTxAntennaPorts);
                    obj.Modulator.Channel = zeros(size(pilotMatrix, 1), size(pilotMatrix, 2), obj.nRxAntennaPorts, obj.nTxAntennaPorts);
                    % check if pilot symbols are allocated overlapping
                    if obj.Modulator.ChannelEstimator.OverlappingPilots
                        % pilot symbols are allocated overlapping, pilot sequence orthogonality must be exploited for channel estimation
                        sequenceLength = obj.Modulator.ChannelEstimator.orthogonalSequenceLength;
                        normFac = sum(obj.Modulator.ChannelEstimator.PilotMatrix,3);

                        for iRx = 1:obj.nRxAntennaPorts
                            pseudoSymbolsPerAnt = pseudoSymbols(:, :, iRx);
                            for iTx = 1:obj.nTxAntennaPorts
                                receivedPilots = reshape(pseudoSymbolsPerAnt(logical(pilotMatrix(:, :, iTx))), sequenceLength, []);
                                channelEstimateFlat = obj.Modulator.PilotSymbols{iTx}(1:sequenceLength)' * receivedPilots ./ sequenceLength; % inner product to expoit orthogonality
                                pilotsLS{iRx, iTx} = kron(channelEstimateFlat.', ones(sequenceLength, 1)).* ...
                                   normFac(logical(obj.Modulator.ChannelEstimator.PilotMatrix(:, :, iTx))); 

                                obj.Modulator.Channel(:, :, iRx, iTx) = obj.Modulator.ChannelEstimator.ChannelInterpolation(pilotsLS{iRx, iTx}, size(pilotMatrix, 1), size(pilotMatrix, 2), iTx);
                            end
                        end
                    else
                        % pilot symbols are allocated on different resource elements for each antenna
                        % LS channel estimation for each MIMO channel individually
                        for iRx = 1:obj.nRxAntennaPorts
                            pseudoSymbolsPerAnt = pseudoSymbols(:, :, iRx);
                            for iTx = 1:obj.nTxAntennaPorts
                                pilotsLS{iRx, iTx}                      = zeros(obj.Modulator.ChannelEstimator.NrPilotSymbols(iTx), 1);
                                pilotsLS{iRx, iTx}                      = pseudoSymbolsPerAnt(logical(pilotMatrix(:, :, iTx))) ./ obj.Modulator.PilotSymbols{iTx};
                                obj.Modulator.Channel(:, :, iRx, iTx)   = obj.Modulator.ChannelEstimator.ChannelInterpolation(pilotsLS{iRx, iTx}, size(pilotMatrix, 1), size(pilotMatrix, 2), iTx);
                            end
                        end
                    end
                    dataIndex = ~sum(pilotMatrix, 3);
                    
                    obj.channelEstimationMSE = 10^(-(obj.transmitPower-30-obj.pathloss)/10) * mean(abs(obj.Modulator.Channel(:) - perfectChannel(:)).^2);
                otherwise
                    error('Channel estimation method not supported');
            end
            scheduledChannel        = reshape(obj.Modulator.Channel(repmat(dataIndex, 1, 1, obj.nRxAntennaPorts, obj.nTxAntennaPorts)), [],  obj.nRxAntennaPorts, obj.nTxAntennaPorts);
            scheduledPseudoSymbols  = reshape(pseudoSymbols(repmat(dataIndex, 1, 1, size(pseudoSymbols, 3))), [], size(pseudoSymbols, 3));
            if strcmp(obj.frameStructure, 'TDD') && ~isempty(obj.Feedback) && obj.Feedback.Cqi.enable
                obj.channelError = squeeze(perfectChannel(1, 1, :) - perfectChannel(1, end,:)).';
            end
            obj.Modulator.channelAtPilots = reshape(obj.Modulator.Channel(repmat(~dataIndex, 1, 1, obj.nRxAntennaPorts, obj.nTxAntennaPorts)), [],  obj.nRxAntennaPorts, obj.nTxAntennaPorts );
            
        end
        
        
        function detect(obj, scheduledChannel, scheduledPseudoSymbols, noisePower)
            
            obj.LLRs = obj.Modulator.getLLRs(scheduledChannel, scheduledPseudoSymbols , noisePower, obj);
            
            % If MUST is enabled (perform ML NOMA detection)
            if obj.IsMUSTNearUE
                nCodewords = length(obj.MIMO.LayerMapping);
                for iCodeword = 1:nCodewords
                    compositeLLRs = reshape(obj.LLRs{iCodeword}', log2(obj.Modulator.SignalConstellation{iCodeword}.ModulationOrder) + 2, [])';
                    
                    % Remove FarUE bits
                    compositeLLRs = compositeLLRs(:, 3:end);
                    
                    obj.LLRs{iCodeword} = compositeLLRs(:);
                end
            end
            nCodewords = length(obj.LLRs);
            obj.DecodedBits = cell(nCodewords, 1);
            obj.FrameError  = zeros(nCodewords, 1);
            
            for iCodeword = 1:nCodewords
                % decoding
                obj.DecodedBits{iCodeword} = obj.ChannelCoder{iCodeword}.decode(-obj.LLRs{iCodeword});
                % check if codeword was in error
                obj.FrameError(iCodeword) = obj.ChannelCoder{iCodeword}.CRCDetectionResult;
            end
        end
    end
    
    % Secondary link side
    methods
        function totalChannel = getTheTotalChannel(obj, simParams, IN)
            % this function only valid for primary channel
            switch obj.Type
                case 'Primary'
                    primaryLinkChannel = 10^(- obj.pathloss / 20) * obj.Channel.GetTransferFunction(obj.Modulator.WaveformObject.GetTimeIndexMidPos, obj.Modulator.WaveformObject.GetFFTsize, obj.Modulator.WaveformObject.Implementation.IntermediateFrequency + (1:obj.Modulator.WaveformObject.Nr.Subcarriers));
                    totalChannel = primaryLinkChannel;
                    [nSubcarriers,nSymbols,~,~] = size(primaryLinkChannel);
                    for iSecondaryLink = 1:size(obj.secondaryLink,1)
                        % We assume that each primary link only has one IN node and two cascade secondary links.
                        SecondaryLinkTXtoIN = obj.secondaryLink{iSecondaryLink, 1};%the link from TX to IN
                        SecondaryLinkINtoRX = obj.secondaryLink{iSecondaryLink, 2};%the link from IN to RX
                        
                        SecondaryLinkTXtoINchannel = 10^( -SecondaryLinkTXtoIN.pathloss / 20)*SecondaryLinkTXtoIN.Channel.GetTransferFunction(obj.Modulator.WaveformObject.GetTimeIndexMidPos,...
                            obj.Modulator.WaveformObject.Implementation.FFTSize,...
                            obj.Modulator.WaveformObject.Implementation.IntermediateFrequency+(1:obj.Modulator.WaveformObject.Nr.Subcarriers));
                        
                        SecondaryLinkINtoRXchannel = 10^( -SecondaryLinkINtoRX.pathloss / 20)*SecondaryLinkINtoRX.Channel.GetTransferFunction(obj.Modulator.WaveformObject.GetTimeIndexMidPos,...
                            obj.Modulator.WaveformObject.Implementation.FFTSize,...
                            obj.Modulator.WaveformObject.Implementation.IntermediateFrequency+(1:obj.Modulator.WaveformObject.Nr.Subcarriers));
                        
                        INID = simParams.topology.INID(SecondaryLinkTXtoIN.Receiver);
                        phaseShiftPerElement = IN{INID}.phaseShiftPerElement;
                        
                        %obtain the phase shift for all the subcarriers and symbols
                        phaseShiftPerElementMartrix = repmat(diag(exp(1i*phaseShiftPerElement)),[1 1 nSubcarriers nSymbols]);
                        
                        % matrix
                        % if the matalb is older than 2020b
                        A = permute(SecondaryLinkINtoRXchannel,[3 4 1 2]);                        
                        B = phaseShiftPerElementMartrix;
                        C = permute(SecondaryLinkTXtoINchannel,[3 4 1 2]);
                        for index3 = 1:size(A,3)
                            for index4 = 1:size(A,4)
                                D(:,:,index3,index4) = A(:,:,index3,index4)*B(:,:,index3,index4)*C(:,:,index3,index4);
                            end
                        end 
                        
                        SecondaryLinkChannel = permute(D,[3 4 1 2]);
                        totalChannel = totalChannel + SecondaryLinkChannel;
                    end
                    totalChannel =  10^((obj.transmitPower - 30)/20)*obj.powerScale*totalChannel;
                otherwise
                    error('Function getTheTotalChannel is only valid for the primary link')
            end
        end
    end
% Results
methods
    function calculateSNR(obj, BOLTZMANN, temperature)
        % this function calculates the SNR
        if strcmp(obj.Type, 'Interference')
            error('There is no SNR calculation for an interference link.');
        end
        
        if strcmp(obj.Direction, 'Downlink')
            % for downlink the total transmit power is spread over all
            % scheduled subcarriers (for all users combined)
            nSubcarriers = mean(obj.scheduledSubcarriers);
        elseif strcmp(obj.Direction, 'Uplink') || strcmp(obj.Direction, 'D2D')
            % for uplink the total transmit power is spread over all
            % scheduled subcarriers of the user
            nSubcarriers = mean(sum(double(obj.schedule)));
        else
            error('Link Direction unkown');
        end
        
        if strcmp(obj.Modulator.Waveform, 'SC')
            totalScheduledBandwidth = obj.Modulator.WaveformObject.PHY.SymbolRate / obj.powerScale ^ 2;
        else
            totalScheduledBandwidth = (nSubcarriers / obj.powerScale ^ 2) * obj.Modulator.WaveformObject.PHY.SubcarrierSpacing;
        end
        signalPowerDensity      = 10 ^ ((obj.transmitPower - 30 - obj.pathloss) / 10) / totalScheduledBandwidth;
        noisePowerDensity       = BOLTZMANN * temperature;
        obj.SNR                 = 10 * log10(signalPowerDensity / noisePowerDensity);
    end
    
    function calculatePAPR(obj, transmitSignal)
        if obj.plotPAPR
            oversamplingFactor          = 4; % minimal oversampling factor to ensure correct PAPR calculation
            timeVector                  = (0:obj.Modulator.WaveformObject.PHY.dt:(obj.Modulator.WaveformObject.PHY.dt * (obj.Modulator.WaveformObject.Nr.SamplesTotal - 1))).';
            timeVectorDesired           = linspace(timeVector(1), timeVector(end), (length(timeVector)*oversamplingFactor)).';
            transmitSignalInterpolated  = interp1(timeVector, transmitSignal, timeVectorDesired);
            obj.PAPR                = 10*log10(max(max(abs(transmitSignalInterpolated).^2)) / mean(mean(abs(transmitSignalInterpolated).^2)));
        else
            obj.PAPR = nan;
        end
    end
    
    function results = getResults(obj, saveData)
        % Return results
        results.SNR         = obj.SNR;
        results.nStreams    = obj.MIMO.nStreams;
        nCodewords          = length(obj.MIMO.LayerMapping);
        results.nDataBits   = obj.NrInputBits;
        results.frameError  = obj.FrameError;
        results.channelMSE  = obj.channelEstimationMSE;
        encodedBitsReceived = cell(nCodewords, 1);
        for iCodeword = 1:nCodewords
            results.mcsUsed(iCodeword)          = obj.Modulator.currentCQI(iCodeword);
            results.nCodeBits(iCodeword)        = length(obj.EncodedBits{iCodeword});
            encodedBitsReceived{iCodeword}      = sign(obj.LLRs{iCodeword}) == 1;
            results.nBitError(iCodeword)        = sum(obj.EncodedBits{iCodeword} ~= encodedBitsReceived{iCodeword});
            results.nCodedBitError(iCodeword)   = sum(obj.InputBits{iCodeword} ~= obj.DecodedBits{iCodeword});
        end
        
        if saveData
            results.transmittedSymbols  = obj.TransmitSymbols;
            results.dataBits            = obj.InputBits;
            results.encodedBits         = obj.EncodedBits;
            results.encodedBitsReceived = encodedBitsReceived;
            results.decodedBits         = obj.DecodedBits;
        end
        results.PAPR         = obj.PAPR;
    end
end

end

