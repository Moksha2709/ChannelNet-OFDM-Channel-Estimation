% parameter file for the LTE-A compliant scenario
%
% perform downlink simulation with LTE-A compliant parameter settings

%% Topology
% Specifiy all the nodes in ascending order with starting
% index of 1 (BS0 or UE0 is not allowed).
scStr.topology.nodes                        = ['BS1,UE1'];              % single cell only

% Primary (desired) links
scStr.topology.primaryLinks                 = ['BS1:UE1'];              % only downlink
                                            
% Links for Joint Tranmission and Detection (future work)                         
scStr.topology.jointTxRxLinks               = [''];  

% Interference Links   
scStr.topology.interferenceGeneration       = 'Automatic';              % no interference link in this scenario
scStr.topology.interferer.attenuation       = 30;                       % therefore parameters have no effect
scStr.topology.interferer.kFactor           = 0; 
scStr.topology.interferingLinks             = ['']; 

%% General Simulation Parameters
% set link types to simulate
scStr.simulation.simulateDownlink           = true;                     % downlink
scStr.simulation.simulateUplink             = false;                    % uplink
scStr.simulation.simulateD2D                = false;                    % device to device links

scStr.simulation.frameStructure             = 'FDD';

% Plot options
scStr.simulation.plotResultsFor             = [1];                      % Choose the nodes that will get their results plotted (1 or 0 for each node).
                                                                        % Enter a single 1 if you want the results of all nodes to be plotted, or 0 if you want no plots.

scStr.simulation.plotOverSNR                = true;                     % select to plot resulty over SNR instead of pathloss
scStr.simulation.plotPAPR                   = false;                   
scStr.simulation.saveData                   = false;                    % Set to true to save bits and symbols.

% Define a sweep parameter
scStr.simulation.sweepParam                 = {'simulation.pathloss'};  % Define the parameter to sweep over. This can be almost any simulation parameter.
                                                                        % Most likely it will be the pathloss to obtain results over SNR.
                                                                                                                                        
scStr.simulation.sweepValue                 = linspace(120,80,8);      % Define parameter values to sweep over. A good starting point for the pathloss is 150 to 110.

scStr.simulation.applySweepingTo            = [1];                      % Define the nodes (or links, depending on the sweep parameter) on which the sweep parameter will be applied (1 or 0 for each node/link).
                                                                        % All other nodes (or links) set to 0 here will use the custom values entered below. 
                                                                        % Enter a single 1 if you want all of them to be swept over.
% Number of simulation frames
scStr.simulation.nFrames                    = 100;                      % Number of frames to simulate per sweep value, adjust to obtain sufficiently small confidence intervals.

%% Physical Transmission Parameters
scStr.simulation.centerFrequency            = 2.5e9;                    % center frequency

scStr.simulation.txPowerBaseStation         = 30;                       % base station total transmit power in dBm
scStr.simulation.txPowerUser                = 30;                       % user total transmit power in dBm

scStr.simulation.codebook                   = 'LTE';                    % LTE or 5G
scStr.simulation.nAntennasBaseStation       = {4};                        % 4x4 MIMO

scStr.simulation.nAntennasUser              = 4;                        % 
scStr.simulation.userVelocity               = 0;                        % UE velocity in m/s

scStr.simulation.pathloss                   = [80];                     % per Link, channel pathloss in dB, this is most likely swept over

% Nonlinearity model
scStr.simulation.nonlinearity               = false;                    % Apply Rapp's PA nonlinear model: Rapp, C. "Effects of HPA-nonlinearity on a 4-DPSK/OFDM-signal for a digital sound broadcasting signal."        
scStr.simulation.amplifierOBO               = [1];                      % Amplifier output back-off, per Link, in dB
scStr.simulation.smoothnessFactor           = [3];                      % Smoothness factor for the Rapp model, per Link, >=0


%% Channel Parameters
scStr.channel.spatialChannelModel           = false;                     % for a 3D channel, this parameter has to be set to ture
scStr.channel.dopplerModel                  = 'Discrete-Jakes';
scStr.channel.timeSubsamplingFactor         = 10;
scStr.channel.correlatedFrames               = false;
scStr.channel.spatialCorrelation            = 'none';
scStr.channel.nPaths                        = 50;                   
scStr.channel.powerDelayProfile             = 'Flat';  
scStr.channel.K                             = 0;
scStr.channel.delta                         = 1;

%% Channel Estimation and Equalization Parameters
scStr.simulation.channelEstimationMethod    = 'PilotAided';             % pilot aided LS channel estimation
scStr.simulation.noisePowerEstimation       = false;
scStr.simulation.pilotPatternDownlink       = 'LTE Downlink';
scStr.simulation.pilotPatternUplink         = 'LTE Uplink';
scStr.simulation.pilotSpacingFrequency      = 6;
scStr.simulation.pilotSpacingTime           = 3.5;
scStr.simulation.pilotSequenceLength        = 12;              
scStr.simulation.receiverTypeMIMO           = 'ZF';                     % Zero Forcing equalization

%% MIMO Parameters
% Layer mapping
scStr.layerMapping.mode                     = 'LTE';  
scStr.layerMapping.table.Uplink             = {1;2;[1,2]};
scStr.layerMapping.table.Downlink           = {1;2;[1,2]};
% MIMO mode
scStr.modulation.transmissionMode           = 'CLSM';
scStr.schedule.multiuserMode.Downlink       = {'none'};                 
scStr.schedule.multiuserMode.Uplink         = {'none'};  
scStr.schedule.multiuserMode.UplinkIC       = [0];                
scStr.modulation.delayDiversity             = 1;
%% Hybrid Precoding Parameters
scStr.modulation.precodingScheme            = 'digital';
scStr.simulation.nAntennaPortsBaseStation   = [4];
scStr.simulation.nAntennaPortsUser          = [4];
scStr.modulation.analogPrecoder{1}        = eye(4);           
scStr.modulation.analogReceiveFilter{1}   = eye(4);
 
%% Feedback Parameters
scStr.feedback.delay                        = 0;
scStr.feedback.averager.Type                = 'miesm';
scStr.modulation.cqiTable                   = 0;

scStr.feedback.enable                       = false;                    % this parameter is ignored as the MIMO mode is CLSM, feedback is atomatically used
scStr.feedback.pmi                          = false;
scStr.feedback.ri                           = false; 
scStr.feedback.cqi                          = true;
scStr.modulation.nStreams                   = 2;                        % 2 active spatial stream
scStr.modulation.precodingMatrix{1}         = 1/sqrt(2) * eye(2);       % employed precoding matrix
scStr.modulation.mcs                        = 8;
scStr.modulation.MUSTIdx                    = [2];                     

%% Modulation Parameters
% waveform
scStr.modulation.waveform                   = {'OFDM'}; 
scStr.modulation.spreadingTransformDownlink = 'none';
scStr.modulation.spreadingTransformUplink   = 'DFT';
% Parameters for SC
scStr.modulation.pulseShapeFilter           = 'RRC';
scStr.modulation.rollOffFactor              = 0.22;
% numerology setup
scStr.modulation.numberOfSubcarriers        = 72;                       % this corresponds to a 1.4MHz transmission
scStr.modulation.subcarrierSpacing          = 15e3;                     
scStr.modulation.nSymbolsTotal              = 15;                       % 15 symbols out of which one is used for all CPs
scStr.modulation.nGuardSymbols              = 1;                        % use one out of 15 symbol durations as CP for remaining 14 symbols
scStr.modulation.samplingRate               = 'Automatic';              % sampling rate

%% Channel Coding Parameters
scStr.coding.code                           = {'Turbo'};
scStr.coding.decoding                       = {'Max-Log-MAP'};                                 
scStr.coding.decodingIterations             = 8; 
scStr.coding.LLRsCalculationMethod          = 'Max-Log';        
scStr.coding.softBufferRatio                = [1]; 

%% Schedule
% static schedule per base station
scStr.schedule.fixedScheduleDL{1}           = ['UE1:72'];             % downlink only
scStr.schedule.fixedScheduleUL{1}           = [];


