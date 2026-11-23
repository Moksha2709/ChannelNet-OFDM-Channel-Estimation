classdef Feedback < handle
    %% The Feedback Class
    %   Mariam Mussbah
    %   
    %   (c) 2017 Institute of Telecommunications, TU Wien.
    %   www.nt.tuwien.ac.at
    %% The Feedback Properties
    properties
        delay                   % Feedback delay
        Pmi                     % Precoding Matrix Indicator
        Ri                      % Rank Indicator
        Cqi                     % Channel Quality Indicator
        nRxAntennaPorts             % Number of receive antenna
        nTxAntennaPorts             % Number of transmit antenna
        codebook                % Code Book
        Csi                     % Full Channel Matrix
        defaultPrecodingMatrix   
        nStreams
        interfererMatrix
        muMimoMatrix
        layerMappingTable
        channelError 
    end
    %% 
    methods
        function obj = Feedback(feedback, nTxAntennaPorts, nRxAntennaPorts, layerMappingTable, varargin)
            % Class constructor
            obj.nRxAntennaPorts             = nRxAntennaPorts;
            obj.nTxAntennaPorts             = nTxAntennaPorts;
            obj.delay                   = feedback.delay;
            obj.Pmi.enable              = feedback.pmi;
            obj.Ri.enable               = feedback.ri;
            obj.Cqi.enable              = feedback.cqi;
            obj.layerMappingTable       = layerMappingTable;
            if nargin >= 5
                obj.nStreams = varargin{1};
            else
                obj.nStreams  = 1;
            end
            if nargin == 6
               obj.defaultPrecodingMatrix  = varargin{2};  
            end
            if obj.delay==0
                arraysize = 1;
            else
                arraysize = obj.delay;
            end
            obj.Pmi.pmiArray            = ones(arraysize, 1);
            obj.Ri.riArray              = ones(arraysize, 1);
            obj.Csi                     = cell(1, arraysize);
            obj.Pmi.counter             = 101;
            obj.Pmi.currentSector       = 1;
            if feedback.cqi 
                obj.Cqi.cqiArray = cell(1, arraysize);
                nCodewords = length(obj.layerMappingTable{obj.nStreams});
                obj.Cqi.cqiArray(1, 1:end) = {ones(nCodewords, 1)};
                switch feedback.averager.Type
                    case 'eesm'
                        obj.Cqi.averager = Feedback.eesmAverager(feedback.averager.EESMbetas,...
                                                                 feedback.averager.MCS_values);
                    case 'miesm'
                        obj.Cqi.averager = Feedback.miesmAverager(feedback.averager.MIESMbetas,...
                                                                  feedback.averager.MCS_values);
                    otherwise
                        error('Averager type not supported!');
                end
                obj.Cqi.mappingTable = feedback.CqiMappingTable;
            end
            obj.Ri.max = min(nTxAntennaPorts, nRxAntennaPorts);
                        
        end
        

        function updateFeedback(obj, channel, pilotMatrix, noisePower, modulationOrder)
            % This function updates the PMI, RI and CQI for the single user mimo and MUST.
            if ~isempty(channel)
                % channel on pilot position, used for CLSM
                scheduledChannel = reshape( channel( repmat(logical( sum(pilotMatrix,3)), 1, 1, obj.nRxAntennaPorts,  obj.nTxAntennaPorts) ), [], obj.nRxAntennaPorts, obj.nTxAntennaPorts );
                % update PMI and RI
                if obj.Pmi.enable
                    [pmi,ri] = obj.getPmi(scheduledChannel, noisePower);

                    obj.Pmi.pmiArray(1:end-1) = obj.Pmi.pmiArray(2:end);
                    obj.Pmi.pmiArray(end) = pmi;
                    
                    obj.Ri.riArray(1:end-1) = obj.Ri.riArray(2:end);
                    obj.Ri.riArray(end) = ri; 
                end % Pmi.enable
                
                % update RI
                if ~obj.Pmi.enable && obj.Ri.enable
                    ri = obj.getRI(scheduledChannel, noisePower);
                    obj.Ri.riArray(1:end-1) = obj.Ri.riArray(2:end);
                    obj.Ri.riArray(end) = ri; 
                end
                
                % update CQI
                if obj.Cqi.enable
                    if obj.Pmi.enable
                        cqi = obj.getCqi(scheduledChannel, obj.codebook.W{obj.Pmi.pmiArray(end)}, noisePower, modulationOrder);
                    elseif obj.Ri.enable
                        cqi = obj.getCqi(scheduledChannel, [], noisePower, modulationOrder);
                    else
                        cqi = obj.getCqi(scheduledChannel, obj.defaultPrecodingMatrix, noisePower, modulationOrder);
                    end
                    obj.Cqi.cqiArray(1:end-1) = obj.Cqi.cqiArray(2:end);
                    obj.Cqi.cqiArray{end} = cqi;
                end % update cqi
            end 
        end
        
        function updateFeedbackDL(obj, noisePower, modulationOrder)   
            % This fucntion updates the downlink CQI for multi-user mimo.
            if ~isempty(obj.muMimoMatrix)
                channel = obj.Csi;
                precodingMatrix = obj.muMimoMatrix;
                interferPrecodingMatrix = obj.interfererMatrix;
                if isempty(obj.channelError)
                    obj.channelError = zeros(size(channel,1),size(channel,2));
                end
                % update CQI
                if obj.Cqi.enable                    
                    [~,RI,N] = size(precodingMatrix);
                    sinr = zeros(N, RI);
                    for iRE = 1:N                        
                        singleEffectiveChannel = channel(:,:,iRE) * precodingMatrix(:,:,iRE);
                        equalizer = pinv(singleEffectiveChannel' * singleEffectiveChannel)*...
                            singleEffectiveChannel';
                        K = equalizer*singleEffectiveChannel;
                        
                        mumimoInterference = equalizer*channel(:,:,iRE)*interferPrecodingMatrix(:,:,iRE);
                        channelEstimationErrorNoise =  equalizer*obj.channelError*[precodingMatrix(:,:,iRE),interferPrecodingMatrix(:,:,iRE)];
                        
                        for iLayer = 1:size(precodingMatrix,2)
                            interStreamInterference = sum(abs(K(iLayer,:)).^2)-abs(K(iLayer,iLayer)).^2; %interstream interference
                            noise = noisePower*sum(abs(equalizer(iLayer, :)).^2); %noise
                            interUserInterfernce = sum(abs(mumimoInterference(iLayer,:)).^2);
                            estimationErrorNoise = sum(abs(channelEstimationErrorNoise(iLayer,:)).^2);                                
                            sinr(iRE,iLayer) = abs(K(iLayer,iLayer))^2/(interStreamInterference + 2*(interUserInterfernce + estimationErrorNoise) + noise);

                        end %layers
                    end
                    cqi = obj.mapSnrToCqi(sinr, modulationOrder);
                end
                    obj.Cqi.cqiArray(1:end-1) = obj.Cqi.cqiArray(2:end);
                    obj.Cqi.cqiArray{end} = cqi;
            end % update cqi
        end
        
        function updateFeedbackUL(obj, noisePower, modulationOrder)
            % updateFeedbackUL updates the uplink CQI for multi-user mimo.
            if ~isempty(obj.muMimoMatrix)
                channel = obj.Csi;
                equalizer = obj.muMimoMatrix;
                interferChannelMatrix = obj.interfererMatrix;
                % update CQI
                if obj.Cqi.enable
                    RI = size(equalizer,1);
                    N  = size(channel,3);
                    sinr = zeros(N, RI);
                    for iRE = 1:N                        
                        singleEffectiveChannel = channel(:,:,iRE);
                        K = equalizer(:,:,iRE)*singleEffectiveChannel;                       
                        mumimoInterference = equalizer(:,:,iRE)*interferChannelMatrix(:,:,iRE);                        
                        for iLayer = 1:size(equalizer,1)
                            interStreamInterference = sum(abs(K(iLayer,:)).^2)-abs(K(iLayer,iLayer)).^2; %interstream interference
                            noise = noisePower*sum(abs(equalizer(iLayer,:, iRE)).^2,2); %noise
                            interUserInterfernce = sum(abs(mumimoInterference(iLayer,:).^2));                               
                            sinr(iRE,iLayer) = abs(K(iLayer,iLayer))^2/(interStreamInterference + noise + 2*interUserInterfernce);
                        end %layers
                    end
                    cqi = obj.mapSnrToCqi(sinr, modulationOrder);
                end
                obj.Cqi.cqiArray(1:end-1) = obj.Cqi.cqiArray(2:end);
                obj.Cqi.cqiArray{end} = cqi;
            end % update cqi
        end
        
        function [precodingMatrix] = getPrecodingMatrix(obj, index)
            if index == 0
                precodingMatrix = obj.defaultPrecodingMatrix;
            elseif index <= size(obj.codebook.W, 2)
                precodingMatrix = obj.codebook.W{index};
            else
                warning('index exceeds codebook size');
            end
        end
    end % public methods

    methods (Access = private)

        function [maxIndex,Ri] = getPmi(obj, scheduledChannel, noisePower)
            % getPmi calculates the PMI for the given channel matrix
            % 'scheduledChannel' and the noise Power 'noisePower'

            codebookSize = size(obj.codebook.W, 2);            
            maxMutualInformation = 0;
            maxIndex    = 1;
            startIndex  = 1;
            endIndex    = codebookSize;
            obj.Pmi.counter = 0;
            for index = startIndex:endIndex
                 precodingMatrix = obj.codebook.W{index};
                 if rank(precodingMatrix) <= obj.Ri.max
                        mutualInformation = 0;
                        for iRE = 1:size(scheduledChannel,1)
                            singleEffectiveChannel = reshape(scheduledChannel(iRE,:,:), [obj.nRxAntennaPorts,obj.nTxAntennaPorts]) * precodingMatrix;
                            equalizer = pinv(singleEffectiveChannel' * singleEffectiveChannel) * singleEffectiveChannel';
                            K = equalizer*singleEffectiveChannel;
                            for iLayer = 1:size(K,1)
                                interStreamInterference = sum(abs(K(iLayer,:)).^2)-abs(K(iLayer,iLayer)).^2; % interstream interference
                                noise = noisePower*sum(abs(equalizer(iLayer,:)).^2); % noise enhancement
                                SINR = abs(K(iLayer,iLayer))^2/(interStreamInterference+noise);
                                mutualInformation = mutualInformation+log2(1+SINR);
                            end
                        end % iter over all RE
                        if(mutualInformation >= maxMutualInformation)
                            maxMutualInformation = mutualInformation;
                            maxIndex = index;
                        end                    
                end
            end %iter over all codebooks
            Ri = rank(obj.codebook.W{maxIndex});
            obj.Pmi.counter = obj.Pmi.counter + 1;
            obj.Pmi.currentSector = ceil(maxIndex);
        end %getPMI
        
        function [cqi] = getCqi(obj, scheduledChannel, precodingMatrix, noisePower, modulationOrder)
            % getCqi calculates the CQI for the given channel matrix
            % 'scheduledChannel' and the noise Power 'noisePower'
            N = size(scheduledChannel, 1);
            if isempty(precodingMatrix)
                RI = obj.Ri.riArray(end);
                iLayer = 1:N;
                if size(obj.codebook.W, 1)==4
                    k = mod(floor((iLayer - 1) / RI), 4)+ 1;
                else
                    k = ones(1,N);
                end                
                p = mod(iLayer - 1, RI) + 1;
                OLSM = true;
            else
                RI = rank(precodingMatrix);
                OLSM = false;
            end
            sinr = zeros(N, RI);
            for iRE = 1:N
                if OLSM
                   precodingMatrix = obj.codebook.W{k(iRE), RI} * (obj.codebook.D{RI}).^(p(iRE)) * obj.codebook.U{RI};
                end
                
                chan = reshape(scheduledChannel(iRE,:,:), [obj.nRxAntennaPorts,...
                                                obj.nTxAntennaPorts]);
                singleEffectiveChannel = chan * precodingMatrix;
                equalizer = pinv(singleEffectiveChannel' * singleEffectiveChannel)*...
                                    singleEffectiveChannel';
                K = equalizer*singleEffectiveChannel;
                for iLayer = 1:size(precodingMatrix,2)
                        interStreamInterference = sum(abs(K(iLayer,:)).^2)-abs(K(iLayer,iLayer)).^2; %interstream interference
                        noise = noisePower*sum(abs(equalizer(iLayer, :)).^2); %noise
                        sinr(iRE,iLayer) = abs(K(iLayer, iLayer))^2/(interStreamInterference + noise);

                end %layers
            end
            cqi = obj.mapSnrToCqi(sinr, modulationOrder); 
            %disp(cqi);
        end %getCQI
        
        function cqi = mapSnrToCqi(obj, sinr, modulationOrder)
            % mapSnrToCqi maps the SINR vector of each layer to an
            % equivalent effective SNR and then returns the corresponding CQI
            nLayers = size(sinr, 2);
            mappingTable = obj.layerMappingTable{nLayers}; % Mapping table for l layers
            nCodewords = length(mappingTable);
            cqi = zeros(nCodewords, 1);
            endLayer = 0;
            if nLayers>1
                for iCodeword = 1:nCodewords
                    startLayer = endLayer + 1;
                    endLayer = endLayer + mappingTable(iCodeword);
                    sinrPerCodeword = sinr(:, startLayer:endLayer);
                    effSNR = obj.Cqi.averager.average(sinrPerCodeword(:), modulationOrder);
                    temp = zeros(size(obj.Cqi.averager.MCS_values));
                    temp(obj.Cqi.mappingTable(obj.Cqi.averager.MCS_values) <= effSNR) = 1;
                    cqi(iCodeword) = find(temp, 1, 'last');
                    if isempty(cqi(iCodeword))
                        cqi(iCodeword) = 1;
                    end
                end
            else
                effSNR = obj.Cqi.averager.average(sinr, modulationOrder);
                temp = zeros(size(obj.Cqi.averager.MCS_values));
                temp(obj.Cqi.mappingTable(obj.Cqi.averager.MCS_values) <= effSNR) = 1;
                cqi = find(temp, 1, 'last');
                if isempty(cqi)
                    cqi = 1;
                end
            end
        end % mapSnrToCqi
        
         function maxRI = getRI(obj, scheduledChannel, noisePower)
                    
            maxMutualInformation = 0;
            maxRI = 1;
            l = 1:size(scheduledChannel,1);            
            for RI = 1:obj.Ri.max
                        if size(obj.codebook.W,1)==4
                            k = mod(floor((l-1)/RI),4)+1;
                        else
                            k=ones(1,size(scheduledChannel,1));
                        end
                            p = mod(l-1,RI)+1;

                        mutualInformation = 0;
                        for n = 1:size(scheduledChannel,2)
                            precodingMatrix = obj.codebook.W{k(n),RI}*(obj.codebook.D{RI}).^(p(n))*obj.codebook.U{RI};
                            singleEffectiveChannel = reshape(scheduledChannel(n,:,:),...
                                        [obj.nRxAntennaPorts,obj.nTxAntennaPorts])* precodingMatrix;
                            equalizer = pinv(singleEffectiveChannel' * singleEffectiveChannel)...
                                        * singleEffectiveChannel';
                            K = equalizer*singleEffectiveChannel;
                            for iLayer = 1:size(K,1)
                                a = sum(abs(K(iLayer,:)).^2)-abs(K(iLayer,iLayer))^2; % interstream interference
                                b = noisePower*sum(abs(equalizer(iLayer,:)).^2); % noise enhancement
                                SINR = abs(K(iLayer,iLayer))^2/(a+b);
                                mutualInformation = mutualInformation+log2(1+SINR);
                            end
                        end % end n
                        
                        if mutualInformation > maxMutualInformation
                            maxMutualInformation = mutualInformation;
                            maxRI = RI;
                        end                    
                
            end % end iter RI 

         end % end getRI
        
    end %methods
    
    
end

