% parameter file for the RIS scenario
%
% The idea behind this scenario is, to show all possible options for all
% parameters. It is also a good starting point to define your own
% simulation scenarios.

% The scenario consists of two BSs, two UEs, and two RISs. Each BS controls 
% a RIS and is connected to one UE. RIS1 has eight elements, and RIS2 has 
% 16 elements. As expected, we observe a 3 dB gain when we double the
% number of RIS elements.

%% Topology
% Specifiy all the nodes in ascending order with starting index of 1 (BS0 or UE0 is not allowed).


scStr.topology.nodes                        = ['BS1,BS2,UE1,UE2,RIS1,RIS2'];      % Specify all nodes in the network

% Primary (desired) links
scStr.topology.primaryLinks                 = ['BS1:UE1,' ...
                                                'BS2:UE2'
                                               ];                       % Links to be considered as disired links
                                                

scStr.topology.RISControllerBS = ['BS1,BS2'];

% Interference Links   
scStr.topology.interferenceGeneration       = 'Manual';              % Generation of interference links
                                                                        % 'Automatic' automatically generates all possible interference links
                                                                        % 'Manual' manually choose interference links and their attenuation
                                                            
scStr.topology.interferer.attenuation       = 500;                       % In dB, for all links under 'Automatic' generation
scStr.topology.interferer.kFactor           = 0; 
scStr.topology.interferingLinks             = [''];   % For 'Manual' generation, specifiy the interference links
                                                                        % Value after the * symbol denotes the attenuation in dB.  
                                                                        % BS1:UE3*20 means that the link from BS1 to UE3 is an
                                                                        % interference link with attenuation equal to 20 dB;
                                                                        
scStr.topology.secondaryGeneration =  'Manual';   % Generation of interference links
                                                                        % 'Automatic' automatically generates all possible secondary links
                                                                        % 'Manual' manually choose interference links and their attenuation                                                                       
scStr.topology.secondary.pathloss = 100;
scStr.topology.secondary.kFactor  = 10; 

scStr.topology.secondaryLinks             = ['BS1:RIS1*60,RIS1:UE1*110,BS2:RIS2*60,RIS2:UE2*110'];  


%% Geometric Layout Parameters
scStr.topology.geometricLayout  = false; % The following parameters are only used when this is set to true

% Position of nodes
scStr.topology.nodesPosition{1}	= [257,274,10];    % Position of the nodes (x,y,z)[m] 
scStr.topology.nodesPosition{2} = [654,396,10];
scStr.topology.nodesPosition{3} = [116,274,1.5];
scStr.topology.nodesPosition{4} = [550,350,1.5];

% Pathloss model
scStr.simulation.pathLossModel.Type             = 'breakPoint'; %'freeSpace','breakPoint','rural','urban','subUrbanMacro'
scStr.simulation.pathLossModel.alpha            = 2;
scStr.simulation.pathLossModel.alpha2           = 3.9;
scStr.simulation.pathLossModel.breakDistance    = 50;
scStr.simulation.pathLossModel.averageBuildingHeight = 1;


%% General Simulation Parameters
% Set link types to simulate
scStr.simulation.simulateDownlink           = true;                     % Downlink
scStr.simulation.simulateUplink             = false;                    % Uplink

% set duplexing mode (frame structure)
scStr.simulation.frameStructure             = 'FDD';                    % 'TDD' or 'FDD'

% Plot options
scStr.simulation.plotResultsFor             = [1];                      % Choose the nodes that will get their results plotted (1 or 0 for each node).
                                                                        % Enter a single 1 if you want the results of all nodes to be plotted, or 0 if you want no plots.
                                                                    
                                                                        
                                                                         
scStr.simulation.plotOverSNR                = true;                     % Select to plot results over SNR instead of pathloss (if pathloss is selected as the sweep parameter).                                                                        
scStr.simulation.plotPAPR                   = false;                    % Select to toggle the Peak-to-Average Power Ratio (PAPR) calculation and plots
scStr.simulation.saveData                   = false;                    % Set to true to save bits and symbols.

% Define a sweep parameter
scStr.simulation.sweepParam                 = {'simulation.txPowerBaseStation'};  % Define the parameter to sweep over. This can be almost any simulation parameter.
                                                                        % Most likely it will be the pathloss to obtain results over SNR.
                                                                        % 'simulation.pathloss'
                                                                        % 'topology.secondary.pathloss'
                                                                                                                                        
scStr.simulation.sweepValue                 = linspace(35,65,10);       % Define parameter values to sweep over. A good starting point for the pathloss is 150 to 110.

scStr.simulation.applySweepingTo            = [1];                      % Define the nodes (or links, depending on the sweep parameter) on which the sweep parameter will be applied (1 or 0 for each node/link).
                                                                        % All other nodes (or links) set to 0 here will use the custom values entered below. 
                                                                        % Enter a single 1 if you want all of them to be swept over.
% Number of simulation frames
scStr.simulation.nFrames                    = 500;                      % Number of frames to simulate per sweep value, adjust to obtain sufficiently small confidence intervals.

%% Physical Transmission Parameters
scStr.simulation.centerFrequency            = 2.5e9;                    % center frequency

scStr.simulation.txPowerBaseStation         = [30];                     % per BS; BS total transmit power in dBm
scStr.simulation.txPowerUser                = [30];                     % per UE; UE total transmit power in dBm

scStr.simulation.codebook                   = 'LTE';                    % 'LTE' or '5G'
scStr.simulation.nAntennasBaseStation       = {1};                      % per BS: number of antennas at the BS
                                                                        % per BS: if the 5G codebook is selected, each vector represents the number of horizontal and vertical antennas[N1,N2]
                                                                        % Supported configurations (N1,N2):
                                                                        %  4 Ports: (2,1)
                                                                        %  8 Ports: (2,2), (4,1)
                                                                        % 12 Ports: (3,2),(6,1)
                                                                        % 16 Ports: (4,2), (8,1)
                                                                        % 24 Ports: (4,3), (6,2),(12,1)
                                                                        % 32 Ports: (4,4), (8,2), (16,1)

                                                                                                                  
scStr.simulation.nAntennasUser              = [1];                      % per UE; number of antennas at the user
scStr.simulation.userVelocity               = [0];                      % per UE; velocity in m/s

scStr.simulation.pathloss                   = [170];                     % per primary link, channel pathloss in dB, this is most likely swept over

% Nonlinearity model
scStr.simulation.nonlinearity               = false;                    % Apply Rapp's PA nonlinear model: Rapp, C. "Effects of HPA-nonlinearity on a 4-DPSK/OFDM-signal for a digital sound broadcasting signal."        
scStr.simulation.amplifierOBO               = [1];                      % Amplifier output back-off, per Link, in dB
scStr.simulation.smoothnessFactor           = [3];                      % Smoothness factor for the Rapp model, per Link, >=0

% RIS related parameters   
scStr.simulation.nElementsRIS = {8,16};
scStr.simulation.reflectCoefficientRIS = 1;                                                   

%% Channel Parameters
scStr.channel.dopplerModel                  = 'Jakes';                  % implementation of a Doppler spectrum:
                                                                        % 'Jakes'
                                                                        % 'Uniform'
                                                                        % 'Discrete-Jakes'
                                                                        % 'Discrete-Uniform'
                                                                        
scStr.channel.timeSubsamplingFactor         = 10;                       % for time-varying channels (10 is a good starting point). This reduces the computational time of the channel realizations 
                                                                        % at the cost of some accuracy loss. Set it to 1 for no time subsampling. Check the manual for more information. 
                                                                        
scStr.channel.correlatedFrames              = false;                    % channel time correlation between frames
                           
scStr.channel.spatialCorrelation            = 'none';                   % spatial correlation according to TS36.101, Annex B
                                                                        % 'none': spatial correlation model is deactivated
                                                                        % 'low': no spatial correlation
                                                                        % 'medium': correlation at UE and BS, but higher at UE
                                                                        % 'high': high correlation at UE and at BS
                                                                
scStr.channel.nPaths                        = 50;                       % number of propagation paths for the Doppler model
                                                                        % for time correlated fading 10 is sufficient, otherwise 50 or higher

scStr.channel.powerDelayProfile             = 'Flat';            % power delay profile model, possible choices are:
                                                                        % 'AWGN'
                                                                        % 'Flat'
                                                                        % 'PedestrianA'
                                                                        % 'PedestrianB'
                                                                        % 'VehicularA'
                                                                        % 'VehicularB'
                                                                        % 'ExtendedPedestrianA'
                                                                        % 'ExtendedVehicularA'
                                                                        % 'HillyTerrain'
                                                                        % 'TDL-A_45ns'
 
                                                                       
% Two-Wave with Diffuse Power (TWDP) small scale fading model: 
% Parameters for the time-invariant case for all users
% These parameters will be carried out only if all users are stationary, i.e the userVelocity parameter is zero for all users
% If there is a mix of moving and stationary users, Rayleigh fading will be  assigned to the stationary ones!
scStr.channel.K                             = 0;                        % TWDP model parameter K,      K > 0
scStr.channel.delta                         = 1;                        % TWDP model parameter delta,  0 >= delta >= 1
                                                                        % TWDP parameters and the represented statistic:
                                                                        % K >>  ; delta = 0       : No fading
                                                                        % K > 0 ; delta = 0       : Rician fading
                                                                        % K = 0 ; delta arbitrary : Rayleigh fading
                                                                        % K >>  ; delta ~ 1       : Hyper-Rayleigh fading 
                                                                        
% Spatial channel model parameters                                                                        
scStr.channel.spatialChannelModel           = false;                    % for a 3D channel, this parameter has to be set to true
scStr.channel.nSpatialPaths                 = 20;                       % Number of paths for the NLOS impulse response
scStr.channel.LOSangleSigmaAOA              = 0;                        % in Degrees; Standard Deviation of the LOS AOA distribution
scStr.channel.LOSangleSigmaZOA              = 0;                        % in Degrees; Standard Deviation of the LOS ZOA distribution
scStr.channel.NLOSangleSigmaAOA             = 50;                       % in Degrees; Standard Deviation of the NLOS AOA distribution
scStr.channel.NLOSangleSigmaZOA             = 50;                       % in Degrees; Standard Deviation of the NLOS ZOA distribution
scStr.channel.angleMeanAOA                  = [60];                     % per Link; in Degrees; Mean Azimuth angle Of Arrival (AOA); Serves as receiver orientation and angular distribution for the LOS part, between [0,360)
scStr.channel.angleMeanZOA                  = [45];                     % per Link; in Degrees; Mean Zenith angle Of Arrival (ZOA); Serves as receiver orientation and angular distribution for the LOS part, between [0,180)
scStr.channel.kFactor                       = [15];                     % per Link; Rician k-Factor in dB
scStr.channel.antennaSpacing                = [1/2];                    % per Node; Spacing between antenna elements; given in multiples of the wavelength   

%% Channel Estimation and Equalization Parameters
scStr.simulation.channelEstimationMethod    = 'Approximate-Perfect';    % channel estimation method: 
                                                                        % 'Approximate-Perfect'
                                                                        % 'PilotAided'
                                                                        
scStr.simulation.noisePowerEstimation       = false;                    % if the noise and interference power are estimated
                                                                        % true: estimate interference and noise power at RX
                                                                        % false: use perfect knowledge of noise power, neglect interference power
                                                                        
scStr.simulation.pilotPatternDownlink       = 'LTE Downlink';            % pilot symbol allocation pattern for Downlink links
scStr.simulation.pilotPatternUplink         = 'LTE Uplink';            % pilot symbol allocation pattern for Uplink links
                                                                        % 'Rectangular'
                                                                        % 'Diamond'
                                                                        % 'LTE Downlink'
                                                                        % 'LTE Uplink'

% pilot spacing settings for the 'Rectangular' and the 'Diamond' pilot pattern
scStr.simulation.pilotSpacingFrequency      = 6;                        % pilot spacing in frequency domain (may be fractions of subcarriers)
scStr.simulation.pilotSpacingTime           = 3.5;                      % pilot spacing in time domain (may be fraction of symbols)
                                                                        
scStr.simulation.pilotSequenceLength        = 12;                       % length of orthogonal pilot symbol sequence
                                                                        % In Multi-user MIMO, this is the maximum number of users supported with channel estimation.

%% MIMO Parameters
% Layer mapping
scStr.layerMapping.mode                     = 'LTE';                    % 'LTE': TS 36.211 V13.2.0 Table 5.3.2A.2-1
                                                                        % '5G':  TS 38.211 V15.2.0 Table 7.3.1.3-1 	
                                                                        % 'custom': based on the layer mapping table                                                                        
% custom layer mapping table
scStr.layerMapping.table.Uplink             = {1;2;[1,2]};
scStr.layerMapping.table.Downlink           = {1;2;[1,2]};              % table{n} represents the codeword to layer mapping for n layers,
                                                                        % table{3} = [1,2] the length of the array equals the number of
                                                                        % codewords and each entery represents the number of layers the codeword is
                                                                        % mapped to.
% MIMO mode
scStr.schedule.multiuserMode.Downlink       = {'none'};                 % per BS; 'MUST', 'ZF-MUMIMO', 'BD-MUMIMO' and 'MRT-MUMIMO' are supported                                                                                                                                            
scStr.schedule.multiuserMode.Uplink         = {'none'};                 % per BS; 'ZF-MUMIMO' and 'MMSE-MUMIMO' are supported
scStr.schedule.multiuserMode.UplinkIC       = [0];                      % Interference cancellation (IC) at the BS; 0 for no IC, 1 for single IC pass, 2 for two, etc.

% MUST power allocation
scStr.modulation.MUSTIdx                    = [2];                      % per BS; the power allocation index of the 3GPP MUST mode = {0, 1, 2, 3}.

% Transmission modes for single user MIMO
scStr.modulation.transmissionMode           = 'custom';                 % 'OLSM' open loop spatial multiplexing
                                                                        % 'CLSM' closed loop spatial multiplexing
                                                                        % 'TxD' transmit diversity
                                                                        % 'custom' for the custom mode the feedback has to be configured manually (see scStr.feedback)
scStr.modulation.delayDiversity             = 1;                        % 0 no delay 1 large delay diversity (only for OLSM) 

scStr.modulation.nStreams                   = [1];                      % per Link; number of active spatial streams
% MIMO Precoding:
% The precoding matrix needs to be of size [nAntennaPorts x nStreams]
scStr.modulation.precodingMatrix{1}         = ones(1,1);                        % per link;  precoding matrix


scStr.simulation.receiverTypeMIMO           = 'ZF';                   % MIMO detector: 'ZF','MMSE','Sphere','ML'
                                                                                                                                        

%% Hybrid Precoding Parameters
scStr.modulation.precodingScheme            = 'digital';                % The two supported schemes are: hybrid and digital.
% The following parameters have to be set only when hybrid precoding to
% chosen
scStr.simulation.nAntennaPortsBaseStation   = [4];                      % per BS
scStr.simulation.nAntennaPortsUser          = [1];                      % per UE

% Per Node, the analog precoder need to be of size [nAntennas x
% nAntennaPorts] (has to be set if precodingScheme is set to hybrid)
scStr.modulation.analogPrecoder{1}        = ones(1,1);        % per node
scStr.modulation.analogPrecoder{2}        = 1;             
scStr.modulation.analogPrecoder{3}        = 1;             
            
scStr.modulation.analogReceiveFilter{1}   = ones(1,1);        % per node
scStr.modulation.analogReceiveFilter{2}   = 1;              
scStr.modulation.analogReceiveFilter{3}   = 1;              
            

%% Feedback Parameters
scStr.feedback.delay                        = 0;                        % Feedback Delay

scStr.feedback.averager.Type            	= 'miesm';                  % Method used to calculate an effective SNR
                                                                        % 'eesm'
                                                                        % 'miesm'
                                                                        
scStr.modulation.cqiTable                   = 1;                        % CQI table selection
                                                                        % TS 36.213 V15.8.0
                                                                        % 0: Table 7.2.3-1 (QPSK to 64 QAM)
                                                                        % 1: Table 7.2.3-2 (QPSK to 256 QAM)
                                                                        % 2: Table 7.2.3-4 (QPSK to 1024-QAM)
                                                                        % CQI selection
scStr.modulation.mcs                        = [4];                     % 1 to 15, per link
                                                                        
% for the custom transmission mode the following parameters are used to configure the feedback
scStr.feedback.enable                       = false;                    % set this to ture to enable the feedback
% when the feedback is enabled the following parameters are used to configure the individual indicators:
scStr.feedback.pmi                          = false;
scStr.feedback.ri                           = false; 
scStr.feedback.cqi                          = false;                                                                  

%% Modulation Parameters
% Waveform
scStr.modulation.waveform                   = {'OFDM'};            % per BS; employed transmission waveform:
                                                                        % 'SC' - single carrier pulse amplitude modulation
                                                                        % 'OFDM' - Orthogonal Frequency Division Multiplexing
                                                                        % 'FBMC' - Filer Bank MultiCarrier
                                                                        % 'UFMC' - Universal Filtered MultiCarrier
                                                                        % 'f-OFDM' - filtered OFDM
                                                                        % 'WOLA' - Weighted OverLap and Add
                                                                        
scStr.modulation.spreadingTransformDownlink = 'none';                   % symbol spreading transformation, to use in combination with
scStr.modulation.spreadingTransformUplink   = 'none';                   % LTE Uplink pilot pattern, either 'none' or 'DFT'

% Parameters for SC
scStr.modulation.pulseShapeFilter           = 'RRC';                    % pulse shape for single carrier modulation: 'rectangular' or 'RRC'
scStr.modulation.rollOffFactor              = 0.22;                     % spectral roll-off factor for SC modulation, may be within 0...1
                                                                        
% Parameters for FBMC
scStr.modulation.prototypeFilter            = 'PHYDYAS-OQAM';           % prototype filter for FBMC:
                                                                        % 'Hermite-OQAM'
                                                                        % 'Hermite-QAM'
                                                                        % 'Rectangle-QAM'
                                                                        % 'RRC-OQAM'
                                                                        % 'RRC-QAM'
                                                                        % 'PHYDYAS-OQAM'
                                                                        % 'PHYDYAS-QAM'
% Parameters for UFMC  
scStr.modulation.nSubcarriersPerSubband     = [12];                     % number of subcarriers per subband
                                                                 
% Numerology setup
scStr.modulation.numberOfSubcarriers        = [72];                  % per BS; number of used subcarriers
scStr.modulation.subcarrierSpacing          = [15e3];        % per BS; per base station in Hz
scStr.modulation.nSymbolsTotal              = [15];             % per BS; total number of time-symbols per frame, the frame duration will be nSymbolsTotal/subcarrierSpacing
scStr.modulation.nGuardSymbols              = [1];                    % per BS; select how many of the total time-symbols will be used as guard symbols (cyclic prefix in OFDM)
scStr.modulation.samplingRate               = 'Automatic';              % there is a single sampling rate for all nodes (all users and all base stations):
                                                                        % either numeric value for manual setting or 'Automatic'

%% Channel Coding Parameters
scStr.coding.code                           = {'Turbo'};                % per Link; channel code:
                                                                        % 'Turbo'
                                                                        % 'LDPC'
                                                                        % 'TB-Convolutional'
                                                                        % 'Polar'
                                                                    
scStr.coding.decoding                       = {'Linear-Log-MAP'};       % per Link; decoding algorithm (* indicates the recommended algorithm for speed and performance):
                                                                        % TB-Convolutional: 'Log-MAP', 'Max-Log-MAP'*
                                                                        % Turbo: 'Log-MAP', 'Max-Log-MAP', 'Linear-Log-MAP'*
                                                                        % LDPC: 'Sum-Product', 'Min-Sum', 'PWL-Min-Sum'*
                                                                        % Polar: 'List-SC', 'CRC-List-SC'*
                                                                            

scStr.coding.decodingIterations             = [8];                      % per Link; number of decoding iterations or list size (typically 8 for turbo, 16 for LDPC, 8 for polar)

scStr.coding.LLRsCalculationMethod          = 'Max-Log';                % The method for the calculation of the log-likelihood ratios:
                                                                        % 'Exact'
                                                                        % 'Max-Log'
                                                                        % For high speed and numerical stability, we highly recommend using 'Max-Log'. Use 'Exact' only if you are testing a very specific scenario with a guaranteed stable input range.
                                                                         
scStr.coding.softBufferRatio                = [1];                      % per link; buffer ratio for limited buffer rate matching (LBRM). Values are in the range 0 to 1. Enter 1 for 100% usage of the soft buffer.
                                                                                 
%% Schedule
% static schedule per base station
scStr.schedule.fixedScheduleDL{1}           = ['UE1:72'];               % schedule for BS1 downlink
scStr.schedule.fixedScheduleDL{2}           = ['UE2:72'];
scStr.schedule.fixedScheduleUL{1}           = ['UE1:72'];               % schedule for BS1 uplink
scStr.schedule.fixedScheduleUL{2}           = ['UE2:72'];   
