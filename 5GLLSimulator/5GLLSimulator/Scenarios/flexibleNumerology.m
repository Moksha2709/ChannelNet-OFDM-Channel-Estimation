% parameter file for the flexible numerology scenario from "Versatile Mobile Communications Simulation: The Vienna 5G Link Level Simulator"
%
% you may consider changes to the powerDelayProfile parameter as well as to the numerology setup (and the schedule) in order to
% simulate the six different result curves for this scenario

%% Topology
scStr.topology.nodes                        = ['BS1,UE1'];                  % single user and base station

% Primary (desired) links
scStr.topology.primaryLinks                 = ['BS1:UE1']; 
                                                
% Links for Joint Tranmission and Detection (future work)                         
scStr.topology.jointTxRxLinks               = [''];  
% Interference Links   
scStr.topology.interferenceGeneration       = 'Automatic';                  % no interfering links present in this scenario
scStr.topology.interferer.attenuation       = 30;
scStr.topology.interferer.kFactor           = 0; 
scStr.topology.interferingLinks             = [];

%% General Simulation Parameters
% Set link types to simulate
scStr.simulation.simulateDownlink           = true;                         % Downlink only
scStr.simulation.simulateUplink             = false;
scStr.simulation.simulateD2D                = false;

scStr.simulation.frameStructure             = 'FDD';

% Plot options
scStr.simulation.plotResultsFor             = [1];                                  
scStr.simulation.plotOverSNR                = false;
scStr.simulation.plotPAPR                   = false;                    
scStr.simulation.saveData                   = false;

% Define a sweep parameter
scStr.simulation.sweepParam                 = {'simulation.userVelocity'};  % sweep over user velocity                                                                       
                                                                                                                                        
scStr.simulation.sweepValue                 = [5, linspace(50,300,6)./3.6]; % user velocity values in m/s
scStr.simulation.applySweepingTo            = [1];

% Number of simulation frames
scStr.simulation.nFrames                    = 200;                          % Number of frames to simulate per sweep value

%% Physical Transmission Parameters
scStr.simulation.centerFrequency            = 5.9e9;                        % center frequency for V2x scenarios

scStr.simulation.txPowerBaseStation         = [30];
scStr.simulation.txPowerUser                = [30];
scStr.simulation.codebook                   = 'LTE';                    % LTE or 5G

scStr.simulation.nAntennasBaseStation       = {1};
                                                                        % per BS: if the 5G codebook is selected, each vector represents the number of horizontal and vertical antennas[N1,N2]
                                                                        % Supported configurations (N1,N2):
                                                                        %  4 Ports: (2,1)
                                                                        %  8 Ports: (2,2), (4,1)
                                                                        % 12 Ports: (3,2),(6,1)
                                                                        % 16 Ports: (4,2), (8,1)
                                                                        % 24 Ports: (4,3), (6,2),(12,1)
                                                                        % 32 Ports: (4,4), (8,2), (16,1)
scStr.simulation.nAntennasUser              = [1];
scStr.simulation.userVelocity               = [0]; 
scStr.simulation.pathloss                   = [60];  

% Nonlinearity model
scStr.simulation.nonlinearity               = false;                    % Apply Rapp's PA nonlinear model: Rapp, C. "Effects of HPA-nonlinearity on a 4-DPSK/OFDM-signal for a digital sound broadcasting signal."        
scStr.simulation.amplifierOBO               = [1];                      % Amplifier output back-off, per Link, in dB
scStr.simulation.smoothnessFactor           = [3];                      % Smoothness factor for the Rapp model, per Link, >=0

%% Channel Parameters
scStr.channel.spatialChannelModel           = false;                     % for a 3D channel, this parameter has to be set to ture
scStr.channel.dopplerModel                  = 'Jakes';
scStr.channel.timeSubsamplingFactor         = 10;
scStr.channel.correlatedFrames               = false; 
scStr.channel.spatialCorrelation            = 'none';                                                                 
scStr.channel.nPaths                        = 50;

scStr.channel.powerDelayProfile             = 'TDL-A_45ns';                 % 'TDL-A_45ns' or 'TDL-A_250ns' according to the scenario

scStr.channel.K                             = 0; 
scStr.channel.delta                         = 1;

%% Channel Estimation and Equalization Parameters
scStr.simulation.channelEstimationMethod    = 'Approximate-Perfect';        % perfect channel knowledge is assumed
scStr.simulation.noisePowerEstimation       = false;
scStr.simulation.pilotPatternDownlink       = 'LTE Downlink';
scStr.simulation.pilotPatternUplink         = 'LTE Uplink';
scStr.simulation.pilotSpacingFrequency      = 6;
scStr.simulation.pilotSpacingTime           = 3.5;
scStr.simulation.pilotSequenceLength        = 12;             
scStr.simulation.receiverTypeMIMO           = 'ZF';

%% MIMO Parameters
% Layer mapping
scStr.layerMapping.mode                     = '5G';
scStr.layerMapping.table.Uplink             = 1;
scStr.layerMapping.table.Downlink           = 1;

% MIMO mode
scStr.modulation.transmissionMode           = 'custom';
scStr.schedule.multiuserMode.Downlink       = {'none'};                 
scStr.schedule.multiuserMode.Uplink         = {'none'};  
scStr.schedule.multiuserMode.UplinkIC       = [0];
scStr.modulation.delayDiversity             = 0;

%% Hybrid Precoding Parameters
scStr.modulation.precodingScheme            = 'digital';
scStr.simulation.nAntennaPortsBaseStation   = [1];                    
scStr.simulation.nAntennaPortsUser          = [1];                    
scStr.modulation.analogPrecoder{1}        = 1;        
scStr.modulation.analogReceiveFilter{1}   = 1;       

%% Feedback Parameters
scStr.feedback.delay                     	= 0;
scStr.feedback.averager.Type             	= 'miesm';   
scStr.modulation.cqiTable                   = 0;
scStr.feedback.enable                    	= false;                        % no feedback is used, CQI is fixed          
scStr.feedback.pmi                       	= false; 
scStr.feedback.ri                        	= false; 
scStr.feedback.cqi                       	= false; 

% when feedback is disabled, the following parameters are used:
scStr.modulation.nStreams                   = [1];                          % single stream transmission
% Per link, precoder selection (used when feedback is disabled)
scStr.modulation.precodingMatrix{1}         = 1;                            % employed precoding matrix

% CQI selection (used when feedback is disabled)
scStr.modulation.mcs                        = [15];                         % employed CQI value

% MUST power allocation
scStr.modulation.MUSTIdx                    = [2];                         

%% Modulation Parameters
% Waveform
scStr.modulation.waveform                   = {'OFDM'};
scStr.modulation.spreadingTransformDownlink = 'none';
scStr.modulation.spreadingTransformUplink   = 'none';
% Parameters for SC
scStr.modulation.pulseShapeFilter           = 'RRC';
scStr.modulation.rollOffFactor              = 0.22;
% Parameters for FBMC
scStr.modulation.prototypeFilter            = 'PHYDYAS-OQAM';               % unused for OFDM
% Parameters for UFMC  
scStr.modulation.nSubcarriersPerSubband     = [12]; 
    	
% numerology setup: to obtain the three different numerologies, change the following parameters as shown in the inline comments
scStr.modulation.numberOfSubcarriers        = [48];                         % 384,	96,		48
scStr.modulation.subcarrierSpacing          = [120e3];                      % 15e3, 60e3, 	120e3
scStr.modulation.nSymbolsTotal              = [120];                        % 14, 	56, 	112
scStr.modulation.nGuardSymbols              = [8];                          % 1, 	4, 		8

scStr.modulation.samplingRate               = 'Automatic';                  % sampling rate																		
 
%% Channel Coding Parameters
scStr.coding.code                           = {'Turbo'};
scStr.coding.decoding                       = {'Linear-Log-MAP'};
scStr.coding.decodingIterations             = [8];
scStr.coding.LLRsCalculationMethod          = 'Max-Log';       
scStr.coding.softBufferRatio                = [1]; 

%% Schedule
% static schedule per base station: the numer of scheduled subcarriers needs to be adapted
scStr.schedule.fixedScheduleDL{1}           = ['UE1:48'];                   % ['UE1:384'], ['UE1:96'] or ['UE1:48']