%% The Vienna 5G Link Level Simulator v1.2
% www.tc.tuwien.ac.at/vccs
% Please refer to the user manual to get familiar with the simulator structure and mechanics. 
% For any questions, consider our forum www.tc.tuwien.ac.at/forum.

% Author: Wilfried Wiedner


close all;
clear;
clc;
rng('default');
cd('..');
addpath('./Examples');

if 1 %set to zero for post processing only
%% Setup
c0 = 299792458.0; %speed of light in m/s
nReps = 100; %number of Repetitions with different BS Positions
noiseReal = 1; %number of noise realisations, over which is averaged, choose 1 for fastest simulation
refBS = 1; %choose reference BS for localization algorithm
rndErr = 1; %if rnd_err = 0, BS locations are chosen such that no rounding error occurs when converting time delay to sample delay
simNoise = 1; %simulate with noise (AWGN channel)
SNRdB = [-25 -20]; %specify SNR values 
preCheckTOA = 0; %TOA measurements in case of AWGN are prechecked, if preCheckTOA = 1
timingInfoResolution = 5; %Repetition steps for printing remaining simulation runtime


% select scenario
simulationScenario = 'DLTDOAlocalizationScenario';

% load parameters according to scenario
simParams = Parameters.SimulationParameters(simulationScenario);

%load precalculated PRS grid for all BS
%every PRS/BS has same number of subcarriers, total symbols, subcarrier spacing, FFT Size, cyclic prefix etc.
loadedStructure = load("+Localization/grid4bs.mat"); %Matlab 5G toolbox has been used to precalculate PRS grid for all BSs
PRSGrid = loadedStructure.grid; %change variable name from "grid" to "PRSGrid"
clear("loadedStructure");

%Set modulation parameters based on size of PRSGrid
PRSGridSize = size(PRSGrid{1});
nSubcarriers = PRSGridSize(1);
symbolMultiplicationFactor = PRSGridSize(2)/simParams.modulation.MCSymbols(1);
simParams.modulation.numberOfSubcarriers(1,:) = nSubcarriers;
simParams.modulation.nSymbolsTotal(1,:) = simParams.modulation.nSymbolsTotal(1,:)*symbolMultiplicationFactor;
simParams.modulation.nGuardSymbols(1,:) = simParams.modulation.nGuardSymbols(1,:)*symbolMultiplicationFactor;
simParams.modulation.MCSymbols(1,:) = simParams.modulation.MCSymbols(1,:)*symbolMultiplicationFactor;
simParams.schedule.fixedScheduleDL(1,:) = {[sprintf('UE1:%d',nSubcarriers)]};

% generate network topology and links between nodes
[Links, BS, UE, IN] = Topology.getTopology(simParams);
Links = simParams.initializeLinks(Links, BS, UE, IN);

nBS         = length(BS);
nUE         = length(UE);
nLinks      = length(Links);

%Check, if SNR array is empty
if isempty(SNRdB)
    SNRlength = 1;
else
    SNRlength = length(SNRdB);
end

%Allocate Memory
BSPos = cell(nReps,nBS); %colums represent BSs, rows Repetitions (for plotting)
delay = zeros(1,nBS);
sampleDelay = zeros(1,nBS);
estimatedDelay = zeros(1,nBS);
estimatedSampleDelay = zeros(1,nBS);
correlationResults = cell(nReps,nBS);
estimatedTDOA = zeros(nReps,nBS-1);
positionEstimates = cell(length(SNRdB),nReps);
sampleDelayTotal = cell(length(SNRdB),nReps); %Results for calculated sample delays for all SNRs and repetitions
estimatedSampleDelayTotal = cell(length(SNRdB),nReps); %Results for estimated sample delays for all SNRs and repetitions 
correlationResultsperSNR = cell(length(SNRdB),1); %Correlation results for all SNRs 
pathLoss = zeros(nReps,nBS); 
txScaledCell = cell(nReps,nBS);
txScaledCell1 = cell(nReps,nBS);
noisePower = cell(length(SNRdB),nReps); %store noise power for CRLB calculation
%start of simulation

%generate BS Positions
%Positions differ in each Repetition, but are the same for every SNR sweep
for iReps = 1:nReps
    for iBS = 1:nBS
        if rndErr == 0
            BSPos{iReps,iBS} = randPos2d_noerr(iBS,nBS,simParams.modulation.samplingRate,simParams.topology.nodesPosition{nBS+1}(1:2));
        else
            BSPos{iReps,iBS} = randPos2d(iBS,nBS);
        end
    end
end

tic;
for iSNR = 1:SNRlength
    if preCheckTOA == 1 && simNoise == 1 %optional TOA precheck
        corruptedSignal = zeros(nReps,nBS); %indicates, which BS signals lead to incorrect TDOA measurements due to noise
    end
    if iSNR ~= 1 && simNoise == 0
        break
    end
for iReps = 1:nReps
    for iBS = 1:nBS        
              
        %update BS positions
        simParams.topology.nodesPosition{iBS}(1:2) = BSPos{iReps,iBS};
    
        %calculate signal delays based on speed of light and distance to user for each BS (only for modelling)
        delay(iBS) = norm(simParams.topology.nodesPosition{iBS}(1:2)-simParams.topology.nodesPosition{nBS+1}(1:2))/c0;
        sampleDelay(iBS) = round(delay(iBS)*simParams.modulation.samplingRate);
    end
    sampleDelayTotal{iSNR,iReps} = sampleDelay;
    
    %set geometric parameters of each link (PL,...)
    simParams.setGeometricParameters(Links);
              
    %get inverse of sampling rate
    dt = Links{1,5}.Modulator.WaveformObject.PHY.dt;  
    
    %allocate memory for the sum received signal   
    sumReceivedSignal = zeros(Links{1,5}.Modulator.WaveformObject.Nr.SamplesTotal + max(sampleDelay), 1);
    
    %generate transmit signals of each basestation based on given PRS resource grid, received signal and sum rx signals up
    for iBS = 1:nBS            
        %generate transmit signal for each BS (link)
        Links{iBS,nLinks}.TransmitSignal = Links{iBS,nLinks}.Modulator.WaveformObject.Modulation(PRSGrid{iBS});
        %genarate receive signal for each link (delay and scale transmit signal)
%          PL = 10^(Links{iBS,nLinks}.pathloss/10); %convert pathloss
%         pathLoss(iReps,iBS) = PL; %store pathloss (linear) for post processing
%         txScaled = Links{iBS,nLinks}.TransmitSignal/sqrt(PL);
%                
%         txScaledCell{iReps,iBS} = txScaled; %store scaled signal for version1
        
        %scaled tx signal version2 using simulator functions. is this the correct way?
        Links{iBS,5}.Channel.NewRealization(1, simParams.simulation.frameStructure, Links{iBS,5}.Direction);
        Links{iBS,5}.generateReceiveSignal();
        txScaledCell1{iReps,iBS} = Links{iBS,5}.ReceiveSignal; %store scaled signal for version2
        Links{iBS,nLinks}.ReceiveSignal = [zeros(sampleDelay(iBS),1); Links{iBS,nLinks}.ReceiveSignal; zeros(max(sampleDelay)-sampleDelay(iBS), 1)];
        pathLoss(iReps,iBS) = 10^(Links{iBS,nLinks}.pathloss/10); %store pathloss (linear) for post processing
        %zeros at the beginning to model delay, zeros at the end for equal length
%         Links{iBS,nLinks}.ReceiveSignal = [zeros(sampleDelay(iBS),1); txScaled; zeros(max(sampleDelay)-sampleDelay(iBS), 1)]; 
    
        %sum up received signals
        sumReceivedSignal = sumReceivedSignal + Links{iBS,nLinks}.ReceiveSignal;       
    end

    %add noise, if desired
    %noise power is calculated based on power of sumReceivedSignal and configured SNR
    %a number of "noiseReal" realizations are summed up and renormalized 
    if simNoise == 1
        noise = zeros(length(sumReceivedSignal),1);
        rxPower = mean(abs(sumReceivedSignal).^2);
        noisePower{iSNR,iReps} = rxPower/10^(SNRdB(iSNR)/10);         
        for i_it = 1:noiseReal
            noise_it = Channel.AWGN(noisePower{iSNR,iReps},length(sumReceivedSignal),1);
            noise = noise + noise_it;
        end
        noise = noise/sqrt(noiseReal);
        sumReceivedSignal = sumReceivedSignal + noise;
    end

    %allocate memory for delta positions and BS distances to ref BS
    BSdeltaPositions = zeros(2,nBS-1); %Colums represent BS, row 1 x and row 2 y coordinate differences to ref BS
    BSDistance = zeros(1,nBS-1);
       
    %estimate delay of each link by correlating the corresponding tx signal with the sum rx signal
    % usually, a local replica of the tx signal is generated by the UE based on the known PRS configuration
    %of each BS; for simplicity, this step is omitted
    j=1;
    for iBS = 1:nBS
        c = abs(xcorr(sumReceivedSignal,Links{iBS,nLinks}.TransmitSignal));
        c(1:length(sumReceivedSignal)) = [];                                %remove useless part of correlation result
        correlationResults{iReps,iBS} = c(1:1*Links{iBS,5}.Modulator.WaveformObject.Implementation.FFTSize); %extract %data for one symbol
        estimatedSampleDelay(iBS) = find( correlationResults{iReps,iBS} == max(correlationResults{iReps,iBS})); %find point of maximum correlation
        estimatedDelay(iBS) = estimatedSampleDelay(iBS)*dt;                 %multiply with inverse of sampling rate to get delay in time domain
        
        %calculate TDOA, delta positions and BS distances to ref BS
        if(iBS == refBS)
            continue;
        end
        estimatedTDOA(iReps,j) = estimatedDelay(iBS) - estimatedDelay(refBS);
        if(estimatedTDOA(iReps,j)==0)
            warning(sprintf('Estimated range difference is zero in Rep %d, BS %d can not take part in localization',iReps,j+1));
        end
        BSdeltaPositions(:,j) = BSPos{iReps,iBS} - BSPos{iReps,refBS};
        BSDistance(j)=norm(BSdeltaPositions(:,j));
        %Precheck, if estimated TDOA fulfills triangle inequality 0 <=TDOA_i,ref <= d_i,ref        
        if(preCheckTOA == 1 && simNoise == 1)
            if(estimatedTDOA(iReps,j)*c0<0 || estimatedTDOA(iReps,j)*c0>BSDistance(j)) %when TDOA can not be negative (Ref BS has shortest distance to UE)
%             if(estimatedTDOA(iReps,j)*c0<-BSDistance(j) || estimatedTDOA(iReps,j)*c0>BSDistance(j))
                warning('TDOA estimate for BS %d in Rep %d is potentially wrong and will be ignored',iBS,iReps)
                estimatedTDOA(iReps,j) = 0;
                corruptedSignal(iReps,iBS) = 1;
            end
        end
        j=j+1;
    end
    estTDOA = estimatedTDOA(iReps,:); %extract TDOA vector for current repetition for better handling
    if(preCheckTOA == 1 && simNoise == 1)
        corruptedSignalIndices = find(corruptedSignal(iReps,:)==1);
    else
        corruptedSignalIndices = [];
    end
    estimatedSampleDelayTotal{iSNR,iReps} = estimatedSampleDelay;
    
    %calculate range differences of BS to ref BS
    estimatedBSdeltaDistance = c0*estTDOA;
    if(length(find(estTDOA~=0))<2) %At least 2 TDOA measurements are needed to estimate a 2D position, positionEstimates will be empty
        warning('Not enough Data to perform Localization');
        continue;
    end
    
    %estimate UE location using friedlander's method
    positionEstimates{iSNR,iReps} = Localization.friedlander(BSPos(iReps,:),BSdeltaPositions, ...
                    estimatedBSdeltaDistance,refBS,nBS,length(estTDOA),corruptedSignalIndices,iReps);

    if iReps == 1 && iSNR == 1
        timemeasure = toc; %calculate runtime of one repetition
        if simNoise == 1
            totalSimulationTime = timemeasure*length(SNRdB)*nReps;
        else
            totalSimulationTime = timemeasure*nReps;
        end
        fprintf('Simulation started, estimated runtime: %.0f seconds\n',totalSimulationTime);
    end
    if mod(iReps,timingInfoResolution) == 0 %print remaining runtime every 10th repetition
        if simNoise == 1
            simulationTimeLeft = totalSimulationTime - (iReps+(iSNR-1)*nReps)*timemeasure;
            fprintf('Completed repetition %d/%d for SNR index %d/%d, approx. %.0f seconds left\n',iReps,nReps,iSNR,length(SNRdB),simulationTimeLeft);
        else
            simulationTimeLeft = totalSimulationTime - iReps*timemeasure;
            fprintf('Completed repetition %d/%d, approx. %.0f seconds left\n',iReps,nReps,simulationTimeLeft);
        end
    end
end
% estimatedTDOASNR{iSNR} = estimatedTDOA; %uncomment, if TDOA estimates for each SNR should be stored
if preCheckTOA == 1 && simNoise == 1 %optional TOA precheck
    corruptedSignalperSNR{iSNR} = corruptedSignal; %store indicators for wrong TOA measurements for each SNR iteration
end
correlationResultsperSNR{iSNR} = correlationResults; %store correlation results for each SNR iteration
end 
end



%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%% Post Processing %%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Calculate RMSE per SNR and positioning error per repetition per SNR
if 1
    if simNoise == 1
        RMSE = zeros(SNRlength,1);
    else
        RMSE = zeros(1,1);
    end
    positioningError = cell(SNRlength,nReps);
    for iSNR = 1:SNRlength
        if iSNR ~= 1 && simNoise == 0
             break
        end
        squaredError = 0;
        for iReps = 1:nReps
            if isempty(positionEstimates{iSNR,iReps}) %skip position estimate which is empty due to not enough measurements
                continue
            end
            squaredError = squaredError + norm(positionEstimates{iSNR,iReps} - simParams.topology.nodesPosition{nBS+1}(1:2)')^2;
            positioningError{iSNR,iReps} = norm(positionEstimates{iSNR,iReps} - simParams.topology.nodesPosition{nBS+1}(1:2)');
        end
        RMSE(iSNR) = sqrt(1/nReps*squaredError);
    end
    
end

%Plot Positions and Estimates (for at max 5 BSs) and RMSE
%RMSE can be interpreted as the radius of a circle centered at the true UE location. Roughly 63% of the location estimates are within this circle 
if 1
     colors = {'b', 'm', 'g', 'r', 'c'};
     styles = {'s', 's', 's', 's', 's'};
    
     for iSNR = 1:SNRlength
         if iSNR ~= 1 && simNoise == 0
             break
         end
         stringLegend = cell(1,nBS);
         figure;
         hold on;
         for iReps = 1:nReps
             for iBS = 1:nBS
                current2DPos = BSPos(iReps,iBS);
                plot(current2DPos{1}(1),current2DPos{1}(2), strcat(colors{iBS}, styles{iBS}), ...
                    'MarkerSize', 7, 'LineWidth', 2);
                    stringLegend{iBS} = sprintf('BS %d',iBS);
             end
             if isempty(positionEstimates{iSNR,iReps}) %skip position estimate which is empty due to not enough measurements
                continue
             end
             plot(positionEstimates{iSNR,iReps}(1), positionEstimates{iSNR,iReps}(2), 'ko', 'MarkerSize', 7, 'MarkerFaceColor', '#D95319', ...
            'LineWidth', 2);
             plot(simParams.topology.nodesPosition{nBS+1}(1), simParams.topology.nodesPosition{nBS+1}(2),'g+','MarkerSize',6,'LineWidth',2);
         end
         phi = 0:pi/50:2*pi;
         xunitx = RMSE(iSNR) * cos(phi) + simParams.topology.nodesPosition{nBS+1}(1);
         yunity = RMSE(iSNR) * sin(phi) + simParams.topology.nodesPosition{nBS+1}(2);
         plot(xunitx,yunity,'b','LineWidth',1.0);
         axis([-11000 11000 -11000 11000]);
         legend([stringLegend 'Estimated UE Location' 'True UE Location']);
         xlabel('X position in m');
         ylabel('Y position in m');
         grid on;
         if simNoise == 1
            title(sprintf('Position estimates at %.0f dB SNR', SNRdB(iSNR)));
         else
            title(sprintf('Position estimates'));
         end
     end
end

%Plot RMSE over SNR
if 0
    if(simNoise==1)
    figure();
    SNRplot = SNRdB(:); %select SNR values to be considered for plot
    RMSEplot = RMSE(:); %select corresponding RMSEs for plot
    plot(SNRplot,RMSEplot,'linewidth',1.5);
    xlabel('SNR in dB');
    ylabel('RMSE in m');
    title('RMSE over SNR');
    grid on;
    else
    warning('Simulation with noise required to plot RMSE over SNR');
    end
end


%Plot correlation results
if 0   
    %select SNR and repetition indices, wich should be considered for plotting
    %in case of an empty array, all results will be considered
    %Example: Plots of the second repetition for all specified SNR
    %           values: SNRindices = []; repIndices = [2];
    %maximum number of plots: number of SNR values * number of repetitions
    
    SNRindices = [];     %select indices by creating a vector with index numbers, which are supposed to be plotted
    repIndices = [1];     %select indices by creating a vector with index numbers, which are supposed to be plotted
                         %for each selected SNR index, all selected rep indices will be considered
    if isempty(SNRindices)
        if simNoise == 1
            SNRindices = (1:length(SNRdB));
        else
            SNRindices = 1;
        end
    end
    
    if isempty(repIndices)
        repIndices = (1:nReps);
    end

    colors = {'b', 'm', 'g', 'r', 'c'};
    t = (1:length(correlationResults{1,1}))*dt;

    for iSNR = SNRindices
        correlation = correlationResultsperSNR{iSNR};
        for iReps = repIndices
            stringLegend = cell(1,nBS);
            figure;
            hold on; 
            j = 1;
            for iBS = 1:nBS
                color=mod(iBS-1,numel(colors))+1;
                plot(t, correlation{iReps,iBS} , colors{color}, 'LineWidth', 2);
                stringLegend{j} = sprintf('BS %d', iBS);
                stringLegend{j+1} = sprintf('Peak Value');
                maxCorr = find(correlation{iReps,iBS}==max(correlation{iReps,iBS}));
                plot(t(maxCorr), correlation{iReps,iBS}(maxCorr), strcat(colors{color}, 'o'), 'MarkerSize', 5, ...
                    'MarkerFaceColor', colors{color}, 'LineWidth', 2);
                j = j + 2;
             end
             legend(stringLegend);
             xlabel('Time in s');
             ylabel('Absolute value');
             if simNoise == 1
                title(sprintf('PRS correlations for BS at UE, Repetition %d, %d dB SNR',iReps,SNRdB(iSNR)));
             else
                title(sprintf('PRS correlations for BS at UE, Repetition %d',iReps));
             end
             grid on;
        end
    end   
end

%compute and plot ECDF of positioning error with 0.95% confidence bounds
%A large number of repetitions is required for meaningful results
if 1
    lowerConfidenceBounds = cell(1,SNRlength);
    upperConfidenceBounds = cell(1,SNRlength);
    
    SNRindices = [];   %Select SNR indices which should be considered for ECDF plot
                       %Empty array -> all SNRs will be considered for plotting
    if isempty(SNRindices)
        if simNoise == 1
            SNRindices = (1:length(SNRdB));
        else
            SNRindices = 1;
        end
    end
    
    for iSNR = SNRindices
        if iSNR ~= 1 && simNoise == 0
            break
        end
        errorArray = cell2mat(positioningError(iSNR,:)); %extract errors for current SNR
        [f,t,flo,fup] = ecdf(errorArray,'Alpha',0.05,'Bounds','on'); %calculate 95% confidence bounds
        lowerConfidenceBounds{iSNR} = flo;
        upperConfidenceBounds{iSNR} = fup;
        figure;
        stairs(t,f,'LineWidth',1.5); %stair plot of ecdf
        hold on;
        flostair = stairs(t,flo,'r','LineWidth',0.2,'LineStyle','--'); %stair plot of lower confidence bound
        x = [flostair.XData(1),repelem(flostair.XData(2:end),2)];
        y1 = [repelem(flostair.YData(1:end-1),2),flostair.YData(end)];
        fupstair = stairs(t,fup,'r','LineWidth',0.2,'LineStyle','--'); %stair plot of upper confidence bound
        y2 = [repelem(fupstair.YData(1:end-1),2),fupstair.YData(end)];
        idx = ~isnan(y1) & ~isnan(y2); 
        hold on
        for i = 1:2:length(x) %shade area between bounds (confidence interval)
            if ( y1(i) > y2(i) )      % Upper
                xx = [x(i:i+1), fliplr(x(i:i+1))]; 
                yy = [y1(i:i+1), fliplr(y2(i:i+1))]; 
                fill(xx, yy, 'r', 'FaceAlpha',0.2,'EdgeColor','none');
            elseif ( y2(i) > y1(i) )  % Lower
                xx = [x(i:i+1), fliplr(x(i:i+1))]; 
                yy = [y1(i:i+1), fliplr(y2(i:i+1))]; 
                fill(xx, yy, 'r', 'FaceAlpha',0.2,'EdgeColor','none');        
            else                       % Identical
                % do nothing
            end
        end
        hold off
        xlabel('Positioning error in m');
        ylabel('ECDF');
        xlim([0 50]); %set x axis limit for better visualization
        legend('ECDF','95% Confidence Bounds','','95% Confidence Interval');
        grid on;
        if simNoise == 1
            title(sprintf('Positioning Error for %d dB SNR', SNRdB(iSNR)));
        else
            title('Positioning Error');
        end
    end
end


%compute CRLB for positioning error
if 0
    if(simNoise==1) 
    %Memory allocation
    RMSECRLB = zeros(1,length(SNRdB));
    RMSECRLBUsed = zeros(1,length(SNRdB));
    CRLBtoaVariance = zeros(nReps,nBS); %for Calculation via FFT Size
    posErrorCRLB = cell(length(SNRdB),nReps);
    CRLBtoaVarianceUsed = zeros(nReps,nBS); %for Calculation via used SC
    posErrorCRLBUsed = cell(length(SNRdB),nReps);
    cdiag = zeros(1,nBS-1);
    D = zeros(nBS-1,2);
    UELocation = simParams.topology.nodesPosition{nBS+1}(1:2);
    BSUEDistances = zeros(1,nBS);
    %compute sum in equation for variance of TOA estimates
    %only dependent on RE grid
    for iBS = 1:nBS
        dataSymbolsTemp = zeros(Links{iBS,5}.Modulator.WaveformObject.Implementation.FFTSize,Links{iBS,5}.Modulator.WaveformObject.Nr.MCSymbols);
        iGrid = PRSGrid{iBS};
        %create RE Grid (Oversampling) following current LLS implementation
        dataSymbolsTemp(Links{iBS,5}.Modulator.WaveformObject.Implementation.IntermediateFrequency+(1:Links{iBS,5}.Modulator.WaveformObject.Nr.Subcarriers),:) = iGrid;%.*Links{iBS,5}.Modulator.WaveformObject.Implementation.NormalizationFactor;
        gridSize = size(dataSymbolsTemp);
        %compute sum
        [~,colIndices]=meshgrid(1:size(dataSymbolsTemp,2),1:size(dataSymbolsTemp,1));
        [~,colIndicesUsed]=meshgrid(1:size(iGrid,2),1:size(iGrid,1)); %for Calculation via used SC
        %colIndices = colIndices-(Links{1,5}.Modulator.WaveformObject.Implementation.FFTSize/2+1); %sum over SC from -FFTSize/2 to FFTSize/2-1
        colIndicesUsed = colIndicesUsed-(size(colIndicesUsed,1)/2+1); 
        dataSymbolsTemp1 = (abs(dataSymbolsTemp).^2).*(colIndices.^2); %take mag squared of each matrix entry and multiply it with its squared col index
        iGrid1 = (abs(iGrid).^2).*(colIndicesUsed.^2);
        colSum = sum(dataSymbolsTemp1); %calculate sum of each col
        totalSum(iBS) = sum(colSum); %sum up col sums 
        colSumUsed = sum(iGrid1);
        totalSumUsed(iBS) = sum(colSumUsed);
    end
    %compute CRLB for positioning error
    j=1;
    for iSNR = 1:length(SNRdB)
        for iReps = 1:nReps
            k = 1;
            for iBS = 1:nBS
                CRLBtoaVariance(iReps,iBS) = noisePower{iSNR,iReps}/(8*pi^2*1/pathLoss(iReps,iBS)*simParams.modulation.subcarrierSpacing(iBS)^2*totalSum(iBS));
                CRLBtoaVarianceUsed(iReps,iBS) = noisePower{iSNR,iReps}/(8*pi^2*1/pathLoss(iReps,iBS)*simParams.modulation.subcarrierSpacing(iBS)^2*totalSumUsed(iBS));
                BSUEDistances(iBS) = norm(UELocation-BSPos{1,iBS});
                if(iBS>1)
                    cdiag(iBS-1) = CRLBtoaVariance(iReps,1) + CRLBtoaVariance(iReps,iBS);
                    cdiagUsed(iBS-1) = CRLBtoaVarianceUsed(iReps,1) + CRLBtoaVarianceUsed(iReps,iBS);
                    D(k,:) = [(UELocation(1)-BSPos{1,1}(1))/BSUEDistances(1)-(UELocation(1)-BSPos{1,iBS}(1))/BSUEDistances(iBS), (UELocation(2)-BSPos{1,1}(2))/BSUEDistances(1)-(UELocation(2)-BSPos{1,iBS}(2))/BSUEDistances(iBS)];
                    k = k+1;
                end
             
            end
        %set up matrices
        C = diag(cdiag);
        CUsed = diag(cdiagUsed);
        x = ~logical(eye(size(C)));
        C(x) = CRLBtoaVariance(iReps,1); 
        CUsed(x)=CRLBtoaVarianceUsed(iReps,1); 
        posErrorCRLB{iSNR,iReps} = c0*trace(sqrt((D'*C^-1*D)^-1));
        posErrorCRLBUsed{iSNR,iReps} = c0*trace(sqrt((D'*CUsed^-1*D)^-1));
        end
   end
    %calculate RMSE for each SNR
    errorDouble = cell2mat(posErrorCRLB);
    squaredError = errorDouble.^2;
    squaredErrorRowSum = sum(squaredError,2);
    errorDoubleUsed = cell2mat(posErrorCRLBUsed);
    squaredErrorUsed = errorDoubleUsed.^2;
    squaredErrorRowSumUsed = sum(squaredErrorUsed,2);
    for iSNR = 1:length(SNRdB)
        RMSECRLB(iSNR) = sqrt(1/nReps*squaredErrorRowSum(iSNR));
        RMSECRLBUsed(iSNR) = sqrt(1/nReps*squaredErrorRowSumUsed(iSNR));
    end
    else
    warning('Simulation with noise required to compute CRLB');
    end
end

%random BS positions
function pos = randPos2d(i,n)
    phi = i*2*pi/n + 2*pi/(2*n)*rand - 2*pi/(2*n); %random pos on I*2*pi/N sector
    r = randi([0, 500], 1, 1)+2000+(i*2500/n); %Random distance between 2000 + (I*2500/N) and 2500+(I*2500/N) from origin (0,0)
    [x, y] = pol2cart(phi,r);
    pos = [x, y];
end

%calculates BS Positions such that sample delay is an integer number
%arguments: Basestation Number (i), nBS, OFDM sample rate, UE position x,y coordinates
%returns: BS position x,y coordinates
function pos = randPos2d_noerr(i,n,sampleRate,UEpos)
    c_0 = 299792458.0;
    phi = i*2*pi/n + 2*pi/(2*n)*rand - 2*pi/(2*n); %random pos on I*2*pi/N sector
    r = randi([0, 500], 1, 1)+2000+(i*2500/n); %Random distance between 2000 + (I*2500/N) and 2500+(I*2500/N) from origin (0,0)
    [x,y]=pol2cart(phi,r);
    [deltaphi, deltar] = cart2pol(x-UEpos(1),y-UEpos(2));
    r_new = round(deltar/c_0*sampleRate)*c_0/sampleRate;
    [deltax_new, deltay_new] = pol2cart(deltaphi,r_new);
    pos = [deltax_new+UEpos(1), deltay_new+UEpos(2)];
end



