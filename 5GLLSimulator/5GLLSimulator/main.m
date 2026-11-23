%% The Vienna 5G Link Level Simulator v1.3
% https://www.tuwien.at/etit/tc/en/vienna-simulators/
% Please refer to the user manual to get familiar with the simulator structure and mechanics. 
% For any questions, consider our forum https://vccsforum.nt.tuwien.ac.at

% Main simulator script

close all;
clear;
clc;

%% Setup
% select scenario 
simulationScenario = 'genericScenario';     % select a simulation scenario:
                                            % 'genericScenario'                                           
                                            % 'flexibleNumerology'     
                                            % 'LTEAcompliant'
                                            % 'massiveMIMO'
                                            % 'multiLink'
                                            % 'NOMA'
                                            % 'RIS'

                                                                             
% load parameters according to scenario                                               
simParams = Parameters.SimulationParameters(simulationScenario);
simParams.UpdateSweepValue(1);
% generate network topology and links between nodes
[Links, BS, UE, IN] = Topology.getTopology(simParams);

nBS         = length(BS);
nUE         = length(UE);
nIN          =  length(IN);
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

% create random stream objects
S = RandStream.create('threefry4x64_20','Seed','shuffle','NumStreams',length(simParams.simulation.sweepValue),'CellOutput',true);

% loop over sweep parameter
parfor iSweep = 1:length(simParams.simulation.sweepValue) % this may be 'for' or 'parfor'
 
    % Set up independent random number substreams for each sweep
    RandStream.setGlobalStream(S{iSweep});
    
    % update sweep value
    simParams.UpdateSweepValue(iSweep); %#ok
    
    % based on the updated sweep parameter, regenerate the network
    [Links, BS, UE, IN] = Topology.getTopology(simParams);

    % Objects initialization should be peformed here
    Links = simParams.initializeLinks(Links, BS, UE, IN);
    
    nBS = length( BS );
    nLinks   = length(Links);
    nIN          =  length(IN);
    
    % save average frame duration
    if iSweep == 1
        averageFrameDuration(iSweep) = simParams.simulation.averageFrameDuration;
    end
    
    % Prepare per sweep value results
    perSweepResults = cell(dimLinks, dimLinks, nFrames);
    
    for iFrame = 1:nFrames
        
        % link adaptation
        % update the channel of all links
        for iLink = 1:nLinks
            for jLink = 1:nLinks
                if ~isempty(Links{iLink, jLink})
                     Links{iLink,jLink}.Channel.NewRealization(iFrame, simParams.simulation.frameStructure, Links{iLink,jLink}.Direction);
                end
            end
        end

        % update all primary uplinks
        for iBS = 1:nBS
            BS{iBS}.updateSpatialProcessing(Links, simParams, IN);
            for iLink = 1:nLinks
                % Uplink
                if simParams.simulation.simulateUplink && ~isempty(Links{iLink, BS{iBS}.ID}) && strcmp(Links{iLink, BS{iBS}.ID}.Type, 'Primary')
                    Links{iLink, BS{iBS}.ID}.updateLink(simParams, Links, IN);
                end
            end
        end
        
         %% Uplink
         if simParams.simulation.simulateUplink
            % All UEs generate their transmit signal for this frame
            for iUE = 1:nUE
                if ~isempty(UE{iUE}.ReceiverUL)
                    UE{iUE}.generateTransmitSignal(Links);
                end
            end
            
            if nIN > 0
                for iIN = 1:nIN
                    if ~isempty(IN{iIN}.TransmitterUL)
                        INID = IN{iIN}.ID;
                        INTotalSignal = [];
                        for iUE = 1:length(IN{iIN}.TransmitterUL)
                            currentLink = Links{IN{iIN}.TransmitterUL(iUE), INID};
                            if ~isempty(currentLink.TransmitSignal)
                                currentLink.generateReceiveSignal();
                                INTotalSignal = Channel.addSignals(INTotalSignal, currentLink.ReceiveSignal);
                            end
                                    
                        end
                        % process INTotalSignal, obtain the TransmitSignal from IN
                        IN{iIN}.generateTransmitSignal(INTotalSignal,Links);  
                    end
                end
            end
            
            for iBS = 1:nBS
                BSID = BS{iBS}.ID;
                BSTotalSignal = [];
                % Collect signals from all users transmitting to this BS
                for iNODE = 1:length(BS{iBS}.TransmitterUL)
                    currentLink = Links{BS{iBS}.TransmitterUL(iNODE), BSID};
                    if strcmp(currentLink.Type, 'Primary')
                        signalLength = currentLink.Modulator.WaveformObject.Nr.SamplesTotal;
                    end
                    if ~isempty(currentLink.TransmitSignal)
                        currentLink.generateReceiveSignal();
                        BSTotalSignal = Channel.addSignals(BSTotalSignal, currentLink.ReceiveSignal);
                    end
                end
                % correct signal length
                BSTotalSignal = Channel.correctSignalLength(BSTotalSignal, signalLength);

                % add noise
                BSTotalSignal = BSTotalSignal + Channel.AWGN( simParams.phy.noisePower, length(BSTotalSignal), BS{iBS}.nAntennas );

                % process received signal
                BS{iBS}.processReceiveSignal(BSTotalSignal, Links, simParams,IN);

                % Collect the results
                for iNODE = 1:length(BS{iBS}.TransmitterUL)
                    currentLink = Links{BS{iBS}.TransmitterUL(iNODE), BSID};
                    if currentLink.isScheduled && strcmp(currentLink.Type, 'Primary')
                        currentLink.calculateSNR(simParams.constants.BOLTZMANN, simParams.phy.temperature);
                        perSweepResults{BS{iBS}.TransmitterUL(iNODE), BSID, iFrame} = currentLink.getResults(simParams.simulation.saveData);
                    end
                end  
            end
         end
         %%
        
        % link adaptation
        % update all primary downlinks
        for iBS = 1:nBS
            for iLink = 1:nLinks
                % Downlink
                if simParams.simulation.simulateDownlink && ~isempty(Links{BS{iBS}.ID, iLink}) && strcmp(Links{BS{iBS}.ID, iLink}.Type, 'Primary')
                    Links{BS{iBS}.ID, iLink}.updateLink( simParams, Links, IN);
                end
            end
        end

        %% Downlink
        if simParams.simulation.simulateDownlink
        % All BSs generate their transmit signal for this frame
            
            for iBS = 1:nBS
                if ~isempty(BS{iBS}.ReceiverDL)
                    BS{iBS}.generateTransmitSignal(Links, simParams, IN);
                end
            end      
            
            if nIN >0
                for iIN = 1:nIN
                    if ~isempty(IN{iIN}.TransmitterDL)
                        INID = IN{iIN}.ID;
                        INTotalSignal = [];
                        for iBS = 1:length(IN{iIN}.TransmitterDL)
                            currentLink = Links{IN{iIN}.TransmitterDL(iBS), INID};
                            if ~isempty(currentLink.TransmitSignal)
                                currentLink.generateReceiveSignal();
                                INTotalSignal = Channel.addSignals(INTotalSignal, currentLink.ReceiveSignal);
                            end
        
                        end
                        % process INTotalSignal, obtain the TransmitSignal from IN
                        IN{iIN}.generateTransmitSignal(INTotalSignal, Links);  % need to be added.
                    end
                end
            end
            
            for iUE = 1:nUE
                UEID = UE{iUE}.ID;
                for iNODE = 1:length(UE{iUE}.TransmitterDL)
                    currentLink = Links{UE{iUE}.TransmitterDL(iNODE), UEID};
                    if strcmp(currentLink.Type, 'Primary')
                        primaryLink = currentLink;                       
                    end
                end
                                       
                if primaryLink.isScheduled
                    % Collect signals from all other BSs and intermediate
                    % nodes
                    UETotalSignal = [];
                    for iNODE = 1:length(UE{iUE}.TransmitterDL)
                        currentLink = Links{UE{iUE}.TransmitterDL(iNODE), UEID};
                         if ~isempty(currentLink.TransmitSignal)
                            currentLink.generateReceiveSignal();
                            UETotalSignal = Channel.addSignals(UETotalSignal, currentLink.ReceiveSignal);
                         end
                    end
                    % correct signal length
                    UETotalSignal = Channel.correctSignalLength(UETotalSignal, primaryLink.Modulator.WaveformObject.Nr.SamplesTotal);
                    
                    % add noise
                    UETotalSignal = UETotalSignal + Channel.AWGN(simParams.phy.noisePower, length(UETotalSignal), UE{iUE}.nAntennas);
                    
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
if simParams.simulation.simulateUplink
    uplinkResults = Results.SimulationResults(nFrames, length(simParams.simulation.sweepValue), nBS, nUE, averageFrameDuration, 'Uplink');
    uplinkResults.collectResults(simResults, UE);
    uplinkResults.postProcessResults(BS);
    % plot results
    if sum(simParams.simulation.plotResultsFor) ~= 0
        Results.plotResults(uplinkResults, 'Uplink', simParams, UE, BS);
    end
end

%% save results
% generate timestamp
tmpStr = datestr(now);
tmpStr = strrep(tmpStr, ':', '_');
timeStamp = strrep(tmpStr, ' ', '_');
% save results (complete workspace)
save(['./results/results_', timeStamp]);

fprintf(['------- Done -------', '\n']);
toc(startTime);
