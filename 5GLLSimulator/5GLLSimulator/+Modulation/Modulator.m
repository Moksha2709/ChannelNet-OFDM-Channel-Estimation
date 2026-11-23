classdef Modulator < handle
%% The Modulator Class (Modulator)
%   Authors
%     - ...
%     - ...
%     - ...
%   (c) 2016 Institute of Telecommunications, TU Wien.
%   www.nt.tuwien.ac.at 

%% The Modulator Properties

% Parameters
    properties
        Waveform                        % Waveform: {'OFDM', 'f-OFDM', 'FBMC', 'UFMC', 'GFDM'}
        ChannelEstimationMethod         % the channel estimation method: {'Approximate-Perfect', 'PilotAided'}
        noisePowerEstimation            % if the noise power is estimated {true,false}    
        ReceiverTypeMIMO                % The MIMO receiver method: {'ZF', 'MMSE', 'ML', 'Sphere'}        
        PilotSymbols                    % tranmitted pilot symbols
        symbolSpreading                 % data symbol spreading method
        channelAtPilots                 % the channel at pilot positions
        Channel                         % the estimated channel
        LLRsCalculationMethod           % the method for calculating the LLRs
        currentCQI                      % save current CQI to enable it as simulation result
    end
    
% Functionality
    properties
        WaveformObject                  % object for modulation and demodulation
        SignalConstellation             % object for bit to symbol mapping and de-mapping
        ChannelEstimator                % channel estimation object
    end    
    
%% The Modulator Functions

% Setup
methods
    function obj = Modulator(varargin) 
        obj.Waveform                = varargin{3};
        obj.symbolSpreading         = varargin{4};
        obj.noisePowerEstimation    = varargin{5};

        nMaxCodewords               = varargin{6};
        for iCodeword = 1:nMaxCodewords
            obj.SignalConstellation{iCodeword} = Modulation.SignalConstellation(varargin{2}, varargin{1}, 0, varargin{7});
        end
        
        obj.LLRsCalculationMethod   = varargin{7};
        
        switch obj.Waveform
            case 'SC'
                obj.WaveformObject = Modulation.SC_PAM(varargin{8}, varargin{9}, varargin{10}, varargin{11}, varargin{12}, varargin{13}, varargin{14}, varargin{15});
            case 'OFDM'
                obj.WaveformObject = Modulation.OFDM(varargin{8}, varargin{9}, varargin{10}, varargin{11}, varargin{12}, varargin{13}, varargin{14}, varargin{15});
            case 'f-OFDM'
                obj.WaveformObject = Modulation.FOFDM(varargin{8}, varargin{9}, varargin{10}, varargin{11}, varargin{12}, varargin{13}, varargin{14}, varargin{15}, varargin{16}, varargin{17}, varargin{18});
            case 'WOLA'
                obj.WaveformObject = Modulation.WOLA(varargin{8}, varargin{9}, varargin{10}, varargin{11}, varargin{12}, varargin{13}, varargin{14}, varargin{15}, varargin{16}, varargin{17});
            case 'FBMC'
                obj.WaveformObject = Modulation.FBMC(varargin{8}, varargin{9}, varargin{10}, varargin{11}, varargin{12}, varargin{13}, varargin{14}, varargin{15}, varargin{16}, varargin{17});
            case 'UFMC'
                obj.WaveformObject = Modulation.UFMC(varargin{8}, varargin{9}, varargin{10}, varargin{11}, varargin{12}, varargin{13}, varargin{14}, varargin{15}, varargin{16}, varargin{17});
%                 obj.WaveformObject = Modulation.UFMC2(varargin{8}, varargin{9}, varargin{10}, varargin{11}, varargin{12}, varargin{13}, varargin{14}, varargin{15}, varargin{16}, varargin{17});
            case 'GFDM'
                obj.WaveformObject = Modulation.GFDM(varargin{8}, varargin{9}, varargin{10}, varargin{11}, varargin{12}, varargin{13}, varargin{14}, varargin{15});
            otherwise
                error('Waveform format unknown!');
        end 
    end
    
    function setMCS(obj, modulationOrder, cqi, MUSTIdx)
        % set the modulation format, order and constellation for adaptive modulation and coding
        
        % save CQI number for results
        obj.currentCQI = cqi;
        
        for iCodeword = 1:length(cqi)
            if strcmp(obj.Waveform, 'FBMC')
                obj.SignalConstellation{iCodeword} = Modulation.SignalConstellation(sqrt(modulationOrder(iCodeword)), 'PAM', 0, obj.LLRsCalculationMethod);
            else
                obj.SignalConstellation{iCodeword} = Modulation.SignalConstellation(modulationOrder(iCodeword), 'QAM', MUSTIdx, obj.LLRsCalculationMethod);
            end
        end
    end
end

methods
    function nCodedBits = getNrCodedBits(obj, nPilotSymbols, schedule, codeword)
        % Get how many bits (coded) are required at the input of the modulator
        nCodedBits = (nnz(schedule)-nPilotSymbols) * log2(obj.SignalConstellation{codeword}.ModulationOrder); 
    end
    
    function spreadSymbols = spreadingTransform(obj, dataSymbols, nScheduledSubcarriers)
        % this function performs a spreading transformation on the data
        % symbols
        
        % check input
        if ~isvector(dataSymbols)
            error('Input data symbols must be vector');
        end
        
        % check if spreading transform is turned on
        if strcmp(obj.symbolSpreading, 'none')
            spreadSymbols = dataSymbols;
            return;
        end
        
        % reshape input vector
        dataSymbols = reshape(dataSymbols, nScheduledSubcarriers, []);
        
        % perform spreading
        switch obj.symbolSpreading
            case{'DFT'}
                spreadSymbols = zeros(nScheduledSubcarriers, size(dataSymbols, 2));
                for ii = 1:size(dataSymbols,2)
                    spreadSymbols(:, ii) = 1/sqrt(nScheduledSubcarriers) * fft(dataSymbols(:, ii));
                end
            otherwise
                error('Symbol spreading method unkown!');
        end
        
        % reshape to vector again
        spreadSymbols = spreadSymbols(:);
    end

    function despreadSymbols = inverseSpreadingTransform(obj, dataSymbols, nScheduledSubcarriers)
        % this function performs a spreading transformation on the data
        % symbols
        
        % check input
        if ~isvector(dataSymbols)
            error('Input data symbols must be vector');
        end
        
        % check if spreading transform is turned on
        if strcmp(obj.symbolSpreading, 'none')
            despreadSymbols = dataSymbols;
            return;
        end
        
        % reshape input vector
        dataSymbols = reshape(dataSymbols, nScheduledSubcarriers, []);
        
        % perform spreading
        switch obj.symbolSpreading
            case{'DFT'}
                despreadSymbols = zeros(nScheduledSubcarriers, size(dataSymbols, 2));
                for ii = 1:size(dataSymbols, 2)
                    despreadSymbols(:, ii) = sqrt(nScheduledSubcarriers) * ifft(dataSymbols(:, ii));
                end
            otherwise
                error('Symbol spreading method unkown!');
        end
        
        % reshape to vector again
        despreadSymbols = despreadSymbols(:);
    end
    
    function [pseudoSymbols] = demodulateTimeSignal(obj, channelOutput)
       % This function take the time signal channelOutput and returns a matrix of OFDM symbols
        nRx             = size(channelOutput, 2);
        pseudoSymbols   = zeros(obj.WaveformObject.Nr.Subcarriers, obj.WaveformObject.Nr.MCSymbols, nRx);
        for iRx = 1:nRx
            pseudoSymbols(:, :, iRx) = obj.WaveformObject.Demodulation(channelOutput(:, iRx));
        end       
    end
    
    function noisePower = estimateNoisePower(obj, channelOutput, noisePowerPerfect)
        nRx = size(channelOutput, 2);
        if obj.noisePowerEstimation
            interferenceNoisePower = zeros(nRx, obj.WaveformObject.Nr.Subcarriers, obj.WaveformObject.Nr.MCSymbols);
            for iRx = 1:nRx
                receivedSignalPadded = [channelOutput(:,iRx); zeros(obj.WaveformObject.Nr.MCSymbols - mod(size(channelOutput, 1), obj.WaveformObject.Nr.MCSymbols), 1)];
                % calculate received spectrum
                spectrum = circshift(1 / sqrt(size(channelOutput, 1) / obj.WaveformObject.Nr.MCSymbols) * fft(reshape(receivedSignalPadded, [], obj.WaveformObject.Nr.MCSymbols), obj.WaveformObject.Implementation.FFTSize), [-obj.WaveformObject.Implementation.IntermediateFrequency 0]);
                % get mean noise plus interference power from adjacent subcarriers
                interferenceNoisePower(iRx, :, :) = repmat(mean(abs([spectrum(end - (3:5), :); spectrum(obj.WaveformObject.Nr.Subcarriers + (3:5),:)]).^2, 1),obj.WaveformObject.Nr.Subcarriers, 1);
            end
            noisePower = interferenceNoisePower;
        else
            noisePower = noisePowerPerfect(1) * ones(obj.WaveformObject.Nr.Subcarriers,obj.WaveformObject.Nr.MCSymbols);
        end
    end
            
    function LLRs = getLLRs(obj, scheduledChannel, scheduledPseudoSymbols, noisePower, Link)
        nRx = Link.nRxAntennas;
        nTx = Link.nTxAntennas;
        
        % get some numbers
        nDataPositions          = size(scheduledPseudoSymbols, 1);
        nSymbols                = size(obj.Channel, 2);
        nScheduledSubcarriers   = (size(scheduledChannel, 1) + obj.ChannelEstimator.NrPilotSymbolPositions) / nSymbols;
        pilotMatrix = obj.ChannelEstimator.PilotMatrix;
        dataIndex = ~sum(pilotMatrix, 3);
        
        % perform LLRs calculation (detection) 
        % mimo
        if ismember(Link.multiuserMode, {'ZF-MUMIMO', 'MRT-MUMIMO', 'MMSE-MUMIMO', 'MRC-MUMIMO'})
            % multi user MIMO, BD is treated as single user MIMO.
            if strcmp(Link.Direction, 'Uplink')
                equalizedSymbols = scheduledPseudoSymbols;
                scaledSymbolNoisePower = noisePower;
            else
                equalizedSymbols = zeros(size(scheduledPseudoSymbols));
                switch Link.multiuserMode
                    case 'MRT-MUMIMO'
                        for i = 1:nDataPositions
                            equalizedSymbols(i, :) = scheduledPseudoSymbols(i, :).* Link.MIMO.MuPrecoder{i} ;
                        end
                    case 'ZF-MUMIMO'
                        for i = 1:nDataPositions
                            equalizedSymbols(i, :) = scheduledPseudoSymbols(i, :) .* Link.MIMO.MuPrecoder{i};
                        end
%                     case 'BD-MUMIMO'
%                         scheduledPseudoSymbols = scheduledPseudoSymbols / (10^((Link.transmitPower - 30 - Link.pathloss) / 20) * Link.powerScale);
%                         for i = 1:nDataPositions
%                             H = reshape(scheduledChannel(i, :, :), Link.Channel.Nr.rxAntennas, Link.Channel.Nr.txAntennas) /(10^((Link.transmitPower - 30 - Link.pathloss) / 20) * Link.powerScale);
%                             H_eff = H * Link.MIMO.MuPrecoder{i};
%                             equalizedSymbols(i, :) = ((H_eff' * H_eff)^-1 * H_eff' * scheduledPseudoSymbols(i, :).').';
%                                 
%                         end 
                    otherwise
                        error('Multi-user mode unknown!');
                end
                symbolNoisePower       = obj.WaveformObject.GetSymbolNoisePower(squeeze(noisePower));
                scaledSymbolNoisePower = mean(symbolNoisePower(:)) * ones(size(equalizedSymbols));
            end
            
            % data symbol de-spreading
            nLayers = size(equalizedSymbols, 2);
            for iLayer = 1:nLayers
                equalizedSymbolsDespread(:, iLayer) = obj.inverseSpreadingTransform(equalizedSymbols(:, iLayer), nScheduledSubcarriers);
            end
            
            % Demap layers back to codewords (symbol level)
            equalizedSymbolsDespread = Link.MIMO.demapLayers(equalizedSymbolsDespread, Link);
            scaledSymbolNoisePower   = Link.MIMO.demapLayers(scaledSymbolNoisePower, Link);
            nCodewords               = length(Link.MIMO.LayerMapping);

            LLRs = cell(nCodewords, 1);
            for iCodeword = 1:nCodewords
                LLRs{iCodeword} = obj.SignalConstellation{iCodeword}.LLR_AWGN(equalizedSymbolsDespread{iCodeword}, scaledSymbolNoisePower{iCodeword});
            end
            
        else
            % single user MIMO
            if (nTx==1) && (nRx==1)
                % SISO detection => Zero forcing is optimal 
                equalizedSymbols            = scheduledPseudoSymbols ./ scheduledChannel;
                symbolNoisePower            = obj.WaveformObject.GetSymbolNoisePower(squeeze(noisePower));
                scheduledSymbolNoisePower   = reshape(symbolNoisePower(repmat(dataIndex, 1, 1, Link.Channel.Nr.rxAntennas, Link.Channel.Nr.txAntennas)), [], Link.Channel.Nr.rxAntennas, Link.Channel.Nr.txAntennas);
                scaledSymbolNoisePower      = scheduledSymbolNoisePower ./ abs(scheduledChannel).^2;

                % data symbol de-spreading
                equalizedSymbolsDespread    = obj.inverseSpreadingTransform(equalizedSymbols, nScheduledSubcarriers);

                % LLRs calculation
                LLRs    = cell(1,1);
                LLRs{1} = obj.SignalConstellation{1}.LLR_AWGN(equalizedSymbolsDespread(:), scaledSymbolNoisePower(:));
            else
                % MIMO detection
                switch obj.ReceiverTypeMIMO
                    case 'ZF'
                        LLRs = obj.LLR_MIMO_ZF(permute(scheduledPseudoSymbols,[2 1]),...
                                               permute(scheduledChannel,[2 3 1]),...
                                               mean(mean(obj.WaveformObject.GetSymbolNoisePower(noisePower))),...
                                               @obj.inverseSpreadingTransform,...
                                               nScheduledSubcarriers, ...
                                               Link);
                    case 'MMSE'
                        LLRs = obj.LLR_MIMO_MMSE(permute(scheduledPseudoSymbols,[2 1]),...
                                                 permute(scheduledChannel,[2 3 1]),...
                                                 mean(mean(obj.WaveformObject.GetSymbolNoisePower(noisePower))),...
                                                 @obj.inverseSpreadingTransform,...
                                                 nScheduledSubcarriers, ...
                                                 Link);  
                    case 'Sphere'
                        if ~strcmp(obj.symbolSpreading,'none')
                            error('Currently shpere decoding is not supported in combination with data symbol spreading!');
                        end
                        LLRs = obj.LLR_MIMO_Sphere(permute(scheduledPseudoSymbols,[2 1]),...
                                                   permute(scheduledChannel,[2 3 1]),...
                                                   mean(mean(obj.WaveformObject.GetSymbolNoisePower(noisePower))),...
                                                   Link);
                    case 'ML'
                        if ~strcmp(obj.symbolSpreading,'none')
                            error('Currently maximum likelihood decoding is not supported in combination with data symbol spreading!');
                        end
                        LLRs = obj.LLR_MIMO_ML(permute(scheduledPseudoSymbols,[2 1]),...
                                               permute(scheduledChannel,[2 3 1]),...
                                               repmat(eye(nRx),1,1,nDataPositions)*mean(mean(obj.WaveformObject.GetSymbolNoisePower(noisePower))),...
                                               Link);                         
                    otherwise
                          error('Equalizer type not supported');
                end % switch obj.ReceiverTypeMIMO
            end % if SISO or MIMO
        end % if multi user MIMO or single user MIMO 
    end
       
    function LLRs = LLR_MIMO_ML(obj, y, H, Rn, Link)
        % This method is a straighhfoward (high compuational complexity)
        % implementation of a MIMO maximum likelihood LLRs calculation (per
        % bit). The model assumes y=Hx+n, whereas "y" represents the received
        % symbols of size y(NrRX,NrPos), "H" the channel matrix of size 
        % H(NrRX,NrTx,NrPos), "Rn" the correlation matrix of the Gaussian 
        % distributed noise with size Rn(NrRX,NrRX,NrPos), and 
        % "Precoder" the precoding matrix of size Precoder(NrTx,NrStreams)
        
        if strcmp(Link.multiuserMode,'BD-MUMIMO')
            PrecodingMatrix = Link.MIMO.MuPrecoder{1};
        else
            PrecodingMatrix = Link.MIMO.precodingMatrix;
        end
        Precoder        = Link.MIMO.getPrecoder();
        if not(exist('PrecodingMatrix','var'))
            PrecodingMatrix = eye(size(H,2));
        end
  
        NrTxStreams = size(PrecodingMatrix, 2);
        NrTimeFrequencyPositions = size(H, 3);
        
        modOrder       = obj.SignalConstellation{1}.ModulationOrderEffective;
        implementation = obj.SignalConstellation{1}.Implementation;  
        symbolMapping  = obj.SignalConstellation{1}.SymbolMapping;
        
        IndexRef = repmat(1:modOrder, modOrder^(NrTxStreams-1), 1);
        IndexRef = IndexRef(:);
        IndexDataSymbolAntennaCombination = zeros(length(IndexRef), NrTxStreams);
        for i=0:NrTxStreams-1
            IndexDataSymbolAntennaCombination(:, i+1) = repmat(IndexRef(1:modOrder^i:end), modOrder^i, 1);
        end
        IndexDataSymbolAntennaCombination = IndexDataSymbolAntennaCombination(1:end/2,:)';
                          
        for i_BitPos = 1:size(implementation.DataSymbolsBitvalueOne, 2)
            % Matlab changes dimensions!!!!!
            if NrTxStreams==2
                x_One_Atom  = [implementation.DataSymbolsBitvalueOne(IndexDataSymbolAntennaCombination(1, :), i_BitPos).'; symbolMapping(IndexDataSymbolAntennaCombination(2, :)).'];
                x_Zero_Atom = [implementation.DataSymbolsBitvalueZero(IndexDataSymbolAntennaCombination(1, :), i_BitPos).'; symbolMapping(IndexDataSymbolAntennaCombination(2, :)).'];
            else
                x_One_Atom  = [implementation.DataSymbolsBitvalueOne(IndexDataSymbolAntennaCombination(1, :), i_BitPos).'; symbolMapping(IndexDataSymbolAntennaCombination(2:end, :))];
                x_Zero_Atom = [implementation.DataSymbolsBitvalueZero(IndexDataSymbolAntennaCombination(1, :), i_BitPos).'; symbolMapping(IndexDataSymbolAntennaCombination(2:end, :))];            
            end 
            for i_TX_Antenna = 0:NrTxStreams-1                
                x_One(:, :, i_TX_Antenna + 1, i_BitPos)  = circshift(x_One_Atom, [i_TX_Antenna,0]);
                x_Zero(:, :, i_TX_Antenna + 1, i_BitPos) = circshift(x_Zero_Atom, [i_TX_Antenna,0]);  
            end            
        end
        
        [~, b, c, d] = size(x_One);
        a            = size(y, 1);
        LLRs         = zeros(c, d, NrTimeFrequencyPositions);
        
        if strcmp(Link.MIMO.method, 'OLSM')
            NrTxStreams = size(Precoder.U, 1);
            l = 1:NrTimeFrequencyPositions;
            if size(Precoder.W, 1)==4
                k = mod(floor((l - 1) / NrTxStreams), 4) + 1;
            else
                k = ones(1, NrTimeFrequencyPositions);
            end
                
            p = mod(l - 1, NrTxStreams) + 1;
        end
        
        for i_TimeFrequencyPos = 1:NrTimeFrequencyPositions
            Rn_temp = Rn(:, :, i_TimeFrequencyPos);
            InvRn_temp = Rn_temp^-1;
            [S, V] = svd(InvRn_temp);            
            C = (S * sqrt(V))';
            
            if strcmp(Link.MIMO.method, 'OLSM')
               PrecodingMatrix = Precoder.W{k(i_TimeFrequencyPos)} * (Precoder.D).^(p(i_TimeFrequencyPos)) * Precoder.U;
            elseif strcmp(Link.multiuserMode,'BD-MUMIMO')
                PrecodingMatrix = Link.MIMO.MuPrecoder{i_TimeFrequencyPos};
            end
           
            y_temp = C*y(:, i_TimeFrequencyPos);
            H_temp = C*H(:, :, i_TimeFrequencyPos) * PrecodingMatrix;
                        
            y_temp_repeated = repmat(y_temp,1,b,c,d);            
            Hx_One_temp = reshape(H_temp*x_One(:,:),a,b,c,d);
            Hx_Zero_temp = reshape(H_temp*x_Zero(:,:),a,b,c,d);
               
            LLRs(:, :, i_TimeFrequencyPos) = squeeze(log(sum(exp(sum(-abs(y_temp_repeated-Hx_One_temp).^2,1)),2)./sum(exp(sum(-abs(y_temp_repeated-Hx_Zero_temp).^2,1)),2)));  
        end
        LLRs             = LLRs(:, :).';
        LLRs(LLRs==Inf)  = 10^10;
        LLRs(LLRs==-Inf) = -10^10;   
        
        % Demap the LLRs layers back to codewords; demapLayersBits expects a cell
        LLRsCell = cell(1, NrTxStreams);
        for iLayer = 1:NrTxStreams
            LLRsCell{iLayer} = LLRs(:, iLayer);
        end
        LLRs = Link.MIMO.demapLayersBits(LLRsCell, Link);
    end  
    
    function [LLRs, x_est, noiseScaling] = LLR_MIMO_ZF(obj, y, H, Pn, despreading, nSubcarriers, Link)
        % This method calculates the LLRs for a MIMO system after a ZF
        % equalization. To keep the compuational complexity low, the cross
        % correlation after the ZF equalizer is neglected. 
        % The model assumes y=Hx+n, whereas "y" represents the received
        % symbols of size y(NrRX,NrPos), "H" the channel matrix of size 
        % H(NrRX,NrTx,NrPos), "Pn" the power of the Gaussian noise n 
        % and "Precoder" the precoding matrix of size Precoder(NrTx,NrStreams) 
        
        if strcmp(Link.multiuserMode,'BD-MUMIMO')
            PrecodingMatrix = Link.MIMO.MuPrecoder{1};
        else
            PrecodingMatrix = Link.MIMO.precodingMatrix;
        end
        Precoder        = Link.MIMO.getPrecoder();
        if not(exist('PrecodingMatrix', 'var'))
            PrecodingMatrix = eye(size(H, 2));
        end  

        N = size(y, 2);
        NrTxStreams = size(PrecodingMatrix, 2);
        NrRxAntennas = size(y, 1);
        
        if strcmp(Link.MIMO.method, 'OLSM')
            NrTxStreams = size(Precoder.W{1}, 2);
            l = 1:N;
            if size(Precoder.W, 1)==4
                k = mod(floor((l - 1) / NrTxStreams), 4) + 1;
            else
                k = ones(1, N);
            end
            p = mod(l - 1, NrTxStreams) + 1;
        elseif strcmp(Link.MIMO.method, 'TxD')
            [H, y] = obj.TxD_decoding(H, y);
            PrecodingMatrix = 1;
            NrTxStreams = size(H, 2);
            N = size(y, 2);
        end
        x_est = zeros(NrTxStreams, N);
        noiseScaling = zeros(NrTxStreams, N);        
        for i_n = 1:N
           if strcmp(Link.MIMO.method,'OLSM')
               PrecodingMatrix = Precoder.W{k(i_n)}*(Precoder.D).^(p(i_n))*Precoder.U;
           elseif strcmp(Link.multiuserMode,'BD-MUMIMO')
                PrecodingMatrix = Link.MIMO.MuPrecoder{i_n};
            end

           H_temp = H(:, :, i_n)*PrecodingMatrix;
           
           if NrRxAntennas<=NrTxStreams
                ZF_Equalizer = H_temp'/(H_temp*H_temp');
           else
                ZF_Equalizer = (H_temp'*H_temp)^-1*H_temp';
           end  
%            ZF_Equalizer = pinv(H_temp);
           x_est(:,i_n) = (ZF_Equalizer*y(:,i_n));           
           noiseScaling(:, i_n) = Pn*sum(ZF_Equalizer.*conj(ZF_Equalizer),2);
        end
        
        if strcmp(Link.MIMO.method,'TxD')
            x_est = reshape(x_est,[],1);
            x_est(2:2:end) = conj(x_est(2:2:end));
        else
            x_est = x_est.';
        end
        
        NrTxStreams = size(x_est,2);
        % symbol de-spreading
        for iStream = 1:NrTxStreams
            x_est(:, iStream) = despreading(x_est(:, iStream), nSubcarriers);
        end
        
        noiseScaling = noiseScaling.';
        
        % Demap layers back to codewords (symbol level)
        x_est        = Link.MIMO.demapLayers(x_est, Link);
        noiseScaling = Link.MIMO.demapLayers(noiseScaling, Link);
        nCodewords   = length(Link.MIMO.LayerMapping);
        
        LLRs = cell(nCodewords, 1);
        for iCodeword = 1:nCodewords
            LLRs{iCodeword} = obj.SignalConstellation{iCodeword}.LLR_AWGN(x_est{iCodeword}, noiseScaling{iCodeword});
        end
    end 
    
    function [LLRs,x_est,noiseScaling,unbiasedScaling] = LLR_MIMO_MMSE(obj, y, H, Pn, despreading, nSubcarriers, Link)
        % This method calculates the LLRs for a MIMO system after an 
        % unbiased MMSE equalization. To keep the compuational complexity
        % low, the cross correlation after the MMSE equalizer is neglected. 
        % The model assumes y=Hx+n, whereas "y" represents the received
        % symbols of size y(NrRX,NrPos), "H" the channel matrix of size 
        % H(NrRX,NrTx,NrPos), "Pn" the power of the Gaussian noise n 
        % and "Precoder" the precoding matrix of size Precoder(NrTx,NrStreams) 
        
        if strcmp(Link.multiuserMode,'BD-MUMIMO')
            PrecodingMatrix = Link.MIMO.MuPrecoder{1};
        else
            PrecodingMatrix = Link.MIMO.precodingMatrix;
        end
        Precoder        = Link.MIMO.getPrecoder();
        if not(exist('PrecodingMatrix','var'))
            PrecodingMatrix = eye(size(H,2));
        end
        
        N = size(y,2);
        NrTxStreams = size(PrecodingMatrix,2);
        NrRXAntennas = size(H,1); 
        
        if strcmp(Link.MIMO.method, 'OLSM')
            NrTxStreams = size(Precoder.U,1);
            l = 1:N;
            if size(Precoder.W, 1) == 4
                k = mod(floor((l - 1) / NrTxStreams), 4) + 1;
            else
                k = ones(1, N);
            end
            
            p = mod(l - 1, NrTxStreams) + 1;
        elseif strcmp(Link.MIMO.method, 'TxD')
            [H, y] = obj.TxD_decoding(H, y);
            PrecodingMatrix = 1;
            NrTxStreams = size(H, 2);
            [NrRXAntennas, N] = size(y);
        end
        
        x_est = zeros(NrTxStreams, N);
        noiseScaling = zeros(NrTxStreams, N); 
        unbiasedScaling = zeros(NrTxStreams, N); 
        for i_n = 1:N
           if strcmp(Link.MIMO.method, 'OLSM')
                PrecodingMatrix = Precoder.W{k(i_n)} * (Precoder.D).^(p(i_n)) * Precoder.U;
           elseif strcmp(Link.multiuserMode,'BD-MUMIMO')
                PrecodingMatrix = Link.MIMO.MuPrecoder{i_n};
            end
           
           H_temp = H(:, :, i_n) * PrecodingMatrix;
           MMSE_Equalizer = H_temp' / (H_temp * H_temp'+ Pn * eye(NrRXAntennas));  
           x_est(:, i_n) = (MMSE_Equalizer * y(:, i_n));
           
           Temp = MMSE_Equalizer * H_temp;
           noiseScaling(:, i_n) = Pn * sum(MMSE_Equalizer .* conj(MMSE_Equalizer), 2) + sum(abs(Temp - diag(diag(Temp))).^2, 2);
           unbiasedScaling(:, i_n) = abs(sum(MMSE_Equalizer .* H_temp.', 2));
        end

        % symbol de-spreading        
        if strcmp(Link.MIMO.method, 'TxD')
            x_est = reshape(x_est, [], 1);
            x_est(2:2:end) = conj(x_est(2:2:end));
            noiseScaling = reshape(noiseScaling, [], 1).';
            unbiasedScaling = reshape(unbiasedScaling, [], 1).';
        else
            x_est = x_est.';
        end
        NrTxStreams = size(x_est, 2);
        
        for iStream = 1:NrTxStreams
            x_est(:, iStream) = despreading(x_est(:, iStream), nSubcarriers);
        end
        
        noiseScaling = noiseScaling.';
        unbiasedScaling = unbiasedScaling.';
        
        % Demap layers back to codewords (symbol level)
        x_est           = Link.MIMO.demapLayers(x_est, Link);
        noiseScaling    = Link.MIMO.demapLayers(noiseScaling, Link);
        unbiasedScaling = Link.MIMO.demapLayers(unbiasedScaling, Link);
        nCodewords      = length(Link.MIMO.LayerMapping);

        LLRs = cell(nCodewords, 1);
        for iCodeword = 1:nCodewords
            LLRs{iCodeword} = obj.SignalConstellation{iCodeword}.LLR_AWGN(x_est{iCodeword} ./ unbiasedScaling{iCodeword}, noiseScaling{iCodeword} ./ unbiasedScaling{iCodeword}.^2);
        end
    end   
    
    function LLRs = LLR_MIMO_Sphere(obj, y, H, Pn, Link)
        % This method calculates the LLRs for a MIMO system by employing
        % a sphere decoder.
        % The model assumes y=Hx+n, whereas "y" represents the received
        % symbols of size y(NrRX,NrPos), "H" the channel matrix of size 
        % H(NrRX,NrTx,NrPos), "Pn" the power of the Gaussian noise n 
        % and "Precoder" the precoding matrix of size Precoder(NrTx,NrStreams)
        
        if strcmp(Link.multiuserMode,'BD-MUMIMO')
            PrecodingMatrix = Link.MIMO.MuPrecoder{1};
        else
            PrecodingMatrix = Link.MIMO.precodingMatrix;
        end
        Precoder    = Link.MIMO.getPrecoder();
        NrTxStreams = size(PrecodingMatrix, 2);

        if strcmp(Link.MIMO.method, 'OLSM')
            NrTxStreams = size(Precoder.U,1);
            l = 1:size(H, 3);
            if size(Precoder.W, 1)==4
                k = mod(floor((l - 1) / NrTxStreams), 4) + 1;
            else
                k = ones(1, size(H, 3));
            end
            p = mod(l - 1, NrTxStreams) + 1;
        end
        
        if exist('PrecodingMatrix', 'var')
            Heff = nan(size(H, 1), NrTxStreams, size(H, 3));
            for i_H = 1:size(H, 3)
                if strcmp(Link.MIMO.method, 'OLSM')
                    PrecodingMatrix = Precoder.W{k(i_H)} * (Precoder.D).^(p(i_H)) * Precoder.U;
                elseif strcmp(Link.multiuserMode,'BD-MUMIMO')
                    PrecodingMatrix = Link.MIMO.MuPrecoder{i_H};
                end
                Heff(:, :, i_H) = H(:, :, i_H) * PrecodingMatrix;
            end
        else
            Heff = H;
        end
        
        % Get symbol and bit maps for each layers
        symbolMaps = cell(1, NrTxStreams);
        bitTables  = cell(1, NrTxStreams);
        nCodewords = length(Link.MIMO.LayerMapping);
        currentLayer = 1;
        for iCodeword = 1:nCodewords
            for iLayer = 1:Link.MIMO.LayerMapping(iCodeword)
                symbolMaps{currentLayer} = obj.SignalConstellation{iCodeword}.SymbolMapping;
                bitTables{currentLayer}  = obj.SignalConstellation{iCodeword}.BitMapping;
                currentLayer = currentLayer + 1;
            end
        end
        
        % Sphere decoding
        LLRsMat = obj.sphereDecode(y, Heff, symbolMaps, bitTables, false) * (1 / Pn);
        LLRsMat(LLRsMat==Inf)  = 10^10;
        LLRsMat(LLRsMat==-Inf) = -10^10;   

        % Demap the LLRs layers back to codewords; demapLayersBits expects a cell
        LLRsCell = cell(1, NrTxStreams);
        currPos = 1;
        for iLayer = 1:NrTxStreams
            nBits = size(bitTables{iLayer}, 2);
            LLRsCell{iLayer} = reshape(LLRsMat(currPos:currPos+nBits-1, :), [], 1);
            currPos = currPos + nBits;
        end
        LLRs = Link.MIMO.demapLayersBits(LLRsCell, Link);
    end 
    
    function [H_combined, r_combined] = TxD_decoding(~, H, r)
        [nRx, nTx, NrPos] = size(H);
        H = permute(H, [3,1,2]);
        r = permute(r, [2,1]);
        switch nTx
            case 2
                switch nRx
                    case 2
                        r_combined = zeros( 4, NrPos/2);
                        H_combined = zeros( 4, nTx, NrPos/2);
                         for j = 1:(NrPos/2)
                                i = 2*(j-1) + 1;
                                r_combined(:,j) = [r(i,1);r(i,2);conj(r(i+1,1));conj(r(i+1,2))];
                                H_combined(:,:,j) = [H(i,1,1),-H(i,1,2);H(i,2,1),-H(i,2,2);conj(H(i+1,1,2)),conj(H(i+1,1,1));conj(H(i+1,2,2)),conj(H(i+1,2,1))];
                         end
                    case 1
                        r_combined = zeros( 2, NrPos/2);
                        H_combined = zeros( 2, nTx, NrPos/2);
                         for j = 1:(NrPos/2)
                                i = 2*(j-1) + 1;
                                r_combined(:,j) = [r(i);conj(r(i+1))];
                                H_combined(:,:,j) = [H(i,1,1),-H(i,1,2);conj(H(i+1,1,2)),conj(H(i+1,1,1))]; 
                         end
                    otherwise
                    error('The mode transmit diversity with %d transmit antennas is not implemented for %d receive antennas.', nTx, nRx);
                end

            case 4
                switch nRx
                    case 4
                        r_combined = zeros( 16, NrPos/4);
                        H_combined = zeros( 16, nTx, NrPos/4);
                        for j = 1:(NrPos/4)
                            i = 4*(j-1) + 1;
                            r_combined(:,j) = [r(i,1);r(i,2);conj(r(i+1,1));conj(r(i+1,2));
                                            r(i+2,1);r(i+2,2);conj(r(i+3,1));conj(r(i+3,2));
                                            r(i,3);r(i,4);conj(r(i+1,3));conj(r(i+1,4));
                                            r(i+2,3);r(i+2,4);conj(r(i+3,3));conj(r(i+3,4))];

                            H_combined(:,:,j) = [H(i,1,1),-H(i,1,3),0,0;H(i,2,1),-H(i,2,3),0,0;conj(H(i+1,1,3)),conj(H(i+1,1,1)),0,0;conj(H(i+1,2,3)),conj(H(i+1,2,1)),0,0;...  % generate equivalent channel matrix
                                0,0,H(i+2,1,2),-H(i+2,1,4);0,0,H(i+2,2,2),-H(i+2,2,4);0,0,conj(H(i+3,1,4)),conj(H(i+3,1,2));0,0,conj(H(i+3,2,4)),conj(H(i+3,2,2));...
                                H(i,3,1),-H(i,3,3),0,0;H(i,4,1),-H(i,4,3),0,0;conj(H(i+1,3,3)),conj(H(i+1,3,1)),0,0;conj(H(i+1,4,3)),conj(H(i+1,4,1)),0,0;...  
                                0,0,H(i+2,3,2),-H(i+2,3,4);0,0,H(i+2,4,2),-H(i+2,4,4);0,0,conj(H(i+3,3,4)),conj(H(i+3,3,2));0,0,conj(H(i+3,4,4)),conj(H(i+3,4,2))];
                        end
                    case 2
                        r_combined = zeros( 8, NrPos/4);
                        H_combined = zeros( 8, nTx, NrPos/4);
                        for j = 1:(NrPos/4)
                            i = 4*(j-1) + 1;
                            r_combined(:,j) = [r(i,1);r(i,2);conj(r(i+1,1));conj(r(i+1,2));
                                            r(i+2,1);r(i+2,2);conj(r(i+3,1));conj(r(i+3,2))];

                            H_combined(:,:,j) = [H(i,1,1),-H(i,1,3),0,0;H(i,2,1),-H(i,2,3),0,0;conj(H(i+1,1,3)),conj(H(i+1,1,1)),0,0;conj(H(i+1,2,3)),conj(H(i+1,2,1)),0,0;...  % generate equivalent channel matrix
                                0,0,H(i+2,1,2),-H(i+2,1,4);0,0,H(i+2,2,2),-H(i+2,2,4);0,0,conj(H(i+3,1,4)),conj(H(i+3,1,2));0,0,conj(H(i+3,2,4)),conj(H(i+3,2,2))];
                        end

                    case 1
                        r_combined = zeros( 4, NrPos/4);
                        H_combined = zeros( 4, nTx, NrPos/4);
                        for j = 1:(NrPos/4)
                            i = 4*(j-1) + 1;
                            r_combined(:,j) = [r(i,1);conj(r(i+1,1));r(i+2,1);conj(r(i+3,1))];

                            H_combined(:,:,j) = [H(i,1,1),-H(i,1,3),0,0;conj(H(i+1,1,3)),conj(H(i+1,1,1)),0,0;
                                0,0,H(i+2,1,2),-H(i+2,1,4);0,0,conj(H(i+3,1,4)),conj(H(i+3,1,2))];
                        end
                    otherwise
                    error('The mode transmit diversity with %d transmit antennas is not implemented for %d receive antennas.', nTx, nRx);
                end

            case 8
                switch nRx
                    case 2 
                        r_combined = zeros( 16, NrPos/8);
                        H_combined = zeros( 16, nTx, NrPos/8);
                        for j = 1:(NrPos/8)
                            i = 8*(j-1) + 1;
                            r_combined(:,j) = [r(i,1);r(i,2);conj(r(i+1,1));conj(r(i+1,2));
                                            r(i+2,1);r(i+2,2);conj(r(i+3,1));conj(r(i+3,2));...
                                            r(i+4,1);r(i+4,2);conj(r(i+5,1));conj(r(i+5,2));...
                                            r(i+6,1);r(i+6,2);conj(r(i+7,1));conj(r(i+7,2))];
                           H_combined(:,:,j) = [H(i,1,1),-H(i,1,5),0,0,0,0,0,0;H(i,2,1),-H(i,2,5),0,0,0,0,0,0;conj(H(i+1,1,5)),conj(H(i+1,1,1)),0,0,0,0,0,0;conj(H(i+1,2,5)),conj(H(i+1,2,1)),0,0,0,0,0,0;...
                                                0,0,H(i+2,1,2),-H(i+2,1,6),0,0,0,0;0,0,H(i+2,2,2),-H(i+2,2,6),0,0,0,0;0,0,conj(H(i+3,1,6)),conj(H(i+3,1,2)),0,0,0,0;0,0,conj(H(i+3,2,6)),conj(H(i+3,2,2)),0,0,0,0;...
                                                0,0,0,0,H(i+4,1,3),-H(i+4,1,7),0,0;0,0,0,0,H(i+4,2,3),-H(i+4,2,7),0,0;0,0,0,0,conj(H(i+5,1,7)),conj(H(i+5,1,3)),0,0;0,0,0,0,conj(H(i+5,2,7)),conj(H(i+5,2,3)),0,0;...
                                                0,0,0,0,0,0,H(i+6,1,4),-H(i+6,1,8);0,0,0,0,0,0,H(i+6,2,4),-H(i+6,2,8);0,0,0,0,0,0,conj(H(i+7,1,8)),conj(H(i+7,1,4));0,0,0,0,0,0,conj(H(i+7,2,8)),conj(H(i+7,2,4))];            


                        end

                    case 1
                        r_combined = zeros(8, NrPos / 8);
                        H_combined = zeros(8, nTx, NrPos / 8);
                        for j = 1:(NrPos / 8)
                            i = 8 * (j - 1) + 1;
                            r_combined(:, j) = [r(i,1);conj(r(i+1,1));r(i+2,1);conj(r(i+3,1));...
                                                r(i+4,1);conj(r(i+5,1));r(i+6,1);conj(r(i+7,1))];
                            H_combined(:, :, j) = [H(i,1,1),-H(i,1,5),0,0,0,0,0,0;conj(H(i+1,1,5)),conj(H(i+1,1,1)),0,0,0,0,0,0;...
                                                   0,0,H(i+2,1,2),-H(i+2,1,6),0,0,0,0;0,0,conj(H(i+3,1,6)),conj(H(i+3,1,2)),0,0,0,0;...
                                                   0,0,0,0,H(i+4,1,3),-H(i+4,1,7),0,0;0,0,0,0,conj(H(i+5,1,7)),conj(H(i+5,1,3)),0,0;...
                                                   0,0,0,0,0,0,H(i+6,1,4),-H(i+6,1,8);0,0,0,0,0,0,conj(H(i+7,1,8)),conj(H(i+7,1,4))];
                       end

                    otherwise
                    error('The mode transmit diversity with %d transmit antennas is not implemented for %d receive antennas.', nTx, nRx);
                end
            otherwise
                error('The mode transmit diversity is not implemented for %d transmit antennas.',nTx);
        end
        r_combined = sqrt(2) * r_combined;
    end
  
    function LLRs = sphereDecode(~, ytotal, H, symbolMaps, bitTables, initialRadiusZF)
        [nRX, nTX, nS] = size(H);

        if nTX > nRX 
            error('Effective nTX cannot be higher than nRX.');
        end
        
        % Preparing parameters for the MEX file
        nTotalBits = 0;
        nSymbolsPerLayer = zeros(numel(symbolMaps), 1);
        nBitsPerSymbol   = zeros(numel(symbolMaps), 1);
        for k = 1:nTX
            symbolMaps{k}       = complex(symbolMaps{k});
            nSymbolsPerLayer(k) = length(symbolMaps{k});
            nBitsPerSymbol(k)   = log2(nSymbolsPerLayer(k));
            nTotalBits          = nTotalBits + nBitsPerSymbol(k);
        end

        parameters    = cell(1, 5);
        parameters{1} = nRX;
        parameters{2} = nTX;
        parameters{3} = nTotalBits;
        parameters{4} = nSymbolsPerLayer;
        parameters{5} = nBitsPerSymbol;
        %     parameters{6} = initialRadius;
        %     parameters{7} = initialBits;

        LLRs = nan(nTotalBits, nS);
        for iy = 1:nS
            [Q, R] = qr(H(:, :, iy));
            y = Q'*ytotal(:, iy);

            if initialRadiusZF == false
                parameters{6} = 10^50;
                initialBits = zeros(1 , nTotalBits);
            else
                yZF = pinv(R)*y;
                symbolsZF = zeros(nTX, 1);
                initialBits = [];
                for k = 1:nTX
                    [~, I] = min(abs(yZF(k) - symbolMaps{k}));
                    symbolsZF(k) = symbolMaps{k}(I);
                    initialBits = [initialBits, bitTables{k}(I, :)];
                end
                parameters{6} = norm(y - R*symbolsZF, 2)^2;
            end
            parameters{7} = initialBits;

            % Sphere decoding for the block iy
            [b_ML, lambda_b_MLc, lambda_ML] = sphereDecodeMEX(complex(y), complex(R), symbolMaps, bitTables, parameters);

            b_ML = logical(b_ML);
            b_soft = zeros(1, nTotalBits);
            b_soft(b_ML)  = lambda_b_MLc(b_ML) - lambda_ML;
            b_soft(~b_ML) = lambda_ML - lambda_b_MLc(~b_ML);
            LLRs(:, iy) = b_soft;
        end
    end
end
end


