classdef FastFading < handle
    % =====================================================================
    % This MATLAB class represents an implementation of a time-variant
    % channel. The channel parameters are initialized by the class
    % constructor. The convolution is performed by the method
    % ".Convolution(.)". A new channel realization is obtained by
    % ".NewRealization;".
    % Additionally, there exist some other useful methods, such as
    % ".GetRmsDelaySpread" or ".PlotPowerDelayProfile"
    % =====================================================================
    % Ronald Nissel, rnissel@nt.tuwien.ac.at
    % (c) 2017 by Institute of Telecommunications, TU Wien
    % www.tc.tuwien.ac.at
    % =====================================================================
    
    
    properties (SetAccess = private)
        PHY
        Nr
        ImpulseResponse
    end
    properties
        Implementation
    end
    methods
        function obj = FastFading(...
                SamplingRate,...                                    % Sampling rate (Samples/s)
                PowerDelayProfile,...                               % Power delay profile, either string or vector: 'Flat', 'AWGN', 'PedestrianA', 'PedestrianB', 'VehicularA', 'VehicularB', 'ExtendedPedestrianA', 'ExtendedPedestrianB', or 'TDL-A_xxns','TDL-B_xxns','TDL-C_xxns' (with xx the RMS delay spread in ns, e.g. 'TDL-A_30ns'), or [1 0 0.2] (Self-defined power delay profile which depends on the sampling rate)
                SamplesTotal,...                                    % Number of total samples
                MaximumDopplerShift,...                             % Maximum Doppler shift: Velocity_kmh/3.6*CarrierFrequency/2.998e8
                DopplerModel,...                                    % Which Doppler model: 'Jakes', 'Uniform', 'Discrete-Jakes', 'Discrete-Uniform'. For "Discrete-", we assume a discrete Doppler spectrum to improve the simulation time. This only works accuratly if the number of samples and the velocity is sufficiently large
                Paths,...                                           % Number of paths for the WSSUS process. Only relevant for a 'Jakes' and 'Uniform' Doppler spectrum
                correlatedFrames,...                                 % whether the channel is correlated in time (across frames) or not
                spatialCorrelation,...                              % spatial correlation of MIMO channels
                correlationCoeffTx,...                              % tansmit side correlation coefficient
                correlationCoeffRx,...                              % receive side correlation coefficient
                nTxAntennas,...                                     % Number of transmit antennas
                nRxAntennas,...                                     % Number of receive antennas
                WarningIfSampleRateDoesNotMatch,...                 % Gives a warning if the predefined delay taps of the channel do not fit the sampling rate. This is usually not much of a problem if they are approximatly the same.
                K,...                                               % TWDP model parameter K
                Delta, ...                                          % TWDP model parameter delta
                spatialChannelModel,...                             % if spatial channel model is set to ture a 3D channel is generated
                Tx_arrayConfiguration, ...                        % The number of horizontal and vertical antennas
                Rx_arrayConfiguration, ...                        % The number of horizontal and vertical antennas
                carrierFrequency, ...                               % carrier frequency for calculating the wave vector
                timeSubsamplingFactor ...                           % The time subsampling factor for time-varying channels        
                )
            
            % Initialize parameters
            obj.PHY.SamplingRate                     = SamplingRate;
            obj.Nr.SamplesTotal                      = SamplesTotal;
            obj.Nr.txAntennas                        = nTxAntennas;
            obj.Nr.rxAntennas                        = nRxAntennas;
            obj.Nr.txAntennasHorizontal              = Tx_arrayConfiguration(1);
            obj.Nr.txAntennasVertical                = Tx_arrayConfiguration(2);
            obj.Nr.rxAntennasHorizontal              = Rx_arrayConfiguration(1);
            obj.Nr.rxAntennasVertical                = Rx_arrayConfiguration(2);
            obj.PHY.carrierFrequency                 = carrierFrequency;
            obj.PHY.MaximumDopplerShift              = MaximumDopplerShift;
            obj.Implementation.spatialModel          = spatialChannelModel;
            obj.Implementation.PowerDelayProfile     = PowerDelayProfile;
            if MaximumDopplerShift > 0 
                obj.Implementation.correlatedFrames      = correlatedFrames;
            else
                obj.Implementation.correlatedFrames      = false;
            end                                   
            obj.Implementation.spatialCorrelation    = spatialCorrelation;
            obj.Implementation.timeSubsamplingFactor = timeSubsamplingFactor;
            obj.PHY.K                                = K;
            obj.PHY.delta                            = Delta;
            
            
            % calculate spatial correlation matrix according to TS36.101, Annex B
            if ~strcmp(obj.Implementation.spatialCorrelation,'none')
                if obj.Nr.txAntennas == 1
                    obj.Implementation.spatialCorrelationMatrixTX = 1;
                else
                    obj.Implementation.spatialCorrelationMatrixTX = toeplitz(correlationCoeffTx.^(linspace(0,1,obj.Nr.txAntennas).^2));
                end
                
                if obj.Nr.rxAntennas == 1
                    obj.Implementation.spatialCorrelationMatrixRX = 1;
                else
                    obj.Implementation.spatialCorrelationMatrixRX = toeplitz(correlationCoeffRx.^(linspace(0,1,obj.Nr.rxAntennas).^2));
                end
            end
            
            obj.PHY.dt = 1/obj.PHY.SamplingRate;
            
            if ischar(PowerDelayProfile)
                % For the new 3GPP 38.900 channel model, see http://www.3gpp.org/DynaReport/38900.htm
                if strcmp(PowerDelayProfile(1:3),'TDL')
                    Pos1 = strfind(PowerDelayProfile,'_');
                    Pos2 = strfind(PowerDelayProfile,'ns');
                    DesiredRMSdelaySpread = str2double(PowerDelayProfile(Pos1+1:Pos2-1))*10^-9;
                    PowerDelayProfile = PowerDelayProfile(1:5);
                end
                % See ftp://www.3gpp.org/tsg_ran/TSG_RAN/TSGR_16/Docs/PDF/RP-020376.pdf
                switch PowerDelayProfile
                    case 'Flat'
                        PowerDelayProfileINdB_DelayIndex = [...
                            0;...                                           % Relative power in dB
                            0];                                             % Relative delay in s
                    case 'AWGN'
                        PowerDelayProfileINdB_DelayIndex = [...
                            0;...                                           % Relative power in dB
                            0];                                             % Relative delay in s
                        if (obj.PHY.MaximumDopplerShift>0) && strcmp(PowerDelayProfile,'AWGN')
                            warning('The velocity is set to zero (AWGN channel!)');
                            obj.PHY.MaximumDopplerShift = 0;
                        end
                    case 'PedestrianA'
                        PowerDelayProfileINdB_DelayIndex = [...
                            0,-9.7,-19.2,-22.8;...                          % Relative power in dB
                            0,110e-9,190e-9,410e-9];                        % Relative delay in s
                    case 'PedestrianB'
                        PowerDelayProfileINdB_DelayIndex = [...
                            0,-0.9,-4.9,-8,-7.8,-23.9;...
                            0,200e-9,800e-9,1200e-9,2300e-9,3700e-9];
                    case 'VehicularA'
                        PowerDelayProfileINdB_DelayIndex = [...
                            0,-1,-9,-10,-15,-20;...
                            0,310e-9,710e-9,1090e-9,1730e-9,2510e-9];
                    case 'VehicularB'
                        PowerDelayProfileINdB_DelayIndex = [...
                            -2.5,0,-12.8,-10,-25.2,-16;...
                            0,300e-9,8900e-9,12900e-9,17100e-9,20000e-9];
                    case 'ExtendedPedestrianA'
                        PowerDelayProfileINdB_DelayIndex = [...
                            0,-1,-2,-3,-8,-17.2,-20.8;
                            0,30e-9,70e-9,90e-9,110e-9,190e-9,410e-9];
                    case 'ExtendedVehicularA'
                        PowerDelayProfileINdB_DelayIndex = [...
                            0,-1.5,-1.4,-3.6,-0.6,-9.1,-7,-12,-16.9;
                            0,30e-9,150e-9,310e-9,370e-9,710e-9,1090e-9,1730e-9,2510e-9];
                    case 'HillyTerrain'
                        PowerDelayProfileINdB_DelayIndex = [-3.6,-8.9,-10.2,-11.5,-11.8,-12.7,-13,-16.2,-17.3,-17.7,-17.6,-22.7,...
                            -24.1,-25.8,-25.8,-26.2,-29,-29.9,-30,-30.7;
                            0,0.356,0.441,0.528,0.546,0.609,0.625,0.842,0.916,0.941,15,16.172,16.492,16.876,16.882,...
                            16.978,17.615,17.827,17.849,18.0160]; 
                        PowerDelayProfileINdB_DelayIndex(2,:) = PowerDelayProfileINdB_DelayIndex(2,:)*1e-6;
                    case 'TDL-A'
                        PowerDelayProfileINdB_DelayIndex(1,:) = ...
                            [-13.4,0,-2.2,-4,-6,-8.2,-9.9,-10.5,-7.5,-15.9,-6.6,-16.7,-12.4,-15.2,-10.8,-11.3,-12.7,-16.2,-18.3,-18.9,-16.6,-19.9,-29.7];
                        PowerDelayProfileINdB_DelayIndex(2,:) = ...
                            DesiredRMSdelaySpread*[0.0000,0.3819,0.4025,0.5868,0.4610,0.5375,0.6708,0.5750,0.7618,1.5375,1.8978,2.2242,2.1718,2.4942,2.5119,3.0582,4.0810,4.4579,4.5695,4.7966,5.0066,5.3043,9.6586];
                    case 'TDL-B'
                        PowerDelayProfileINdB_DelayIndex(1,:) = ...
                            [0,-2.2,-4,-3.2,-9.8,-1.2,-3.4,-5.2,-7.6,-3,-8.9,-9,-4.8,-5.7,-7.5,-1.9,-7.6,-12.2,-9.8,-11.4,-14.9,-9.2,-11.3];
                        PowerDelayProfileINdB_DelayIndex(2,:) = ...
                            DesiredRMSdelaySpread*[0.0000,0.1072,0.2155,0.2095,0.2870,0.2986,0.3752,0.5055,0.3681,0.3697,0.5700,0.5283,1.1021,1.2756,1.5474,1.7842,2.0169,2.8294,3.0219,3.6187,4.1067,4.2790,4.7834];
                    case 'TDL-C'
                        PowerDelayProfileINdB_DelayIndex(1,:) = ...
                            [-4.4,-1.2,-3.5,-5.2,-2.5,0,-2.2,-3.9,-7.4,-7.1,-10.7,-11.1,-5.1,-6.8,-8.7,-13.2,-13.9,-13.9,-15.8,-17.1,-16,-15.7,-21.6,-22.8];
                        PowerDelayProfileINdB_DelayIndex(2,:) = ...
                            DesiredRMSdelaySpread*[0,0.2099,0.2219,0.2329,0.2176,0.6366,0.6448,0.6560,0.6584,0.7935,0.8213,0.9336,1.2285,1.3083,2.1704,2.7105,4.2589,4.6003,5.4902,5.6077,6.3065,6.6374,7.0427,8.6523];
                    otherwise
                        error('Power delay profile model not supported!');
                end
                IndexDelays = round(PowerDelayProfileINdB_DelayIndex(2,:)./obj.PHY.dt)+1;
                if  WarningIfSampleRateDoesNotMatch && (sum(abs(rem(PowerDelayProfileINdB_DelayIndex(2,:),obj.PHY.dt)))>0)
                    fprintf('Sampling rate does not match the predefined delays of the channel model!\n');
                    fprintf('Delay taps are changed according to (top = desired value; bottom = chosen value):\n');
                    disp([PowerDelayProfileINdB_DelayIndex(2,:);(IndexDelays-1)*obj.PHY.dt]);
                end
                PowerDelayProfileTemp = zeros(length(IndexDelays),max(IndexDelays));
                for i_delay = 1:length(IndexDelays)
                    PowerDelayProfileTemp(i_delay,IndexDelays(i_delay)) = 10.^(PowerDelayProfileINdB_DelayIndex(1,i_delay)/10);
                end
                obj.PHY.PowerDelayProfile = sum(PowerDelayProfileTemp,1);
                obj.PHY.DesiredPowerDelayProfiledB = PowerDelayProfileINdB_DelayIndex;
            else
                obj.PHY.PowerDelayProfile = PowerDelayProfile;
                
                obj.PHY.DesiredPowerDelayProfiledB(1,:) = 10*log10(PowerDelayProfile);
                obj.PHY.DesiredPowerDelayProfiledB(2,:) = (0:size(obj.PHY.DesiredPowerDelayProfiledB,2)-1)*obj.PHY.dt;
            end
            obj.Implementation.PowerDelayProfileNormalized = obj.PHY.PowerDelayProfile.'/sum(obj.PHY.PowerDelayProfile);
            
            obj.Implementation.IndexDelayTaps = find(obj.PHY.PowerDelayProfile');
            
            NrOnes = sum(obj.Nr.SamplesTotal:-1:(obj.Nr.SamplesTotal-length(obj.PHY.PowerDelayProfile)+1));
            obj.Implementation.MappingConvolutionMatrix = nan(NrOnes,2);
            for i_NrTaps = 1:length(obj.PHY.PowerDelayProfile)
                obj.Implementation.MappingConvolutionMatrix(sum(obj.Nr.SamplesTotal:-1:obj.Nr.SamplesTotal-i_NrTaps+2)+(1:obj.Nr.SamplesTotal-i_NrTaps+1),:) = [-i_NrTaps+1+(i_NrTaps:obj.Nr.SamplesTotal).' (i_NrTaps:obj.Nr.SamplesTotal).'];
            end
            
            % Faster mapping because zeros are not mapped
            obj.Implementation.MappingConvolutionMatrixFast = obj.Implementation.MappingConvolutionMatrix;
            for i_NrTaps = find(obj.PHY.PowerDelayProfile==0)
                obj.Implementation.MappingConvolutionMatrixFast(sum(obj.Nr.SamplesTotal:-1:obj.Nr.SamplesTotal-i_NrTaps+2)+(1:obj.Nr.SamplesTotal-i_NrTaps+1),:) = -1;
            end
            obj.Implementation.MappingConvolutionMatrixFast(obj.Implementation.MappingConvolutionMatrixFast(:,1)==-1,:)=[];
            
            if obj.PHY.MaximumDopplerShift/(obj.PHY.SamplingRate/obj.Nr.SamplesTotal)<=0.5 && strcmp(DopplerModel(1:min(8,end)),'Discrete') && obj.PHY.MaximumDopplerShift>0
                warning('Discrete Doppler spectrum: The velocity is so low, that it is set to zero. Change to a "Jakes" or "Uniform" spectrum or increase the number of symbols in time!');
                obj.PHY.MaximumDopplerShift = 0;
            end
            
            if obj.PHY.MaximumDopplerShift>0
                obj.Implementation.DopplerModel = DopplerModel;
                if strcmp(obj.Implementation.DopplerModel(1:min(8,end)),'Discrete') && ~obj.Implementation.correlatedFrames
                    obj.Implementation.UseDiscreteDopplerSpectrum = true;
                    % Calculate frequency spacing between discrete Doppler shifts
                    df = obj.PHY.SamplingRate/obj.Nr.SamplesTotal;
                    
                    NrDopplerShifts = ceil(obj.PHY.MaximumDopplerShift/df);
                    
                    IntervalPoints = df*((-NrDopplerShifts-1:NrDopplerShifts)+0.5);
                    IntervalPoints(IntervalPoints<=-obj.PHY.MaximumDopplerShift)=-obj.PHY.MaximumDopplerShift;
                    IntervalPoints(IntervalPoints>=obj.PHY.MaximumDopplerShift)=obj.PHY.MaximumDopplerShift;
                    
                    switch obj.Implementation.DopplerModel
                        case 'Discrete-Jakes'
                            DiscreteDopplerSpectrum = asin(IntervalPoints(2:end)/obj.PHY.MaximumDopplerShift)-asin(IntervalPoints(1:end-1)/obj.PHY.MaximumDopplerShift); % calculate the integral of the continous Doppler spectrum over a certain interval
                        case 'Discrete-Uniform'
                            DiscreteDopplerSpectrum = IntervalPoints(2:end)-IntervalPoints(1:end-1); % calculate the integral of the continous Doppler spectrum over a certain interval
                        otherwise
                            error('Doppler spectrum not supported');
                    end
                    
                    % Normalize
                    DiscreteDopplerSpectrum = DiscreteDopplerSpectrum./sum(DiscreteDopplerSpectrum);
                    
                    obj.Implementation.DiscreteDopplerSpectrum = repmat(DiscreteDopplerSpectrum.',1,length(obj.Implementation.IndexDelayTaps));
                elseif strcmp(obj.Implementation.DopplerModel(1:min(8,end)),'Discrete') && obj.Implementation.correlatedFrames
                    error('Discrete Doppler spectrum: Correlated fading not supported with discrete Doppler spectrum!');
                else
                    obj.Nr.Paths = Paths;
                    obj.Implementation.UseDiscreteDopplerSpectrum = false;
                    obj.generateTimeCorrelationParameters;
                end
            end
            
            % Check if the time-subsampling factor is too high
            coherenceTime       = 0.423 / MaximumDopplerShift; % Rappaport, Wireless Communications, 2002.    
            interpolationLength = (1 / SamplingRate) * timeSubsamplingFactor;
            if interpolationLength > coherenceTime / 10
                warning('The channel time-subsampling factor might be too high for the time-variations of the channel.');
            end
            
            obj.NewRealization(0);
            
            obj.Implementation.CancelElementsConvolutionMatrix = ones(obj.Nr.SamplesTotal,length(obj.PHY.PowerDelayProfile))==1;
            for i_NrTaps = 1:length(obj.PHY.PowerDelayProfile)-1
                obj.Implementation.CancelElementsConvolutionMatrix(i_NrTaps,(end-length(obj.PHY.PowerDelayProfile)+1+i_NrTaps):end) = false;
            end
            obj.Implementation.CancelElementsConvolutionMatrixFast = obj.Implementation.CancelElementsConvolutionMatrix(:,obj.Implementation.IndexDelayTaps);
            
        end
        
        function generateTimeCorrelationParameters(obj,varargin)
            % This function generates the relevant parameters when time correlation is on. 
            % Also takes care of assigning identical parameters to
            % Uplink-Downlink pairs in TDD mode.
            
            if obj.Implementation.correlatedFrames
                if nargin > 1
                    if ~obj.Implementation.spatialModel.spatialChannelModel
                        obj.Implementation.randomVariables.theta = permute(varargin{1}.Implementation.randomVariables.theta,[1,2,4,3]);
                        obj.Implementation.randomVariables.phi = permute(varargin{1}.Implementation.randomVariables.phi,[1,2,3,5,4]);
                        obj.Implementation.randomVariables.psi = permute(varargin{1}.Implementation.randomVariables.psi,[1,2,3,5,4]);
                    else
                        obj.Implementation.randomVariables = varargin{1}.Implementation.randomVariables;
                    end
                else
                    if ~obj.Implementation.spatialModel.spatialChannelModel
                        % generate independent random variables for time correlated Rayleigh fading channel model
                        obj.Implementation.randomVariables.theta    = 2*pi*rand(length(obj.Implementation.IndexDelayTaps),1,obj.Nr.rxAntennas,obj.Nr.txAntennas)-pi;
                        obj.Implementation.randomVariables.phi      = 2*pi*rand(length(obj.Implementation.IndexDelayTaps),1,obj.Nr.Paths,obj.Nr.rxAntennas,obj.Nr.txAntennas)-pi;
                        obj.Implementation.randomVariables.psi      = 2*pi*rand(length(obj.Implementation.IndexDelayTaps),1,obj.Nr.Paths,obj.Nr.rxAntennas,obj.Nr.txAntennas)-pi;
                    else
                        % generate independent random variables for time correlated spatial channel model
                        obj.Implementation.randomVariables.azimuthArrivalAngleLOS      = Utils.Extras.wrapTo360(obj.Implementation.spatialModel.angleMeanAOA + obj.Implementation.spatialModel.LOSangleSigmaAOA * randn(1));
                        obj.Implementation.randomVariables.zenithArrivalAngleLOS       = Utils.Extras.mirrorTo180(Utils.Extras.wrapTo360(obj.Implementation.spatialModel.angleMeanZOA + obj.Implementation.spatialModel.LOSangleSigmaZOA   * randn(1)));
                        obj.Implementation.randomVariables.azimuthArrivalAngleNLOS     = Utils.Extras.wrapTo360(repmat(rand(length(obj.Implementation.IndexDelayTaps),1).*360,1,obj.Implementation.spatialModel.nSpatialPaths) + obj.Implementation.spatialModel.NLOSangleSigmaAOA .* randn(length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths));
                        obj.Implementation.randomVariables.zenithArrivalAngleNLOS      = Utils.Extras.mirrorTo180(Utils.Extras.wrapTo360(repmat(rand(length(obj.Implementation.IndexDelayTaps),1).*180,1,obj.Implementation.spatialModel.nSpatialPaths) + obj.Implementation.spatialModel.NLOSangleSigmaZOA .* randn(length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths)));
                        obj.Implementation.randomVariables.azimuthDepartureAngleNLOS   = Utils.Extras.wrapTo360(repmat(rand(length(obj.Implementation.IndexDelayTaps),1).*360,1,obj.Implementation.spatialModel.nSpatialPaths) + obj.Implementation.spatialModel.NLOSangleSigmaAOA .* randn(length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths));
                        obj.Implementation.randomVariables.zenithDepartureAngleNLOS    = Utils.Extras.mirrorTo180(Utils.Extras.wrapTo360(repmat(rand(length(obj.Implementation.IndexDelayTaps),1).*180,1,obj.Implementation.spatialModel.nSpatialPaths) + obj.Implementation.spatialModel.NLOSangleSigmaZOA .* randn(length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths)));
                        obj.Implementation.randomVariables.polarisationPhases          = rand(4,length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths)*2*pi - repmat(pi,[4,length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths]);
                        obj.Implementation.randomVariables.azimuthVelocityAngleNLOS    = Utils.Extras.wrapTo360((rand(length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths)*360));
                        obj.Implementation.randomVariables.zenithVelocityAngleNLOS     = Utils.Extras.mirrorTo180(Utils.Extras.wrapTo360((rand(length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths)*360)));
                    end
                end
            end
        end
        
        function NewRealization( obj, frame, frameStructure, direction )
            % overwrite frame index for TDD mode
            if nargin == 4
                if strcmp(frameStructure, 'TDD')
                    if strcmp(direction, 'Uplink')
                        frame = 2*frame - 1;
                    elseif strcmp(direction, 'Downlink')
                        frame = 2*frame; 
                    end
                end
            end
            
            % obtain new realization of the channel
            if obj.Implementation.spatialModel.spatialChannelModel
                % 3D Channel Model
                
                wavelength = 299792458/obj.PHY.carrierFrequency;
                interelementSpacingTx = obj.Implementation.spatialModel.antennaSpacingTx *wavelength;
                interelementSpacingRx = obj.Implementation.spatialModel.antennaSpacingRx *wavelength;
                horizontalSegmentsTx    =  interelementSpacingTx*((0:obj.Nr.txAntennasHorizontal-1)-((obj.Nr.txAntennasHorizontal-1)/2));
                verticalSegmentsTx      =  interelementSpacingTx*((0:obj.Nr.txAntennasVertical-1)-((obj.Nr.txAntennasVertical-1)/2));
                horizontalSegmentsRx    =  interelementSpacingRx*((0:obj.Nr.rxAntennasHorizontal-1)-((obj.Nr.rxAntennasHorizontal-1)/2));
                verticalSegmentsRx      =  interelementSpacingRx*((0:obj.Nr.rxAntennasVertical-1)-((obj.Nr.rxAntennasVertical-1)/2));
                
                kFactor = 10^(obj.Implementation.spatialModel.kFactor/10);  % Convert to linear scale
                
                % How to parametrise this?
                kappa   = 1000;       % Cross-polarisation coupling factor
               
                if obj.Implementation.correlatedFrames && nargin == 4
                    % Parametrisation for correlated fading. Takes care of
                    % appropriately assigning UL-DL pairs for the chosen Links 
                    
                    % LOS
                    azimuthArrivalAngleLOS = obj.Implementation.randomVariables.azimuthArrivalAngleLOS;
                    zenithArrivalAngleLOS  = obj.Implementation.randomVariables.zenithArrivalAngleLOS;
                    
                    % NLOS
                    if strcmp(direction, 'Uplink')
                        azimuthArrivalAngleNLOS     = obj.Implementation.randomVariables.azimuthArrivalAngleNLOS;
                        zenithArrivalAngleNLOS      = obj.Implementation.randomVariables.zenithArrivalAngleNLOS;
                        azimuthDepartureAngleNLOS   = obj.Implementation.randomVariables.azimuthDepartureAngleNLOS;
                        zenithDepartureAngleNLOS    = obj.Implementation.randomVariables.zenithDepartureAngleNLOS;
                    else
                        azimuthArrivalAngleNLOS     = obj.Implementation.randomVariables.azimuthDepartureAngleNLOS;
                        zenithArrivalAngleNLOS      = obj.Implementation.randomVariables.zenithDepartureAngleNLOS;
                        azimuthDepartureAngleNLOS   = obj.Implementation.randomVariables.azimuthArrivalAngleNLOS;
                        zenithDepartureAngleNLOS    = obj.Implementation.randomVariables.zenithArrivalAngleNLOS;
                    end
                                        
                    % Random Phases
                    zenithCophase   = reshape(obj.Implementation.randomVariables.polarisationPhases(1,:,:),length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths);
                    azimuthCophase  = reshape(obj.Implementation.randomVariables.polarisationPhases(2,:,:),length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths);
                    zenithXphase    = reshape(obj.Implementation.randomVariables.polarisationPhases(3,:,:),length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths);
                    azimuthXphase   = reshape(obj.Implementation.randomVariables.polarisationPhases(4,:,:),length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths);
                    
                    % Velocity Angles
                    if obj.PHY.MaximumDopplerShift > 0
                        azimuthVelocityAngle = obj.Implementation.randomVariables.azimuthVelocityAngleNLOS;
                        zenithVelocityAngle  = obj.Implementation.randomVariables.zenithVelocityAngleNLOS;
                    end
                    
                else
                % Uncorrelated fading. Generate new (independent) sets of
                % parameters for each realisation
                    % LOS
                    azimuthArrivalAngleLOS = Utils.Extras.wrapTo360(obj.Implementation.spatialModel.angleMeanAOA + obj.Implementation.spatialModel.LOSangleSigmaAOA * randn(1)) ;
                    zenithArrivalAngleLOS  = Utils.Extras.mirrorTo180(Utils.Extras.wrapTo360(obj.Implementation.spatialModel.angleMeanZOA + obj.Implementation.spatialModel.LOSangleSigmaZOA   * randn(1))); 
                    
                    % NLOS
                    azimuthArrivalAngleNLOS   = Utils.Extras.wrapTo360(repmat(rand(length(obj.Implementation.IndexDelayTaps),1).*360,1,obj.Implementation.spatialModel.nSpatialPaths) + obj.Implementation.spatialModel.NLOSangleSigmaAOA .* randn(length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths));
                    zenithArrivalAngleNLOS    = Utils.Extras.mirrorTo180(Utils.Extras.wrapTo360(repmat(rand(length(obj.Implementation.IndexDelayTaps),1).*180,1,obj.Implementation.spatialModel.nSpatialPaths) + obj.Implementation.spatialModel.NLOSangleSigmaZOA .* randn(length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths)));
                    azimuthDepartureAngleNLOS = Utils.Extras.wrapTo360(repmat(rand(length(obj.Implementation.IndexDelayTaps),1).*360,1,obj.Implementation.spatialModel.nSpatialPaths) + obj.Implementation.spatialModel.NLOSangleSigmaAOA .* randn(length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths));
                    zenithDepartureAngleNLOS  = Utils.Extras.mirrorTo180(Utils.Extras.wrapTo360(repmat(rand(length(obj.Implementation.IndexDelayTaps),1).*180,1,obj.Implementation.spatialModel.nSpatialPaths) + obj.Implementation.spatialModel.NLOSangleSigmaZOA .* randn(length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths)));
                    
                    % Random Phases
                    zenithCophase   = rand(length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths)*2*pi - repmat(pi,[length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths]);
                    azimuthCophase  = rand(length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths)*2*pi - repmat(pi,[length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths]);
                    zenithXphase    = rand(length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths)*2*pi - repmat(pi,[length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths]);
                    azimuthXphase   = rand(length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths)*2*pi - repmat(pi,[length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths]);
                                        

                    % Velocity angles
                    if obj.PHY.MaximumDopplerShift > 0
                        azimuthVelocityAngle = (Utils.Extras.wrapTo360(rand(length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths)*360));
                        zenithVelocityAngle  = Utils.Extras.mirrorTo180((Utils.Extras.wrapTo360(rand(length(obj.Implementation.IndexDelayTaps),obj.Implementation.spatialModel.nSpatialPaths)*180)));
                    end
                end
                
                % LOS part
                azimuthDepartureAngleLOS    = Utils.Extras.wrapTo360(azimuthArrivalAngleLOS+180); % Azimuth angle to the x axis
                zenithDepartureAngleLOS     = Utils.Extras.mirrorTo180(Utils.Extras.wrapTo360(zenithArrivalAngleLOS+180)); % Elevation angle to the z axis
                % wave vector
                bearingTx  = obj.Implementation.spatialModel.nodesOrientationTx(1);
                downtiltTx = obj.Implementation.spatialModel.nodesOrientationTx(2);
                slantTx    = obj.Implementation.spatialModel.nodesOrientationTx(3);

                rotationMatrixTx = [cosd(bearingTx)*cosd(downtiltTx),...
                    sind(bearingTx)*cosd(downtiltTx),...
                    -sind(downtiltTx);...
                    ...
                    cosd(bearingTx)*sind(downtiltTx)*sind(slantTx) - sind(bearingTx)*cosd(slantTx),...
                    sind(bearingTx)*sind(downtiltTx)*sind(slantTx) + cosd(bearingTx)*cosd(slantTx),...
                    cosd(downtiltTx)*sind(slantTx);
                    ...
                    cosd(bearingTx)*sind(downtiltTx)*cosd(slantTx) + sind(bearingTx)*sind(slantTx),...
                    sind(bearingTx)*sind(downtiltTx)*cosd(slantTx) - cosd(bearingTx)*sind(slantTx),...
                    cosd(downtiltTx)*cosd(slantTx);];

                bearingRx  = obj.Implementation.spatialModel.nodesOrientationRx(1);
                downtiltRx = obj.Implementation.spatialModel.nodesOrientationRx(2);
                slantRx    = obj.Implementation.spatialModel.nodesOrientationRx(3);

                rotationMatrixRx = [cosd(bearingRx)*cosd(downtiltRx),...
                    sind(bearingRx)*cosd(downtiltRx),...
                    -sind(downtiltRx);...
                    ...
                    cosd(bearingRx)*sind(downtiltRx)*sind(slantRx) - sind(bearingRx)*cosd(slantRx),...
                    sind(bearingRx)*sind(downtiltRx)*sind(slantRx) + cosd(bearingRx)*cosd(slantRx),...
                    cosd(downtiltRx)*sind(slantRx);
                    ...
                    cosd(bearingRx)*sind(downtiltRx)*cosd(slantRx) + sind(bearingRx)*sind(slantRx),...
                    sind(bearingRx)*sind(downtiltRx)*cosd(slantRx) - cosd(bearingRx)*sind(slantRx),...
                    cosd(downtiltRx)*cosd(slantRx);];

                waveVectorTx = rotationMatrixTx * 2*pi/wavelength*[sind(zenithDepartureAngleLOS)*cosd(azimuthDepartureAngleLOS);...
                    sind(zenithDepartureAngleLOS)*sind(azimuthDepartureAngleLOS);...
                    cosd(zenithDepartureAngleLOS)*ones(size(azimuthDepartureAngleLOS))];
                waveVectorRx = rotationMatrixRx * 2*pi/wavelength*[sind(zenithArrivalAngleLOS)*cosd(azimuthArrivalAngleLOS);...
                    sind(zenithArrivalAngleLOS)*sind(azimuthArrivalAngleLOS);...
                    cosd(zenithArrivalAngleLOS)*ones(size(azimuthArrivalAngleLOS))];
                
                %array component vectors (horizontal and vertical)
                horizontalArrayComponentTx  = exp(1i*waveVectorTx(1)*horizontalSegmentsTx);
                verticalArrayComponentTx    = exp(1i*waveVectorTx(2)*verticalSegmentsTx);
                horizontalArrayComponentRx  = exp(1i*waveVectorRx(1)*horizontalSegmentsRx);
                verticalArrayComponentRx    = exp(1i*waveVectorRx(2)*verticalSegmentsRx);
                
                % array manifold vector v ( antenna spatial characteristic)
                % either by a kronecker tensor product, or vectorizing a matrix with
                % rows being the individual array vectors for each ant. element
                arrayVectorTx = kron(verticalArrayComponentTx,horizontalArrayComponentTx);
                arrayVectorRx = kron(verticalArrayComponentRx,horizontalArrayComponentRx);
                
                % Antenna polarization modelling:
                % slant angle ksi is taken to be:
                % ksi = 0 deg -> vertically pol. ant. element
                % ksi = +-45 deg -> pair of cross-pol. ant. elements ( X )
                % Field Pattern.. F(theta, phi)
                
                if 2*(obj.Nr.txAntennasHorizontal*obj.Nr.txAntennasVertical) == obj.Nr.txAntennas
                    % Cross-polarization considered
                    arrayVectorTx           = [arrayVectorTx,arrayVectorTx];
                    zenithFieldPatternTx    = [ones(1,obj.Nr.txAntennas/2)*cos(pi/4),ones(1,obj.Nr.txAntennas/2)*cos(-pi/4)];
                    azimuthFieldPatternTx   = [ones(1,obj.Nr.txAntennas/2)*sin(pi/4),ones(1,obj.Nr.txAntennas/2)*sin(-pi/4)];
                    fieldPatternTx          = [zenithFieldPatternTx;azimuthFieldPatternTx];
                    polarizationTerm        = arrayfun(@(x1,x2,x3,x4) [x1,x2;x3,x4],exp(1i*zenithCophase),sqrt(kappa^-1)*exp(1i*zenithXphase),sqrt(kappa^-1)*exp(1i*azimuthXphase),exp(1i*azimuthCophase),'UniformOutput',false);
                else
                    % Vertical polarization considered
                    zenithFieldPatternTx    = ones(1,obj.Nr.txAntennas);
                    azimuthFieldPatternTx   = zeros(1,obj.Nr.txAntennas);
                    fieldPatternTx          = [zenithFieldPatternTx;azimuthFieldPatternTx];
                    polarizationTerm        = num2cell(exp(1j * zenithCophase));
                end
                
                if 2*(obj.Nr.rxAntennasHorizontal*obj.Nr.rxAntennasVertical) == obj.Nr.rxAntennas
                    % Cross-polarization considered
                    arrayVectorRx           = [arrayVectorRx,arrayVectorRx];
                    zenithFieldPatternRx    = [ones(1,obj.Nr.rxAntennas/2)*cos(pi/4),ones(1,obj.Nr.rxAntennas/2)*cos(-pi/4)];
                    azimuthFieldPatternRx   = [ones(1,obj.Nr.rxAntennas/2)*sin(pi/4),ones(1,obj.Nr.rxAntennas/2)*sin(-pi/4)];
                    fieldPatternRx          = [zenithFieldPatternRx;azimuthFieldPatternRx];
                else
                    % Vertical polarization considered
                    zenithFieldPatternRx    = ones(1,obj.Nr.rxAntennas);
                    azimuthFieldPatternRx   =  zeros(1,obj.Nr.rxAntennas);
                    fieldPatternRx          = [zenithFieldPatternRx;azimuthFieldPatternRx];
                end
                
                % Generate the LOS channel Impuse Response H
                % In the case of x-pol, the first half of the antennas is theta polarized and  second half has the same position as first half but is
                % phi polarized
                
                % time-variant fading components for LOS
                if obj.PHY.MaximumDopplerShift>0
                    
                    velocity = 299792458 /obj.PHY.carrierFrequency * obj.PHY.MaximumDopplerShift;
                    
                    t = (0:obj.PHY.dt:obj.PHY.dt*(obj.Nr.SamplesTotal-1))+obj.PHY.dt*obj.Nr.SamplesTotal*frame;
                    
                    % Subsampling is performed with a factor of timeSubsamplingFactor, and then the resultant impulse response 
                    % is interpolated to the full impulse response using the nearest-neighbour.
                    tSubsamp = t(1:obj.Implementation.timeSubsamplingFactor:end);
                    indSubsamp = reshape(repmat(1:ceil(obj.Nr.SamplesTotal/obj.Implementation.timeSubsamplingFactor), obj.Implementation.timeSubsamplingFactor, 1), 1, []);

                    dopplerVelocityVector = velocity*[sind(zenithDepartureAngleLOS)*cosd(azimuthDepartureAngleLOS);...
                        sind(zenithDepartureAngleLOS)*sind(azimuthDepartureAngleLOS);...
                        cosd(zenithDepartureAngleLOS)];
                    
                    dopplerComponent = exp(1j*2*pi*[sind(zenithArrivalAngleLOS)*cosd(azimuthArrivalAngleLOS);...
                        sind(zenithArrivalAngleLOS)*sind(azimuthArrivalAngleLOS);...
                        cosd(zenithArrivalAngleLOS)*ones(size(azimuthArrivalAngleLOS))].'*...
                        dopplerVelocityVector ./ wavelength * tSubsamp).';
                    
                    Hlos = bsxfun(@times,permute(fieldPatternRx.' * [1,0;0,-1] * fieldPatternTx .* (repmat(arrayVectorRx,obj.Nr.txAntennas,1).') .* repmat(arrayVectorTx,obj.Nr.rxAntennas,1),[3,1,2]) , repmat(dopplerComponent,1,obj.Nr.rxAntennas,obj.Nr.txAntennas));

                    obj.ImpulseResponse = zeros(length(tSubsamp),size(obj.Implementation.PowerDelayProfileNormalized,1), obj.Nr.rxAntennas, obj.Nr.txAntennas);
                else
                    % time-invariant fading, LOS
                    Hlos = fieldPatternRx.' * [1,0;0,-1] * fieldPatternTx .* (repmat(arrayVectorRx,obj.Nr.txAntennas,1).') .* repmat(arrayVectorTx,obj.Nr.rxAntennas,1);

                    obj.ImpulseResponse = zeros(1,size(obj.Implementation.PowerDelayProfileNormalized,1), obj.Nr.rxAntennas, obj.Nr.txAntennas);
                end
                
                % Iterate over Delay Taps- NLOS part
                % Each Tap
                for iTap = 1:length(obj.Implementation.IndexDelayTaps)
                    
                    if obj.PHY.MaximumDopplerShift>0
                        HnlosTemp = zeros(length(tSubsamp),obj.Nr.rxAntennas,obj.Nr.txAntennas);
                    else
                        HnlosTemp = zeros(obj.Nr.rxAntennas,obj.Nr.txAntennas);
                    end

                    % Iterate over Paths
                    for iPath = 1:obj.Implementation.spatialModel.nSpatialPaths
                                 
                        % wave vector
                        bearingTx  = obj.Implementation.spatialModel.nodesOrientationTx(1);
                        downtiltTx = obj.Implementation.spatialModel.nodesOrientationTx(2);
                        slantTx    = obj.Implementation.spatialModel.nodesOrientationTx(3);

                        rotationMatrixTx = [cosd(bearingTx)*cosd(downtiltTx),...
                            sind(bearingTx)*cosd(downtiltTx),...
                            -sind(downtiltTx);...
                            ...
                            cosd(bearingTx)*sind(downtiltTx)*sind(slantTx) - sind(bearingTx)*cosd(slantTx),...
                            sind(bearingTx)*sind(downtiltTx)*sind(slantTx) + cosd(bearingTx)*cosd(slantTx),...
                            cosd(downtiltTx)*sind(slantTx);
                            ...
                            cosd(bearingTx)*sind(downtiltTx)*cosd(slantTx) + sind(bearingTx)*sind(slantTx),...
                            sind(bearingTx)*sind(downtiltTx)*cosd(slantTx) - cosd(bearingTx)*sind(slantTx),...
                            cosd(downtiltTx)*cosd(slantTx);];

                        bearingRx  = obj.Implementation.spatialModel.nodesOrientationRx(1);
                        downtiltRx = obj.Implementation.spatialModel.nodesOrientationRx(2);
                        slantRx    = obj.Implementation.spatialModel.nodesOrientationRx(3);

                        rotationMatrixRx = [cosd(bearingRx)*cosd(downtiltRx),...
                            sind(bearingRx)*cosd(downtiltRx),...
                            -sind(downtiltRx);...
                            ...
                            cosd(bearingRx)*sind(downtiltRx)*sind(slantRx) - sind(bearingRx)*cosd(slantRx),...
                            sind(bearingRx)*sind(downtiltRx)*sind(slantRx) + cosd(bearingRx)*cosd(slantRx),...
                            cosd(downtiltRx)*sind(slantRx);
                            ...
                            cosd(bearingRx)*sind(downtiltRx)*cosd(slantRx) + sind(bearingRx)*sind(slantRx),...
                            sind(bearingRx)*sind(downtiltRx)*cosd(slantRx) - cosd(bearingRx)*sind(slantRx),...
                            cosd(downtiltRx)*cosd(slantRx);];

                        waveVectorTx = rotationMatrixTx * 2*pi/wavelength*[sind(zenithDepartureAngleNLOS(iTap,iPath))*cosd(azimuthDepartureAngleNLOS(iTap,iPath));...
                            sind(zenithDepartureAngleNLOS(iTap,iPath))*sind(azimuthDepartureAngleNLOS(iTap,iPath));...
                            cosd(zenithDepartureAngleNLOS(iTap,iPath))*ones(size(azimuthDepartureAngleNLOS(iTap,iPath)))];
                        waveVectorRx = rotationMatrixRx * 2*pi/wavelength*[sind(zenithArrivalAngleNLOS(iTap,iPath))*cosd(azimuthArrivalAngleNLOS(iTap,iPath));...
                            sind(zenithArrivalAngleNLOS(iTap,iPath))*sind(azimuthArrivalAngleNLOS(iTap,iPath));...
                            cosd(zenithArrivalAngleNLOS(iTap,iPath))*ones(size(azimuthArrivalAngleNLOS(iTap,iPath)))];
                        
                        % array components vector
                        horizontalArrayComponentTx = exp(1i*waveVectorTx(1)*horizontalSegmentsTx);
                        verticalArrayComponentTx = exp(1i*waveVectorTx(2)*verticalSegmentsTx);
                        horizontalArrayComponentRx = exp(1i*waveVectorRx(1)*horizontalSegmentsRx);
                        verticalArrayComponentRx = exp(1i*waveVectorRx(2)*verticalSegmentsRx);
                        
                        % array manifold vector
                        arrayVectorTx = repmat(kron(horizontalArrayComponentTx,verticalArrayComponentTx),1,obj.Nr.txAntennas/(obj.Nr.txAntennasHorizontal*obj.Nr.txAntennasVertical));
                        arrayVectorRx = repmat(kron(horizontalArrayComponentRx,verticalArrayComponentRx),1,obj.Nr.rxAntennas/(obj.Nr.rxAntennasHorizontal*obj.Nr.rxAntennasVertical));
                        
                        % NLOS part
                        if obj.PHY.MaximumDopplerShift > 0
                            dopplerVelocityVector = velocity*[sind(zenithVelocityAngle(iTap,iPath))*cosd(azimuthVelocityAngle(iTap,iPath));...
                                sind(zenithVelocityAngle(iTap,iPath))*sind(azimuthVelocityAngle(iTap,iPath));...
                                cosd(zenithVelocityAngle(iTap,iPath))*ones(size(azimuthVelocityAngle(iTap,iPath)))];                            
                            dopplerComponent = exp(1j*2*pi*[sind(zenithArrivalAngleLOS)*cosd(azimuthArrivalAngleLOS);...
                                sind(zenithArrivalAngleLOS)*sind(azimuthArrivalAngleLOS);...
                                cosd(zenithArrivalAngleLOS)*ones(size(azimuthArrivalAngleLOS))].'*...
                                dopplerVelocityVector ./ wavelength * tSubsamp).';
                            HnlosTemp = HnlosTemp + bsxfun(@times,permute(fieldPatternRx.' * polarizationTerm{iTap, iPath} * fieldPatternTx .* (repmat(arrayVectorRx,obj.Nr.txAntennas,1).') .* repmat(arrayVectorTx,obj.Nr.rxAntennas,1),[3,1,2]),repmat(dopplerComponent,1,obj.Nr.rxAntennas,obj.Nr.txAntennas));
                        else                            
                            HnlosTemp = HnlosTemp + fieldPatternRx.' * polarizationTerm{iTap, iPath} * fieldPatternTx .* (repmat(arrayVectorRx,obj.Nr.txAntennas,1).') .* repmat(arrayVectorTx,obj.Nr.rxAntennas,1);
                        end
                    end % end Paths                  
                    obj.ImpulseResponse(:,obj.Implementation.IndexDelayTaps(iTap),:,:) = sqrt(obj.Implementation.PowerDelayProfileNormalized(obj.Implementation.IndexDelayTaps(iTap))/obj.Implementation.spatialModel.nSpatialPaths)*HnlosTemp;
                end % end Delay Taps                
                % combine LOS & NLOS part
                obj.ImpulseResponse = sqrt(1 / (1 + kFactor))*obj.ImpulseResponse;                
                obj.ImpulseResponse(:,1,:,:) = reshape(obj.ImpulseResponse(:,1,:,:),size(Hlos)) + sqrt(kFactor / (1+kFactor))*Hlos;
                
                if obj.PHY.MaximumDopplerShift > 0
                    % Interpolation
                    obj.ImpulseResponse = obj.ImpulseResponse(indSubsamp(1:obj.Nr.SamplesTotal), :, :, :);
                end 
            else % end Spatial Model
                if strcmp(obj.Implementation.PowerDelayProfile, 'AWGN')
                    obj.ImpulseResponse(1,:,:,:) = ones( obj.Nr.rxAntennas, obj.Nr.txAntennas );
                else
                    % time-variant channel
                    if obj.PHY.MaximumDopplerShift>0
                        obj.ImpulseResponse = zeros( obj.Nr.SamplesTotal, size(obj.Implementation.PowerDelayProfileNormalized,1), obj.Nr.rxAntennas, obj.Nr.txAntennas  );
                        if obj.Implementation.UseDiscreteDopplerSpectrum % Faster calulation using IFFT. Underlying assumption: discrete Doppler shifts => valid only for a high number of samples/Doppler shift
                            for iTx = 1:obj.Nr.txAntennas
                                for iRx = 1:obj.Nr.rxAntennas
                                    NrDopplerShifts = (size(obj.Implementation.DiscreteDopplerSpectrum,1)-1)/2;
                                    
                                    GaussUncorr1 = obj.Nr.SamplesTotal/sqrt(2)*(randn(NrDopplerShifts+1,length(obj.Implementation.IndexDelayTaps))+1j*randn(NrDopplerShifts+1,length(obj.Implementation.IndexDelayTaps)));
                                    GaussUncorr2 = obj.Nr.SamplesTotal/sqrt(2)*(randn(NrDopplerShifts,length(obj.Implementation.IndexDelayTaps))+1j*randn(NrDopplerShifts,length(obj.Implementation.IndexDelayTaps)));
                                    
                                    GaussUncorr1 = GaussUncorr1.*repmat(sqrt(obj.Implementation.PowerDelayProfileNormalized(obj.Implementation.IndexDelayTaps).'),size(GaussUncorr1,1),1);
                                    GaussUncorr2 = GaussUncorr2.*repmat(sqrt(obj.Implementation.PowerDelayProfileNormalized(obj.Implementation.IndexDelayTaps).'),size(GaussUncorr2,1),1);
                                    
                                    obj.ImpulseResponse(:,obj.Implementation.IndexDelayTaps,iRx,iTx) = ifft(...
                                        [sqrt(obj.Implementation.DiscreteDopplerSpectrum(NrDopplerShifts+1:end,:)).*GaussUncorr1;...
                                        zeros(obj.Nr.SamplesTotal-NrDopplerShifts*2-1,length(obj.Implementation.IndexDelayTaps));...
                                        sqrt(obj.Implementation.DiscreteDopplerSpectrum(1:NrDopplerShifts,:)).*GaussUncorr2]);
                                end
                            end
                        else % This is the true Doppler spectum (continuous and not discrete!)
                            if obj.Implementation.correlatedFrames
                                % correlated Rayleigh fading channel according to:
                                % Yahong Rosa Zheng et. al., "Simulation Models With Correct Statistical Properties for Rayleigh Fading Channels", IEEE Trans. on Comm., Vol. 51, No. 6, June, 2003
                                % with a slight modification as described in the appendix of:
                                % Thomas Zemen et. al., "Time-Variant Channel Estimation Using Discrete Prolate Spheroidal Sequences", IEEE Trans. on Signal Processing, Vol. 53, No. 9, Sep. 2005
                                switch obj.Implementation.DopplerModel
                                    case 'Jakes'
                                        ImpulseResponseTemp = zeros(length(obj.PHY.PowerDelayProfile),obj.Nr.SamplesTotal,obj.Nr.rxAntennas,obj.Nr.txAntennas);
                                        t = (0:obj.PHY.dt:obj.PHY.dt*(obj.Nr.SamplesTotal-1))+obj.PHY.dt*obj.Nr.SamplesTotal*frame;
                                        alpha = (2*pi*repmat(reshape((1:obj.Nr.Paths),[1,1,obj.Nr.Paths]),[length(obj.Implementation.IndexDelayTaps),1,1,obj.Nr.rxAntennas,obj.Nr.txAntennas])-pi+permute(repmat(obj.Implementation.randomVariables.theta,[1,1,1,1,obj.Nr.Paths]),[1 2 5 3 4])) ./ (4*obj.Nr.Paths);

                                        % Subsampling is performed with a factor of timeSubsamplingFactor, and then the resultant impulse response 
                                        % is interpolated to the full impulse response using the nearest-neighbour.
                                        tSubsamp = t(1:obj.Implementation.timeSubsamplingFactor:end);
                                        indSubsamp = reshape(repmat(1:ceil(obj.Nr.SamplesTotal/obj.Implementation.timeSubsamplingFactor), obj.Implementation.timeSubsamplingFactor, 1), 1, []);

                                        
                                        X = exp(1i*obj.Implementation.randomVariables.psi).*cos(2*pi* obj.PHY.MaximumDopplerShift .* tSubsamp .* cos(alpha) + obj.Implementation.randomVariables.phi); % bsxfun implicit since matlab 2016b
                                        subsampledIR = 2/sqrt(2*obj.Nr.Paths) * sum(X, 3); 
                                        
                                        % Interpolation
                                        ImpulseResponseTemp(obj.Implementation.IndexDelayTaps, :, :, :) = subsampledIR(:, indSubsamp(1:obj.Nr.SamplesTotal), :, :, :);
                                        
                                        obj.ImpulseResponse = permute(obj.Implementation.PowerDelayProfileNormalized .* ImpulseResponseTemp,[2 1 3 4]);
                                    case 'Uniform'
                                        error('Uniform Doppler spectrum currently not implemented for correlated fading!');
                                    otherwise
                                        error('Doppler spectrum not supported');
                                end
                            else
                                % uncorrelated fading
                                ImpulseResponseTemp = zeros(length(obj.PHY.PowerDelayProfile),obj.Nr.SamplesTotal);
                                for iTx = 1:obj.Nr.txAntennas
                                    for iRx = 1:obj.Nr.rxAntennas
                                        switch obj.Implementation.DopplerModel
                                            case 'Jakes'
                                                DopplerShifts = cos(rand([length(obj.Implementation.IndexDelayTaps), 1, obj.Nr.Paths])*2*pi)*obj.PHY.MaximumDopplerShift;
                                            case 'Uniform'
                                                DopplerShifts = 2*(rand([length(obj.Implementation.IndexDelayTaps), 1, obj.Nr.Paths])-0.5)*obj.PHY.MaximumDopplerShift;
                                            otherwise
                                                error('Doppler spectrum not supported');
                                        end
                                        RandomPhase = rand([length(obj.Implementation.IndexDelayTaps) 1 obj.Nr.Paths]);
                                        t = 0:obj.PHY.dt:obj.PHY.dt*(obj.Nr.SamplesTotal-1);
                                        
                                        % Subsampling is performed with a factor of timeSubsamplingFactor, and then the resultant impulse response 
                                        % is interpolated to the full impulse response  using the nearest-neighbour.
                                        tSubsamp = t(1:obj.Implementation.timeSubsamplingFactor:end);
                                        indSubsamp = reshape(repmat(1:ceil(obj.Nr.SamplesTotal/obj.Implementation.timeSubsamplingFactor), obj.Implementation.timeSubsamplingFactor, 1), 1, []);

                                        subsampledIR = sum(exp(1j*2*pi* (bsxfun(@plus, RandomPhase, bsxfun(@times, DopplerShifts, tSubsamp)))), 3) ./ sqrt(obj.Nr.Paths);
                                        
                                        % Interpolation
                                        ImpulseResponseTemp(obj.Implementation.IndexDelayTaps, :) = subsampledIR(:, indSubsamp(1:obj.Nr.SamplesTotal));
                                        
                                        obj.ImpulseResponse(:,:,iRx,iTx) = bsxfun(@times,sqrt(obj.Implementation.PowerDelayProfileNormalized), ImpulseResponseTemp).';
                                    end
                                end
                            end
                        end
                    else
                        % time-invariant channel
                        sigD2=1/(2*(1+obj.PHY.K));
                        V1=sqrt(obj.PHY.K*sigD2/2)*(sqrt(1+obj.PHY.delta)+sqrt(1-obj.PHY.delta));
                        V2=sqrt(obj.PHY.K*sigD2/2)*(sqrt(1+obj.PHY.delta)-sqrt(1-obj.PHY.delta));
                        obj.ImpulseResponse = zeros(1,size(obj.Implementation.PowerDelayProfileNormalized,1), obj.Nr.rxAntennas, obj.Nr.txAntennas);
                        for iTx = 1:obj.Nr.txAntennas
                            for iRx = 1:obj.Nr.rxAntennas
                                obj.ImpulseResponse(1,:,iRx,iTx) = ((sqrt(sigD2*obj.Implementation.PowerDelayProfileNormalized)).*(randn(size(obj.Implementation.PowerDelayProfileNormalized))+1j*randn(size(obj.Implementation.PowerDelayProfileNormalized)))).';
                                obj.ImpulseResponse(1,1,iRx,iTx) = obj.ImpulseResponse(1,1,iRx,iTx) + V1*exp(1j*2*pi*rand()) + V2*exp(1j*2*pi*rand());
                            end
                        end
                    end
                end
            end
            
            % introduce spatial correlation via Kronecker correlation model
            if ~strcmp(obj.Implementation.spatialCorrelation,'none')
                for iTime = 1:size(obj.ImpulseResponse,1)
                    for iDelay = 1:size(obj.ImpulseResponse,2)
                        obj.ImpulseResponse(iTime,iDelay,:,:) = sqrtm(obj.Implementation.spatialCorrelationMatrixRX) * reshape(obj.ImpulseResponse(iTime,iDelay,:,:),obj.Nr.rxAntennas, obj.Nr.txAntennas) * sqrtm(obj.Implementation.spatialCorrelationMatrixTX);
                    end
                end
            end
        end
        
        
        function convolvedSignal = Convolution(obj, signal)
            % Convolution of the signal with the time variant impulse response
            
            N = size(signal,1);
            if obj.PHY.MaximumDopplerShift>0
                convolvedSignal = zeros(N, obj.Nr.rxAntennas);
                ConvolutionMatrix   = obj.GetConvolutionMatrix;
                for iTx = 1:obj.Nr.txAntennas
                    for iRx = 1:obj.Nr.rxAntennas
                        convolvedSignal(:,iRx) = convolvedSignal(:,iRx) + ConvolutionMatrix{iRx,iTx}(1:N,1:N)*signal(:,iTx);
                    end
                end
            else
                convolvedSignal = zeros(N + size(obj.Implementation.PowerDelayProfileNormalized,1)-1, obj.Nr.rxAntennas);
                for iTx = 1:obj.Nr.txAntennas
                    for iRx = 1:obj.Nr.rxAntennas
                        convolvedSignal(:,iRx) = convolvedSignal(:,iRx) + conv( signal(:,iTx), obj.ImpulseResponse(1,:,iRx,iTx) );
                    end
                end
                convolvedSignal = convolvedSignal(1:N,:);% remove tails
            end
        end
        
        function ConvolutionMatrix = GetConvolutionMatrix(obj)
            % returns the time-variant convolution matrix
            
            ConvolutionMatrix = cell( obj.Nr.rxAntennas, obj.Nr.txAntennas );
            if obj.PHY.MaximumDopplerShift>0
                for iTx = 1:obj.Nr.txAntennas
                    for iRx = 1:obj.Nr.rxAntennas
                        ImpulseResponseTemp = obj.ImpulseResponse(:,obj.Implementation.IndexDelayTaps,iRx,iTx);
                        ConvolutionMatrix{iRx,iTx} = sparse(obj.Implementation.MappingConvolutionMatrixFast(:,2),obj.Implementation.MappingConvolutionMatrixFast(:,1),ImpulseResponseTemp(obj.Implementation.CancelElementsConvolutionMatrixFast),obj.Nr.SamplesTotal,obj.Nr.SamplesTotal);
                    end
                end
            else
                for iTx = 1:obj.Nr.txAntennas
                    for iRx = 1:obj.Nr.rxAntennas
                        ImpulseResponseTemp = obj.ImpulseResponse(ones(obj.Nr.SamplesTotal,1),obj.Implementation.IndexDelayTaps,iRx,iTx);
                        ConvolutionMatrix{iRx,iTx} = sparse(obj.Implementation.MappingConvolutionMatrixFast(:,2),obj.Implementation.MappingConvolutionMatrixFast(:,1),ImpulseResponseTemp(obj.Implementation.CancelElementsConvolutionMatrixFast),obj.Nr.SamplesTotal,obj.Nr.SamplesTotal);
                    end
                end
            end
        end
        
        function ChannelTransferFunction = GetTransferFunction(obj, TimePos, FFTSize, ActiveSubcarrier)
            % Calculates the channel transfer function at certain time
            % positions. The first argument is a vector and gives the time
            % positions. The second argument represents the FFT size of the
            % underlying modulation format. The third argument (if
            % specified) determines which subcarriers are active (only
            % these frequency positions are returned).
            
            ChannelTransferFunction = zeros(FFTSize, length(TimePos), obj.Nr.rxAntennas, obj.Nr.txAntennas);
            if obj.PHY.MaximumDopplerShift==0
                TimePos = ones(length(TimePos), 1);
            end
            for iTx = 1:obj.Nr.txAntennas
                for iRx = 1:obj.Nr.rxAntennas
                    ImpulseTemp = [obj.ImpulseResponse(TimePos,:,iRx,iTx).'; zeros(FFTSize - size(obj.ImpulseResponse, 2), length(TimePos))];
                    ChannelTransferFunctionTmp = fft(ImpulseTemp, [], 1);
                    ChannelTransferFunction(:, :, iRx, iTx) = ChannelTransferFunctionTmp(1:FFTSize, :); % if channel impulse response is longer than FFTsize, take only first FFTsize samples
                end
            end
            if exist('ActiveSubcarrier', 'var')
                ChannelTransferFunction = ChannelTransferFunction(ActiveSubcarrier, :, :, :);
            end
        end
        
        function [TimeCorrelation, Time] = GetTimeCorrelation(obj)
            % returns the time-autocorrelation function of the channel.
            
            if obj.PHY.MaximumDopplerShift>0
                if obj.Implementation.UseDiscreteDopplerSpectrum
                    % Can be implemented similar as the frequency
                    % correlation. Needs to be done when time
                    warning('Exact solution only for a continuous Doppler spectrum.');
                end
                Time = -obj.PHY.dt*(obj.Nr.SamplesTotal-1):obj.PHY.dt:obj.PHY.dt*(obj.Nr.SamplesTotal-1);
                switch obj.Implementation.DopplerModel
                    case 'Jakes'
                        TimeCorrelation = besselj(0,pi*2*obj.PHY.MaximumDopplerShift*Time);
                    case 'Uniform'
                        TimeCorrelation = Utils.Extras.sinc(2*obj.PHY.MaximumDopplerShift*Time);
                end
            else
                TimeCorrelation = ones(1,obj.Nr.SamplesTotal*2-1);
            end
        end
        
        function [FrequencyCorrelation,Frequency] = GetFrequencyCorrelation(obj)
            % returns the frequency-autocorrelation function of the channel.
            
            df = 1/(obj.Nr.SamplesTotal*obj.PHY.dt);
            
            FrequencyCorrelation = fft([obj.Implementation.PowerDelayProfileNormalized;zeros(obj.Nr.SamplesTotal-length(obj.Implementation.PowerDelayProfileNormalized),1)]);
            FrequencyCorrelation = circshift(FrequencyCorrelation,[ceil(obj.Nr.SamplesTotal/2) 1]);
            
            Frequency =((1:obj.Nr.SamplesTotal)-ceil(obj.Nr.SamplesTotal/2)-1)*df;
        end
        
        function MeanDelay = GetMeanDelay(obj)
            % returns the mean delay of the channel.
            
            Tau = (0:(length(obj.Implementation.PowerDelayProfileNormalized))-1)*obj.PHY.dt;
            MeanDelay = sum(Tau.*obj.Implementation.PowerDelayProfileNormalized.');
        end
        function RmsDelaySpread = GetRmsDelaySpread(obj)
            % returns the root mean squared doppler spread of the channel
            
            Tau = (0:(length(obj.Implementation.PowerDelayProfileNormalized))-1)*obj.PHY.dt;
            MeanDelay = obj.GetMeanDelay;
            RmsDelaySpread = sqrt(sum(Tau.^2.*obj.Implementation.PowerDelayProfileNormalized.')-MeanDelay.^2);
        end
        function CorrelationMatrix = GetCorrelationMatrix(obj)
            % returns the correlation matrix of the vectorized convolution
            % matrix. Let y=H*x be the channel description with H beeing
            % the time-variant convolution matrix. Then, this method
            % returns the E{H(:)H(:)'}.
            
            IndexTimeCorrelation = bsxfun(@plus,obj.Nr.SamplesTotal+(0:(obj.Nr.SamplesTotal-1)).',(0:-1:-(obj.Nr.SamplesTotal-1)));
            TimeCorrelation =  obj.GetTimeCorrelation;
            CorrelationMatrixOrdered = (...
                repmat(TimeCorrelation(IndexTimeCorrelation),[size(obj.Implementation.PowerDelayProfileNormalized,1) 1]).*...
                kron(sparse(obj.Implementation.PowerDelayProfileNormalized),ones(size(IndexTimeCorrelation))));
            IndexCorrMatrixConv = bsxfun(@plus,(1:(obj.Nr.SamplesTotal+1):obj.Nr.SamplesTotal^2).',(0:1:(size(obj.ImpulseResponse,2)-1)));
            % Memory efficient solution
            SplittingFactor = ceil(numel(IndexCorrMatrixConv)*obj.Nr.SamplesTotal*8/1e9);
            while mod(obj.Nr.SamplesTotal/SplittingFactor,1)
                SplittingFactor = SplittingFactor+1;
            end
            if SplittingFactor>1
                CorrelationMatrix = sparse(obj.Nr.SamplesTotal^2+size(IndexCorrMatrixConv,2)-1,obj.Nr.SamplesTotal^2+size(IndexCorrMatrixConv,2)-1);
                Row = repmat(reshape(IndexCorrMatrixConv,[],1),obj.Nr.SamplesTotal/SplittingFactor,1);
                for i_split = 1:SplittingFactor
                    Index1Temp = (1:obj.Nr.SamplesTotal/SplittingFactor)+(i_split-1)*obj.Nr.SamplesTotal/SplittingFactor;
                    Index2Temp = (1:numel(CorrelationMatrixOrdered)/SplittingFactor)+(i_split-1)*numel(CorrelationMatrixOrdered)/SplittingFactor;
                    
                    Column = reshape(kron(IndexCorrMatrixConv(Index1Temp,:).',ones(size(IndexCorrMatrixConv,1),1)),[],1);
                    CorrelationMatrix = CorrelationMatrix+...
                        sparse(Row,Column,CorrelationMatrixOrdered(Index2Temp),...
                        obj.Nr.SamplesTotal^2+size(IndexCorrMatrixConv,2)-1,...
                        obj.Nr.SamplesTotal^2+size(IndexCorrMatrixConv,2)-1);
                end
            else
                CorrelationMatrix = sparse(...
                    repmat(reshape(IndexCorrMatrixConv,[],1),obj.Nr.SamplesTotal,1),...
                    reshape(kron(IndexCorrMatrixConv.',ones(size(IndexCorrMatrixConv,1),1)),[],1),...
                    CorrelationMatrixOrdered(:));
            end
            CorrelationMatrix = CorrelationMatrix(1:obj.Nr.SamplesTotal^2,1:obj.Nr.SamplesTotal^2);
        end
        
        function [TimeCorrelation,Time] = PlotTimeCorrelation(obj,TimeSpacing)
            % Plot the time correlation. The input argument represents
            % the time-spacing and plots discrete points at multiples
            % of the time-spacing (only for presentational purpose)
            
            [TimeCorrelation,Time]=obj.GetTimeCorrelation;
            figure();
            plot(Time,abs(TimeCorrelation));
            ylabel('|Time Correlation|');
            xlabel('Time (s)');
            
            if not(exist('TimeSpacing','var'))
                TimePointSymbols = (-ceil(Time(end)/TimeSpacing):ceil(Time(end)/TimeSpacing))*TimeSpacing;
                hold on;
                Plot1 = stem(TimePointSymbols,abs(interp1(Time,TimeCorrelation,TimePointSymbols)),'black');
                legend(Plot1,{'TimeSpacing'});
            end
        end
        
        function [FrequencyCorrelation,Frequency] = PlotFrequencyCorrelation(obj,FrequencySpacing)
            % Plot the frequency correlation. The input argument represents
            % the time-spacing and plots discrete points at multiples
            % of the time-spacing (only for presentational purpose)
            
            [FrequencyCorrelation,Frequency]=obj.GetFrequencyCorrelation;
            figure();
            plot(Frequency,abs(FrequencyCorrelation));
            ylabel('|Frequency Correlation|');
            xlabel('Frequency (Hz)');
            
            if not(exist('FrequencySpacing','var'))
                FrequencyPointSymbols = (-ceil(Frequency(end)/FrequencySpacing):ceil(Frequency(end)/FrequencySpacing))*FrequencySpacing;
                hold on;
                Plot1 = stem(FrequencyPointSymbols,abs(interp1(Frequency,FrequencyCorrelation,FrequencyPointSymbols)),'black');
                legend(Plot1,{'FrequencySpacing'});
            end
        end
        function [PowerDelayProfile,Tau] = PlotPowerDelayProfile(obj)
            % Plot the desired power delay profile and the chosen power delay
            % profile, limited by the sampling rate
            
            Tau = (0:(length(obj.Implementation.PowerDelayProfileNormalized))-1)*obj.PHY.dt;
            PowerDelayProfile = obj.Implementation.PowerDelayProfileNormalized;
            if nargout==0
                DesiredTemp = 10.^(obj.PHY.DesiredPowerDelayProfiledB(1,:)/10);
                DesiredTemp = DesiredTemp/sum(DesiredTemp);
                RMSDelaySpread = obj.GetRmsDelaySpread;
                stem(obj.PHY.DesiredPowerDelayProfiledB(2,:)/1e-6,DesiredTemp,'-x red');
                hold on;
                stem(Tau/1e-6,PowerDelayProfile,'-o  blue');
                xlim([-obj.PHY.dt/1e-6/2 Tau(end)/1e-6+obj.PHY.dt/1e-6/2]);
                ylim([0 1]);
                xlabel('Delay [µs]');
                ylabel('Power Delay Profile');
                title(['RMS Delay Spread: ' num2str(round(RMSDelaySpread/1e-9)) 'ns']);
                legend({'Desired Delay Taps','Chosen Delay Taps (due to sampling)'});
            end
        end
        
    end
end