% parameter file to generate comparison for all CQI values
%
% this parameter file should no be used via the main script directly but via the LTE_comparison.m script in 

%% Topology
% single user downlink
scStr.topology.nodes                        = ['BS1,UE1'];
scStr.topology.primaryLinks                 = ['BS1:UE1'];
                                                
                                            
% Links for Joint Tranmission and Detection (future work)                         
scStr.topology.jointTxRxLinks               = [''];  

% Interference Links   
scStr.topology.interferenceGeneration       = 'Automatic';
scStr.topology.interferer.attenuation       = 100;
scStr.topology.interferer.kFactor           = 0; 
scStr.topology.interferingLinks             = [ ];
                                                                        
%% General Simulation Parameters
% Set link types to simulate
scStr.simulation.simulateDownlink           = true;                     % Downlink only
scStr.simulation.simulateUplink             = false; 
scStr.simulation.simulateD2D                = false;

scStr.simulation.frameStructure             = 'FDD';

% Plot options
scStr.simulation.plotResultsFor             = [1];
                                                                         
scStr.simulation.plotOverSNR                = true;  
scStr.simulation.plotPAPR                   = false;                   
scStr.simulation.saveData                   = false; 

% Define a sweep parameter
scStr.simulation.sweepParam                 = {'simulation.pathloss'};                                                                                                                                          
scStr.simulation.sweepValue                 = linspace(150,90,6);       % Define parameter values to sweep over. A good starting point for the pathloss is 150 to 110.

scStr.simulation.applySweepingTo            = [1];

% Number of simulation frames
scStr.simulation.nFrames                    = 100;

%% Physical Transmission Parameters
scStr.simulation.centerFrequency            = 2.5e9; 
scStr.simulation.txPowerBaseStation         = [30];
scStr.simulation.txPowerUser                = [30];
scStr.simulation.codebook                   = 'LTE';                    % LTE or 5G
scStr.simulation.nAntennasBaseStation       = {1};

scStr.simulation.nAntennasUser              = [1];
scStr.simulation.userVelocity               = [0];
scStr.simulation.pathloss                   = [80]; 

% Nonlinearity model
scStr.simulation.nonlinearity               = false;                                                     
scStr.simulation.amplifierOBO               = [1];
scStr.simulation.smoothnessFactor           = [3];

%% Channel Parameters
scStr.channel.spatialChannelModel           = false;                     % for a 3D channel, this parameter has to be set to ture
scStr.channel.dopplerModel                  = 'Jakes'; 
scStr.channel.timeSubsamplingFactor         = 10;
scStr.channel.correlatedFrames               = false; 
scStr.channel.spatialCorrelation            = 'none';       
scStr.channel.nPaths                        = 50;
scStr.channel.powerDelayProfile             = 'AWGN';                                                                        
scStr.channel.K                             = 0;
scStr.channel.delta                         = 1;

%% Channel Estimation and Equalization Parameters
scStr.simulation.channelEstimationMethod    = 'Approximate-Perfect';
scStr.simulation.noisePowerEstimation       = false;
scStr.simulation.pilotPatternDownlink       = 'LTE Downlink';           % pilot symbol allocation pattern for Downlink links
scStr.simulation.pilotPatternUplink         = 'LTE Uplink';             % pilot symbol allocation pattern for Uplink links
scStr.simulation.pilotSpacingFrequency      = 6;                        % pilot spacing in frequency domain (may be fractions of subcarriers)
scStr.simulation.pilotSpacingTime           = 3.5;                      % pilot spacing in time domain (may be fraction of symbols)
scStr.simulation.pilotSequenceLength        = 12;
scStr.simulation.receiverTypeMIMO           = 'ZF';

%% MIMO Parameters
% Layer mapping
scStr.layerMapping.mode                     = 'LTE';
scStr.layerMapping.table.Uplink             = {1;2;[1,2]};
scStr.layerMapping.table.Downlink           = {1;2;[1,2]};
% MIMO mode
scStr.modulation.transmissionMode           = 'custom';
scStr.schedule.multiuserMode.Downlink       = {'none'};                 
scStr.schedule.multiuserMode.Uplink         = {'none'}; 
scStr.schedule.multiuserMode.UplinkIC       = [0];
scStr.modulation.delayDiversity             = 1; 

%% Hybrid Precoding Parameters
scStr.modulation.precodingScheme            = 'digital';
scStr.simulation.nAntennaPortsBaseStation   = [1];
scStr.simulation.nAntennaPortsUser          = [1];
scStr.modulation.analogPrecoder{1}          = 1;             
scStr.modulation.analogReceiveFilter{1}     = 1;
%% Feedback Parameters
scStr.feedback.delay                        = 0; 

scStr.feedback.averager.Type            	= 'miesm';                       
scStr.modulation.cqiTable                   = 0;

% for the custom transmission mode the following parameters are used to configure the feedback
scStr.feedback.enable                       = false;                    % set this to ture to enable the feedback
% when the feedback is enabled the following parameters are used to configure the individual indicators:
scStr.feedback.pmi                          = false;
scStr.feedback.ri                           = false; 
scStr.feedback.cqi                          = true;
 
scStr.modulation.precodingCodebook          = 'custom';  
% when feedback is disabled, the following parameters are used:                                                                         
scStr.modulation.nStreams                   = [1];                      % per Link; number of active spatial streams

scStr.modulation.precodingMatrix{1}         = 1;

scStr.modulation.mcs                        = [12];    

% MUST power allocation
scStr.modulation.MUSTIdx                    = [2];                      

%% Modulation Parameters
% Waveform
scStr.modulation.waveform                   = {'OFDM'};
scStr.modulation.spreadingTransformDownlink = 'none';
scStr.modulation.spreadingTransformUplink   = 'none';
scStr.modulation.prototypeFilter            = 'PHYDYAS-OQAM';
% Parameters for UFMC  
scStr.modulation.nSubcarriersPerSubband     = [12];
                                                             
% Numerology setup
scStr.modulation.numberOfSubcarriers        = [72];
scStr.modulation.subcarrierSpacing          = [15e3];
scStr.modulation.nSymbolsTotal              = [15];
scStr.modulation.nGuardSymbols              = [1];
scStr.modulation.samplingRate               = 15e3*72*2;

%% Channel Coding Parameters
scStr.coding.code                           = {'Turbo'};
scStr.coding.decoding                       = {'Linear-Log-MAP'};
scStr.coding.decodingIterations             = [8];
scStr.coding.LLRsCalculationMethod          = 'Max-Log';             
scStr.coding.softBufferRatio                = [1]; 

%% Schedule
% static schedule per base station
scStr.schedule.fixedScheduleDL{1}           = ['UE1:72'];

                                                                        



