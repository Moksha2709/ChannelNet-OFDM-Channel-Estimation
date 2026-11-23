%% The Vienna 5G Link Level Simulator v1.2
% www.tc.tuwien.ac.at/vccs
% Please refer to the user manual to get familiar with the simulator structure and mechanics. 
% For any questions, consider our forum https://vccsforum.nt.tuwien.ac.at

% Author: Mislav Zane


close all;
clear;
clc;

cd('..');
addpath('./Examples'); 
%% Setup
% select scenario
simulationScenario = 'AoAlocalizationScenario';

% load parameters according to scenario
simParams = Parameters.SimulationParameters(simulationScenario);


% generate network topology and links between nodes
[Links, BS, UE, IN] = Topology.getTopology(simParams);

nBS         = length(BS);
nUE         = length(UE);
nLinks      = length(Links);
nFrames     = simParams.simulation.nFrames;
nSweeps     = length(simParams.simulation.sweepValue);

% define UE positions on straight line
nUEpositions = 2;
UEpositions = [-400,347,10] + (0:1:nUEpositions-1)'*[600,0,0];
nUEpositions = size(UEpositions,1);


% specify localization techniques
localizationAlgorithms = struct('plotName',{'MUSIC & LS', 'conventional BF & LS','ESPRIT & LS', 'unitary ESPRIT & LS'}, ...
                                'function',{@Localization.LA_MUSIC_LS, @Localization.LA_convBF_LS,         @Localization.LA_ESPRIT_LS, @Localization.LA_unitESPRIT_LS});
nLocAlg = size(localizationAlgorithms,2);

%% Simulation Loop
startTime   = tic;
prevTime    = 0;
myCluster   = parcluster('local');
NumWorkers  = myCluster.NumWorkers;
fprintf(['------- Started -------', '\n']);


% create random stream objects
S = RandStream.create('threefry4x64_20','Seed','shuffle','NumStreams',nSweeps,'CellOutput',true);


% allocate memory for results
estimatedAngles    = zeros(nFrames,nUEpositions,nSweeps,nLocAlg,nBS);
estimatedPosition  = zeros(nFrames,nUEpositions,nSweeps,nLocAlg,3);

% loop over sweep parameter
for iSweep = 1:nSweeps 
    
    RandStream.setGlobalStream(S{iSweep});
    
    % update sweep value
    simParams.UpdateSweepValue(iSweep);
    
    
    for iUEposition = 1:size(UEpositions,1)

        % update user position and orientation
        simParams.topology.nodesPosition{nBS + 1} = UEpositions(iUEposition,:);

        % based on the updated sweep parameter, regenerate the network
        [Links, BS, UE, IN] = Topology.getTopology(simParams);

        % Objects initialization should be peformed here
        Links = simParams.initializeLinks(Links, BS, UE, IN);
        
        % save average frame duration
        if iUEposition == 1
            averageFrameDuration(iUEposition) = simParams.simulation.averageFrameDuration;
        end

        for iFrame = 1:nFrames
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
                for iLink = 1:nLinks
                    % Uplink
                    if simParams.simulation.simulateUplink && ~isempty(Links{iLink, BS{iBS}.ID}) && strcmp(Links{iLink, BS{iBS}.ID}.Type, 'Primary')
                        Links{iLink, BS{iBS}.ID}.updateLink(simParams, Links);
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
                for iBS = 1:nBS
                    BSID = BS{iBS}.ID;
                    BSTotalSignal = [];
                    for iUE = 1:length(BS{iBS}.TransmitterUL)
                        currentLink = Links{BS{iBS}.TransmitterUL(iUE), BSID};
                        if strcmp(currentLink.Type, 'Primary')
                            signalLength = currentLink.Modulator.WaveformObject.Nr.SamplesTotal;
                        end
                        if currentLink.isScheduled
                            currentLink.generateReceiveSignal();

                            BSTotalSignal = Channel.addSignals(BSTotalSignal, currentLink.ReceiveSignal);
                        end
                    end
                    % correct signal length
                    BSTotalSignal = Channel.correctSignalLength(BSTotalSignal, signalLength);

                    % add noise
                    BSTotalSignal = BSTotalSignal + Channel.AWGN( simParams.phy.noisePower, length(BSTotalSignal), BS{iBS}.nAntennas );
                    Links{nBS+1,iBS}.ReceiveSignal = BSTotalSignal;
                end
            end

            %% Localization
            speedOfLight = 299792458;
            centerFrequency = simParams.simulation.centerFrequency;
            waveLength = speedOfLight/centerFrequency;

            receivedSignal  = cell(nBS,1);
            BS_Locations    = cell(nBS,1);
            BS_Orientations = cell(nBS,1);
            numOfRxAntennas = cell(nBS,1);
            antennaDistance = cell(nBS,1);
            for iBS = 1:nBS
                receivedSignal{iBS}  = Links{nBS+1,iBS}.ReceiveSignal;
                BS_Locations{iBS}    = simParams.topology.nodesPosition{iBS};
                BS_Orientations{iBS} = simParams.channel.nodesOrientation{iBS};
                numOfRxAntennas{iBS} = Links{nBS+1,iBS}.nRxAntennas;
                antennaDistance{iBS} = waveLength * Links{nBS+1,iBS}.spatialModelParameters.antennaSpacingRx;
            end

            for iLocAlg = 1:nLocAlg
                [  estimatedPosition(iFrame,iUEposition,iSweep,iLocAlg,:), estimatedAngles(iFrame,iUEposition,iSweep,iLocAlg,:)  ] = ...
                    localizationAlgorithms(iLocAlg).function(receivedSignal, BS_Locations, BS_Orientations, numOfRxAntennas, antennaDistance, centerFrequency);
            end

            

            %% Time Calculation
            % Some basic time calculation.
            if double(tic-prevTime)*1e-6 > 60
                prevTime = tic;
                jFrame   = iFrame + nFrames*(iUEposition-1) + nFrames*nUEpositions*(iSweep-1);
                fprintf('Sweep & UEpos: %i/%i, Frame: %i/%i, approx. %.0fs left\n', (iSweep-1)*nUEpositions+iUEposition,nSweeps*nUEpositions,iFrame,nFrames, double(tic-startTime)*1e-6*(nFrames*nUEpositions*nSweeps-jFrame)/jFrame);
            end
        end % for iFrame
    end % parfor iUEposition
end % for iSweep


%% Save Results
simulationTime = toc(startTime);
toc(startTime);
% generate timestamp
timeStamp = datestr(now,'yyyy-mm-dd_HH_MM_SS');
% save results (complete workspace)
save(['./results/results_loc_', timeStamp]);
fprintf(['------- Done -------', '\n']);


%%
%%%%%%%%%%%%%%%%%%%%%%%
%%%  POST PROCESSING
%%%%%%%%%%%%%%%%%%%%%%%

%% General Simulation Info
% - display general simulation parameters and properties
if 1
    locAlgStr = localizationAlgorithms(1).plotName;
    for iLocAlg = 2:nLocAlg
        locAlgStr = strcat(locAlgStr,", ",localizationAlgorithms(iLocAlg).plotName);
    end
    sweepParamName = strsplit(simParams.simulation.sweepParam{1}, '.');
    info = {
    "Localization Algorithms:", locAlgStr;
    "Number of UE positions:", num2str(nUEpositions);
    "Number of BSs:", num2str(nBS);
    "Sweep Parameter:", sweepParamName{end};
    "Sweep Values:", num2str(simParams.simulation.sweepValue);
    "nFrames:", num2str(nFrames);
    "Simulation Time [h:mm:ss]:", char(duration(0,0,simulationTime))};
    for iLine = 1:size(info,1)
        fprintf("%-"+num2str(max(strlength([info{:,1}])))+"s %s\n",info{iLine,1},info{iLine,2});
    end
end

%% Calculate Positioning Error
% - using the actual UE positions and the estimates, the corresponding positioning
%    errors are calculated
if 1
    positioningErrorDistance = zeros(nFrames,nUEpositions,nSweeps,nLocAlg);
    for iSweep = 1:nSweeps
        for iUEposition = 1:nUEpositions
            for iFrame = 1:nFrames
                for iLocAlg = 1:nLocAlg
                    positioningErrorDistance(iFrame,iUEposition,iSweep,iLocAlg) = ...
                        norm( reshape(estimatedPosition(iFrame,iUEposition,iSweep,iLocAlg,:),1,3) - UEpositions(iUEposition,:) );
                end
            end
        end
    end
end

%% BS Coverage Check
% - check if the estimated UE position is within BS coverage
% - consider BS coverage in evaluating UE position estimates
% - overwrites positioning errors with nan (not a number) if the estimated
%    position does not lie in the coverage circle of the BS
% - the coverage circle of a BS is parameterized individually by its
%    radius (BScoverageRadius)
if 0
    BScoverageRadius = ones(1,nBS) * 1000;
    outOfCoverage = false(nFrames,nUEpositions,nSweeps,nLocAlg);
    for iSweep = 1:nSweeps
        for iUEposition = 1:nUEpositions
            for iFrame = 1:nFrames
                for iLocAlg = 1:nLocAlg
                    for iBS = 1:nBS
                        outOfCoverage(iFrame,iUEposition,iSweep,iLocAlg) = outOfCoverage(iFrame,iUEposition,iSweep,iLocAlg) | ...
                             (norm( reshape(estimatedPosition(iFrame,iUEposition,iSweep,iLocAlg,:),1,3) - simParams.topology.nodesPosition{iBS} ) ...
                             > BScoverageRadius(iBS));
                    end
                end
            end
        end
    end
    positioningErrorDistance( outOfCoverage > 0 ) = nan;
end


%%
%%%%%%%%%%%%%%%%%%%%%
%%%  VISUALIZATION
%%%%%%%%%%%%%%%%%%%%%

%% 2D Scenario
% - visualize localization scenario as topview, projected to xy-plane
% - draw BS and UE positions
% - BS positions are drawn as points or with their orientation indicated
%    (drawBSOrientation) with adjustable line length
%    (orienationIndicatorLength)
% - optionally output all BS and UE coordinates to the Command Window
%    (printPositions)
if 0
    % parameters
    drawBSOrientation            = 1;
    orienationIndicatorLength    = 50;
    printPositions2CommandWindow = 0;

    figure
    hold on;
    for iBS = 1:nBS
        if drawBSOrientation
            lineDist = orienationIndicatorLength * [cosd(simParams.channel.nodesOrientation{iBS}(1)),sind(simParams.channel.nodesOrientation{iBS}(1))];
            BSplotHandle = line([simParams.topology.nodesPosition{iBS}(1) - lineDist(1), simParams.topology.nodesPosition{iBS}(1) + lineDist(1)], ...
                                [simParams.topology.nodesPosition{iBS}(2) - lineDist(2), simParams.topology.nodesPosition{iBS}(2) + lineDist(2)], ...
                                'Color','blue');
            line([simParams.topology.nodesPosition{iBS}(1), simParams.topology.nodesPosition{iBS}(1) - lineDist(2)], ...
                 [simParams.topology.nodesPosition{iBS}(2), simParams.topology.nodesPosition{iBS}(2) + lineDist(1)], ...
                 'Color','blue');
        else
            BSplotHandle = scatter(simParams.topology.nodesPosition{iBS}(1),simParams.topology.nodesPosition{iBS}(2),50,'blue','square','filled');
        end

        if printPositions2CommandWindow
            fprintf("BS%i: x = %4.0f, y = %4.0f, z = %4.0f\n", iBS,simParams.topology.nodesPosition{iBS})
        end
    end
    UEplotHandle = scatter(UEpositions(:,1),UEpositions(:,2),50,'red','x');
    if printPositions2CommandWindow
        for iUE = 1:nUEpositions
            fprintf("UEpos%i: x = %4.0f, y = %4.0f, z = %4.0f\n", iUE,UEpositions(iUE,:))
        end
    end
    axis equal
    grid on
    title('2D Scenario')
    xlabel('x coordinate [m]');
    ylabel('y coordinate [m]');
    legend([BSplotHandle, UEplotHandle], "BS","UE")
end

%% RMS Positioning Error over Sweep Parameter
% - gather errors of all simulated frames from all UE positions according
%    to their sweep parameter value
% - plots their root mean squared error
% - also calculates and plots the confidence intervals
if 0
    % putting results from UE positions and frames into a single dimension
    positioningErrorDistanceRsh = reshape(positioningErrorDistance,[],nSweeps,nLocAlg);

    % calculate RMS positioning error
    squaredErrorDistance = positioningErrorDistanceRsh.^2;
    meanSquaredErrorDistance = mean(squaredErrorDistance,1,'omitnan');
    rootMeanSquaredErrorDistance = sqrt(meanSquaredErrorDistance);

    % calculate confidence intervals
    mean_func         = @(inputValue) mean(inputValue,'omitnan');
    confErrorDistance = zeros(2,nSweeps,nLocAlg);
    for iLocAlg = 1:nLocAlg
        confErrorDistance(:,:,iLocAlg) = sqrt( Utils.Extras.bootci(squaredErrorDistance(:,:,iLocAlg), 0.95, 10^4, mean_func, false) );
    end

    % plot
    figure
    hold on
    labels = cell(1,nLocAlg);
    for iLocAlg = 1:nLocAlg
        errorbar(simParams.simulation.sweepValue,rootMeanSquaredErrorDistance(:,:,iLocAlg), ...
            confErrorDistance(1,:,iLocAlg),confErrorDistance(2,:,iLocAlg));
        labels{iLocAlg} = localizationAlgorithms(iLocAlg).plotName;
    end
    legend(labels)
    grid on
    title('RMS Positioning Error over Sweep Parameter')
    sweepParamName = strsplit(simParams.simulation.sweepParam{1}, '.');
    xlabel(sweepParamName{end});
    ylabel('RMS Positioning Error [m]');
    set(gca, 'YScale','log')
end

%% Probability of Sub-Threshold Accuracy over Sweep Parameter
% - gather errors of all simulated frames from all UE positions according
%    to their sweep parameter value
% - plots the probability for the positioning error being smaller than an
%    arbitrary threshold (thresh_acc) for each sweep parameter value
if 0
    % parameter
    thresh_acc = 10;
    
    % putting results from UE positions and frames into a single dimension
    positioningErrorDistanceRsh = reshape(positioningErrorDistance,[],nSweeps,nLocAlg);

    % calculate probability
    probability = sum(positioningErrorDistanceRsh < thresh_acc) ./ (nFrames*nUEpositions);
    
    % plot
    figure
    hold on
    labels = cell(1,nLocAlg);
    for iLocAlg = 1:nLocAlg
        plot(simParams.simulation.sweepValue,probability(:,:,iLocAlg));
        labels{iLocAlg} = localizationAlgorithms(iLocAlg).plotName;
    end
    legend(labels)
    grid on
    title('Probability of Sub-Threshold Accuracy')
    sweepParamName = strsplit(simParams.simulation.sweepParam{1}, '.');
    xlabel(sweepParamName{end});
    ylabel(strcat('Probability of Sub-',num2str(thresh_acc),'m Accuracy'));
end

%% Error Histogram
% - plots histogram of the positioning errors
% - UE position is selected by its index (iUEposition)
% - sweep parameter value is selected by its index (iSweep)
% - outliers are truncated to an adjustable value (truncError)
% - disable outlier truncation by setting truncError to 0
if 0
    % select positions and sweep value
    iUEposition = 2;    % index of  UEpositions
    iSweep      = 3;    % index of  simParams.simulation.sweepValue
    % parameters
    truncError = 0;

    
    positioningErrorDistanceSel = zeros(nFrames,nLocAlg);
    for iLocAlg = 1:nLocAlg
        positioningErrorDistanceSel(:,iLocAlg) = positioningErrorDistance(:,iUEposition,iSweep,iLocAlg);
    end

    % truncate error values
    if truncError
        positioningErrorDistanceSel = min(positioningErrorDistanceSel, truncError);
    end
    
    % plot
    figure
    hold on;
    maxError = max(positioningErrorDistanceSel,[],'all');
    for iLocAlg = 1:nLocAlg
        histogram(positioningErrorDistanceSel(:,iLocAlg),50,'BinLimits',[0,maxError]);
        labels{iLocAlg} = localizationAlgorithms(iLocAlg).plotName;
    end
    legend(labels)
    grid on
    sweepParamName = strsplit(simParams.simulation.sweepParam{1}, '.');
    title(strcat("Error Histogram for ",sweepParamName{end}," = ", ...
        num2str(simParams.simulation.sweepValue(iSweep))));
    xlabel('positioning error [m]');
    ylabel("number of times");
end

%% Positioning Error ECDF
% - plots empirical cumulative distribution function of positioning errors
% - UE position is selected by its index (iUEposition)
% - sweep parameter value is selected by its index (iSweep)
% - outliers are truncated to an adjustable value (truncError)
% - disable outlier truncation by setting truncError to 0
if 0
    % select positions and sweep value
    iUEposition = 1;    % index of  UEpositions
    iSweep      = 4;    % index of  simParams.simulation.sweepValue
    % parameters
    truncError  = 0;

    
    positioningErrorDistanceSel = zeros(nFrames,nLocAlg);
    for iLocAlg = 1:nLocAlg
        positioningErrorDistanceSel(:,iLocAlg) = positioningErrorDistance(:,iUEposition,iSweep,iLocAlg);
    end

    % truncate error values
    if truncError
        positioningErrorDistanceSel = min(positioningErrorDistanceSel, truncError);
    end
    
    % plot
    figure
    hold on;
    maxError = max(positioningErrorDistanceSel,[],'all');
    for iLocAlg = 1:nLocAlg
        cdfplot(positioningErrorDistanceSel(:,iLocAlg));
        labels{iLocAlg} = localizationAlgorithms(iLocAlg).plotName;
    end
    legend(labels)
    grid on
    sweepParamName = strsplit(simParams.simulation.sweepParam{1}, '.');
    title(strcat("Positioning Error ECDF for ",sweepParamName{end}," = ", ...
        num2str(simParams.simulation.sweepValue(iSweep))));
    xlabel('positioning error [m]');
    ylabel("empirical cdf of positioning error");
    set(gca, 'XScale','log')
end

%% RMS positioning error at UE Position (2D)
% - plots RMS positioning error according to actual UE position
% - an interpolated 3D mesh plot, a scaled color plot, or both can be
%    visualized in one figure
% - sweep parameter value is selected by its index (iSweep)
% - localization algorithm is selected by its index (iLocAlg)
% - results for 3D mesh plot are generated by interpolating simulation
%    results onto a mesh with adjustable mesh size (interpolMeshSize)
% - the interpolation method paramter (interpolMethod) is set to 'linear',
%    'nearest', 'natural', 'cubic' or 'v4'
% - outliers are truncated to an adjustable value (truncRMSE)
% - disable outlier truncation by setting truncError to 0
% - the color map can be customized (color_mapping, default = [])
if 0
    % select sweep value and localization algorithm
    iSweep  = 1;    % index of  simParams.simulation.sweepValue
    iLocAlg = 1;    % index of  localizationAlgorithms
    % parameters
    plot_interpolMesh = 0;
    plot_scaledColor  = 1;
    interpolMeshSize  = 1;
    interpolMethod    = 'linear';
    truncRMSE         = 0;
%     color_mapping     = [];%CubeHelix(256,0.5,-1.5,1.2,1.0);
    color_mapping     = [];%flipud(cubehelix);


    % check if z-coordinate is constant
    nUEpositionsX = size(unique(UEpositions(:,1)),1);
    nUEpositionsY = size(unique(UEpositions(:,2)),1);
    nUEpositionsZ = size(unique(UEpositions(:,3)),1);
    if nUEpositionsZ ~= 1
        warning("Not all UE positions are at same height, may result in unfair comparison!")
    end

    % calculate RMS positioning error
    squaredErrorDistance = positioningErrorDistance(:,:,iSweep,iLocAlg).^2;
    meanSquaredErrorDistance = mean(squaredErrorDistance,1,'omitnan');
    rootMeanSquaredErrorDistance = sqrt(meanSquaredErrorDistance).';
    
    % truncate error values
    if truncRMSE
        rootMeanSquaredErrorDistance = min(rootMeanSquaredErrorDistance, truncRMSE);
    end
    rootMeanSquaredErrorDistanceMax = max(rootMeanSquaredErrorDistance);

    xPositionRange = [min(UEpositions(:,1)), max(UEpositions(:,1))];
    yPositionRange = [min(UEpositions(:,2)), max(UEpositions(:,2))];

    figure
    hold on

    %% interpolated 3D mesh plot
    if plot_interpolMesh
        [xq,yq] = meshgrid(xPositionRange(1):interpolMeshSize:xPositionRange(2), ...
            yPositionRange(1):interpolMeshSize:yPositionRange(2));
        interpolRMSE = griddata(UEpositions(:,1),UEpositions(:,2),rootMeanSquaredErrorDistance,xq,yq,interpolMethod);
        % plot
        plot3(UEpositions(:,1),UEpositions(:,2),rootMeanSquaredErrorDistance,'ro')
        mesh(xq,yq,interpolRMSE)
        legend('Sample Points','Interpolated Surface')
    end
    
    %% scaled colors plot
    if plot_scaledColor
        data = [UEpositions,rootMeanSquaredErrorDistance];
        sortedData = sortrows(data,[1,2]);
        rootMeanSquaredErrorDistanceRsh = reshape(sortedData(:,4),[nUEpositionsY,nUEpositionsX]);
        % plot
        imagesc(xPositionRange,yPositionRange,rootMeanSquaredErrorDistanceRsh)
        ax = gca;
        ax.YDir='normal';
    end
    
    c = colorbar;
    if ~isempty(color_mapping)
        colormap(color_mapping)
    end
    caxis([0,rootMeanSquaredErrorDistanceMax]);
    c.Label.String = 'RMS positioning error [m]';
    sweepParamName = strsplit(simParams.simulation.sweepParam{1}, '.');
    title(strcat("RMS positioning error at UE position (", ...
        "algorithm = ",localizationAlgorithms(iLocAlg).plotName, ...
        ", ",sweepParamName{end}," = ",num2str(simParams.simulation.sweepValue(iSweep)),")"));
    xlabel('x coordinate [m]');
    ylabel('y coordinate [m]');
end

%% Probability of Sub-Threshold Accuracy at UE Position (2D)
% - plots the probability for the positioning error being smaller than an
%    arbitrary threshold (thresh_acc) for each actual UE position
% - an interpolated 3D mesh plot, a scaled color plot, or both can be
%    visualized in one figure
% - sweep parameter value is selected by its index (iSweep)
% - localization algorithm is selected by its index (iLocAlg)
% - results for 3D mesh plot are generated by interpolating simulation
%    results onto a mesh with adjustable mesh size (interpolMeshSize)
% - the interpolation method paramter (interpolMethod) is set to 'linear',
%    'nearest', 'natural', 'cubic' or 'v4'
% - the color map can be customized (color_mapping, default = [])
if 0
    % select sweep value and localization algorithm
    iSweep  = 3;    % index of  simParams.simulation.sweepValue
    iLocAlg = 1;    % index of  localizationAlgorithms
    % parameters
    plot_interpolMesh = 0;
    plot_scaledColor  = 1;
    interpolMeshSize  = 1;
    interpolMethod    = 'linear';
    thresh_acc = 1;
%     color_mapping     = [];%CubeHelix(256,0.5,-1.5,1.2,1.0); % trying out external helix color mapping
    color_mapping     = [];%flipud(cubehelix);


    % check if z-coordinate is constant
    nUEpositionsX = size(unique(UEpositions(:,1)),1);
    nUEpositionsY = size(unique(UEpositions(:,2)),1);
    nUEpositionsZ = size(unique(UEpositions(:,3)),1);
    if nUEpositionsZ ~= 1
        warning("Not all UE positions are at same height, may result in unfair comparison!")
    end

    % calculate probability
    probability = sum(positioningErrorDistance(:,:,iSweep,iLocAlg) < thresh_acc) ./ nFrames;

    xPositionRange = [min(UEpositions(:,1)), max(UEpositions(:,1))];
    yPositionRange = [min(UEpositions(:,2)), max(UEpositions(:,2))];

    figure
    hold on

    %% interpolated 3D mesh plot
    if plot_interpolMesh
        [xq,yq] = meshgrid(xPositionRange(1):interpolMeshSize:xPositionRange(2), ...
            yPositionRange(1):interpolMeshSize:yPositionRange(2));
        interpolRMSE = griddata(UEpositions(:,1),UEpositions(:,2),probability,xq,yq,interpolMethod);
        % plot
        plot3(UEpositions(:,1),UEpositions(:,2),probability,'ro')
        mesh(xq,yq,interpolRMSE)
        legend('Sample Points','Interpolated Surface')
    end
    
    %% scaled colors plot
    if plot_scaledColor
        data = [UEpositions,probability'];
        sortedData = sortrows(data,[1,2]);
        probabilityRsh = reshape(sortedData(:,4),[nUEpositionsY,nUEpositionsX]);
        % plot
        imagesc(xPositionRange,yPositionRange,probabilityRsh)
        ax = gca;
        ax.YDir='normal';
    end
    
    c = colorbar;
    if ~isempty(color_mapping)
        colormap(color_mapping)
    end
    caxis([0,1]);
    c.Label.String = strcat('Probability of Sub-',num2str(thresh_acc),'m Accuracy');
    sweepParamName = strsplit(simParams.simulation.sweepParam{1}, '.');
    title(strcat('Probability of Sub-',num2str(thresh_acc),'m Accuracy at UE position (', ...
        'algorithm = ',localizationAlgorithms(iLocAlg).plotName, ...
        ', ',sweepParamName{end}," = ",num2str(simParams.simulation.sweepValue(iSweep)),")"));
    xlabel('x coordinate [m]');
    ylabel('y coordinate [m]');
end


%% Estimated UE Positions (2D)
% - visualize localization scenario as topview, projected to xy-plane
% - draw BS, actual and estimated UE positions
% - BS positions are drawn as points or with their orientation indicated
%    (drawBSOrientation) with adjustable line length
%    (orienationIndicatorLength)
% - optionally draw estimated direction of arrival (plot_DoA)
% - set line length of DoA lines (lineLength)
% - sweep parameter value is selected by its index (iSweep)
% - localization algorithm is selected by its index (iLocAlg)
% - UE position is selected by its index (iUEposition)
if 1
    % select sweep value and localization algorithm
    iSweep      = 1;    % index of  simParams.simulation.sweepValue
    iLocAlg     = 3;    % index of  localizationAlgorithms
    iUEposition = 1;    % index of  UEpositions
    % parameters
    drawBSOrientation            = 1;
    orienationIndicatorLength    = 50;
    plot_DoA                     = 1;
    DoALineLength                = 300;
    
    
    figure
    hold on;
    for iBS = 1:nBS
        if drawBSOrientation
            lineDist = orienationIndicatorLength * [cosd(simParams.channel.nodesOrientation{iBS}(1)),sind(simParams.channel.nodesOrientation{iBS}(1))];
            BSplotHandle = line([simParams.topology.nodesPosition{iBS}(1) - lineDist(1), simParams.topology.nodesPosition{iBS}(1) + lineDist(1)], ...
                                [simParams.topology.nodesPosition{iBS}(2) - lineDist(2), simParams.topology.nodesPosition{iBS}(2) + lineDist(2)], ...
                                'Color','blue');
            line([simParams.topology.nodesPosition{iBS}(1), simParams.topology.nodesPosition{iBS}(1) - lineDist(2)], ...
                 [simParams.topology.nodesPosition{iBS}(2), simParams.topology.nodesPosition{iBS}(2) + lineDist(1)], ...
                 'Color','blue');
        else
            BSplotHandle = scatter(simParams.topology.nodesPosition{iBS}(1),simParams.topology.nodesPosition{iBS}(2),100,'blue','square','filled');
        end
    end
    UEplotHandle = scatter(UEpositions(iUEposition,1),UEpositions(iUEposition,2),150,'red','X','LineWidth',50);

    % add estimated user positions to plot
    estimatedPositionSel = reshape(estimatedPosition(:,iUEposition,iSweep,iLocAlg,:),nFrames,3);
    UEestHandle  = scatter(estimatedPositionSel(:,1),estimatedPositionSel(:,2),50,[0,.6,0],'+');
    
    % add estimated angle of arrival to plot
    if plot_DoA
        for iBS = 1:nBS
            iBSpos = [simParams.topology.nodesPosition{iBS}(1),simParams.topology.nodesPosition{iBS}(2)];
            for iFrame = 1:min(100,nFrames)
                estimatedAnglesSel = estimatedAngles(iFrame,iUEposition,iSweep,iLocAlg,iBS);
                plot(iBSpos(1)+[0,1]*DoALineLength*cosd(estimatedAnglesSel),...
                     iBSpos(2)+[0,1]*DoALineLength*sind(estimatedAnglesSel));
            end
        end
    end
    axis equal
    grid on
    sweepParamName = strsplit(simParams.simulation.sweepParam{1}, '.');
    title(strcat("Estimated UE Positions (", ...
        "algorithm = ",localizationAlgorithms(iLocAlg).plotName, ...
        ", ",sweepParamName{end}," = ",num2str(simParams.simulation.sweepValue(iSweep)),")"));
    xlabel('x coordinate [m]');
    ylabel('y coordinate [m]');
    legend([BSplotHandle, UEplotHandle, UEestHandle], "BS","UE","estimated UE");
end


%% end of script
rmpath('./Examples');





















