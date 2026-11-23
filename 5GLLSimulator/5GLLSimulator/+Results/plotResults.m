function [ ] = plotResults(results, transmissionType, parameters, UE, BS)
% This function plots the results in terms of uncoded and coded BER, FER,
% throughput, PAPR. Usually, results are plotted over the sweep parameter, but
% they can also be plotted over SNR.

% check if results should be plotted over SNR
C = strsplit(parameters.simulation.sweepParam{1}, '.');
if parameters.simulation.plotOverSNR
    if ~strcmp(C{2},'pathloss')
        warning('Result can only be plotted over SNR if the simulation is swept over pathloss.');
        plotOverSNR = false;
        if length(C) > 2
            myXLabel = strcat(C{2},'.',C{3});
        else
            myXLabel = C{2};
        end
    else
        plotOverSNR = true;
        myXLabel = 'SNR in dB';
    end
else
    plotOverSNR = false;
    if length(C) > 2
        myXLabel = append(C{2},'.',C{3});
    else
        myXLabel = C{2};
    end
end   

nBS = length(BS);
nUE = length(UE);

% uncoded and coded BER for all users
tmpLegend = cell(1);
itmpLegend = 0;
tmpMinValue = 1;
figure('visible','off');
linecolors = colormap('lines');
for iUE = 1:nUE
    if UE{iUE}.PlotResults && ~isempty(results.userResults{iUE})
        itmpLegend = itmpLegend + 1;
        tmpLegend{itmpLegend} = UE{iUE}.Name;

        if plotOverSNR
            xValues = mean(results.userResults{iUE}.SNR);
        else
            xValues = parameters.simulation.sweepValue;
        end

        % uncoded BER
        tmpPlot = errorbar(xValues, results.userResults{iUE}.BERUncoded.mean, results.userResults{iUE}.BERUncoded.confidence(1,:), results.userResults{iUE}.BERUncoded.confidence(2,:), 'color', linecolors(UE{iUE}.ID-nBS,:), 'linestyle', '--' );
        tmpPlot.LData = tmpPlot.YData - max(eps, tmpPlot.YData - tmpPlot.LData); % Plots a line to -inf in the log plot if the lower CI equals 0
        set(get(get(tmpPlot,'Annotation'),'LegendInformation'),'IconDisplayStyle','off');
        currentMinValue = min(nonzeros(results.userResults{iUE}.BERUncoded.mean));
        if ~isempty(currentMinValue)
            if((currentMinValue > eps) && (currentMinValue < tmpMinValue) ); tmpMinValue = currentMinValue; end
        else
            tmpMinValue = 1e-6;
        end
        hold on;

        % coded BER
        e = errorbar(xValues, results.userResults{iUE}.BERCoded.mean, results.userResults{iUE}.BERCoded.confidence(1,:), results.userResults{iUE}.BERCoded.confidence(2,:), 'color', linecolors(UE{iUE}.ID-nBS,:) );
        e.LData = e.YData - max(eps, e.YData - e.LData); % Plots a line to -inf in the log plot if the lower CI equals 0
        currentMinValue = min(nonzeros(results.userResults{iUE}.BERCoded.mean));
        if ~isempty(currentMinValue)
            if( (currentMinValue > eps) && (currentMinValue < tmpMinValue) ); tmpMinValue = currentMinValue; end
        else
            tmpMinValue = 1e-5;
        end
    end
end
% dummy plots for legends
if itmpLegend ~= 0
    shg
    plot(0,0,'color','black','linestyle','-','Visible','on');
    plot(0,0,'color','black','linestyle','--','Visible','on');
    tmpLegend{itmpLegend+1} = 'coded';
    tmpLegend{itmpLegend+2} = 'uncoded';
    
    h = get(gcf,'CurrentAxes');
    set(h,'YScale','log');
    if strcmp(myXLabel,'pathloss') ||  strcmp(myXLabel,'secondary.pathloss')
        set(h, 'XDir','reverse'); 
    end
    ylim([10^(floor(log10(tmpMinValue))) 1]);
    xlabel(myXLabel);
    ylabel('BER');
    title([transmissionType, ' - BER per user']);
    legend( tmpLegend, 'location', 'southwest' );
    grid on;
end

% FER for all users
tmpLegend = cell(1);
itmpLegend = 0;
tmpMinValue = 0.9;
figure('visible','off');
for iUE = 1:nUE
    if UE{iUE}.PlotResults && ~isempty(results.userResults{iUE})
        if plotOverSNR 
            xValues = mean(results.userResults{iUE}.SNR);
        else
            xValues = parameters.simulation.sweepValue;
        end

        e = errorbar(xValues, results.userResults{iUE}.FER.mean, results.userResults{iUE}.FER.confidence(1,:), results.userResults{iUE}.FER.confidence(2,:), 'color', linecolors(UE{iUE}.ID-nBS,:) );
        e.LData = e.YData - max(eps, e.YData - e.LData); % Plots a line to -inf in the log plot if the lower CI equals 0
        itmpLegend = itmpLegend + 1;
        tmpLegend{itmpLegend} = UE{iUE}.Name;
        currentMinValue = min(nonzeros(results.userResults{iUE}.FER.mean));
        if ~isempty(currentMinValue)
            if( (currentMinValue > eps) && (currentMinValue < tmpMinValue) ); tmpMinValue = currentMinValue; end
        else
            tmpMinValue = 1e-3;
        end
        hold on;
    end
end
if itmpLegend ~= 0
    shg
    h = get(gcf,'CurrentAxes');
    set(h,'YScale','log');
    if strcmp(myXLabel,'pathloss') ||  strcmp(myXLabel,'secondary.pathloss')
        set(h, 'XDir','reverse'); 
    end
    ylim([10^(floor(log10(tmpMinValue))) 1]);
    xlabel(myXLabel);
    ylabel('FER');
    title([transmissionType, ' - FER per user']);
    legend( tmpLegend, 'location', 'southwest' );
    grid on;
end

% throughput for all users
tmpLegend = cell(1);
itmpLegend = 0;
figure('visible','off');
for iUE = 1:nUE
    if UE{iUE}.PlotResults && ~isempty(results.userResults{iUE})
        if plotOverSNR
            xValues = mean(results.userResults{iUE}.SNR);
        else
            xValues = parameters.simulation.sweepValue;
        end

        errorbar(xValues, results.userResults{iUE}.throughput.mean / 1e6, results.userResults{iUE}.throughput.confidence(1,:) / 1e6 , results.userResults{iUE}.throughput.confidence(2,:) / 1e6, 'color', linecolors(UE{iUE}.ID-nBS,:) );
        itmpLegend = itmpLegend + 1;
        tmpLegend{itmpLegend} = UE{iUE}.Name; 
        hold on;
    end
end
if itmpLegend ~= 0
    shg
    h = get(gcf,'CurrentAxes');
    if strcmp(myXLabel,'pathloss') ||  strcmp(myXLabel,'secondary.pathloss')
        set(h, 'XDir','reverse'); 
    end
    ylim([0 inf])
    xlabel(myXLabel);
    ylabel('Throughput in MBit/s');
    title([transmissionType, ' - Throughput per user']);
    legend( tmpLegend, 'location', 'northwest' );
    grid on;
end

% channel estimation error for all users
if strcmp(parameters.simulation.channelEstimationMethod, 'PilotAided')
    tmpLegend = cell(1);
    itmpLegend = 0;
    figure('visible','off');
    for iUE = 1:nUE
        if UE{iUE}.PlotResults && ~isempty(results.userResults{iUE})
            if plotOverSNR
                xValues = mean(results.userResults{iUE}.SNR);
            else
                xValues = parameters.simulation.sweepValue;
            end

            e = errorbar(xValues, results.userResults{iUE}.channelMSE.mean, results.userResults{iUE}.channelMSE.confidence(1,:), results.userResults{iUE}.channelMSE.confidence(2,:), 'color', linecolors(UE{iUE}.ID-nBS,:) );
            itmpLegend = itmpLegend + 1;
            tmpLegend{itmpLegend} = UE{iUE}.Name;
            hold on;
        end
    end
    if itmpLegend ~= 0
        shg
        h = get(gcf,'CurrentAxes');
        set(h,'YScale','log');
        e.LData = e.YData - max(eps, e.YData - e.LData); 
        if strcmp(myXLabel,'pathloss') ||  strcmp(myXLabel,'secondary.pathloss')
            set(h, 'XDir','reverse'); 
        end
        xlabel(myXLabel);
        ylabel('channel estimation MSE');
        title([transmissionType, ' - channel estimation error']);
        legend( tmpLegend, 'location', 'southwest' );
        grid on;
    end
end

% PAPR for all BS/Users
if parameters.simulation.plotPAPR
    tmpLegend = cell(1);
    itmpLegend = 0;
    figure('visible','off');
    if strcmp(transmissionType,'Downlink')
        for iBS = 1:nBS
            if BS{iBS}.PlotResults && ~isempty(results.userResults{iBS})
                semilogy(results.userResults{iBS}.PAPR.DataPoints, 1-results.userResults{iBS}.PAPR.CDF , 'color', linecolors(BS{iBS}.ID,:) );
                itmpLegend = itmpLegend + 1;
                tmpLegend{itmpLegend} = BS{iBS}.Name;
                hold on;
            end
        end
        title([transmissionType, ' - PAPR per Base Station']);
    else
        for iUE = 1:nUE
            if UE{iUE}.PlotResults && ~isempty(results.userResults{iUE})
                semilogy(results.userResults{iUE}.PAPR.DataPoints, 1-results.userResults{iUE}.PAPR.CDF , 'color', linecolors(UE{iUE}.ID-nBS,:) );
                itmpLegend = itmpLegend + 1;
                tmpLegend{itmpLegend} = UE{iUE}.Name;
                hold on;
            end
        end
        title([transmissionType, ' - PAPR per User']);
    end
    if itmpLegend ~= 0
        shg
        h = get(gcf,'CurrentAxes');
        ylim([0 inf])
        xlabel('PAPR in dB');
        ylabel('P( PAPR > abscissa)');
        legend( tmpLegend, 'location', 'northwest' );
        grid on;
    end
end

% Sum throughput for every cell (BS)
tmpLegend = cell(1);
itmpLegend = 0;
figure('visible', 'off');
for iBS = 1:nBS
    if BS{iBS}.PlotResults && results.sumThroughput{iBS}.nParticipatingUEs > 0
        if plotOverSNR 
            warning(['Sum throughput results cannot be plotted against SNR. They have been plotted against ' C{2} ' instead.']);
            myXLabel = C{2};
        end
        xValues = parameters.simulation.sweepValue;
        errorbar(xValues, results.sumThroughput{iBS}.mean / 1e6, results.sumThroughput{iBS}.confidence(1,:) / 1e6 , results.sumThroughput{iBS}.confidence(2,:) / 1e6, 'color', linecolors(BS{iBS}.ID,:) );
        itmpLegend = itmpLegend + 1;
        tmpLegend{itmpLegend} = BS{iBS}.Name; 
        hold on;
    end
end
if itmpLegend ~= 0
    shg
    h = get(gcf, 'CurrentAxes');
    if strcmp(myXLabel,'pathloss') ||  strcmp(myXLabel,'secondary.pathloss')
        set(h, 'XDir','reverse'); 
    end
    ylim([0 inf])
    xlabel(myXLabel);
    ylabel('Sum throughput in MBit/s');
    title([transmissionType, ' - Sum throughput']);
    legend( tmpLegend, 'location', 'southeast' );
    grid on;
end