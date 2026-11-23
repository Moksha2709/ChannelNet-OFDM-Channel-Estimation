classdef SimulationResults < handle
    % this class contains and processes the simulation results
    
    properties
        userResults     % per user simulation results
        sumThroughput   % per cell (base station) sum rate
        nFrames         % number of simulated frames
        nSweep          % number of sweep values
        nUE             % number of users per base station
        nBS             % number of base stations
        frameDuration   % time duration of a frame
        resType         % results type {downlink, uplink, D2D}
    end

    methods
        function obj = SimulationResults(nFrames, nSweep, nBS, nUE, time, resType)
            % simulationResults class constructor
            
            if nargin > 0
                obj.nFrames         = nFrames;
                obj.nSweep          = nSweep;
                obj.nUE             = nUE;
                obj.nBS             = nBS;
                obj.frameDuration   = time;
                
                % initialize results type
                switch resType
                    case {'Downlink', 'Uplink', 'D2D'}
                        obj.resType = resType;
                    otherwise
                        error('Results type unknown.');
                end
                
                % initialize user results
                obj.userResults = cell(1, nUE);
                for iUE = 1:nUE
                    obj.userResults{iUE} = Results.UserResults(nFrames, nSweep);
                end
                
                obj.sumThroughput = cell(1, obj.nBS);
                for iBS = 1:nBS
                     obj.sumThroughput{iBS}.values              = zeros(nFrames, nSweep);
                     obj.sumThroughput{iBS}.nParticipatingUEs   = 0;
                end
            end
            
        end
        
        function collectResults(obj, sweepResults, UE)
            % this method collects temporary results from parallel
            % procesing
            
            switch obj.resType
                case {'Downlink'}
                    for iSweep = 1:obj.nSweep
                        tmpResults = sweepResults{iSweep};
                        for iUE = 1:obj.nUE
                            if isempty(UE{iUE}.TransmitterDL) || isempty(tmpResults{UE{iUE}.TransmitterDL(1), UE{iUE}.ID, 1}) 
                               obj.userResults{iUE} = [];
                               continue; 
                            end
                            obj.userResults{iUE}.associatedBSID = UE{iUE}.TransmitterDL(1);
                            for iFrame = 1:obj.nFrames
                                obj.userResults{iUE}.SNR(iFrame, iSweep)                                = tmpResults{UE{iUE}.TransmitterDL(1), UE{iUE}.ID, iFrame}.SNR;
                                obj.userResults{iUE}.nSpatialStreamsUsed.values(iFrame, iSweep)         = tmpResults{UE{iUE}.TransmitterDL(1), UE{iUE}.ID, iFrame}.nStreams;
                                obj.userResults{iUE}.mcsUsed.valuesPerStream{iFrame, iSweep}            = tmpResults{UE{iUE}.TransmitterDL(1), UE{iUE}.ID, iFrame}.mcsUsed;
                                
                                % results per stream and for all streams in total
                                obj.userResults{iUE}.nDataBits.valuesPerStream{iFrame, iSweep}          = tmpResults{UE{iUE}.TransmitterDL(1), UE{iUE}.ID, iFrame}.nDataBits;
                                obj.userResults{iUE}.nDataBits.values(iFrame, iSweep)                   = sum( obj.userResults{iUE}.nDataBits.valuesPerStream{iFrame,iSweep});
                                obj.userResults{iUE}.nCodeBits.valuesPerStream{iFrame, iSweep}          = tmpResults{UE{iUE}.TransmitterDL(1), UE{iUE}.ID, iFrame}.nCodeBits;
                                obj.userResults{iUE}.nCodeBits.values(iFrame, iSweep)                   = sum( obj.userResults{iUE}.nCodeBits.valuesPerStream{iFrame,iSweep});

                                obj.userResults{iUE}.bitErrorsUncoded.valuesPerStream{iFrame, iSweep}   = tmpResults{UE{iUE}.TransmitterDL(1), UE{iUE}.ID, iFrame}.nBitError;
                                obj.userResults{iUE}.bitErrorsUncoded.values(iFrame, iSweep)            = sum(obj.userResults{iUE}.bitErrorsUncoded.valuesPerStream{iFrame,iSweep});
                                obj.userResults{iUE}.bitErrorsCoded.valuesPerStream{iFrame, iSweep}     = tmpResults{UE{iUE}.TransmitterDL(1), UE{iUE}.ID, iFrame}.nCodedBitError;
                                obj.userResults{iUE}.bitErrorsCoded.values(iFrame, iSweep)              = sum(obj.userResults{iUE}.bitErrorsCoded.valuesPerStream{iFrame, iSweep});
                                
                                obj.userResults{iUE}.frameErrors.valuesPerStream{iFrame, iSweep}        = tmpResults{UE{iUE}.TransmitterDL(1), UE{iUE}.ID, iFrame}.frameError;
                                obj.userResults{iUE}.frameErrors.values(iFrame, iSweep)                 = mean(obj.userResults{iUE}.frameErrors.valuesPerStream{iFrame, iSweep});
                                
                                obj.userResults{iUE}.channelMSE.values(iFrame, iSweep)                  = tmpResults{UE{iUE}.TransmitterDL(1), UE{iUE}.ID, iFrame}.channelMSE;
                                
                                obj.userResults{iUE}.PAPR.values(iFrame, iSweep)                        = tmpResults{UE{iUE}.TransmitterDL(1), UE{iUE}.ID, iFrame}.PAPR;
                            end %for iFrame
                        end %for iUE
                    end %for iSweep
                case {'Uplink'}
                    for iSweep = 1:obj.nSweep
                        tmpResults = sweepResults{iSweep};
                        for iUE = 1:obj.nUE
                            if isempty(UE{iUE}.ReceiverUL) || isempty(tmpResults{UE{iUE}.ID, UE{iUE}.ReceiverUL(1), 1}) 
                               obj.userResults{iUE} = [];
                               continue; 
                            end
                            obj.userResults{iUE}.associatedBSID = UE{iUE}.ReceiverUL(1);
                            for iFrame = 1:obj.nFrames
                                obj.userResults{iUE}.SNR(iFrame, iSweep)                                = tmpResults{UE{iUE}.ID, UE{iUE}.ReceiverUL(1), iFrame}.SNR;
                                obj.userResults{iUE}.nSpatialStreamsUsed.values(iFrame, iSweep)         = tmpResults{UE{iUE}.ID, UE{iUE}.ReceiverUL(1), iFrame}.nStreams;
                                obj.userResults{iUE}.mcsUsed.valuesPerStream{iFrame, iSweep}            = tmpResults{UE{iUE}.ID, UE{iUE}.ReceiverUL(1), iFrame}.mcsUsed;
                                
                                % results per stream and for all streams in total
                                obj.userResults{iUE}.nDataBits.valuesPerStream{iFrame, iSweep}          = tmpResults{UE{iUE}.ID, UE{iUE}.ReceiverUL(1), iFrame}.nDataBits;
                                obj.userResults{iUE}.nDataBits.values(iFrame, iSweep)                   = sum( obj.userResults{iUE}.nDataBits.valuesPerStream{iFrame, iSweep});
                                obj.userResults{iUE}.nCodeBits.valuesPerStream{iFrame, iSweep}          = tmpResults{UE{iUE}.ID, UE{iUE}.ReceiverUL(1), iFrame}.nCodeBits;
                                obj.userResults{iUE}.nCodeBits.values(iFrame, iSweep)                   = sum( obj.userResults{iUE}.nCodeBits.valuesPerStream{iFrame, iSweep});
                                
                                obj.userResults{iUE}.bitErrorsUncoded.valuesPerStream{iFrame, iSweep}   = tmpResults{UE{iUE}.ID, UE{iUE}.ReceiverUL(1), iFrame}.nBitError;
                                obj.userResults{iUE}.bitErrorsUncoded.values(iFrame, iSweep)            = sum( obj.userResults{iUE}.bitErrorsUncoded.valuesPerStream{iFrame, iSweep});
                                obj.userResults{iUE}.bitErrorsCoded.valuesPerStream{iFrame, iSweep}     = tmpResults{UE{iUE}.ID, UE{iUE}.ReceiverUL(1), iFrame}.nCodedBitError;
                                obj.userResults{iUE}.bitErrorsCoded.values(iFrame, iSweep)              = sum( obj.userResults{iUE}.bitErrorsCoded.valuesPerStream{iFrame, iSweep});

                                obj.userResults{iUE}.frameErrors.valuesPerStream{iFrame, iSweep}        = tmpResults{UE{iUE}.ID, UE{iUE}.ReceiverUL(1), iFrame}.frameError;
                                obj.userResults{iUE}.frameErrors.values(iFrame, iSweep)                 = mean( obj.userResults{iUE}.frameErrors.valuesPerStream{iFrame, iSweep});
                                
                                obj.userResults{iUE}.channelMSE.values(iFrame, iSweep)                  = tmpResults{UE{iUE}.ID, UE{iUE}.ReceiverUL(1), iFrame}.channelMSE;
                                
                                obj.userResults{iUE}.PAPR.values(iFrame, iSweep)                        = tmpResults{UE{iUE}.ID, UE{iUE}.ReceiverUL(1), iFrame}.PAPR;
                            end %for iFrame
                        end %for iUE
                    end %for iSweep
                otherwise
                    error('Results type unknown.');
            end %switch obj.resType 
        end %function collectResults
        
        function postProcessResults(obj, BS)
            % this function post processes the saved simulation results,
            % i.e., it calculates mean values and confidence intervals
            
            % function handles for bootci
            mean_func   = @(inputValue) mean(inputValue);
            
            % calculate confidence intervals
            for iUE = 1:obj.nUE
                if ~isempty(obj.userResults{iUE})
                    % coded Bit Error Ratio
                    obj.userResults{iUE}.BERCoded.values          = obj.userResults{iUE}.bitErrorsCoded.values ./ obj.userResults{iUE}.nDataBits.values;
                    obj.userResults{iUE}.BERCoded.mean            = mean(obj.userResults{iUE}.BERCoded.values, 'omitnan');
                    mask = ~isnan(obj.userResults{iUE}.BERCoded.values);
                    if mask
                        BERCodedMasked = reshape(obj.userResults{iUE}.BERCoded.values( mask ), [], obj.nSweep);
                        obj.userResults{iUE}.BERCoded.confidence  = Utils.Extras.bootci(BERCodedMasked, 0.95, 10^4, mean_func, false);
                        obj.userResults{iUE}.BERCoded.confidence  = repmat([-1;1], 1, obj.nSweep) .* (obj.userResults{iUE}.BERCoded.confidence - repmat(obj.userResults{iUE}.BERCoded.mean, 2, 1));
                    else
                        obj.userResults{iUE}.BERCoded.confidence  = NaN(2, obj.nSweep );
                    end

                    % uncoded Bit Error Ratio
                    obj.userResults{iUE}.BERUncoded.values          = obj.userResults{iUE}.bitErrorsUncoded.values ./ obj.userResults{iUE}.nCodeBits.values;
                    obj.userResults{iUE}.BERUncoded.mean            = mean(obj.userResults{iUE}.BERUncoded.values, 'omitnan');
                    mask = ~isnan(obj.userResults{iUE}.BERUncoded.values);
                    if mask
                        BERUncodedMasked = reshape(obj.userResults{iUE}.BERUncoded.values(mask), [], obj.nSweep);
                        obj.userResults{iUE}.BERUncoded.confidence  = Utils.Extras.bootci(BERUncodedMasked, 0.95, 10^4, mean_func, false);
                        obj.userResults{iUE}.BERUncoded.confidence  = repmat([-1;1], 1, obj.nSweep) .* (obj.userResults{iUE}.BERUncoded.confidence - repmat(obj.userResults{iUE}.BERUncoded.mean, 2, 1));
                    else
                        obj.userResults{iUE}.BERUncoded.confidence  = NaN(2, obj.nSweep);
                    end

                    % Frame Error Ratio
                    framesSent = double(~isnan(obj.userResults{iUE}.nDataBits.values));
                    obj.userResults{iUE}.FER.values = obj.userResults{iUE}.frameErrors.values ./ framesSent;
                    obj.userResults{iUE}.FER.mean = mean(obj.userResults{iUE}.FER.values);
                    mask = ~isnan(obj.userResults{iUE}.FER.values);
                    if mask
                        FERMasked  = reshape(obj.userResults{iUE}.FER.values(mask), [], obj.nSweep);
                        obj.userResults{iUE}.FER.confidence = Utils.Extras.bootci(FERMasked, 0.95, 10^4, mean_func, false);
                        obj.userResults{iUE}.FER.confidence = repmat([-1;1], 1, obj.nSweep) .* (obj.userResults{iUE}.FER.confidence - repmat(obj.userResults{iUE}.FER.mean, 2, 1));
                    else
                        obj.userResults{iUE}.FER.confidence = NaN(2, obj.nSweep);
                    end

                    % throughput
                    obj.userResults{iUE}.throughput.values = (obj.userResults{iUE}.nDataBits.values .* (1 - double(obj.userResults{iUE}.frameErrors.values))) / obj.frameDuration;
                    obj.userResults{iUE}.throughput.mean = mean(obj.userResults{iUE}.throughput.values);
                    mask = ~isnan(obj.userResults{iUE}.throughput.values);
                    if mask
                        throughputMasked  = reshape(obj.userResults{iUE}.throughput.values( mask ), [], obj.nSweep);
                        obj.userResults{iUE}.throughput.confidence = Utils.Extras.bootci(throughputMasked, 0.95, 10^4, mean_func, false);
                        obj.userResults{iUE}.throughput.confidence = repmat([-1;1], 1, obj.nSweep) .* (obj.userResults{iUE}.throughput.confidence - repmat(obj.userResults{iUE}.throughput.mean, 2, 1));
                    else
                        obj.userResults{iUE}.throughput.confidence = NaN(2, obj.nSweep );
                    end

                    % sum throughput
                    for iBS = 1:length(BS)
                        if BS{iBS}.ID == obj.userResults{iUE}.associatedBSID
                            obj.sumThroughput{iBS}.values            = obj.sumThroughput{iBS}.values + obj.userResults{iUE}.throughput.values;
                            obj.sumThroughput{iBS}.nParticipatingUEs = obj.sumThroughput{iBS}.nParticipatingUEs + 1;
                        end
                    end

                    % channel estimation error
                    obj.userResults{iUE}.channelMSE.mean = mean(obj.userResults{iUE}.channelMSE.values);
                    mask = ~isnan(obj.userResults{iUE}.channelMSE.values);
                    if mask
                        channelMSEMasked = reshape( obj.userResults{iUE}.channelMSE.values(mask), [], obj.nSweep);
                        obj.userResults{iUE}.channelMSE.confidence = Utils.Extras.bootci(channelMSEMasked, 0.95, 10^4, mean_func, false);
                        obj.userResults{iUE}.channelMSE.confidence = repmat([-1;1], 1, obj.nSweep) .* (obj.userResults{iUE}.channelMSE.confidence - repmat(obj.userResults{iUE}.channelMSE.mean, 2, 1));
                    else
                        obj.userResults{iUE}.channelMSE.confidence = NaN(2, obj.nSweep);
                    end

                    % PAPR CDF calculation
                    [a, b] = Utils.Extras.ecdf(obj.userResults{iUE}.PAPR.values(:));
                    obj.userResults{iUE}.PAPR.CDF        = a;
                    obj.userResults{iUE}.PAPR.DataPoints = b;
                end
            end %for iUE
            
            % calculate sum throughput confidence interval
            for iBS = 1:length(BS)
                obj.sumThroughput{iBS}.mean = mean(obj.sumThroughput{iBS}.values);
                mask = ~isnan(obj.sumThroughput{iBS}.values);
                if mask
                    sumThroughputMasked  = reshape(obj.sumThroughput{iBS}.values(mask), [], obj.nSweep);
                    obj.sumThroughput{iBS}.confidence = Utils.Extras.bootci(sumThroughputMasked, 0.95, 10^4, mean_func, false);
                    obj.sumThroughput{iBS}.confidence = repmat([-1;1], 1, obj.nSweep) .* (obj.sumThroughput{iBS}.confidence - repmat(obj.sumThroughput{iBS}.mean, 2, 1));
                else
                    obj.sumThroughput{iBS}.confidence = NaN(2, obj.nSweep);
                end
            end
        end %function postProcessResults
             
    end
    
end

