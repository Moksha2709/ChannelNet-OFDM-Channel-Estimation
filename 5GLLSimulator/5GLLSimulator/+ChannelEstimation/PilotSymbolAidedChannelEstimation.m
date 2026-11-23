classdef PilotSymbolAidedChannelEstimation < handle
    % Ronald Nissel, rnissel@nt.tuwien.ac.at
    % (c) 2016 by Institute of Telecommunications, TU Wien
    % www.tc.tuwien.ac.at
    
    
    properties (SetAccess = private)
        NrPilotSymbols
        NrPilotSymbolPositions
        PilotPattern
        PilotSpacingFrequency
        PilotSpacingTime
        InterpolationMethod
        orthogonalSequenceLength
        InterpolationProperties
        PilotMatrix
        OverlappingPilots
    end
    
    methods
        %% Class constructor, define default values.
        function obj = PilotSymbolAidedChannelEstimation(varargin)
            %% Initialize parameters, set default values
            obj.PilotPattern                = varargin{1};
            obj.orthogonalSequenceLength    = varargin{3};
            obj.InterpolationMethod         = varargin{4};
            nAntennaPorts                       = varargin{5};
            
            % Generate pilot matrix according to the specified pilot pattern.
            % A zero corresponse to a data symbol, a one to a pilot symbol
            switch obj.PilotPattern
                case 'Rectangular'
                    nSubcarriers = varargin{2}(1,1);
                    obj.PilotSpacingFrequency   = varargin{2}(1, 2);
                    nMCSymbols                  = varargin{2}(2, 1);
                    obj.PilotSpacingTime        = varargin{2}(2, 2);
                    
                    % check number of antennas
                    if nAntennaPorts > (floor(obj.PilotSpacingFrequency) * floor(obj.PilotSpacingTime))
                        error('Number of antennas must be smaller than frequency domain pilot spacing times time domain pilot spacing for chosen pilot pattern!');
                    end
                    
                    % generate unit cell
                    FrequOffset = floor(obj.PilotSpacingFrequency / 2) - 1;
                    TimeOffset = floor(obj.PilotSpacingTime / 2) - 1;
                    
                    [unitCellSizeFrequ, unitCellNumPilotFreq] = rat(obj.PilotSpacingFrequency, 1e-3);
                    [unitCellSizeTime, unitCellNumPilotTime] = rat(obj.PilotSpacingTime, 1e-3);
                    
                    FrequIndexTemp = floor(linspace(1, unitCellSizeFrequ, unitCellNumPilotFreq + 1));
                    unitCellFrequIndices = FrequIndexTemp(1:unitCellNumPilotFreq) + FrequOffset;
                    
                    TimeIndextemp = floor(linspace(1, unitCellSizeTime, unitCellNumPilotTime + 1));
                    unitCellTimeIndices = TimeIndextemp(1:unitCellNumPilotTime) + TimeOffset;
                    
                    unitCell = zeros(unitCellSizeFrequ, unitCellSizeTime);
                    unitCell(unitCellFrequIndices, unitCellTimeIndices) = 1;
                    
                    % generate pilot matrix
                    obj.PilotMatrix = zeros(nSubcarriers, nMCSymbols, nAntennaPorts);
                    for iAnt = 1:nAntennaPorts
                        unitCellShifted = circshift(unitCell, [mod(floor((iAnt - 1) / floor(obj.PilotSpacingTime)), floor(obj.PilotSpacingFrequency) ), mod((iAnt - 1), floor(obj.PilotSpacingTime))]);
                        unitCellRepeated = repmat(unitCellShifted, [ceil(nSubcarriers / unitCellSizeFrequ), ceil(nMCSymbols / unitCellSizeTime)]);
                        obj.PilotMatrix(:, :, iAnt) = unitCellRepeated(1:nSubcarriers, 1:nMCSymbols);
                    end
                                        
                    obj.OverlappingPilots = false;
                case 'Diamond'
                    nSubcarriers = varargin{2}(1,1);
                    obj.PilotSpacingFrequency   = varargin{2}(1, 2);
                    nMCSymbols                  = varargin{2}(2, 1);
                    obj.PilotSpacingTime        = varargin{2}(2, 2);
                    
                    % check number of antennas
                    if nAntennaPorts > (floor(obj.PilotSpacingFrequency) * floor(obj.PilotSpacingTime))
                        error('Number of antennas must be smaller than frequency domain pilot spacing times time domain pilot spacing for chosen pilot pattern!');
                    end
                    
                    % generate unit cell
                    FrequOffset = floor(obj.PilotSpacingFrequency / 2) - 1;
                    TimeOffset = floor(obj.PilotSpacingTime / 2) - 1;
                    
                    [unitCellSizeFrequ, unitCellNumPilotFreq] = rat(obj.PilotSpacingFrequency, 1e-3);
                    [unitCellSizeTime, unitCellNumPilotTime] = rat(obj.PilotSpacingTime, 1e-3);
                    
                    if unitCellNumPilotTime == 1
                        unitCellNumPilotTime = 2;
                        unitCellSizeTime = 2 * unitCellSizeTime;
                    end
                    
                    FrequIndexTemp = floor(linspace(1, unitCellSizeFrequ, unitCellNumPilotFreq + 1));
                    unitCellFrequIndices = FrequIndexTemp(1:unitCellNumPilotFreq) + FrequOffset;
                    
                    TimeIndextemp = floor(linspace(1, unitCellSizeTime, unitCellNumPilotTime + 1));
                    unitCellTimeIndices = TimeIndextemp(1:unitCellNumPilotTime) + TimeOffset;
                    
                    % equal out length
                    unitCellFrequIndices = repmat(unitCellFrequIndices, [1, floor(unitCellNumPilotTime / unitCellNumPilotFreq)]);
                    unitCellTimeIndices = repmat(unitCellTimeIndices, [1, floor(length(unitCellFrequIndices) / unitCellNumPilotTime)]);
                    
                    for iPilot = 1:length(unitCellFrequIndices)
                        if mod(iPilot, 2) == 0
                            unitCellFrequIndices(iPilot) = unitCellFrequIndices(iPilot) + floor(obj.PilotSpacingFrequency / 2);
                        end
                    end
                    
                    if length(unitCellTimeIndices) ~= length(unitCellFrequIndices)
                        error('Pilot indices must have a time and a frequency index!');
                    end
                    
                    unitCell = zeros(unitCellSizeFrequ, unitCellSizeTime);
                    for iPilot = 1:length(unitCellFrequIndices)
                        unitCell(unitCellFrequIndices(iPilot), unitCellTimeIndices(iPilot)) = 1;
                    end
                    
                    % generate pilot matrix
                    obj.PilotMatrix = zeros(nSubcarriers, nMCSymbols, nAntennaPorts);
                    for iAnt = 1:nAntennaPorts
                        unitCellShifted = circshift(unitCell, [mod(floor((iAnt - 1) / floor(obj.PilotSpacingTime)), floor(obj.PilotSpacingFrequency) ), mod((iAnt - 1), floor(obj.PilotSpacingTime))]);
                        unitCellRepeated = repmat(unitCellShifted, [ceil(nSubcarriers / unitCellSizeFrequ), ceil(nMCSymbols / unitCellSizeTime)]);
                        obj.PilotMatrix(:, :, iAnt) = unitCellRepeated(1:nSubcarriers, 1:nMCSymbols);
                    end
                                        
                    obj.OverlappingPilots = false;
                case 'LTE Downlink'
                    nSubcarriers  = varargin{2}(1, 1);
                    nMCSymbols    = varargin{2}(2, 1);
                    
                    if nAntennaPorts > 4
                        error('LTE Downlink pilot pattern is not defined for more than four antenna ports!');
                    end
                    
                    if nMCSymbols ~= 14 && nMCSymbols ~= 12
                        warning('Pilot pattern is LTE Downlink like, but not standard compliant for a number of %d symbols per slot!', nMCSymbols);
                    end
                    
                    obj.PilotMatrix   = zeros(nSubcarriers, nMCSymbols, nAntennaPorts);
                    pilotMatrixRb     = zeros(12, nMCSymbols, nAntennaPorts);
                    
                    % construct pilot pattern for antenna ports 1 and 2
                    unitCell                            = zeros(6, nMCSymbols / 2);
                    unitCell(6, 1)                      = 1;
                    unitCell(3, nMCSymbols / 2 - 2)     = 1;
                    resourceBlock12                     = repmat(unitCell, 2, 2);
                    
                    pilotMatrixRb(:, :, 1)              = resourceBlock12;                           % antenna port 1
                    pilotMatrixRb(3:end, 1:end - 2, 2)  = flipud(resourceBlock12(3:end, 1:end - 2)); % antenna port 2
                    
                    % construct pilot pattern for antenna ports 3 and 4
                    resourceBlock3                          = zeros(12, nMCSymbols);
                    resourceBlock3(6, 2)                    = 1;
                    resourceBlock3(3, nMCSymbols / 2 + 2)   = 1;
                    resourceBlock3(12, 2)                   = 1;
                    resourceBlock3(9, nMCSymbols / 2 + 2)   = 1;
                    
                    pilotMatrixRb(:, :, 3)                  = resourceBlock3;                           % antenna port 3
                    pilotMatrixRb(3:end, 1:end - 2, 4)      = flipud(resourceBlock3(3:end, 1:end -2 )); % antenna port 4
                    
                    % select antenna ports and repeat for each resource block
                    obj.PilotMatrix = repmat(pilotMatrixRb(:, :, 1:nAntennaPorts), nSubcarriers / 12, 1, 1);
                    obj.OverlappingPilots = false;
                case 'LTE Uplink'
                    nSubcarriers  = varargin{2}(1,1);
                    nMCSymbols    = varargin{2}(2,1);
                    
                    if nMCSymbols ~= 14 && nMCSymbols ~= 12
                        warning('Pilot pattern is LTE Uplink like, but not standard compliant for a number of %d symbols per slot!', nMCSymbols);
                    end
                    
                    index_vector = zeros(1, nMCSymbols);
                    index_vector(1, ceil(nMCSymbols / 4)) = 1;
                    index_vector(1, ceil(nMCSymbols / 4) + nMCSymbols / 2) = 1;
                    
                    obj.PilotMatrix   = repmat(index_vector, [nSubcarriers, 1, nAntennaPorts]);
                    obj.OverlappingPilots = true; % pilot symbols are allocated on the same time-frequency resources for all antennas (SU-MIMO) and users (MU-MIMO)
                case 'Custom'
                    obj.PilotSpacingFrequency   = nan;
                    obj.PilotSpacingTime        = nan;
                    obj.PilotMatrix             = varargin{2};
                    obj.OverlappingPilots       = true;
                otherwise
                    error('Pilot pattern is not supported!');
            end
            obj.NrPilotSymbols = squeeze(sum(sum(obj.PilotMatrix, 1), 2));
            obj.NrPilotSymbolPositions = sum(sum(sum(obj.PilotMatrix, 3) > 0, 1), 2);
        end
        
        function InterpolatedChannel = ChannelInterpolation(obj, LSChannelEstimatesAtPilotPosition, BlockLengthFrequency, BlockLengthTime, iAntennaPort)
            % interpolation method
            switch obj.InterpolationMethod
                case {'linear', 'nearest', 'natural'}
                    [x_pilot_pos, y_pilot_pos] = find(obj.PilotMatrix(:, :, iAntennaPort));
                    obj.InterpolationProperties = scatteredInterpolant(x_pilot_pos, y_pilot_pos, zeros(obj.NrPilotSymbols(iAntennaPort), 1), obj.InterpolationMethod);
                case 'linear-time'
                    x_pilot_pos = find(obj.PilotMatrix(1, :, iAntennaPort));
                case 'MovingBlockAverage'
                    PilotIndices = find(obj.PilotMatrix(:, :, iAntennaPort));
                    PilotMatrixPosNumbered = zeros(size(obj.PilotMatrix(:, :, iAntennaPort)));
                    PilotMatrixPosNumbered(PilotIndices) = 1:numel(PilotIndices);
                    
                    maxF = size(obj.PilotMatrix, 1);
                    maxT = size(obj.PilotMatrix, 2);
                    
                    IndexF = -BlockLengthFrequency:BlockLengthFrequency;
                    IndexT = -BlockLengthTime:BlockLengthTime;
                    
                    obj.InterpolationProperties.InterpolationMatrix = zeros(numel(obj.PilotMatrix), obj.NrPilotSymbols(iAntennaPort));
                    for i_pos = 1:numel(obj.PilotMatrix(:, :, iAntennaPort))
                        Impulse = zeros(size(obj.PilotMatrix(:, :, iAntennaPort)));
                        Impulse(i_pos) = 1;
                        [posF, posT] = find(Impulse);
                        
                        IndexPosT                       = posT + IndexT;
                        IndexPosT(IndexPosT < 1)        = [];
                        IndexPosT(IndexPosT > maxT)     = [];
                        IndexPosF                       = posF + IndexF;
                        IndexPosF(IndexPosF < 1)        = [];
                        IndexPosF(IndexPosF > maxF)     = [];
                        Impulse(IndexPosF, IndexPosT)   = 1;
                        
                        InterpolationMatrixPosPilots = PilotMatrixPosNumbered(logical(Impulse) & logical(obj.PilotMatrix(:, :, iAntennaPort)));
                        
                        obj.InterpolationProperties.InterpolationMatrix(i_pos, InterpolationMatrixPosPilots) = 1 / numel(InterpolationMatrixPosPilots);
                    end
                otherwise
                    error('Channel interpolation method not supported!');
            end
            
            switch obj.InterpolationMethod
                case {'linear', 'nearest', 'natural'}
                    obj.InterpolationProperties.Values = LSChannelEstimatesAtPilotPosition;
                    [yq, xq] = meshgrid(1:size(obj.PilotMatrix, 2), 1:size(obj.PilotMatrix,1));
                    InterpolatedChannel = obj.InterpolationProperties(xq, yq);
                case 'linear-time'
                    xq = 1:size(obj.PilotMatrix, 2);
                    InterpolatedChannel = interp1(x_pilot_pos, reshape(LSChannelEstimatesAtPilotPosition, size(obj.PilotMatrix, 1), []).', xq, 'linear', 'extrap').';
                case 'FullAverage'
                    InterpolatedChannel = ones(size(obj.PilotMatrix)) * mean(LSChannelEstimatesAtPilotPosition);
                case 'MovingBlockAverage'
                    InterpolatedChannel = obj.InterpolationProperties.InterpolationMatrix * LSChannelEstimatesAtPilotPosition;
                otherwise
                    error('Interpolation method not implemented');
            end
        end
        
        
        
        function AuxiliaryMatrix = GetAuxiliaryMatrix(varargin)
            obj = varargin{1};
            NrAxuiliarySymbols = varargin{2};
            
            AuxiliaryMatrix = obj.PilotMatrix;
            [index_l,index_k]=find(obj.PilotMatrix);
            if (min(index_l)<2) || (max(index_l)>=size(obj.PilotMatrix,1))
                warning('Pilots should not be close to the border! There might be a problem!');
            elseif (min(index_k)<2) || (max(index_k)>=size(obj.PilotMatrix,2))
                warning('Pilots should not be close to the border! There might be a problem!');
            end
            
            for i_lk = 1:size(index_l,1)
                switch NrAxuiliarySymbols
                    case 1
                        AuxiliaryMatrix(index_l(i_lk),index_k(i_lk)+1) = -1;
                    case 2
                        AuxiliaryMatrix(index_l(i_lk),index_k(i_lk)+1) = -1;
                        AuxiliaryMatrix(index_l(i_lk),index_k(i_lk)-1) = -1;
                    case 3
                        AuxiliaryMatrix(index_l(i_lk),index_k(i_lk)+1) = -1;
                        AuxiliaryMatrix(index_l(i_lk),index_k(i_lk)-1) = -1;
                        AuxiliaryMatrix(index_l(i_lk)+1,index_k(i_lk)) = -1;
                    case 4
                        AuxiliaryMatrix(index_l(i_lk),index_k(i_lk)+1) = -1;
                        AuxiliaryMatrix(index_l(i_lk),index_k(i_lk)-1) = -1;
                        AuxiliaryMatrix(index_l(i_lk)+1,index_k(i_lk)) = -1;
                        AuxiliaryMatrix(index_l(i_lk)-1,index_k(i_lk)) = -1;
                    otherwise
                        error('Only 1,2,3,4 auxiliary symbols per pilot are supported');
                end
            end
        end
        
        function InterpolationMatrix = GetInterpolationMatrix(varargin)
            obj = varargin{1};
            
            [x_pilot_pos,y_pilot_pos] = find(obj.PilotMatrix);
            InterpolationMatrix = zeros(numel(obj.PilotMatrix),numel(x_pilot_pos));
            for i_pos =1:length(x_pilot_pos)
                TestDirac = zeros(size(x_pilot_pos));
                TestDirac(i_pos)=1;
                ImpulseResponse = obj.ChannelInterpolation(TestDirac);
                
                InterpolationMatrix(:,i_pos)=ImpulseResponse(:);
            end
            
        end
        
        function PlotPilotPattern(varargin)
            if numel(varargin)==2
                PilotMatrixTemp = varargin{2};
            else
                PilotMatrixTemp = varargin{1}.PilotMatrix;
            end
            
            PilotMatrixRGB(:,:,1) = PilotMatrixTemp==0;
            PilotMatrixRGB(:,:,2) = not(PilotMatrixTemp==1);
            PilotMatrixRGB(:,:,3) = not(PilotMatrixTemp==-1);
            
            imagesc(PilotMatrixRGB);
            hold on;
            for i_row = 1:size(PilotMatrixRGB,1)+1
                plot([.5,size(PilotMatrixRGB,2)+0.5],[i_row-.5,i_row-.5],'k-');
            end
            for i_column = 1:size(PilotMatrixRGB,2)+1
                plot([i_column-.5,i_column-.5],[.5,size(PilotMatrixRGB,1)+0.5],'k-');
            end
            xlabel('Time index');
            ylabel('Frequency index');
            title('Pilot pattern');
        end
        
    end
    
    
end