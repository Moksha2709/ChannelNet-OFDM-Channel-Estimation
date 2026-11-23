classdef BaseStation < handle & Elements.Node
%% The BaseStation Class (BaseStation)
%   (c) 2016 Institute of Telecommunications, TU Wien.
%   www.nt.tuwien.ac.at 
%% Basetation Properties
    properties
        txPower
        nAntennas
        nAntennaPorts
        nTotalScheduledSubcarriers
        arrayConfiguration
        analogPrecoder
        analogReceiveFilter
        multiuserMode
        intermediateNodes
    end
%% The BaseStation Functions
%% Initialization
    methods
        function obj = BaseStation(name, id, nAntennas, nAntennaPorts, analogPrecoder, analogReceiveFilter, transmitPower, multiuserModeDL, multiuserModeUL, multiuserModeULIC, plotResults)
            obj = obj@Elements.Node(name, id, 'BaseStation', plotResults);
            obj.nAntennas               = nAntennas(1)*nAntennas(2);
            obj.arrayConfiguration    = nAntennas;
            obj.nAntennaPorts           = nAntennaPorts;
            obj.analogPrecoder          = analogPrecoder;
            obj.analogReceiveFilter     = analogReceiveFilter;
            obj.txPower                 = transmitPower;
            obj.multiuserMode.Downlink  = multiuserModeDL;
            obj.multiuserMode.Uplink    = multiuserModeUL;
            obj.multiuserMode.UplinkIC  = multiuserModeULIC;
        end
    end
%% Transmit Functions
    methods
        
        
        function generateTransmitSignal(obj, Links, simParams, IN)
            iScheduledUE                = 0;
            
            % Generate transmit signal
            if ismember(obj.multiuserMode.Downlink, {'ZF-MUMIMO', 'MRT-MUMIMO', 'BD-MUMIMO'})
                % Joint signal procssing for multi-user MIMO
                compositeChannel = [];
                compositeSymbols = [];
                primaryScheduledLinks = [];
                % Collect channel of all users assigned to the BS
                for iUE = 1:length(obj.ReceiverDL)
                    Links{obj.ID, obj.ReceiverDL(iUE)}.transmitPower = obj.txPower;
                    currentLink = Links{obj.ID, obj.ReceiverDL(iUE)};
                    if any(currentLink.schedule(:)) && strcmp(currentLink.Type, 'Primary')
                        primaryScheduledLinks = cat(1,primaryScheduledLinks,currentLink);
                        currentLink.isScheduled = 1;
                        iScheduledUE = iScheduledUE + 1;
                        nStreams = currentLink.MIMO.nStreams;   
                        
                        if strcmp(currentLink.frameStructure, 'FDD')
                            % FDD mode: use the actual channel of the link
                            channel = currentLink.getTheTotalChannel(simParams, IN);
                        elseif strcmp(currentLink.frameStructure, 'TDD')
                            % TDD mode: use the channel estimated in the uplink
                            channel = Links{obj.ReceiverDL(iUE), obj.ID}.getTheTotalChannel(simParams, IN);
                            channel = permute(channel, [1 2 4 3]);
                        end

                        channel = reshape(channel( repmat(logical( ~sum(currentLink.Modulator.ChannelEstimator.PilotMatrix,3)),...
                                                 1,1,size(channel,3),size(channel,4))),[],size(channel,3),size(channel,4));                        
                        compositeChannel = cat(1,compositeChannel,permute(channel,[2,3,1])); 
                    end                    
                end %for iUE  
                nPrimaryLinks = length(primaryScheduledLinks);
               
                % channel coding and symbol mapping
                for iLink = 1:nPrimaryLinks
                    currentLink = primaryScheduledLinks(iLink);
                    nCodewords = length(currentLink.MIMO.LayerMapping);
                    % Channel Coding for this user
                    currentLink.InputBits   = cell(nCodewords,1);
                    currentLink.EncodedBits = cell(nCodewords,1);
                    for iCodeword = 1:nCodewords
                        currentLink.InputBits{iCodeword}    = randi([0 1], currentLink.NrInputBits(iCodeword), 1);
                        currentLink.EncodedBits{iCodeword}  = currentLink.ChannelCoder{iCodeword}.encode(currentLink.InputBits{iCodeword});
                    end

                    % Symbol Mapping for this user
                    symbolsPerStream = null(1);
                    currentMod = currentLink.Modulator;
                    for iCodeword = 1:nCodewords
                        dataSymbols = currentMod.SignalConstellation{iCodeword}.Bit2Symbol(currentLink.EncodedBits{iCodeword});
                        currentLink.TransmitSymbols{iCodeword} = dataSymbols;
                        symbolsPerStream = [symbolsPerStream; reshape(dataSymbols, currentLink.MIMO.LayerMapping(iCodeword), [])];

                    end
                    
                    % symbol spreading
                    spreadSymbolsPerStream = zeros(size(symbolsPerStream));
                    for iStream = 1:nStreams
                        spreadSymbolsPerStream(iStream, :) = currentMod.spreadingTransform(symbolsPerStream(iStream, :), currentLink.scheduledSubcarriers);
                    end

                    compositeSymbols = cat(1,compositeSymbols, spreadSymbolsPerStream);
                end % iLink
                
                % MU-MIMO precoding 
                dataSymbolsPrecoded = zeros(size(compositeSymbols', 2), obj.nAntennas);
                for i = 1:size(compositeSymbols, 2)
                    H = compositeChannel(:, :, i);
                    switch obj.multiuserMode.Downlink 
                        case 'ZF-MUMIMO'
                            % Based on 'Low-Complexity Hybrid Precoding in Massive Multiuser MIMO Systems'
                            F = 1 / sqrt(obj.nAntennas) * exp(1i * angle(H'));
                            Heq = H * F;
                            precodingMatrix = F * Heq'/(Heq * Heq');
                            normFac = norm(precodingMatrix, 'fro');
                            precodingMatrix = precodingMatrix / normFac;
                            for iLink = 1:nPrimaryLinks
                                 primaryScheduledLinks(iLink).MIMO.MuPrecoder{i} = normFac;
                            end
                        case 'MRT-MUMIMO'
                            normalizationMatrix = diag(sqrt(sum(abs(H').^2, 1)).^-1) / sqrt(nPrimaryLinks);
                            precodingMatrix = H' * normalizationMatrix;
                            normFac = H*H';
                            for iLink = 1:nPrimaryLinks
                                 primaryScheduledLinks(iLink).MIMO.MuPrecoder{i} = (normFac(iLink, iLink)*normalizationMatrix(iLink,iLink)).^(-1);
                            end
                         case 'BD-MUMIMO'
                            % precoding to cancel inter user interference
                            precodingMatrix = null(1);
                            startIndexStreams = 1;
                            startIndexAntennas = 1;
                            nStream = Links{obj.ID, obj.ReceiverDL(1)}.MIMO.nStreams;
                            nRxAntennas = Links{obj.ID, obj.ReceiverDL(1)}.nRxAntennas;
                            H_bar = H(nRxAntennas+startIndexAntennas:end, :);

                            % cancel inter user interference
                            [~, S, V] = svd(H_bar);
                            V_null = V(:, size(diag(S), 1) + 1:end);

                            % cancel multi-stream interference
                            [~, ~, V] = svd(H * V_null);
                            V_one = V(:, 1:nStream);
                            precodingMatrixUserk = V_null * V_one / sqrt(obj.nAntennas);
                            precodingMatrix = [precodingMatrix, precodingMatrixUserk];
                            primaryScheduledLinks(1).MIMO.MuPrecoder{i} = precodingMatrixUserk;
                            startIndexStreams = startIndexStreams + nStreams;
                            startIndexAntennas = startIndexAntennas + nRxAntennas;
                            for iLink = 2:nPrimaryLinks
                                nStream = primaryScheduledLinks(iLink).MIMO.nStreams;
                                nRxAntennas = Links{obj.ID, obj.ReceiverDL(iLink)}.nRxAntennas;
                                H_bar = [H(1:startIndexAntennas - 1, :); H(startIndexAntennas + nRxAntennas:end, :)];

                                % cancel inter user interference
                                [~, S, V] = svd(H_bar);
                                V_null = V(:, size(diag(S), 1) + 1:end);

                                % cancel multi-stream interference
                                [~, ~, V] = svd(H * V_null);
                                V_one = V(:, 1:nStream);
                                precodingMatrixUserk =  V_null * V_one / sqrt(obj.nAntennas);
                                precodingMatrix = [precodingMatrix, precodingMatrixUserk];
                                primaryScheduledLinks(iLink).MIMO.MuPrecoder{i} = precodingMatrixUserk;
                                startIndexStreams = startIndexStreams + nStreams;
                                startIndexAntennas = startIndexAntennas + nRxAntennas;
                            end
                        otherwise
                            error('Multi-user MIMO mode not implemented');
                    end
                    dataSymbolsPrecoded(i, :) = precodingMatrix * compositeSymbols(:, i); 
                end
                
                switch currentMod.Waveform
                    case {'OFDM', 'f-OFDM', 'WOLA', 'UFMC', 'FBMC'}
                        pilotSymbols = cell(obj.nAntennas, 1);
                        modulationMat = zeros(currentMod.WaveformObject.Nr.Subcarriers, currentMod.WaveformObject.Nr.MCSymbols, obj.nAntennas);
                        if strcmp(currentMod.Waveform, 'FBMC')
                            % employ real valued pilot symbols only for FBMC
                            orthogonalSequenceType = 'Hadamard';
                        else
                            orthogonalSequenceType = 'Zadoff-Chu';
                        end

                        normFac = sum(currentMod.ChannelEstimator.PilotMatrix,3);
                        for iAntenna = 1:obj.nAntennaPorts
                            % assemble orthogonal pilot sequence
                            sequenceIndex = iAntenna;
                            sequenceLength = currentMod.ChannelEstimator.orthogonalSequenceLength;
                            pilotSymbolsTemp = +Utils.generateOrthogonalSequence(sequenceLength, sequenceIndex, orthogonalSequenceType);
                            currentNumberOfPilots = nnz(logical(currentMod.ChannelEstimator.PilotMatrix(:, :, iAntenna)));
                            if mod(currentNumberOfPilots, sequenceLength) > 0
                                error('Number of assigned pilot symbols (%.1f) is not devisible by orthogonal pilot sequence length! (%.1f)', currentNumberOfPilots, sequenceLength);
                            end
                            pilotSymbolSequenceTemp = repmat(pilotSymbolsTemp, [ceil(currentNumberOfPilots / sequenceLength), 1]);
                            pilotSymbols{iAntenna} = pilotSymbolSequenceTemp(1:currentNumberOfPilots)./ ...
                                sqrt(normFac(logical(currentMod.ChannelEstimator.PilotMatrix(:, :, iAntenna))));  
                            % assemble matrix of data and pilot symbols
                            modulationMatTemp = zeros(currentMod.WaveformObject.Nr.Subcarriers, currentMod.WaveformObject.Nr.MCSymbols);
                            modulationMatTemp( logical(currentMod.ChannelEstimator.PilotMatrix(:, :, iAntenna))) = pilotSymbols{iAntenna};
                            modulationMatTemp(~logical(sum(currentMod.ChannelEstimator.PilotMatrix, 3)))         = dataSymbolsPrecoded(:, iAntenna);
                            modulationMat(:, :, iAntenna) = modulationMatTemp;
                        end
                        currentMod.PilotSymbols = pilotSymbols;
                    case 'GFDM'
                        % To be added
                        error('GFDM with channel estimation is not yet implemented!');
                    otherwise
                        error('Waveform unknown!');
                end
                
                for iUE=1:length(obj.ReceiverDL)
                    currentLink = Links{obj.ID, obj.ReceiverDL(iUE)};
                    currentLink.Modulator.PilotSymbols = pilotSymbols;
                    if any(currentLink.schedule(:)) && strcmp(currentLink.Type, 'Primary')
                        % the users are always scheduled over the entire bandwidth for MUMIMO; there is no power scale.
                        currentLink.powerScale = 1;
                    end
                end

                transmitSignalUnitPowerPerAntenna = zeros(currentMod.WaveformObject.Nr.SamplesTotal, obj.nAntennaPorts);
                for iAntenna = 1:obj.nAntennaPorts
                    transmitSignalUnitPowerPerAntenna(:, iAntenna) = currentMod.WaveformObject.Modulation(modulationMat(:, :, iAntenna));
                end                               
                transmitSignalUnitPower = transmitSignalUnitPowerPerAntenna;  
            else
                % single user MIMO
                % if multi-user is set to none or MUST, we generate and process the signal for each user separately
                for iUE = 1:length(obj.ReceiverDL)
                    currentLink = Links{obj.ID, obj.ReceiverDL(iUE)};
                    if any(currentLink.schedule(:)) && strcmp(currentLink.Type, 'Primary') && ~currentLink.IsMUSTFarUE
                        currentLink.isScheduled = 1;
                        iScheduledUE = iScheduledUE + 1;
                        nCodewords = length(currentLink.MIMO.LayerMapping);
                        nStreams = currentLink.MIMO.nStreams;

                        % Channel Coding for this user
                        currentLink.InputBits   = cell(nCodewords, 1);
                        currentLink.EncodedBits = cell(nCodewords, 1);
                        for iCodeword = 1:nCodewords
                            currentLink.InputBits{iCodeword}    = randi([0, 1], currentLink.NrInputBits(iCodeword), 1);
                            currentLink.EncodedBits{iCodeword}  = currentLink.ChannelCoder{iCodeword}.encode(currentLink.InputBits{iCodeword});
                        end

                        % If MUST is enabled, get the bits of the farUE
                        if currentLink.IsMUSTNearUE
                            farUELink = Links{obj.ID, currentLink.MUSTFarUE};
                            farUELink.isScheduled = 1;
                            nCodewordsFar = length(farUELink.MIMO.LayerMapping);
                            farUELink.InputBits = cell(nCodewordsFar, 1);
                            farUELink.EncodedBits = cell(nCodewordsFar, 1);
                            for iCodeword = 1:nCodewordsFar
                                farUELink.InputBits{iCodeword} = randi([0, 1], farUELink.NrInputBits(iCodeword), 1);
                                farUELink.EncodedBits{iCodeword} = farUELink.ChannelCoder{iCodeword}.encode(farUELink.InputBits{iCodeword});
                            end
                            farUEEncodedBits = farUELink.EncodedBits;
                        else
                            farUEEncodedBits = cell(nCodewords, 1);
                        end

                        % Symbol Mapping for this user
                        currentMod = currentLink.Modulator;
                        symbolsPerStream = null(1);
                        for iCodeword = 1:nCodewords
                            dataSymbols = currentMod.SignalConstellation{iCodeword}.Bit2Symbol(currentLink.EncodedBits{iCodeword}, farUEEncodedBits{iCodeword});
                            currentLink.TransmitSymbols{iCodeword} = dataSymbols;
                            symbolsPerStream = [symbolsPerStream; reshape(dataSymbols, currentLink.MIMO.LayerMapping(iCodeword), [])]; 
                        end
                        
                        % symbol spreading
                        spreadSymbolsPerStream = zeros(size(symbolsPerStream));
                        for iStream = 1:nStreams
                            spreadSymbolsPerStream(iStream, :) = currentMod.spreadingTransform(symbolsPerStream(iStream, :), currentLink.scheduledSubcarriers);
                        end

                        % MIMO precoding of data symbols
                        dataSymbolsPrecoded = currentLink.MIMO.precoding(spreadSymbolsPerStream.', obj.nAntennaPorts);

                        switch currentMod.Waveform
                            case {'SC', 'OFDM', 'f-OFDM', 'WOLA', 'UFMC', 'FBMC'}
                                pilotSymbols = cell(obj.nAntennas, 1);
                                modulationMat = zeros(currentMod.WaveformObject.Nr.Subcarriers, currentMod.WaveformObject.Nr.MCSymbols, obj.nAntennaPorts);
%                                         pilotsAlphabet = [-1, 1];
                                if strcmp(currentMod.Waveform, 'FBMC')
                                    % employ real valued pilot symbols only for FBMC
                                    orthogonalSequenceType = 'Hadamard';
                                else
                                    orthogonalSequenceType = 'Zadoff-Chu';
                                end

                               normFac = sum(currentMod.ChannelEstimator.PilotMatrix,3);
                                for iAntenna = 1:obj.nAntennaPorts
                                    % assemble orthogonal pilot sequence
                                    sequenceIndex = iAntenna;
                                    sequenceLength = currentMod.ChannelEstimator.orthogonalSequenceLength;
                                    pilotSymbolsTemp = +Utils.generateOrthogonalSequence(sequenceLength, sequenceIndex, orthogonalSequenceType);
                                    currentNumberOfPilots = nnz(logical(currentMod.ChannelEstimator.PilotMatrix(:, :, iAntenna)));
                                    if currentMod.ChannelEstimator.OverlappingPilots && mod(currentNumberOfPilots, sequenceLength) > 0
                                        error('Number of assigned pilot symbols is not devisible by orthogonal pilot sequence length!');
                                    end
                                    pilotSymbolSequenceTemp = repmat(pilotSymbolsTemp, [ceil(currentNumberOfPilots / sequenceLength), 1]);
                                    pilotSymbols{iAntenna} = pilotSymbolSequenceTemp(1:currentNumberOfPilots)./ ...
                                        sqrt(normFac(logical(currentMod.ChannelEstimator.PilotMatrix(:, :, iAntenna))));                                    

                                    % assemble matrix of data and pilot symbols
                                    modulationMatTemp = zeros(currentMod.WaveformObject.Nr.Subcarriers, currentMod.WaveformObject.Nr.MCSymbols);
                                    modulationMatTemp( logical(currentMod.ChannelEstimator.PilotMatrix(:, :, iAntenna)))    = pilotSymbols{iAntenna};
                                    modulationMatTemp(~logical(sum(currentMod.ChannelEstimator.PilotMatrix, 3)))            = dataSymbolsPrecoded(:,iAntenna);
                                    modulationMat(:, :, iAntenna) = modulationMatTemp;
                                end
                                currentMod.PilotSymbols = pilotSymbols;
                            case 'GFDM'
                                % To be added
                                error('GFDM with channel estimation is not yet implemented!');
                            otherwise
                                error('Waveform unknown!');
                        end

                        % modulation for each link
                        transmitSignalUnitPowerPerAntenna = zeros(currentMod.WaveformObject.Nr.SamplesTotal, obj.nAntennaPorts);
                        for iAntenna = 1:obj.nAntennaPorts
                            transmitSignalUnitPowerPerAntenna(:,iAntenna) = currentMod.WaveformObject.Modulation(modulationMat(:,:,iAntenna));
                        end
                        
                        % per user power scaling (such that the total transmit PSD is flat) 
                        currentLink.powerScale = sqrt(currentMod.WaveformObject.Nr.Subcarriers / obj.nTotalScheduledSubcarriers);
                        
                        transmitSignalUnitPowerPerUE(:, :, iScheduledUE) = transmitSignalUnitPowerPerAntenna .* currentLink.powerScale;
                        
                        % both NearUE and FarUE has the same transmit signal
                        if currentLink.IsMUSTNearUE
                            for iCodeword = 1:nCodewords
                                farUELink.TransmitSymbols{iCodeword} = currentLink.TransmitSymbols{iCodeword};
                            end
                            farUELink.Modulator.PilotSymbols = pilotSymbols;   
                            farUELink.powerScale = currentLink.powerScale;
                        end
                        
                    end %is scheduled

                end %for iUE
            
                % combine user signals
                transmitSignalUnitPower = sum(transmitSignalUnitPowerPerUE, 3);
            end
            % rescale to average transmit power
            transmitSignal = transmitSignalUnitPower * 10 ^ ((obj.txPower - 30) / 20);
            
            % analog precoding
            transmitSignal = transmitSignal * obj.analogPrecoder.';

            % Calculate PAPR of transmitted signal
            calculatePAPR(Links{obj.ID, obj.ReceiverDL(1)},transmitSignal);
            
            % Check for nonlinear PA model
            if currentLink.nonlinearity
                transmitSignal = currentLink.applyNonlinearity(transmitSignal);
            end
            
            
            % Just copy it to all connected links. Since they all share the same transmit signal
            for iUE = 1:length(obj.ReceiverDL)
                Links{obj.ID, obj.ReceiverDL(iUE)}.TransmitSignal = transmitSignal;
                Links{obj.ID, obj.ReceiverDL(iUE)}.transmitPower  = obj.txPower;
                Links{obj.ID, obj.ReceiverDL(iUE)}.PAPR           = Links{obj.ID, obj.ReceiverDL(1)}.PAPR;
            end             
        end
    end
    
%% Receive Functions
    methods
        function processReceiveSignal(obj, totalSignal, Links, params, IN)
           % apply analog receive filter
           totalSignal = totalSignal*obj.analogReceiveFilter.';
           % MU-MIMO joint processing
            if ismember(obj.multiuserMode.Uplink, {'ZF-MUMIMO', 'MMSE-MUMIMO', 'MRC-MUMIMO'})
                nUsers = length(obj.TransmitterUL);       
                compositeChannel = [];
                compositeChannelAtPilots = [];
                meanNoisePowerUE = zeros(nUsers,1);
                primaryScheduledLinks = [];
                nPrimaryLinks = 0;
                for iUE = 1:nUsers
                    currentLink = Links{obj.TransmitterUL(iUE), obj.ID};
                    if currentLink.isScheduled && strcmp(currentLink.Type, 'Primary')
                        primaryScheduledLinks = cat(1,primaryScheduledLinks,currentLink);
                        nPrimaryLinks = nPrimaryLinks + 1;
                        pseudoSymbols = currentLink.Modulator.demodulateTimeSignal(totalSignal);
                        [scheduledChannel, compsiteSymbols] = currentLink.estimateScheduledChannel(pseudoSymbols,params, IN);
                        noisePowerUE =    currentLink.Modulator.estimateNoisePower(totalSignal, params.phy.noisePower);
                        meanNoisePowerUE(nPrimaryLinks) = mean(mean(currentLink.Modulator.WaveformObject.GetSymbolNoisePower(noisePowerUE)));
                        compositeChannel = cat(3,compositeChannel,scheduledChannel);
                        compositeChannelAtPilots = cat(3,compositeChannelAtPilots,currentLink.Modulator.channelAtPilots);                      
                    end
                end                
                compositeChannelAtPilotsDL = permute(compositeChannelAtPilots,[3,2,1]);
                compositeChannelAtPilotsUL = permute(compositeChannelAtPilots,[2,3,1]);
                compositeChannel    = permute(compositeChannel,[2,3,1]);
                nSymbols            = size(compsiteSymbols,1);
                meanNoisePower      = mean(meanNoisePowerUE);
                
                linksList = 1:nPrimaryLinks;
                for iIC = 1:(obj.multiuserMode.UplinkIC+1) % over possible IC iterations
                    equalizedSymbols = zeros(length(linksList),nSymbols);
                    noiseScaling     = zeros(length(linksList),nSymbols);

                    switch obj.multiuserMode.Uplink
                        case 'ZF-MUMIMO'
                            for iSymbol = 1:nSymbols
                                H = compositeChannel(:, :, iSymbol);
                                ZF_Equalizer = (H' * H) \ H';
                                equalizedSymbols(:, iSymbol) = ZF_Equalizer * compsiteSymbols(iSymbol, :).';
                                noiseScaling(:, iSymbol) = sum(ZF_Equalizer .* conj(ZF_Equalizer), 2);
                            end
                        case 'MMSE-MUMIMO'
                            for iSymbol = 1:nSymbols
                                H = compositeChannel(:,:,iSymbol);
                                MMSE_Equalizer = (H'*H + meanNoisePower*eye(size(H, 2)))\H';
                                equalizedSymbols(:,iSymbol) = MMSE_Equalizer * compsiteSymbols(iSymbol,:).';
                                noiseScaling(:, iSymbol) = sum(MMSE_Equalizer.*conj(MMSE_Equalizer),2);
                            end
                        case 'MRC-MUMIMO'
                            for iSymbol = 1:nSymbols
                                H = compositeChannel(:,:,iSymbol);
                                MRC_Equalizer = H';
                                powerScaling = diag(diag(H'*H).^-1);
                                equalizedSymbols(:,iSymbol) = powerScaling*MRC_Equalizer * compsiteSymbols(iSymbol,:).';
                                noiseScaling(:, iSymbol) = sum(MRC_Equalizer.*conj(MRC_Equalizer),2);
                            end
                        otherwise 
                            error('Multiuser MIMO mode unknown.');
                    end

                    % Feedback calculation
                    if ~isempty(primaryScheduledLinks(1).Feedback) && primaryScheduledLinks(1).Feedback.Cqi.enable && (strcmp(primaryScheduledLinks(1).frameStructure, 'TDD') || primaryScheduledLinks(1).Feedback.delay > 0)
                        compositePrecoderAtPilotsDL  = [];
                        compositeEqualizerAtPilotsUL = [];
                        % Feedback
                        nPilot = size(compositeChannelAtPilotsDL,3);
                        for iPilot = 1:nPilot
                            % Downlink precoder 
                            if strcmp(primaryScheduledLinks(1).frameStructure, 'TDD') && iIC == 1 % Done only once before possible IC
                                H = compositeChannelAtPilotsDL(:,:,iPilot);
                                switch obj.multiuserMode.Downlink 
                                    case 'ZF-MUMIMO'
                                        F = 1/sqrt(obj.nAntennas)*exp(1i*angle(H'));
                                        Heq = H*F;
                                        precodingMatrix = F*Heq'/(Heq*Heq');
                                        normFac = norm(precodingMatrix, 'fro');
                                        precodingMatrix = precodingMatrix/normFac;
                                    case 'MRT-MUMIMO'
                                        normalizationMatrix = diag(sqrt(sum(abs(H').^2, 1)).^-1) / sqrt(nPrimaryLinks);
                                        precodingMatrix = H' * normalizationMatrix;
                                    case 'BD-MUMIMO'
                                        precodingMatrix = null(1);
                                        startIndexStreams = 1;
                                        startIndexAntennas = 1;
                                        nStream = Links{obj.ID, obj.ReceiverDL(1)}.MIMO.nStreams;
                                        nRxAntennas = Links{obj.ID, obj.ReceiverDL(1)}.nRxAntennas;
                                        H_bar = H(startIndexAntennas+nRxAntennas:end, :);

                                        % cancel inter user interference
                                        [~, S, V] = svd(H_bar);
                                        V_null = V(:, size(diag(S), 1) + 1:end);

                                        % cancel multi-stream interference
                                        [~, ~, V] = svd(H * V_null);
                                        V_one = V(:, 1:nStream );
                                        precodingMatrixUserk = V_null * V_one / sqrt(obj.nAntennas);
                                        precodingMatrix = [precodingMatrix, precodingMatrixUserk];
                                        startIndex = startIndex + nStreams;
                                        startIndexAntennas = startIndexAntennas + nRxAntennas;
                                        for iLink = 2:nPrimaryLinks
                                            nStream = primaryScheduledLinks(iLink).MIMO.nStreams;
                                            H_bar = [H(1:startIndexAntennas - 1, :); H(startIndexAntennas + nRxAntennas:end, :)];
                                            % cancel inter user interference
                                            [~, S, V] = svd(H_bar);
                                            V_null = V(:, size(diag(S), 1) + 1:end);
                                            % cancel multi-stream interference
                                            [~, ~, V] = svd(H * V_null);
                                            V_one = V(:, 1 : nStream);
                                            precodingMatrixUserk =  V_null * V_one / sqrt(obj.nAntennas);
                                            precodingMatrix = [precodingMatrix, precodingMatrixUserk];
                                            startIndex = startIndex + nStreams;
                                            startIndexAntennas = startIndexAntennas + nRxAntennas;
                                        end
                                    otherwise
                                        error('Multi-user MIMO mode not supported')
                                end
                                compositePrecoderAtPilotsDL  = cat(3,compositePrecoderAtPilotsDL,precodingMatrix);
                            end

                            % Uplink FB precoder for delay > 0  
                            if primaryScheduledLinks(1).Feedback.delay > 0
                                H = compositeChannelAtPilotsUL(:,:,iPilot);
                                switch obj.multiuserMode.Uplink
                                    case 'ZF-MUMIMO'                            
                                        equlizerUL = (H' * H) \ H';                               
                                    case 'MMSE-MUMIMO'
                                        equlizerUL = (H'*H + meanNoisePower*eye(size(H,2)))\H';
                                    case 'MRC-MUMIMO'
                                        equlizerUL = diag(diag(H'*H).^-1)*H';
                                    otherwise 
                                        error('Multiuser MIMO mode unknown.');
                                end
                                compositeEqualizerAtPilotsUL = cat(3,compositeEqualizerAtPilotsUL,equlizerUL);
                            end
                        end
     
                        % Update channel, precoder/equalizer and interferer matrix for MU-MIMO feedback
                        % Downlink
                        for idx = 1:length(linksList)
                            iLink = linksList(idx);
                            % Uplink
                            currentLink = primaryScheduledLinks(iLink);
                            if primaryScheduledLinks(iLink).Feedback.delay > 0
                                currentLink.Feedback.Csi = compositeChannelAtPilotsUL(:,idx,:);
                                currentLink.Feedback.muMimoMatrix = compositeEqualizerAtPilotsUL(idx,:,:);
                                currentLink.Feedback.interfererMatrix = compositeChannelAtPilotsUL;
                                currentLink.Feedback.interfererMatrix(:,idx,:) = [];
                            end
                            % Downlink
                            if strcmp(currentLink.frameStructure, 'TDD') && iIC == 1 % Done only once before possible IC
                                currentDL = Links{currentLink.Receiver, currentLink.Transmitter};
                                currentDL.Feedback.Csi = compositeChannelAtPilotsDL(iLink,:,:);
                                currentDL.Feedback.muMimoMatrix = compositePrecoderAtPilotsDL(:,iLink,:);
                                currentDL.Feedback.interfererMatrix = compositePrecoderAtPilotsDL;
                                currentDL.Feedback.interfererMatrix(:,iLink,:) = [];
                                currentDL.Feedback.channelError = currentLink.channelError;  
                            end
                        end 
                    end
                    % Detection
                    indrem = [];
                    for idx = 1:length(linksList)
                        iLink = linksList(idx);
                        currentLink = primaryScheduledLinks(iLink);
                        noisePower = meanNoisePowerUE(nPrimaryLinks);
                        scaledNoisePower = noisePower*noiseScaling(idx, :);
                        currentLink.detect(0, equalizedSymbols(idx, :).', scaledNoisePower);
                        
                        if obj.multiuserMode.UplinkIC > 0 
                            % If IC is enabled, reconstruct the received signal of the correcttly 
                            % detected UEs and subtract it from the received signal
                            if currentLink.FrameError == 0
                                reconstructedSymbols = obj.reconstructUESignal(currentLink);
                                subSig = nan(size(compsiteSymbols));
                                for iA = 1:size(compsiteSymbols,2)
                                    subSig(:, iA) = reconstructedSymbols .* squeeze(compositeChannel(iA, idx, :)); 
                                end
                                compsiteSymbols = compsiteSymbols - subSig;
                                indrem = [indrem idx];
                            end
                        
                        end
                    end              
                    % Remove the contribution from the composite channel
                    compositeChannel(:, indrem, :) = []; 
                    compositeChannelAtPilotsUL(:, indrem, :) = [];

                    linksList(indrem) = []; 
                    if isempty(linksList) || isempty(indrem)
                        break;
                    end
                end
            else
               % SU-MIMO process the users one by one
                for iUE = 1:length(obj.TransmitterUL)
                    currentLink = Links{obj.TransmitterUL(iUE), obj.ID};
                    if currentLink.isScheduled && strcmp(currentLink.Type, 'Primary')
                        pseudoSymbols = currentLink.Modulator.demodulateTimeSignal(totalSignal);
                        [scheduledChannel, scheduledPseudoSymbols] = currentLink.estimateScheduledChannel(pseudoSymbols,params, IN);
                        noisePower = currentLink.Modulator.estimateNoisePower(totalSignal, params.phy.noisePower);
                        currentLink.detect(scheduledChannel, scheduledPseudoSymbols, noisePower);
                    end
                end % iUE
            end
        end
        
        
        
        
        function reconSymbols = reconstructUESignal(obj, currentLink)
            % Reconstruct the transmit data symbols of the UE
            nCodewords              = length(currentLink.MIMO.LayerMapping);
            codedBits               = cell(nCodewords, 1);
            dataSymbols             = cell(nCodewords, 1);
            spreadSymbolsPerStream  = null(1);
            for iCodeword = 1:nCodewords
                codedBits{iCodeword} = currentLink.ChannelCoder{iCodeword}.encode(currentLink.DecodedBits{iCodeword});
                dataSymbols{iCodeword} = currentLink.Modulator.SignalConstellation{iCodeword}.Bit2Symbol(codedBits{iCodeword});
                spreadSymbols = currentLink.Modulator.spreadingTransform(dataSymbols{iCodeword}, currentLink.scheduledSubcarriers);
                spreadSymbolsPerStream = [spreadSymbolsPerStream;reshape(spreadSymbols, currentLink.MIMO.LayerMapping(iCodeword), [])];                    
            end
            if ismember(currentLink.multiuserMode,{'ZF-MUMIMO','MMSE-MUMIMO','MRC-MUMIMO'})
                reconSymbols = spreadSymbolsPerStream.';
            else
                reconSymbols = currentLink.MIMO.precoding(spreadSymbolsPerStream.', obj.nAntennaPorts);
            end
        end
        
        
    end
    
%% Update parameters
    methods
        function updateSpatialProcessing(obj, Links, simParams, IN)
            % update the phases of the RIS elements
            for iIN = 1:length(obj.intermediateNodes)
                phaseShiftPerElement = 2*pi*(0.5-rand(1,obj.intermediateNodes{iIN}.nElements));
                obj.intermediateNodes{iIN}.update(phaseShiftPerElement);
            end
            % DL in FDD mode
            if ismember(obj.multiuserMode.Downlink, {'ZF-MUMIMO', 'MRT-MUMIMO', 'BD-MUMIMO'}) || ismember(obj.multiuserMode.Uplink, {'ZF-MUMIMO', 'MRC-MUMIMO', 'MMSE-MUMIMO'})
                primaryScheduledDL = [];
                for iUE = 1:length(obj.ReceiverDL)
                    Links{obj.ID, obj.ReceiverDL(iUE)}.transmitPower = obj.txPower;
                    currentLink = Links{obj.ID, obj.ReceiverDL(iUE)};
                    if any(currentLink.schedule(:)) && strcmp(currentLink.Type, 'Primary')
                        currentLink.MIMO.setNStreams(simParams.modulation.nStreams(currentLink.ID));
                        primaryScheduledDL = cat(1,primaryScheduledDL,currentLink);
                    end
                end
                nPrimaryScheduledDL = length(primaryScheduledDL);
                if nPrimaryScheduledDL > 0 &&  ismember(obj.multiuserMode.Downlink, {'ZF-MUMIMO', 'MRT-MUMIMO', 'BD-MUMIMO'}) && strcmp(primaryScheduledDL(1).frameStructure, 'FDD') && ~isempty(primaryScheduledDL(1).Feedback) && primaryScheduledDL(1).Feedback.Cqi.enable
                    % Joint signal procssing for multi-user MIMO
                    compositeChannelAtPilots = [];
                    for iLink = 1:nPrimaryScheduledDL
                            currentLink = primaryScheduledDL(iLink);
                            nStreams = currentLink.MIMO.nStreams;   
                                % FDD mode: use the actual channel of the link
                            channel = currentLink.getTheTotalChannel(simParams, IN); 
                           channelAtPilots =  reshape(channel( repmat(logical( sum(currentLink.Modulator.ChannelEstimator.PilotMatrix,3)),...
                                         1,1,size(channel,3),size(channel,4))),[],size(channel,3),size(channel,4));

                            compositeChannelAtPilots = cat(1,compositeChannelAtPilots,permute(channelAtPilots,[2,3,1]));
                    end
                    compositePrecoder = [];
                    for iPilot = 1:size(compositeChannelAtPilots,3)
                        H = compositeChannelAtPilots(:,:,iPilot);
                        switch obj.multiuserMode.Downlink 
                            case 'ZF-MUMIMO'
                                    F = 1/sqrt(obj.nAntennas)*exp(1i*angle(H'));
                                    Heq = H*F;
                                    precodingMatrix = F*Heq'/(Heq*Heq');
                                    normFac = norm(precodingMatrix, 'fro');
                                    precodingMatrix = precodingMatrix/normFac;
                            case 'MRT-MUMIMO'
                                normalizationMatrix = diag(sqrt(sum(abs(H').^2, 1)).^-1) / sqrt(nPrimaryScheduledDL);
                                precodingMatrix = H' * normalizationMatrix;
                            case 'BD-MUMIMO'
                                precodingMatrix = null(1);
                                startIndexStreams = 1;
                                startIndexAntennas = 1;
                                nStream = Links{obj.ID, obj.ReceiverDL(1)}.MIMO.nStreams;
                                nRxAntennas = Links{obj.ID, obj.ReceiverDL(1)}.nRxAntennas;
                                H_bar = H(startIndexAntennas + nRxAntennas:end, :);

                                % cancel inter user interference
                                [~, S, V] = svd(H_bar);
                                V_null = V(:, size(diag(S), 1) + 1:end);

                                % cancel multi-stream interference
                                [~, ~, V] = svd(H * V_null);
                                V_one = V(:, 1:nStream );
                                precodingMatrixUserk = V_null * V_one / sqrt(obj.nAntennas);
                                precodingMatrix = [precodingMatrix, precodingMatrixUserk];
                                startIndexStreams = startIndexStreams + nStreams;
                                startIndexAntennas = startIndexAntennas + nRxAntennas;
                                for iLink = 2:nPrimaryScheduledDL
                                    nStream = primaryScheduledDL(iLink).MIMO.nStreams;
                                    nRxAntennas = Links{obj.ID, obj.ReceiverDL(iLink)}.nRxAntennas;
                                    H_bar = [H(1:startIndexAntennas - 1, :); H(startIndexAntennas + nRxAntennas:end, :)];
                                    % cancel inter user interference
                                    [~, S, V] = svd(H_bar);
                                    V_null = V(:, size(diag(S), 1) + 1:end);
                                    % cancel multi-stream interference
                                    [~, ~, V] = svd(H * V_null);
                                    V_one = V(:, 1 : nStream);
                                    precodingMatrixUserk =  V_null * V_one / sqrt(obj.nAntennas);
                                    precodingMatrix = [precodingMatrix, precodingMatrixUserk];
                                    startIndexStreams = startIndexStreams + nStreams;
                                    startIndexAntennas = startIndexAntennas + nRxAntennas;
                                end
                            otherwise
                                error('Multi-user MIMO mode not supported')
                        end
                        compositePrecoder = cat(3,compositePrecoder,precodingMatrix);
                    end
                    startIndexPrecoder = 1;
                    startIndexChannel = 1;
                    for iLink = 1:nPrimaryScheduledDL
                        currentLink = primaryScheduledDL(iLink);
                        endIndexChannel = startIndexChannel + currentLink.nRxAntennas -1;
                        currentLink.Feedback.Csi = compositeChannelAtPilots(startIndexChannel:endIndexChannel,:,:);
                        startIndexChannel = endIndexChannel + 1;
                        endIndexPrecoder = startIndexPrecoder + currentLink.MIMO.nStreams -1;
                        currentLink.Feedback.muMimoMatrix = compositePrecoder(:,startIndexPrecoder:endIndexPrecoder,:);                         
                        currentLink.Feedback.interfererMatrix = compositePrecoder(:,:,:);
                        currentLink.Feedback.interfererMatrix(:,startIndexPrecoder:endIndexPrecoder,:) = [];
                        startIndexPrecoder = endIndexPrecoder +1;
                    end
                end % end DL FDD FB
                % UL FB delay 0
                primaryScheduledUL = [];
                for iUE = 1:length(obj.TransmitterUL)
                    Links{obj.TransmitterUL(iUE),obj.ID}.transmitPower = obj.txPower;
                    currentLink = Links{obj.TransmitterUL(iUE), obj.ID};
                    if any(currentLink.schedule(:)) && strcmp(currentLink.Type, 'Primary') 
                        primaryScheduledUL = cat(1,primaryScheduledUL,currentLink);
                    end
                end
                compositeChannelAtPilots = [];
                compositeEqualizerAtPilots = [];
                nPrimaryScheduledUL = length(primaryScheduledUL);
                if nPrimaryScheduledUL > 0 &&  ismember(obj.multiuserMode.Uplink, {'ZF-MUMIMO', 'MRC-MUMIMO', 'MMSE-MUMIMO'}) && ~isempty(primaryScheduledUL(1).Feedback) && primaryScheduledUL(1).Feedback.Cqi.enable && primaryScheduledUL(1).Feedback.delay == 0
                    meanNoisePowerUE = zeros(nPrimaryScheduledUL,1);
                    for iLink = 1:nPrimaryScheduledUL
                        currentLink = primaryScheduledUL(iLink);
                        channel = currentLink.getTheTotalChannel(simParams, IN);
                        channelAtPilots = reshape(channel( repmat(logical( sum(currentLink.Modulator.ChannelEstimator.PilotMatrix,3)),...
                        1,1,size(channel,3),size(channel,4))),[],size(channel,3),size(channel,4));
                        compositeChannelAtPilots = cat(3,compositeChannelAtPilots,channelAtPilots);     
                        meanNoisePowerUE(iLink) = mean(mean(currentLink.Modulator.WaveformObject.GetSymbolNoisePower(simParams.phy.noisePower)));
                    end
                    meanNoisePower      = mean(meanNoisePowerUE);
                    compositeChannelAtPilots = permute(compositeChannelAtPilots,[2,3,1]);
                    nPilot = size(compositeChannelAtPilots,3);
                    for iPilot = 1:nPilot
                        H = compositeChannelAtPilots(:,:,iPilot);
                        switch obj.multiuserMode.Uplink
                            case 'ZF-MUMIMO'                            
                                    equlizerUL = (H' * H) \ H';                               
                            case 'MMSE-MUMIMO'
                                    equlizerUL = (H'*H + meanNoisePower*eye(nPrimaryScheduledUL))\H';
                            case 'MRC-MUMIMO'
                                    equlizerUL = diag(diag(H'*H).^-1)*H';
                            otherwise 
                                error('Multiuser MIMO mode unknown.');
                        end
                        compositeEqualizerAtPilots = cat(3,compositeEqualizerAtPilots,equlizerUL); 
                    end
                    for iLink = 1:nPrimaryScheduledUL
                        currentLink = primaryScheduledUL(iLink);
                        % Update channel, precoder/equalizer and interferer matrix for MU-MIMO feedback
                        % Uplink
                        currentLink.Feedback.Csi = compositeChannelAtPilots(:,iLink,:);
                        currentLink.Feedback.muMimoMatrix = compositeEqualizerAtPilots(iLink,:,:);
                        currentLink.Feedback.interfererMatrix = compositeChannelAtPilots;
                        currentLink.Feedback.interfererMatrix(:,iLink,:) = [];
                    end   
                end % end uplink 0 delay feedback
            end
               
        end % end spatial processing 
    end
       
end

