% comparison to the LTE-A simulator

close all;
clear;
clc;

cd('..');


% define number of MCS values
nCQI            = 15;
nSNRValues      = 12;
SNRRegionsStart = -10:1.9:18;
SNRRegionDelta  = 4;

%% Setup
% select scenario
simulationScenario = 'LTE_comp_scenario'; 
                                                
% load parameters according to scenario                                               
simParams = Parameters.SimulationParameters( simulationScenario );

% init results
throughputOverall   = zeros(nCQI, 2, nSNRValues);
FEROverall          = zeros(nCQI, 2, nSNRValues);

% create independent random streams for each sweep in case parallel computation is switched on
S = RandStream.create('threefry4x64_20','Seed','shuffle','NumStreams',length(simParams.simulation.sweepValue),'CellOutput',true);
if  ~isempty(ver('distcomp'))
    sc = parallel.pool.Constant(@() S);
end

for cqi = 1:nCQI
   
    fprintf('------- CQI %d -------\n',cqi);
    
    % set MCS value
    simParams.modulation.mcs = cqi;
    simParams.simulation.sweepValue = 143 - linspace(SNRRegionsStart(cqi), SNRRegionsStart(cqi)+SNRRegionDelta, nSNRValues);

    % generate network topology and links between nodes
    [Links, BS, UE] = Topology.getTopology(simParams);

    nBS         = length(BS);
    nUE         = length(UE);
    dimLinks    = length(Links);
    nFrames     = simParams.simulation.nFrames;

    % initialize result variables
    perSweepResults         = cell(length(simParams.simulation.sweepValue), nFrames);
    simResults              = cell(1, length(simParams.simulation.sweepValue));
    averageFrameDuration    = 0;

    %% Simulation loop
    startTime   = tic;
    myCluster   = parcluster('local');
    NumWorkers  = myCluster.NumWorkers;
    fprintf(['------- Started -------', '\n']);

    % loop over sweep parameter
    for iSweep = 1:length(simParams.simulation.sweepValue) % this may be 'for' or 'parfor'
        if ~isempty(getCurrentTask())
            stream = sc.Value{iSweep};
        elseif iSweep == 1
            stream = RandStream.create('mt19937ar','Seed','shuffle');
        end
    RandStream.setGlobalStream(stream);
        % update sweep value
        simParams.UpdateSweepValue(iSweep); %#ok

        % based on the updated sweep parameter, regenerate the network
        [Links, BS, UE, IN] = Topology.getTopology(simParams);

        % Objects initialization should be peformed here
        Links = simParams.initializeLinks(Links, BS, UE, IN); %#ok

        % save average frame duration
        if iSweep == 1
            averageFrameDuration(iSweep) = simParams.simulation.averageFrameDuration;
        end

        % Prepare per sweep value results
        perSweepResults = cell(dimLinks, dimLinks, nFrames);

        for iFrame = 1:nFrames
            % link adaptation
            % update all links
            nBS = length( BS );
            nLinks   = length(Links);
            % update the channel of all links
            for iLink = 1:nLinks
                for jLink = 1:nLinks
                    if ~isempty(Links{iLink, jLink})                        
                         Links{iLink,jLink}.Channel.NewRealization(iFrame, simParams.simulation.frameStructure, Links{iLink,jLink}.Direction);
                    end
                end
            end
            for iBS = 1:nBS
                BS{iBS}.updateSpatialProcessing(Links, simParams, IN);
                for iLink = 1:nLinks
                    % Downlink
                    if simParams.simulation.simulateDownlink && ~isempty(Links{BS{iBS}.ID, iLink}) && strcmp(Links{BS{iBS}.ID, iLink}.Type, 'Primary')
                        Links{BS{iBS}.ID, iLink}.updateLink( simParams, Links, IN);
                    end
                    % Uplink
                    if simParams.simulation.simulateUplink && ~isempty(Links{iLink, BS{iBS}.ID}) && strcmp(Links{iLink, BS{iBS}.ID}.Type, 'Primary')
                        Links{iLink, BS{iBS}.ID}.updateLink( simParams, Links, IN);
                    end
                end
            end

            %% Downlink
            if simParams.simulation.simulateDownlink
            % All BSs generate their transmit signal for this frame
                for iBS = 1:nBS
                    BS{iBS}.generateTransmitSignal(Links);
                end

                for iUE = 1:nUE
                    UEID = UE{iUE}.ID;
                    primaryLink = Links{UE{iUE}.TransmitterDL(1), UEID};             
                    if primaryLink.isScheduled
                        primaryLink.generateReceiveSignal();
                        UETotalSignal = primaryLink.ReceiveSignal;

                        % Collect signals from all other BSs
                        for iBS = 2:length(UE{iUE}.TransmitterDL)
                            currentLink = Links{UE{iUE}.TransmitterDL(iBS), UEID};
                            currentLink.generateReceiveSignal();
                            UETotalSignal = Channel.addSignals(UETotalSignal, currentLink.ReceiveSignal);
                        end
                        % correct signal length
                        UETotalSignal = Channel.correctSignalLength(UETotalSignal, primaryLink.Modulator.WaveformObject.Nr.SamplesTotal);

                        % add noise
                        UETotalSignal = UETotalSignal + Channel.AWGN( simParams.phy.noisePower, length(UETotalSignal), UE{iUE}.nAntennas );

                        % process received signal
                        UE{iUE}.processReceiveSignal(UETotalSignal, Links, simParams, IN);

                        % Collect the results which is now stored in the primary link
                        primaryLink.calculateSNR(simParams.constants.BOLTZMANN, simParams.phy.temperature);
                        perSweepResults{UE{iUE}.TransmitterDL(1), UEID, iFrame} = primaryLink.getResults(simParams.simulation.saveData);
                    end
                end

            end 

            %% Time calculation
            % Some basic time calculation.
            intermediateTime = tic;
            if mod(iFrame, 20) == 0
                fprintf('Sweep: %i/%i, Frame: %i/%i, approx. %.0fs left\n', iSweep,length(simParams.simulation.sweepValue),iFrame,nFrames, double(intermediateTime-startTime)*1e-6*(nFrames*length(simParams.simulation.sweepValue)-(iFrame+(iSweep-1)*nFrames))/(iFrame+(iSweep-1)*nFrames));
            end
        end % for iFrame
        simResults{iSweep} = perSweepResults;
    end % parfor iSweep

    %% post process simulation results
    if simParams.simulation.simulateDownlink
        downlinkResults = Results.SimulationResults(nFrames, length(simParams.simulation.sweepValue), nBS, nUE, averageFrameDuration, 'Downlink');
        downlinkResults.collectResults(simResults, UE);
        downlinkResults.postProcessResults(BS);
        % plot results
        if sum(simParams.simulation.plotResultsFor) ~= 0
            Results.plotResults(downlinkResults, 'Downlink', simParams, UE, BS);
        end
    end

    fprintf(['------- Done -------', '\n']);
    toc(startTime);
    
    % save results for this CQI value
    throughputOverall(cqi,1,:)  = mean(downlinkResults.userResults{1}.SNR);
    throughputOverall(cqi,2,:)  = downlinkResults.userResults{1}.throughput.mean;
    
    FEROverall(cqi,1,:)         = mean(downlinkResults.userResults{1}.SNR);
    FEROverall(cqi,2,:)         = downlinkResults.userResults{1}.FER.mean;
    
end

save('results/5GSimReferenceCurves','throughputOverall','FEROverall');
