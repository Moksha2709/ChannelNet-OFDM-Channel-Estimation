classdef SC_PAM < handle
    % =====================================================================        
    % This MATLAB class represents an implementation of a single carrier (SC) pulse amplitude modulation (PAM). The 
    % modulation parameters are initialized by the class constructor. 
    % The modulation of data symbols x and the demodulation of the
    % received samples r are then performed by the methods ".Modulation(x)"
    % and ".Demodulation(r)". 
     
    properties (SetAccess = private)
        Nr                  % for dimensionless parameters
        PHY                 % for parameters with physical interpretation
        Implementation      % implmentation relevent parameters
    end
    
    methods
        function obj = SC_PAM(varargin)
            % Initialize parameters, set default values
            if numel(varargin) == 8
                obj.Nr.MCSymbols                = varargin{1};      % Number symbols in time
                obj.PHY.SymbolRate              = varargin{2};      % symbols per second
                obj.PHY.SamplingRate            = varargin{3};      % Sampling rate (Samples/s)
                obj.PHY.FilterType              = varargin{4};      % pulse shape filter type
                obj.PHY.FilterLength            = varargin{5};      % length of pulse shape filter impulse response
                obj.PHY.FilterRollOff           = varargin{6};      % pulse shape filter roll off factor
                obj.PHY.IntermediateFrequency   = varargin{7};      % Intermediate frequency of the first subcarrier (Hz)
                obj.PHY.ZeroGuardTimeLength     = varargin{8};      % Length of the guard time (s), that is, zeros at the beginning and at the end of the transmission
            else
                error('Number of input variables must be 8');
            end
            
            obj.Nr.Subcarriers = 1;
            
            % calculate and set all dependent parameters
            obj.SetDependentParameters();
            
            % generate filter functions
            samples = linspace(- obj.PHY.FilterLength / 2 * obj.Implementation.SamplesPerSymbol , obj.PHY.FilterLength / 2 * obj.Implementation.SamplesPerSymbol, obj.PHY.FilterLength * obj.Implementation.SamplesPerSymbol + 1);
            switch obj.PHY.FilterType
                case 'rectangular'
                    % the rectangular pulse shaping is implemented via repetitions of samples, therefore there is no filter function implemented here
                    if obj.PHY.FilterLength > 0
                        error('Single Carrier modulation: The excess filter length for a rectangular pulse shape must be zero!');
                    end
                case 'RC'
                    obj.Implementation.PulseShapeFilter = zeros(length(samples), 1);
                    for i_sample = 1:length(samples)
                        if abs(abs(samples(i_sample)) - obj.Implementation.SamplesPerSymbol / (2 * obj.PHY.FilterRollOff)) < 1000 * eps
                            obj.Implementation.PulseShapeFilter(i_sample) = pi / 4 * +Utils.Extras.sinc(1 / (2 * obj.PHY.FilterRollOff));
                        else
                            obj.Implementation.PulseShapeFilter(i_sample) = +Utils.Extras.sinc(samples(i_sample) / obj.Implementation.SamplesPerSymbol) * cos(pi * obj.PHY.FilterRollOff * samples(i_sample) / obj.Implementation.SamplesPerSymbol) / (1 - 4 * obj.PHY.FilterRollOff^2 * (samples(i_sample) / obj.Implementation.SamplesPerSymbol)^2);
                        end
                    end
                case 'RRC'
                    obj.Implementation.PulseShapeFilter = zeros(length(samples), 1);
                    for i_sample = 1:length(samples)
                        if abs(samples(i_sample)) < 1000 * eps
                            obj.Implementation.PulseShapeFilter(i_sample) = 1 + obj.PHY.FilterRollOff * (4 / pi - 1);
                        elseif abs(abs(samples(i_sample)) - obj.Implementation.SamplesPerSymbol / (4 * obj.PHY.FilterRollOff)) < 1000 * eps
                            obj.Implementation.PulseShapeFilter(i_sample) = obj.PHY.FilterRollOff / sqrt(2) * ((1 + 2 / pi) * sin(pi / (4 * obj.PHY.FilterRollOff)) + (1 - 2 / pi) * cos(pi / (4 * obj.PHY.FilterRollOff)));
                        else
                            obj.Implementation.PulseShapeFilter(i_sample) = (sin(pi * samples(i_sample) / obj.Implementation.SamplesPerSymbol * (1 - obj.PHY.FilterRollOff)) + 4 * obj.PHY.FilterRollOff * samples(i_sample) / obj.Implementation.SamplesPerSymbol * cos(pi * samples(i_sample) / obj.Implementation.SamplesPerSymbol * (1 + obj.PHY.FilterRollOff))) ...
                                / (pi * samples(i_sample) / obj.Implementation.SamplesPerSymbol * (1 - (4 * obj.PHY.FilterRollOff * samples(i_sample) / obj.Implementation.SamplesPerSymbol).^2));
                        end
                    end
                otherwise
                    error('Single carrier modulation: pulse shape filter type unknown!');
            end
            
        end
        
        function SetDependentParameters(obj)
            % method that sets all parameters which are dependent on other parameters
            
            if mod(obj.PHY.SamplingRate, obj.PHY.SymbolRate) > 0
                error('Number of SC symbols does not fit the sampling rate! One symbol must have an integer number of samples.');
            end
            
            if strcmp(obj.PHY.FilterType, 'rectangular') && obj.PHY.FilterLength > 0
                warning('Single carrier modulation: Excess filter length of rectangular pulse shape is set to zero!');
                obj.PHY.FilterLength = 0;
            end
            
            obj.Implementation.ZeroGuardSamples         = round(obj.PHY.ZeroGuardTimeLength * obj.PHY.SamplingRate);                                            % number of samples for the zero guard
            obj.Implementation.SamplesPerSymbol         = round(obj.PHY.SamplingRate / obj.PHY.SymbolRate);                                                     % number of samples per symbol
            obj.Implementation.IntermediateFrequency    = obj.PHY.IntermediateFrequency;
            obj.Implementation.FilterLength         = obj.PHY.FilterLength * obj.Implementation.SamplesPerSymbol + 1;
            obj.PHY.dt                                  = 1 / obj.PHY.SamplingRate;                                                                             % inter sample time
            obj.PHY.TimeSpacing                         = obj.Implementation.SamplesPerSymbol * obj.PHY.dt;                                                     % symbol duration
            obj.Nr.SamplesTotal                         = (obj.Nr.MCSymbols * obj.Implementation.SamplesPerSymbol ) + 2 * obj.Implementation.ZeroGuardSamples + obj.Implementation.FilterLength - 1;  % total number of samples for all symbols including zero guards
        end
        
        % Set Functions
%         function SetNrSubcarriers(varargin) 
%             % set the number of subcarriers
%             
%             obj = varargin{1};
%             % set specific property
%             obj.Nr.Subcarriers = varargin{2};
%             % recalculate dependent parameters
%             obj.SetDependentParameters;
%         end
        
        % Get methods
        function FFTsizeReturn = GetFFTsize(obj)
            FFTsizeReturn = obj.Implementation.SamplesPerSymbol;
        end
          
        % Modulation and Demodulation
        function TransmitSignal = Modulation(obj, DataSymbols)
            % modulate the data symbols. The input argument is a matrix
            % of size "Number of subcarriers" \times "Number of OFDM symbols (time)"
            % which represents the transmit data symbols

            switch obj.PHY.FilterType
                case 'rectangular'
                    % rectangular pulse shape filter
                    TransmitSignalTmp = repmat(DataSymbols(:).', obj.Implementation.SamplesPerSymbol, 1);
                    TransmitSignal = TransmitSignalTmp(:);
                case {'RC', 'RRC'}
                    % stretch symbols to symbol time (dirac comb) and convolve with pulse shape filter impulse response
                    DataSymbolsDiracComb = reshape([DataSymbols; zeros(obj.Implementation.SamplesPerSymbol - 1, size(DataSymbols, 2))], 1, []);
                    TransmitSignal = conv(DataSymbolsDiracComb, obj.Implementation.PulseShapeFilter);
                otherwise
                    error('SC modulation pulse shape filter type unknown!');
            end
        end
        
        function ReceivedSymbols = Demodulation(obj, ReceivedSignal)
            % demodulates the received time signal and returns a matrix of 
            % size "Number of subcarriers" \times "Number of OFDM symbols"
            % which represents the received symbols after demodulation but
            % before channel equalization
            
            switch obj.PHY.FilterType
                case 'rectangular'
                    ReceivedSymbols = mean(reshape(ReceivedSignal, obj.Implementation.SamplesPerSymbol, []), 1);
                case {'RC', 'RRC'}
                    ReceivedSymbolsTmp = conv(ReceivedSignal, obj.Implementation.PulseShapeFilter);
                    ReceivedSymbols = ReceivedSymbolsTmp(obj.Implementation.FilterLength:obj.Implementation.SamplesPerSymbol:end - obj.Implementation.FilterLength + 1) / obj.Implementation.SamplesPerSymbol;
                otherwise
                    error('SC modulation pulse shape filter type unknown!');
            end
            
        end
        
        function Pn = GetSymbolNoisePower(obj, Pn_time)
            % returns the symbol noise power, that is, the noise power
            % after demodulation. The input argument is the noise power 
            % in the time domain. 
            
            Pn = Pn_time.* obj.PHY.SymbolRate / obj.PHY.SamplingRate;
        end
        
        function TimePos = GetTimeIndexMidPos(obj)
            % returns a vector which represents the discete time position
            % of the corresponding FBMC symbol (middle position)
            
            TimePos = obj.Implementation.ZeroGuardSamples + round(obj.Implementation.SamplesPerSymbol / 2) + 1 + (0:obj.Nr.MCSymbols - 1) * obj.Implementation.SamplesPerSymbol;
        end  
         
    end
end