classdef SimulationParameters < handle
    % this class contains all simulation parameters, including user defined
    % parameters and constants
    
    properties
        simulation      % general simulation parameters
        topology       % network topology, describing which nodes are connected to each other
        schedule        % the time constant user allocation
        modulation    % modulation related parameters
        phy             % physical parameters
        coding          % channel coding parameters
        channel         % parameters related to the channel model
        constants       % physical constants
        feedback        % feedback related parameters
        layerMapping
        considerSecondaryLink % when there is IN node and secondary link, set it as 1, otherwise 0 
    end
    
    methods
        function obj = SimulationParameters( scenario )
            % simulation parameters class constructor
            
            % load parameters from a scenario file
            obj.loadScenario( scenario );
            
            % pre-defined parameters that should not be changed
            obj.setConstantParameters;
            
            % check parameters
            obj.checkParameters();
            
            % calculate all dependent parameters
            obj.dependentParameters();
            
        end %function SimulationParameters
        
        function dependentParameters(obj)
            % this method calculates all parameters that are dependent on
            % other parameters
            
            % calculate thermal noise power (k*T*B)
            obj.phy.noisePower = obj.constants.BOLTZMANN * obj.phy.temperature * obj.modulation.samplingRate;
            
            % set number of symbols for data transmission to total number
            % of symbols minus number of symbols used as time guard (CP)
            obj.modulation.MCSymbols = obj.modulation.nSymbolsTotal - obj.modulation.nGuardSymbols;
            
            % calculate the total number of samples, assuming there is at least one base station
            tmpMod                              =    Modulation.Modulator(  'QAM', obj.modulation.mcsValues(1).modulationOrder, 'OFDM',...
                {'none'},...                                    % data symbol spreading type
                false,...                                       % noise power estimation
                1,...                                           % max number of codewords
                obj.coding.LLRsCalculationMethod, ...           % the method for calculating the LLRs
                1,...                                           % Number subcarriers
                obj.modulation.MCSymbols(1),...                 % Number OFDM Symbols
                obj.modulation.subcarrierSpacing(1),...         % Subcarrier spacing (Hz)
                obj.modulation.samplingRate,...                 % Sampling rate (Samples/s)
                0,...                                           % Intermediate frequency first subcarrier (Hz)
                false,...                                       % Transmit real valued signal
                obj.modulation.nGuardSymbols(1)/...             % Cyclic prefix length (s)
                (obj.modulation.subcarrierSpacing(1)*...
                obj.modulation.MCSymbols(1)), ...
                0 ...                                           % Zero guard length (s)
                );
            
            %             obj.modulation.totalNumberOfSamples = tmpMod.WaveformObject.Nr.SamplesTotal;
            
            % get spatial correlation parameter according to TS36.101, Annex B
            switch obj.channel.spatialCorrelation
                case {'none','low'}
                    obj.channel.spatialCorrBS = 0;
                    obj.channel.spatialCorrUE = 0;
                case 'medium'
                    obj.channel.spatialCorrBS = 0.3;
                    obj.channel.spatialCorrUE = 0.9;
                case 'high'
                    obj.channel.spatialCorrBS = 0.9;
                    obj.channel.spatialCorrUE = 0.9;
                otherwise
                    error('Level of spatial correlation not supported!');
            end
            
            
        end
        
        function checkParameters(obj)
            % this method check whether the choice of parameters is
            % consistent and allowed
            
            % check nodes
            if ischar(obj.topology.nodes)
                tempStr = strsplit(obj.topology.nodes, ',');
                
                if length(tempStr) == 1
                    error('Topology nodes input invalid!');
                else
                    nUE = 0;
                    nBS = 0;
                    nRIS = 0;
                    for iNode = 1:length(tempStr)
                        switch tempStr{iNode}(1:2)
                            case {'UE'}
                                index = str2double(tempStr{iNode}((3:end)));
                                if isnan(index) || index <= 0
                                    error('The topology nodes are entered incorrectly. Please make sure no extra characters or spaces are present.')
                                else
                                    nUE = nUE + 1;
                                end
                            case {'BS'}
                                index = str2double(tempStr{iNode}((3:end)));
                                if isnan(index) || index <= 0
                                    error('The topology nodes are entered incorrectly. Please make sure no extra characters or spaces are present.')
                                else
                                    nBS = nBS + 1;
                                end
                            case {'RI'}
                                if strcmp(tempStr{iNode}(1:3),'RIS')
                                    index = str2double(tempStr{iNode}((4:end)));
                                    if isnan(index) || index <= 0
                                        error('The topology nodes are entered incorrectly. Please make sure no extra characters or spaces are present.')
                                    else
                                        nRIS = nRIS + 1;
                                    end
                                else
                                    error('Topology nodes input invalid!');
                                end
                            otherwise
                                error('Topology nodes input invalid!');
                        end
                    end
                end
                
            else
                error('Topology nodes input invalid format!');
            end
            obj.topology.nNodes = nUE + nBS + nRIS;
            
            % Get number of links
            obj.topology.nLinks = length(strsplit(obj.topology.primaryLinks, ','));

            if isfield(obj.topology,'secondaryLinks') && ~isempty(obj.topology.secondaryLinks)
                obj.topology.nSecondaryLinks = length(strsplit(obj.topology.secondaryLinks, ','));
            else
                obj.topology.nSecondaryLinks = 0;
            end

            if ~isfield(obj.topology,'interferingLinks')
                if strcmp(obj.topology.interferenceGeneration,'Manual')
                    error('The parameters interferingLinks is missing.');
                else
                    obj.topology.interferingLinks = '';
                end

            end
             if  ~isempty(obj.topology.interferingLinks)
                obj.topology.nInterferingLinks = length(strsplit(obj.topology.interferingLinks, ','));
            else
                obj.topology.nInterferingLinks = 0;
            end
            % Get number of secondary links and set considerSecondaryLink
            obj.considerSecondaryLink  = 0;
            if nRIS > 0
                obj.considerSecondaryLink  = 1;
            end
            % Check if sweep parameter is correct
            % unpack struct from property
            variableName = strsplit(obj.simulation.sweepParam{1},'.');
            
            if isprop(obj, variableName{1})
                % extract struct if it exists
                tmpStruct = obj.(variableName{1});
            else
                error('sweep parameter is not a valid parameter');
            end %if isprop
            
            if isempty(tmpStruct.(variableName{2}))
                % error when variable does not exist
                error('sweep parameter is not a valid parameter');
            end
            
            % Identifiy whether the sweep parameter is per Node, per BS,
            % per UE, or per Link.
            switch variableName{end}
                case {'txPowerBaseStation', 'nAntennasBaseStation'}
                    sweepParamType = 'per BS';
                case {'txPowerUser', 'nAntennasUser', 'userVelocity'}
                    sweepParamType = 'per UE';
                case {'mcs', 'decodingIterations', 'softBufferRatio', 'amplifierOBO', 'smoothnessFactor', 'angleMeanAOA', 'angleMeanZOA', 'kFactor'}
                    sweepParamType = 'per Link';
                case {'centerFrequency', 'K', 'delta'}
                    sweepParamType = 'global';
                case {'attenuation'}
                    if strcmp(obj.topology.interferenceGeneration,'Automatic')
                        sweepParamType = 'global';
                        warning('For the automatic interfering link generation mode the attenuation is a global parameter')
                    else
                        sweepParamType = 'per I-Link';
                    end
                case {'pathloss'}
                    if length(variableName) == 2
                        sweepParamType = 'per Link';
                    else
                        if strcmp(obj.topology.secondaryGeneration,'Automatic')
                            sweepParamType = 'global';
                            warning('For the automatic secondary link generation mode the path loss is a global parameter')
                        else
                            sweepParamType = 'per S-Link';
                        end
                    end
                otherwise
                    error('The selected sweep parameter is not supported.');
            end
            
            % Per BS parameters
            if length(obj.simulation.txPowerBaseStation) == 1; obj.simulation.txPowerBaseStation = repmat(obj.simulation.txPowerBaseStation, 1, nBS); end
            if length(obj.simulation.nAntennasBaseStation) == 1; obj.simulation.nAntennasBaseStation = repmat(obj.simulation.nAntennasBaseStation, 1, nBS); end
            if length(obj.schedule.multiuserMode.Downlink) == 1; obj.schedule.multiuserMode.Downlink = repmat(obj.schedule.multiuserMode.Downlink, 1, nBS); end
            if length(obj.schedule.multiuserMode.Uplink) == 1; obj.schedule.multiuserMode.Uplink = repmat(obj.schedule.multiuserMode.Uplink, 1, nBS); end

            if ~isfield(obj.schedule.multiuserMode,'UplinkIC')
                if obj.simulation.simulateUplink && any(ismember(obj.schedule.multiuserMode.Uplink,{'ZF-MUMIMO','MRC-MUMIMO','MMSE-MUMIMO'}))
                    error('The parameter schedule.multiuserMode.UplinkIC is missing.');
                else
                    obj.schedule.multiuserMode.UplinkIC = 1;
                end
            end
            if length(obj.schedule.multiuserMode.UplinkIC) == 1; obj.schedule.multiuserMode.UplinkIC = repmat(obj.schedule.multiuserMode.UplinkIC, 1, nBS); end
            
            % modulation
            if length(obj.modulation.waveform) == 1; obj.modulation.waveform = repmat(obj.modulation.waveform, 1, nBS); end
            if length(obj.modulation.numberOfSubcarriers) == 1; obj.modulation.numberOfSubcarriers = repmat(obj.modulation.numberOfSubcarriers, 1, nBS); end
            if length(obj.modulation.subcarrierSpacing) == 1; obj.modulation.subcarrierSpacing = repmat(obj.modulation.subcarrierSpacing, 1, nBS); end
            if length(obj.modulation.nSymbolsTotal) == 1; obj.modulation.nSymbolsTotal = repmat(obj.modulation.nSymbolsTotal, 1, nBS); end
            if length(obj.modulation.nGuardSymbols) == 1; obj.modulation.nGuardSymbols = repmat(obj.modulation.nGuardSymbols, 1, nBS); end

            if obj.simulation.simulateDownlink && ~isfield(obj.modulation,'MUSTIdx')
                if any(strcmp(obj.schedule.multiuserMode.Downlink,'MUST'))
                    error('The parameter smodulation.MUSTIdx is missing.');
                else
                    obj.modulation.MUSTIdx = 1;
                end
            end
            if length(obj.modulation.MUSTIdx) == 1; obj.modulation.MUSTIdx = repmat(obj.modulation.MUSTIdx, 1, nBS); end

            
            % Per UE parameters
            if length(obj.simulation.txPowerUser) == 1; obj.simulation.txPowerUser = repmat(obj.simulation.txPowerUser, 1, nUE); end
            if length(obj.simulation.nAntennasUser) == 1; obj.simulation.nAntennasUser = repmat(obj.simulation.nAntennasUser, 1, nUE); end
            if length(obj.simulation.userVelocity) == 1; obj.simulation.userVelocity = repmat(obj.simulation.userVelocity, 1, nUE); end
            
            % Per RIS
            if nRIS > 0
                if length(obj.simulation.nElementsRIS) == 1; obj.simulation.nElementsRIS = repmat(obj.simulation.nElementsRIS, 1, nRIS); end
                if length(obj.simulation.reflectCoefficientRIS) == 1; obj.simulation.reflectCoefficientRIS = repmat(obj.simulation.reflectCoefficientRIS, 1, nRIS); end
            end
            
            
            % Per Primary Link parameters
            if length(obj.simulation.pathloss) == 1; obj.simulation.pathloss = repmat(obj.simulation.pathloss, 1, obj.topology.nLinks); end

            if ~isfield(obj.modulation,'nStreams')
                if  ((obj.simulation.simulateUplink && ~any(strcmp(obj.schedule.multiuserMode.Uplink,'none'))) || (obj.simulation.simulateDownlink && ~any(strcmp(obj.schedule.multiuserMode.Downlink, 'none'))))
                    obj.modulation.nStreams = 1;
                elseif (obj.feedback.enable && (obj.feedback.pmi || obj.feedback.ri))
                    obj.modulation.nStreams = 1;
                else
                    error('The parameter modulation.nStreams is missing.');
                end
            end
            if length(obj.modulation.nStreams) == 1; obj.modulation.nStreams = repmat(obj.modulation.nStreams, 1, obj.topology.nLinks); end

            if ~isfield(obj.modulation,'precodingMatrix')
                if  ((obj.simulation.simulateUplink && ~any(strcmp(obj.schedule.multiuserMode.Uplink,'none'))) || (obj.simulation.simulateDownlink && ~any(strcmp(obj.schedule.multiuserMode.Downlink, 'none')))) 
                    obj.modulation.precodingMatrix{1} = 1;
                elseif (obj.feedback.enable && obj.feedback.pmi) || ismember(obj.modulation.transmissionMode,{'OLSM','CLSM'})
                    obj.modulation.precodingMatrix{1} = 1;
                    if ~isfield(obj.simulation,'codebook')
                        error('The parameter simulation.codebook is missing.');
                    end
                else
                    error('The parameter modulation.precodingMatrix is missing.');
                end
            end
            if length(obj.modulation.precodingMatrix) == 1; obj.modulation.precodingMatrix(2:obj.topology.nLinks) = obj.modulation.precodingMatrix(1); end
            if length(obj.modulation.mcs) == 1; obj.modulation.mcs = repmat(obj.modulation.mcs, 1, obj.topology.nLinks); end

            if ~isfield(obj.simulation,'amplifierOBO')
                if obj.simulation.nonlinearity
                    error('The parameter simulation.amplifierOBO is missing');
                else
                    obj.simulation.amplifierOBO = 1;
                end

            end

            if ~isfield(obj.simulation,'smoothnessFactor')
                if obj.simulation.nonlinearity
                    error('The parameter simulation.smoothnessFactor is missing');
                else
                    obj.simulation.smoothnessFactor = 1;
                end

            end

            if length(obj.simulation.amplifierOBO) == 1; obj.simulation.amplifierOBO = repmat(obj.simulation.amplifierOBO, 1, obj.topology.nLinks); end
            if length(obj.simulation.smoothnessFactor) == 1; obj.simulation.smoothnessFactor = repmat(obj.simulation.smoothnessFactor, 1, obj.topology.nLinks); end

            
            % Per Node Parameter
            if strcmp(obj.modulation.precodingScheme,'hybrid')
                if length(obj.simulation.nAntennaPortsBaseStation) ==1; obj.simulation.nAntennaPortsBaseStation = repmat(obj.simulation.nAntennaPortsBaseStation, 1, nBS); end
                if length(obj.simulation.nAntennaPortsUser) == 1; obj.simulation.nAntennaPortsUser = repmat(obj.simulation.nAntennaPortsUser, 1, nUE); end
                if length(obj.modulation.analogPrecoder) == 1; obj.modulation.analogPrecoder(2:obj.topology.nNodes) = obj.modulation.analogPrecoder(1); end
                if length(obj.modulation.analogReceiveFilter) == 1; obj.modulation.analogReceiveFilter(2:obj.topology.nNodes) = obj.modulation.analogReceiveFilter(1); end
            else
                % if hybrid precoding is not chosen, the analog precoder and receive filter are set to 1
                warning('For fully digital precoding the number of port is set equal to the number of antennas');
                obj.simulation.nAntennaPortsUser = obj.simulation.nAntennasUser;
                obj.modulation.analogPrecoder = [];
                obj.modulation.analogPrecoder{1} = 1;
                obj.modulation.analogPrecoder(2:obj.topology.nNodes) = obj.modulation.analogPrecoder(1);
                obj.modulation.analogReceiveFilter = [];
                obj.modulation.analogReceiveFilter{1} = 1;
                obj.modulation.analogReceiveFilter(2:obj.topology.nNodes) = obj.modulation.analogReceiveFilter(1);
            end
            
            % Geometric Layout parameters
            if ~isfield(obj.topology,'geometricLayout')
                obj.topology.geometricLayout = false;
            end
            
            if obj.topology.geometricLayout
                if ~isfield(obj.topology,'nodesPosition') || length(obj.topology.nodesPosition)~= obj.topology.nNodes
                    error('Each node has to be assigned a position');
                else
                    if ~isfield(obj.simulation.pathLossModel,'Type')
                        error('The field Type in the path loss model is missing');
                    elseif ~ismember(obj.simulation.pathLossModel.Type,{'freeSpace','breakPoint','rural','urban','subUrbanMacro','urbanMacroLOS'})
                        error('The path loss model defined in the field Type is not implemented. Set Type to either freeSpace, breakPoint, rural, urban or subUrbanMacro');
                    end
                    if ~isfield(obj.simulation.pathLossModel,'alpha')
                        error('The path loss exponent pathLossModel.alpha is missing');
                    end
                    if strcmp(obj.simulation.pathLossModel.Type,'breakPoint')
                        if ~isfield(obj.simulation.pathLossModel,'breakDistance')
                            error('The breaking distance  pathLossModel.breakDistance is missing');
                        end
                        if ~isfield(obj.simulation.pathLossModel,'alpha2')
                            error('The second path loss exponent pathLossModel.alpha2 is missing');
                        end
                    end
                    if strcmp(obj.simulation.pathLossModel.Type,'urban')
                        if ~isfield(obj.simulation.pathLossModel,'averageBuildingHeight')
                            error('The averageBuildingHeight pathLossModel.averageBuildingHeight is missing');
                        end
                    end
                end
            end
            % Spatial Channel Model parameters
            if obj.channel.spatialChannelModel
                if length(obj.channel.angleMeanAOA)      == 1; obj.channel.angleMeanAOA = repmat(obj.channel.angleMeanAOA, 1, obj.topology.nLinks); end
                if length(obj.channel.angleMeanZOA)      == 1; obj.channel.angleMeanZOA = repmat(obj.channel.angleMeanZOA, 1, obj.topology.nLinks); end
                if length(obj.channel.kFactor)           == 1; obj.channel.kFactor = repmat(obj.channel.kFactor, 1, obj.topology.nLinks); end
                if length(obj.channel.antennaSpacing)    == 1; obj.channel.antennaSpacing = repmat(obj.channel.antennaSpacing, 1, obj.topology.nNodes); end
                if ~isfield(obj.channel,'nodesOrientation'); obj.channel.nodesOrientation = {[0,0,0]}; end
                if length(obj.channel.nodesOrientation) == 1; obj.channel.nodesOrientation(2:obj.topology.nNodes) = obj.channel.nodesOrientation(1); end
                obj.channel.nPaths = 0;
                obj.channel.K = 0;
                obj.channel.delta = 0;              
            end
            
            if obj.topology.geometricLayout &&  ismember(variableName{end},{'pathloss','attenuation'})
                error('Sweep over path loss or attenuation is not possible when the parameter topology.geometricLayout is set to true.'); 
            end

            % coding
            if length(obj.coding.code) == 1; obj.coding.code = repmat(obj.coding.code, 1, obj.topology.nLinks); end
            if length(obj.coding.decoding) == 1; obj.coding.decoding = repmat(obj.coding.decoding, 1, obj.topology.nLinks); end
            if length(obj.coding.decodingIterations) == 1; obj.coding.decodingIterations = repmat(obj.coding.decodingIterations, 1, obj.topology.nLinks); end
            if length(obj.coding.softBufferRatio) == 1; obj.coding.softBufferRatio = repmat(obj.coding.softBufferRatio, 1, obj.topology.nLinks); end
            % />
            
            % check simulation parameters

            if ~obj.topology.geometricLayout  && length(obj.simulation.pathloss) ~= obj.topology.nLinks
                error('There must be a path loss defined for each primary user!');
            end
            if length(obj.simulation.txPowerUser) ~= nUE
                error('There must be a tx power defined for each user!');
            end
            if length(obj.simulation.txPowerBaseStation) ~= nBS
                error('There must be a tx power defined for each base station!');
            end
            if length(obj.schedule.multiuserMode.Downlink) ~= nBS
                error('There must be a downlink multi-user MIMO mode defined for each base station!');
            end
            if length(obj.schedule.multiuserMode.Uplink) ~= nBS
                error('There must be a uplink multi-user MIMO mode defined for each base station!');
            end

            if length(obj.schedule.multiuserMode.UplinkIC) ~= nBS
                error('Interference cancellation must be defined for each base station!');
            end
            
            if length(obj.simulation.nAntennasUser) ~= nUE
                error('There must be a number of antennas defined for each user!');
            end
            
            if length(obj.simulation.nAntennaPortsUser) ~= nUE
                error('There must be a number of antenna ports defined for each user!');
            end
            
            if length(obj.simulation.nAntennasBaseStation) ~= nBS
                error('There must be a number of antennas defined for base station!');
            else
                for iBS = 1:nBS
                    if length(obj.simulation.nAntennasBaseStation{iBS}) == 1
                        obj.simulation.nAntennaPortsBaseStation(iBS) = obj.simulation.nAntennasBaseStation{iBS};
                        obj.simulation.nAntennasBaseStation{iBS} = [obj.simulation.nAntennasBaseStation{iBS}, 1];          
                    else
                        obj.simulation.nAntennaPortsBaseStation(iBS) = obj.simulation.nAntennasBaseStation{iBS}(1)*obj.simulation.nAntennasBaseStation{iBS}(2);
                    end
                end
            end
            
            if length(obj.simulation.nAntennaPortsBaseStation) ~= nBS
                error('There must be a number of antenna ports defined for base station!');
            end
            
            if nRIS > 0
                % check if enough parameters were entered, i.e., number of
                % paramerters equals number of RIS
                if length(obj.simulation.nElementsRIS) ~= nRIS
                    error('There must be a number of elements defined for each RIS!');
                else
                    for iRIS = 1:nRIS
                        if length(obj.simulation.nElementsRIS{iRIS}) == 1
                            obj.simulation.nElementsRIS{iRIS} = [obj.simulation.nElementsRIS{iRIS}, 1];
                        end

                    end
                end
                
            end
            if ~islogical(obj.simulation.nonlinearity)
                error('Invalid nonlinearity selection parameter! Input must be a logical true/false!')
            end
            
            if ~(strcmp(obj.simulation.frameStructure, 'FDD') || strcmp(obj.simulation.frameStructure, 'TDD'))
                error('Only duplexing modes FDD or TDD are supported!')
            end
            
            if any(obj.simulation.userVelocity == 0) && obj.channel.correlatedFrames
                warning('Correlated frames works only when the user velocity is greater than zero! Automatically setting the parameter "correlatedFrames" to false!');
            end
            
            % check TDD operation settings
            if strcmp(obj.simulation.frameStructure, 'TDD') && ~obj.channel.correlatedFrames
                warning('TDD operation with a uncorrelated time-domain channel will lead to bad performance!');
            end
            
            if strcmp(obj.simulation.frameStructure, 'TDD') && any(obj.simulation.userVelocity == 0)
                warning('TDD operation with a user velocity of zero leads to random performance results!');
            end
            
            % check modulation parameters
            if length(obj.modulation.waveform) ~= nBS
                error('There must be a waveform defined for each base station!');
            end
            
            if length(obj.modulation.subcarrierSpacing) ~= nBS
                error('There must be a subcarrier spacing defined for each base station!');
            end
            
            if length(obj.modulation.numberOfSubcarriers) ~= nBS
                error('There must be a number of subcarriers defined for each base station!');
            end
            
            if length(obj.modulation.nSymbolsTotal) ~= nBS
                error('There must be a total number of symbols defined for each base station!');
            end
            
            if length(obj.modulation.nGuardSymbols) ~= nBS
                error('There must be a number of guard symbols defined for each base station!');
            end
            
            if length(obj.modulation.MUSTIdx) ~= nBS
                error('There must be a MUSTIdx defined for each base station!');
            end
            
            if length(obj.simulation.userVelocity) ~= nUE
                error('There must be user velocity defined for each user!');
            end
            
            if ~strcmp(obj.modulation.spreadingTransformDownlink, 'none') && ~strcmp(obj.simulation.pilotPatternDownlink, 'LTE Uplink')
                error('Symbol spreading is only available with the LTE Uplink pilot pattern!');
            end
            
            if ~strcmp(obj.modulation.spreadingTransformUplink, 'none') && ~strcmp(obj.simulation.pilotPatternUplink, 'LTE Uplink')
                error('Symbol spreading is only available with the LTE Uplink pilot pattern!');
            end
            
            % checks for single carrier modulation
            SC_cells = strcmp(obj.modulation.waveform, 'SC');
            if any(SC_cells)
                % there must be no guard symbols with single carrier modulation
                if obj.modulation.nGuardSymbols(SC_cells) ~= 0
                    error('There must be zero guard symbols for SC modulation!');
                end
                
                % there must be one subcarrier for single carrier modulation
                if obj.modulation.numberOfSubcarriers(SC_cells) ~= 1
                    error('There must be only one subcarrier for SC modulation!');
                end
            end
            
            % check channel coding parameters
            if length(obj.coding.code) ~= obj.topology.nLinks
                error('There must be a code defined for each link!');
            end
            
            if length(obj.coding.decoding) ~= obj.topology.nLinks
                error('There must be a decoding algorithm  defined for each link!');
            end
            
            if length(obj.coding.decodingIterations) ~= obj.topology.nLinks
                error('There must be a decoding iterations defined for each link!');
            end
            
            if length(obj.coding.softBufferRatio) ~= obj.topology.nLinks
                error('There must be a soft buffer ratio defined for each link!');
            end
            
            % check MUMIMO mode
            if length(obj.schedule.multiuserMode.Downlink) ~= nBS
                error('There must be a downlink multiuser transmission mode defined for each base station!');
            end
            
            if length(obj.schedule.multiuserMode.Uplink) ~= nBS
                error('There must be a uplink multiuser transmission mode defined for each base station!');
            end
            
            
            if (obj.simulation.simulateUplink && any(ismember(obj.schedule.multiuserMode.Uplink,{'ZF-MUMIMO','MRC-MUMIMO','MMSE-MUMIMO'}))) || (obj.simulation.simulateDownlink && any(ismember(obj.schedule.multiuserMode.Downlink, {'ZF-MUMIMO','MRT-MUMIMO'})))
                if any(obj.simulation.nAntennasUser~=1)
                    error('The implemented multi-user MIMO scheme only support users with one antenna.');
                end
                if ~isfield(obj.modulation,'transmissionMode')
                    obj.modulation.transmissionMode = custom;
                end
                
                if ~strcmp(obj.modulation.transmissionMode,'custom')
                    error('The implemented multi-user MIMO scheme only support the custom transmission mode');
                else
                    if obj.feedback.enable && (obj.feedback.pmi || obj.feedback.ri)
                        obj.feedback.pmi = 0;
                        obj.feedback.ri = 0;
                        warning('The chosen multi-user MIMO scheme only support CQI feedback. PMI and RI feedback have been deactivated');
                    end
                end
            end
            if obj.simulation.simulateDownlink && any(strcmp(obj.schedule.multiuserMode.Downlink,'BD-MUMIMO'))
                if any(obj.simulation.nAntennasUser == 1)
                    error('BD-MUMIMO is implemented for users with more than one antenna.');
                end
                if ~strcmp(obj.modulation.transmissionMode,'custom')
                    error('The implemented multi-user MIMO scheme only support the custom transmission mode');
                else
                    if obj.feedback.enable && (obj.feedback.pmi || obj.feedback.ri)
                        obj.feedback.pmi = 0;
                        obj.feedback.ri = 0;
                        warning('The chosen multi-user MIMO scheme only support CQI feedback. PMI and RI feedback have been deactivated');
                    end
                end
            end
            if ~isfield(obj.simulation,'pilotSequenceLength')
                if (obj.simulation.simulateDownlink && strcmp(obj.simulation.pilotPatternDownlink,'LTE Uplink')) || (obj.simulation.simulateUplink && strcmp(obj.simulation.pilotPatternUpink,'LTE Uplink'))
                    error('The parameter simulation.pilotSequenceLength is missing.')
                else
                    obj.simulation.pilotSequenceLength  = nUE;
                end
            end
            if ~strcmp(obj.simulation.channelEstimationMethod, 'Approximate-Perfect') && obj.simulation.simulateUplink && (obj.simulation.pilotSequenceLength < nUE)
                error('Orthogonal pilot symbol sequence length must be at least number of users in multi-user MIMO uplink with channel estimation!');
            end
            
            % set the feedback according to the transmission mode
            switch obj.modulation.transmissionMode
                case 'CLSM'
                    if ~obj.feedback.enable
                        warning('For the CLSM mode, feedback is activated.');
                        obj.feedback.enable                    = true;
                    end
                    if ~obj.feedback.pmi
                        warning('For the CLSM mode, the PMI and RI feedback are activated');
                        obj.feedback.pmi                       = true;
                        obj.feedback.ri                        = false;
                    end
                    if ~obj.feedback.cqi
                        warning('For the CLSM mode, the CQI feedback is activated');
                        obj.feedback.cqi                       = true;
                    end
                    if obj.feedback.delay>0 && ~obj.channel.correlatedFrames
                        warning('For a temporal uncorrelated channel and a delay larger than 0 activating the feedback does not yield any improvements');
                    end
                    
                case 'OLSM'
                    if ~obj.feedback.enable
                        warning('For the OLSM mode feedback is activated.');
                        obj.feedback.enable                    = true;
                    end
                    if obj.feedback.pmi
                        warning('For the OLSM mode the PMI is deactivated');
                        obj.feedback.pmi                       = false;
                    end
                    if ~obj.feedback.ri
                        warning('For the OLSM mode the RI is activated');
                        obj.feedback.ri                       = true;
                    end
                    if ~obj.feedback.cqi
                        warning('For the OLSM mode the CQI is activated');
                        obj.feedback.cqi                       = true;
                    end
                    if obj.feedback.delay>0 && ~obj.channel.correlatedFrames
                        warning('For a temporal uncorrelated channel and a delay larger than 0 activating the feedback does not yield any improvements');
                    end
                    
                case 'TxD'
                    if obj.simulation.simulateUplink && any(~ismember(prod(cell2mat(obj.simulation.nAntennasBaseStation.').'), [1,2]))
                        error('The TxD mode for the uplink is implemented for one and two receive antennas. At least one of the base stations has more than 2 antennas.');
                    end
                    if obj.simulation.simulateDownlink && any(~ismember(obj.simulation.nAntennasUser, [1,2]))
                        error('The TxD mode for the downlink is implemented for one and two receive antennas. At least one of the users has more than 2 antennas.');
                    end
                    if obj.feedback.enable || obj.feedback.pmi || obj.feedback.ri || obj.feedback.cqi
                        warning('For the TxD the feedback is deactivated');
                        obj.feedback.enable                    = false;
                        obj.feedback.pmi                       = false;
                        obj.feedback.ri                        = false;
                        obj.feedback.cqi                       = false;
                    end
                    % only one stream for TxD
                    if (sum(obj.modulation.nStreams>1)>0)
                        warning('For TxD the number of streams was set to 1');
                        obj.modulation.nStreams                = ones(size(obj.modulation.nStreams));
                    end 
                    if (sum(prod(cell2mat(obj.simulation.nAntennasBaseStation.').')==1)>0)
                        warning('TxD with one transmit antenna does not add any diversity');
                    end
                otherwise
                    if obj.feedback.enable && obj.feedback.ri && ~obj.feedback.pmi
                        warning('The currently implemented feedback calculates the RI and PMI jointly. Therefore, the PMI feedback was also activated.');
                        obj.feedback.pmi = true;
                    end
                    if obj.feedback.enable && obj.feedback.pmi && ~obj.feedback.ri
                        warning('The currently implemented feedback calculates the RI and PMI jointly. Therefore, the RI feedback was also activated.');
                        obj.feedback.ri = true;
                    end
                    if obj.feedback.enable && obj.feedback.delay>0 && ~obj.channel.correlatedFrames
                        warning('For a temporal uncorrelated channel and a delay larger than 0 activating the feedback does not yield any improvements');
                    end
                    % feedback setting are set as defined in the scenario file
            end
            % check analog precoder/receive filter
            if obj.topology.nNodes ~= length(obj.modulation.analogPrecoder)
                error('You have defined %d Nodes but in scStr.modulation.analogPrecoder %d analog precoding matrices were defined. An analog precoder must be assigned to each Node.',obj.topology.nLinks ,size(obj.modulation.analogPrecoder,2));
            end
            if obj.topology.nNodes ~= length(obj.modulation.analogReceiveFilter)
                error('You have defined %d Nodes but in scStr.modulation.analogReceiveFilter %d analog receive filter were defined. An analog receive filter must be assigned to each Node.',obj.topology.nLinks ,size(obj.modulation.analogReceiveFilter,2));
            end
            % Check precoding matrix, number of streams and mcs
            if  (~obj.feedback.enable || ~obj.feedback.pmi) && ~ obj.feedback.ri &&  ~strcmp(obj.modulation.transmissionMode,'TxD')
                if obj.topology.nLinks ~= length(obj.modulation.nStreams)
                    error('You have defined %d links but scStr.modulation.nStreams contains %d values. A value must be assigned to each primary link.',obj.topology.nLinks ,size(obj.modulation.nStreams,2));
                end
                if obj.topology.nLinks ~= length(obj.modulation.precodingMatrix)  && (any(strcmp(obj.schedule.multiuserMode.Downlink, 'none')) || any(strcmp(obj.schedule.multiuserMode.Uplink, 'none')))
                    error('You have defined %d links but in scStr.modulation.precodingMatrix %d precoding matrices were defined. A precoding matrix must be assigned to each primary link.',obj.topology.nLinks ,size(obj.modulation.precodingMatrix,2));
                end
            else
                precodingMatrix = cell(obj.topology.nLinks,1);
                precodingMatrix(:) = {obj.modulation.precodingMatrix{1}};
                obj.modulation.precodingMatrix = precodingMatrix;
                obj.modulation.nStreams = repmat(obj.modulation.nStreams(1), 1, obj.topology.nLinks);
            end
            
            if  (~obj.feedback.enable || ~obj.feedback.ri) &&  ~strcmp(obj.modulation.transmissionMode,'TxD')
                if obj.topology.nLinks ~= length(obj.modulation.nStreams)
                    error('You have defined %d links but scStr.modulation.nStreams contains %d values. A value must be assigned to each primary link.',obj.topology.nLinks ,size(obj.modulation.nStreams,2));
                end
                if obj.topology.nLinks ~= length(obj.modulation.precodingMatrix) && (any(strcmp(obj.schedule.multiuserMode.Downlink, 'none')) || any(strcmp(obj.schedule.multiuserMode.Uplink, 'none')))
                    error('You have defined %d links but in scStr.modulation.precodingMatrix %d precoding matrices were defined. A precoding matrix must be assigned to each primary link.',obj.topology.nLinks ,size(obj.modulation.precodingMatrix,2));
                end
            else
                precodingMatrix = cell(obj.topology.nLinks,1);
                precodingMatrix(:) = {obj.modulation.precodingMatrix{1}};
                obj.modulation.precodingMatrix = precodingMatrix;
                obj.modulation.nStreams = repmat(obj.modulation.nStreams(1), 1, obj.topology.nLinks);
            end
            if ~obj.feedback.enable || ~obj.feedback.cqi
                if obj.topology.nLinks ~= length(obj.modulation.mcs)
                    error('You have defined %d links but scStr.modulation.mcs contains only %d values. A value must be assigned to each primary link.',obj.topology.nLinks ,size(obj.modulation.mcs,2));
                end
                if any( obj.modulation.mcs <1) || any( obj.modulation.mcs > 15)
                    error('CQI not supported');
                end
            else
                if obj.topology.nLinks ~= length(obj.modulation.mcs)
                    obj.modulation.mcs = ones(1,obj.topology.nLinks);
                end
            end
            
            if (strcmp(obj.simulation.receiverTypeMIMO, 'ML')) && obj.feedback.enable && obj.feedback.cqi
                % The ML detector is only implemented for the case of equal MCS on all codewords
                % therefore, if the MCS are set for each codeword individually, they may only be used if only a single codeword is possible
                if (obj.feedback.ri && any(min([obj.simulation.nAntennasUser, prod(cell2mat(obj.simulation.nAntennasBaseStation.').')]) > 1)) || (~obj.feedback.ri && (max(obj.modulation.nStreams) > 1))
                    % if there is CQI feedback, and possibly more than one codeword at any link, they may not be used
                    error('Maximum likelihood detection supports only a single layer transmission in the case of CQI feedback!');
                end
            end
            
            % check plotResultsFor
            if length(obj.simulation.plotResultsFor) ~=1 && length(obj.simulation.plotResultsFor) ~= obj.topology.nNodes
                error('The parameter ''plotResultsFor'' has to either have a single entry (i.e., applied globally), or has number of entries equal to the total number of nodes in the topology.');
            end
            for iP = 1:length(obj.simulation.plotResultsFor)
                if obj.simulation.plotResultsFor(iP) ~= 1 && obj.simulation.plotResultsFor(iP) ~= 0
                    error('The entries of the parameter ''plotResultsFor'' can only take values of 0 or 1.');
                end
            end
            
            % check applySweepingTo
            switch sweepParamType
                case 'per Node'
                    if length(obj.simulation.applySweepingTo) ~= 1 && length(obj.simulation.applySweepingTo) ~= obj.topology.nNodes
                        error('The parameter ''applySweepingTo'' has to either have a single entry (i.e., applied globally), or has number of entries equal to the total number of nodes in the topology.');
                    end
                case 'per BS'
                    if length(obj.simulation.applySweepingTo) ~= 1 && length(obj.simulation.applySweepingTo) ~= nBS
                        error('The parameter ''applySweepingTo'' has to either have a single entry (i.e., applied globally), or has number of entries equal to the total number of BSs in the topology.');
                    end
                case 'per UE'
                    if length(obj.simulation.applySweepingTo) ~= 1 && length(obj.simulation.applySweepingTo) ~= nUE
                        error('The parameter ''applySweepingTo'' has to either have a single entry (i.e., applied globally), or has number of entries equal to the total number of UEs in the topology.');
                    end
                case 'per Link'
                    if length(obj.simulation.applySweepingTo) ~= 1 && length(obj.simulation.applySweepingTo) ~= obj.topology.nLinks 
                        error('The parameter ''applySweepingTo'' has to either have a single entry (i.e., applied globally), or has number of entries equal to the total number of Links in the topology.');
                    end
                case 'per I-Link'
                    if length(obj.simulation.applySweepingTo) ~= 1 && length(obj.simulation.applySweepingTo) ~= obj.topology.nInterferingLinks 
                        error('The parameter ''applySweepingTo'' has to either have a single entry (i.e., applied globally), or has number of entries equal to the total number of interfering Links in the topology.');
                    end
                case 'per S-Link'
                    if length(obj.simulation.applySweepingTo) ~= 1 && length(obj.simulation.applySweepingTo) ~= obj.topology.nSecondaryLinks 
                        error('The parameter ''applySweepingTo'' has to either have a single entry (i.e., applied globally), or has number of entries equal to the total number of secondary Links in the topology.');
                    end
                case 'global'
                    if length(obj.simulation.applySweepingTo) ~= 1
                        warning('The selected sweep parameter is a global parameter; parameter ''applySweepingTo'' is set to [1].')
                        obj.simulation.applySweepingTo = [1];
                    end
            end
            for iP = 1:length(obj.simulation.applySweepingTo)
                if obj.simulation.applySweepingTo(iP) ~= 1 && obj.simulation.applySweepingTo(iP) ~= 0
                    error('The entries of the parameter ''applySweepingTo'' can only take values of 0 or 1.');
                end
            end
            
            % Downlink schedule check
            if obj.simulation.simulateDownlink
                if ~isfield(obj.schedule, 'fixedScheduleDL')
                    error('Downlink simulation is enabled, but no downlink schedule is defined!');
                end
                
                if length(obj.schedule.fixedScheduleDL) ~= nBS
                    error('There must be a schedule specified for each base station!');
                else
                    for iBS = 1:nBS
                        if ~ismember(obj.schedule.multiuserMode.Downlink{iBS}, {'MUST', 'ZF-MUMIMO', 'BD-MUMIMO', 'MRT-MUMIMO', 'none'})
                            error('The downlink multiuser mode for base station %d is unknown', iBS);
                        elseif ismember(obj.schedule.multiuserMode.Downlink{iBS}, {'ZF-MUMIMO', 'BD-MUMIMO', 'MRT-MUMIMO'})
                            warning('For all multi-user MIMO modes the downlink schedule in the scenario files is ignored. All users assigned to the basestation are scheduled on all available subcarriers.');
                        end
                        if ~isempty(obj.schedule.fixedScheduleDL{iBS})
                            tempStr = strsplit(obj.schedule.fixedScheduleDL{iBS}, ',');
                            nSubcarriersTemp = 0;
                            for iNode = 1:length(tempStr)
                                tmpNodeStr = strsplit(tempStr{iNode}, ':');
                                if length(tmpNodeStr) == 2
                                    if strcmp(tmpNodeStr{1}(1:2), 'UE')
                                        if isempty(strfind(tmpNodeStr{2}, 'UE'))
                                            if str2double(tmpNodeStr{2}) > 0
                                                if mod(str2double(tmpNodeStr{2}), 12) > 0 && strcmp(obj.simulation.pilotPatternDownlink, 'LTE Downlink')
                                                    error('When the LTE Downlink pilot pattern is selected, the number of scheduled subcarriers must be a mutiple of 12!');
                                                end
                                                nSubcarriersTemp = nSubcarriersTemp + str2double(tmpNodeStr{2});
                                            elseif  str2double(tmpNodeStr{2}) ==0
                                                error('Schedule error! Base station %d has a user with 0 resources assigned!',iBS);
                                            else
                                                error('Schedule of base station %d is invalid!',iBS);
                                            end
                                        else
                                            if strcmp(obj.schedule.multiuserMode.Downlink{iBS}, 'none')
                                                error(['For users with overlapping downlink schedule, the downlink multiuserMode cannot be set to ' char(39) 'none' char(39) '.']);
                                            end
                                        end
                                    elseif strcmp(tmpNodeStr{1}(1:4), 'none')
                                        if str2double(tmpNodeStr{2}) >= 0
                                            nSubcarriersTemp = nSubcarriersTemp + str2double(tmpNodeStr{2});
                                        else
                                            error('Schedule of base station %d is invalid!',iBS);
                                        end
                                    else
                                        error('Schedule of base station %d is invalid!',iBS);
                                    end
                                else
                                    error('Schedule of base station %d is invalid!',iBS);
                                end
                            end
                            if nSubcarriersTemp ~= obj.modulation.numberOfSubcarriers(iBS)
                                error('Scheduled number of subcarriers in base station %d must add to the total number of %d subcarriers.', iBS, obj.modulation.numberOfSubcarriers(iBS));
                            end
                        end
                    end
                end
            end
            
            % Uplink schedule check
            if obj.simulation.simulateUplink
                if ~isfield(obj.schedule, 'fixedScheduleUL')
                    error('Uplink simulation is enabled, but no uplink schedule is defined!');
                end
                
                if length(obj.schedule.fixedScheduleUL) ~= nBS
                    error('There must be a schedule specified for each base station!');
                else
                    for iBS = 1:nBS
                        if ~ismember(obj.schedule.multiuserMode.Uplink{iBS}, {'ZF-MUMIMO', 'MMSE-MUMIMO', 'MRC-MUMIMO', 'none'})
                            error('The uplink multiuser mode for base station %d is unknown', iBS);
                        elseif ismember(obj.schedule.multiuserMode.Uplink{iBS}, {'ZF-MUMIMO', 'MMSE-MUMIMO', 'MRC-MUMIMO'})
                            warning('For all multi-user MIMO modes the uplink schedule in the scenario files is ignored. All users assigned to the basestation are scheduled to transmit on all available subcarriers.');
                        end
                        if ~isempty(obj.schedule.fixedScheduleUL{iBS})
                            tempStr = strsplit(obj.schedule.fixedScheduleUL{iBS}, ',');
                            nSubcarriersTemp = 0;
                            for iNode = 1:length(tempStr)
                                tmpNodeStr = strsplit(tempStr{iNode}, ':');
                                if length(tmpNodeStr) == 2
                                    if strcmp(tmpNodeStr{1}(1:2), 'UE')
                                        if isempty(strfind(tmpNodeStr{2}, 'UE'))
                                            if str2double(tmpNodeStr{2}) > 0
                                                if mod(str2double(tmpNodeStr{2}), 12)>0 && strcmp(obj.simulation.pilotPatternUplink, 'LTE Downlink')
                                                    error('When the LTE Downlink pilot pattern is selected, the number of scheduled subcarriers must be a mutiple of 12!');
                                                end
                                                nSubcarriersTemp = nSubcarriersTemp + str2double(tmpNodeStr{2});
                                            else
                                                error('Schedule of base station %d is invalid!',iBS);
                                            end
                                        else
                                            if strcmp(obj.schedule.multiuserMode.Uplink{iBS}, 'none')
                                                error(['For users with overlapping uplink schedule, the uplink multiuserMode cannot be set to ' char(39) 'none' char(39) '.']);
                                            end
                                        end
                                    elseif strcmp(tmpNodeStr{1}(1:4), 'none')
                                        if str2double(tmpNodeStr{2}) >= 0
                                            nSubcarriersTemp = nSubcarriersTemp + str2double(tmpNodeStr{2});
                                        else
                                            error('Schedule of base station %d is invalid!',iBS);
                                        end
                                    else
                                        error('Schedule of base station %d is invalid!',iBS);
                                    end
                                else
                                    error('Schedule of base station %d is invalid!',iBS);
                                end
                            end
                            if nSubcarriersTemp ~= obj.modulation.numberOfSubcarriers(iBS)
                                error('Scheduled number of subcarriers in base station %d must add to the total number of %d subcarriers.', iBS, obj.modulation.numberOfSubcarriers(iBS));
                            end
                        end
                    end
                end
            end
            
            % check if schedule is compatible with frameStructure
            if strcmp(obj.simulation.frameStructure, 'TDD')
                if ~obj.simulation.simulateDownlink || ~obj.simulation.simulateUplink
                    error('For selected FrameStructure TDD simulateDownlink and simulateUplink have to be activated!');
                end
                if any(ismember(obj.schedule.multiuserMode.Downlink,{'ZF-MUMIMO', 'MRT-MUMIMO', 'BD-MUMIMO'})) && any(~ismember(obj.schedule.multiuserMode.Uplink,{'ZF-MUMIMO', 'MRC-MUMIMO', 'MMSE-MUMIMO'}))
                    error('For selected FrameStructure TDD the uplink and the downlink have to be in a multi-user MIMO mode.');
                end
                
                %                 for iBS = 1:nBS
                %                     if ~strcmp(obj.schedule.fixedScheduleUL{iBS}, obj.schedule.fixedScheduleDL{iBS})
                %                         error('In TDD Mode UL and DL Schedule have to be the same!');
                %                     end
                %                 end
            end
            
            % check relation of modulation parameters between cells
            % for FBMC the number of real valued symbols is twice as high compared to a non FBMC cell with complex valued symbols
            fbmc_index = zeros(nBS,1);
            for iBS = 1:nBS
                fbmc_index(iBS,1) = double(strcmp(obj.modulation.waveform(iBS),'FBMC'))+1;
            end
            
            for iBS = 2:nBS
                tmpFactor = obj.modulation.subcarrierSpacing(1) / obj.modulation.subcarrierSpacing(iBS);
                
                if( obj.modulation.nSymbolsTotal(iBS) / fbmc_index(iBS) * tmpFactor ~= obj.modulation.nSymbolsTotal(1) / fbmc_index(1) )
                    error('Invalid ratio of subcarrier spacing, number of subcarriers and number of total symbols across cells.');
                end
            end
            
            % check and set sampling rate
            if ischar(obj.modulation.samplingRate)
                if strcmp(obj.modulation.samplingRate,'Automatic')
                    % automatically calculate sampling rate
                    % choose sampling frequency such that the guard length is an integer multiple of the sampling time
                    
                    % get the numerator for time spacings to be integer divisible by the sampling time
                    timespacing_numerator = obj.modulation.nGuardSymbols;
                    timespacing_numerator(timespacing_numerator == 0) = 1;
                    
                    % get the denominator oftime spacings to be integer divisible by the sampling time
                    timespacing_denominator = obj.modulation.subcarrierSpacing;
                    num_symbols_tmp = obj.modulation.nSymbolsTotal - obj.modulation.nGuardSymbols;
                    timespacing_denominator(obj.modulation.nGuardSymbols ~= 0) = num_symbols_tmp(obj.modulation.nGuardSymbols ~= 0) .* timespacing_denominator(obj.modulation.nGuardSymbols ~= 0);
                    
                    % calculate a sampling time that is greatest common divisor of all the time spacings
                    [~, guardLengthGCD_numerator, guardLengthGCD_denominator] = Utils.vectorGCD_rational(timespacing_numerator, timespacing_denominator);
                    max_sampling_time_gcd = guardLengthGCD_numerator / guardLengthGCD_denominator;
                    
                    % minimum sampling rate is at least twice the largest bandwidth over all cells
                    max_sampling_time = 1 / (max(obj.modulation.subcarrierSpacing .* obj.modulation.numberOfSubcarriers) * 2);
                    
                    if max_sampling_time_gcd > max_sampling_time
                        % if the calculated GCD sampling time is too large, look for a smaller GCD
                        numerator_factors = factor(guardLengthGCD_numerator);
                        if length(numerator_factors) > 1 && 1 / guardLengthGCD_denominator <= max_sampling_time
                            % if a factorization of the GCD exists, look for the second (third, fourth...) greatest common divisor
                            for i_factor = 1:length(numerator_factors)
                                if prod(numerator_factors(i_factor:end)) / guardLengthGCD_denominator <= max_sampling_time
                                    obj.modulation.samplingRate = guardLengthGCD_denominator / prod(numerator_factors(i_factor:end));
                                    break;
                                end
                            end
                        else
                            % if no factorization exists, use integer multiples of the GCD sampling time
                            obj.modulation.samplingRate = ceil(max_sampling_time_gcd / max_sampling_time) / max_sampling_time_gcd;
                        end
                    else
                        % if the GCD sampling time is sufficiently small, use it
                        obj.modulation.samplingRate = 1 / max_sampling_time_gcd;
                    end
                    
                    fprintf('The sampling rate was set to %f MHz.\n', obj.modulation.samplingRate/1e6);
                    
                else
                    error('Sampling rate statement unknown!');
                end
            elseif isnumeric(obj.modulation.samplingRate)
                % check is there is only one sampling rate
                if length(obj.modulation.samplingRate) > 1
                    error('There must be a single sampling rate for all cells!');
                end
            else
                error('Sampling rate input format invalid!');
            end
            
            % check if sampling rate is at least twice the largest bandwidth
            if any( obj.modulation.subcarrierSpacing .* obj.modulation.numberOfSubcarriers .* 2 > obj.modulation.samplingRate)
                warning('Sampling rate is smaller than twice the largest bandwidth!');
            end
            
            % check if sampling rate is multiple of 1/guard time
            if any(mod(obj.modulation.samplingRate .* obj.modulation.nGuardSymbols ./ ((obj.modulation.nSymbolsTotal - obj.modulation.nGuardSymbols) .* obj.modulation.subcarrierSpacing), 1)>0)
                warning('Guard time is not integer multiple of the sampling time!');
            end
            
            % check if sampling time is multiple of 1/symbol time
            if any( mod(obj.modulation.samplingRate ./ obj.modulation.subcarrierSpacing, 1) > 0)
                warning('Guard time is not integer multiple of the symbol time!');
            end
            
            % check channel
            if strcmp(obj.channel.powerDelayProfile, 'AWGN') && (any(obj.simulation.nAntennasUser > 1) || any(prod(cell2mat(obj.simulation.nAntennasBaseStation.').') > 1))
                error('AWGN channel not defined for MIMO transmission!');
            end
            
            if obj.channel.correlatedFrames && ~strcmp(obj.channel.dopplerModel,'Jakes')
                error('Time correlated fading only supported with the ''Jakes'' Doppler spectrum.');
            end
            
            if ~ischar(obj.channel.spatialCorrelation)
                error('Spatial channel correlation parameter must be string!');
            end
            
            if ~strcmp(obj.channel.spatialCorrelation,'none') && all(obj.simulation.nAntennasUser==1) && all(prod(cell2mat(obj.simulation.nAntennasBaseStation.').')==1)
                warning('Spatial channel correlation is set to %s while all nodes have only a single antenna. Spatial correlation has no effect in a SISO simulation!',obj.channel.spatialCorrelation);
            end
            
            if ~all(~obj.simulation.userVelocity) && obj.channel.K~=0
                warning('In the mixcure case of moving and stationary users, Rayleigh fading will be applied to the stationary ones!');
                obj.channel.K = 0;
            end
            
            if obj.channel.timeSubsamplingFactor < 1
                error('The channel time-subsampling factor must be equal to or larger than 1.');
            end
            
            if (obj.channel.delta < 0) || (obj.channel.delta >1)
                error('TWDP parameter delta must be between 0 and 1!');
            end
            
            if (obj.channel.K < 0)
                error('TWDP parameter K must be positive!');
            end
            
            if obj.channel.spatialChannelModel
                
                if obj.channel.nSpatialPaths(obj.channel.nSpatialPaths < 0) ~= 0
                    error('Number of spatial paths cannot be negative!')
                end
                
                if obj.channel.LOSangleSigmaAOA(obj.channel.LOSangleSigmaAOA < 0) ~= 0
                    error('Azimuth AoA distribution cannot have negative standard deviation!')
                end
                
                if obj.channel.LOSangleSigmaZOA(obj.channel.LOSangleSigmaZOA < 0) ~= 0
                    error('Zenith AoA distribution cannot have negative standard deviation!')
                end
                
                if obj.channel.NLOSangleSigmaAOA(obj.channel.NLOSangleSigmaAOA < 0) ~= 0
                    error('Azimuth AoA distribution cannot have negative standard deviation!')
                end
                
                if obj.channel.NLOSangleSigmaZOA(obj.channel.NLOSangleSigmaZOA < 0) ~= 0
                    error('Zenith AoA distribution cannot have negative standard deviation!')
                end
                
                if length(obj.channel.angleMeanAOA) ~= obj.topology.nLinks
                    error('There must be an azimuth AoA distribution mean value defined for each link!');
                end
                
                if length(obj.channel.angleMeanZOA) ~= obj.topology.nLinks
                    error('There must be a zenith AoA distribution mean value defined for each link!');
                end
                
                if length(obj.channel.kFactor) ~= obj.topology.nLinks
                    error('There must be a k-Factor value defined for each link!');
                end
                
                if length(obj.channel.antennaSpacing) ~= obj.topology.nNodes
                    error('There must be an antenna spacing value defined for each node!');
                end
                
                orientationParameterHasWrongSize = 0;
                for nodeOrientation = obj.channel.nodesOrientation
                    orientationParameterHasWrongSize =  orientationParameterHasWrongSize || ~isequal(size(nodeOrientation{1}), [1,3]);
                end
                if length(obj.channel.nodesOrientation) ~= obj.topology.nNodes || orientationParameterHasWrongSize
                    error('There must be three orientation values [bearing,downtilt,slant] defined for each node!');
                end                
            end
            
            
            
            
            % check if sampling rate fits channel model
            % the check is implemented in the channel class -> just
            
            dummy.spatialChannelModel = false;                % create dummy object for the spatial channel model structure
            
            Channel.FastFading( obj.modulation.samplingRate, ...        % sampling rate
                obj.channel.powerDelayProfile, ...      % channel model
                1, ...                                  % total number of samples
                0, ...                                  % doppler frequency
                obj.channel.dopplerModel,...            % doppler model
                obj.channel.nPaths,...                  % number of paths
                false,...                               % time correlated fading
                'none',...                              % spatial correlation
                0,...                                   % spatial correlation coeff TX
                0,...                                   % spatial correlation coeff RX
                1,...                                   % number of transmit antennas
                1,...                                   % number of receive antennas
                true,...                                % show checks
                0,...                                   % K = 0
                1, ...                                  % delta = 1
                dummy,...                               % Spatial channel model
                [2,1], ...                              % antenna configuration
                [2,1],...
                0, ...
                obj.channel.timeSubsamplingFactor ...
                );
            
            
            % check feedback object
            if obj.feedback.enable
                if (isfield(obj.feedback, 'delay') && isfield(obj.feedback.averager, 'Type'))
                    if obj.feedback.delay < 0
                        error('Feedback delay can not be negative!');
                    end
                    if (~strcmp(obj.feedback.averager.Type,'eesm') && ~strcmp(obj.feedback.averager.Type, 'miesm'))
                        error('Only EESM and MIESM averager are supported!');
                    end
                else
                    error('To enable to feedback a delay and an averager type are necessary!');
                end
            end
            
            if ~isfield(obj.simulation, 'saveData')
                obj.simulation.saveData = false;
            end
        end
        
        function loadScenario(obj, scenario)
            % this method loads parameters from a scenario file
            
            % check input
            if ~ischar(scenario)
                error('Scenario must be string!');
            end
            if exist(['Scenarios/', scenario, '.m'], 'file') == 2
                run(['Scenarios/', scenario]);
            elseif exist(['Examples/', scenario, '.m'], 'file') == 2
                run(['Examples/', scenario]);
            else
                error('Scenario does not exist!');
            end
            
            % copy scenario parameters to object
            obj.simulation      = scStr.simulation;
            obj.topology        = scStr.topology;
            obj.schedule        = scStr.schedule;
            obj.channel         = scStr.channel;
            obj.modulation      = scStr.modulation;
            obj.coding          = scStr.coding;
            obj.layerMapping    = scStr.layerMapping;
            if isfield(scStr, 'feedback')
                obj.feedback = scStr.feedback;
            else
                obj.feedback.enable = 0;
            end
            
            
        end
        
        function UpdateSweepValue(obj, iSweep)
            % this method overwirtes a specific object property with the
            % current sweep variable value
            variableName = strsplit(obj.simulation.sweepParam{1}, '.');
            if length(variableName) == 2
                if obj.simulation.applySweepingTo == 1
                    obj.simulation.applySweepingTo = ones(size(obj.(variableName{1}).(variableName{2})));
                elseif sum(obj.simulation.applySweepingTo) == 0 || isempty(obj.simulation.applySweepingTo)
                    error('Atleast one element in obj.simulation.applySweepingTo has to be set to 1.');
                end

                if iscell( obj.(variableName{1}).(variableName{2}))
                    for iElement = 1:sum(obj.simulation.applySweepingTo)
                    obj.(variableName{1}).(variableName{2}){iElement} = obj.simulation.sweepValue(iSweep);
                    end
                else
                    obj.(variableName{1}).(variableName{2})(logical(obj.simulation.applySweepingTo)) = obj.simulation.sweepValue(iSweep);
                end
            elseif length(variableName) == 3
                if (strcmp(variableName{3},'pathloss') && strcmp(obj.topology.secondaryGeneration,'Manual'))
                    if obj.simulation.applySweepingTo == 1
                        obj.simulation.applySweepingTo = ones(1,obj.topology.nSecondaryLinks);
                    elseif sum(obj.simulation.applySweepingTo) == 0 || isempty(obj.simulation.applySweepingTo)
                        error('Atleast one element in obj.simulation.applySweepingTo has to be set to 1.');
                    end
                    obj.(variableName{1}).(variableName{2}).(variableName{3}) = zeros(1,obj.topology.nSecondaryLinks);
                    obj.(variableName{1}).(variableName{2}).(variableName{3})(logical(obj.simulation.applySweepingTo)) = obj.simulation.sweepValue(iSweep);
                elseif  (strcmp(variableName{3},'attenuation') && strcmp(obj.topology.interferenceGeneration,'Manual'))
                    if obj.simulation.applySweepingTo == 1
                        obj.simulation.applySweepingTo = ones(1,obj.topology.nInterferingLinks);
                    elseif sum(obj.simulation.applySweepingTo) == 0 || isempty(obj.simulation.applySweepingTo)
                        error('Atleast one element in obj.simulation.applySweepingTo has to be set to 1.');
                    end
                    obj.(variableName{1}).(variableName{2}).(variableName{3}) = zeros(1,obj.topology.nInterferingLinks);
                    obj.(variableName{1}).(variableName{2}).(variableName{3})(logical(obj.simulation.applySweepingTo)) = obj.simulation.sweepValue(iSweep);
                else
                    if obj.simulation.applySweepingTo == 1
                        obj.simulation.applySweepingTo = ones(size(obj.(variableName{1}).(variableName{2}).(variableName{3})));
                    elseif sum(obj.simulation.applySweepingTo) == 0 || isempty(obj.simulation.applySweepingTo)
                        error('Atleast one element in obj.simulation.applySweepingTo has to be set to 1.');
                    end
                    obj.(variableName{1}).(variableName{2}).(variableName{3})(logical(obj.simulation.applySweepingTo)) = obj.simulation.sweepValue(iSweep);
                end
            else
                error('Please add another elseif here based on the parameter you have created!');
            end
            obj.checkParameters();
        end
        
        function UpdateRISPhaseShift(obj, nINs, IN)
            for INindex = 1:nINs
                IN{INindex}.generateRandomPhaseShiftPerElement
                obj.simulation.phaseShiftPerElementRIS{INindex} = IN{INindex}.phaseShiftPerElement;
            end
        end
        
        function setConstantParameters( obj )
            % defines constant and pre-defined parameters that should not
            % be changed
            
            % define physical constants in SI units
            obj.constants.SPEED_OF_LIGHT            = 299792458;
            obj.constants.BOLTZMANN                 = 1.38064852e-23;
            obj.constants.VACUUM_PERMEABILITY = 4 * pi * 1e-7;
            obj.constants.VACUUM_PERMITTIVITY = 8.85 * 1e-12;
            
            % set parameters that are assumed to be constant
            obj.phy.temperature                     = 293;
            switch obj.modulation.cqiTable
                case 0
                    % 3GPP TS 36.213 V15.8.0 Table 7.2.3-1 (QPSK to 64 QAM)
                    % pre-defined MCS
                    obj.modulation.mcsValues(1).cqi = 1;
                    obj.modulation.mcsValues(1).alphabet = 'QPSK';
                    obj.modulation.mcsValues(1).modulationOrder = 4;
                    obj.modulation.mcsValues(1).codingRateTimes1024 = 78;
                    obj.modulation.mcsValues(1).efficiency = 0.1523;
                    
                    obj.modulation.mcsValues(2).cqi = 2;
                    obj.modulation.mcsValues(2).alphabet = 'QPSK';
                    obj.modulation.mcsValues(2).modulationOrder = 4;
                    obj.modulation.mcsValues(2).codingRateTimes1024 = 120;
                    obj.modulation.mcsValues(2).efficiency = 0.2344;
                    
                    obj.modulation.mcsValues(3).cqi = 3;
                    obj.modulation.mcsValues(3).alphabet = 'QPSK';
                    obj.modulation.mcsValues(3).modulationOrder = 4;
                    obj.modulation.mcsValues(3).codingRateTimes1024 = 193;
                    obj.modulation.mcsValues(3).efficiency = 0.3770;
                    
                    obj.modulation.mcsValues(4).cqi = 4;
                    obj.modulation.mcsValues(4).alphabet = 'QPSK';
                    obj.modulation.mcsValues(4).modulationOrder = 4;
                    obj.modulation.mcsValues(4).codingRateTimes1024 = 308;
                    obj.modulation.mcsValues(4).efficiency = 0.6016;
                    
                    obj.modulation.mcsValues(5).cqi = 5;
                    obj.modulation.mcsValues(5).alphabet = 'QPSK';
                    obj.modulation.mcsValues(5).modulationOrder = 4;
                    obj.modulation.mcsValues(5).codingRateTimes1024 = 449;
                    obj.modulation.mcsValues(5).efficiency = 0.8770;
                    
                    obj.modulation.mcsValues(6).cqi = 6;
                    obj.modulation.mcsValues(6).alphabet = 'QPSK';
                    obj.modulation.mcsValues(6).modulationOrder = 4;
                    obj.modulation.mcsValues(6).codingRateTimes1024 = 602;
                    obj.modulation.mcsValues(6).efficiency = 1.1758;
                    
                    obj.modulation.mcsValues(7).cqi = 7;
                    obj.modulation.mcsValues(7).alphabet = '16QAM';
                    obj.modulation.mcsValues(7).modulationOrder = 16;
                    obj.modulation.mcsValues(7).codingRateTimes1024 = 378;
                    obj.modulation.mcsValues(7).efficiency = 1.4766;
                    
                    obj.modulation.mcsValues(8).cqi = 8;
                    obj.modulation.mcsValues(8).alphabet = '16QAM';
                    obj.modulation.mcsValues(8).modulationOrder = 16;
                    obj.modulation.mcsValues(8).codingRateTimes1024 = 490;
                    obj.modulation.mcsValues(8).efficiency = 1.9141;
                    
                    obj.modulation.mcsValues(9).cqi = 9;
                    obj.modulation.mcsValues(9).alphabet = '16QAM';
                    obj.modulation.mcsValues(9).modulationOrder = 16;
                    obj.modulation.mcsValues(9).codingRateTimes1024 = 616;
                    obj.modulation.mcsValues(9).efficiency = 2.4063;
                    
                    obj.modulation.mcsValues(10).cqi = 10;
                    obj.modulation.mcsValues(10).alphabet = '64QAM';
                    obj.modulation.mcsValues(10).modulationOrder = 64;
                    obj.modulation.mcsValues(10).codingRateTimes1024 = 466;
                    obj.modulation.mcsValues(10).efficiency = 2.7305;
                    
                    obj.modulation.mcsValues(11).cqi = 11;
                    obj.modulation.mcsValues(11).alphabet = '64QAM';
                    obj.modulation.mcsValues(11).modulationOrder = 64;
                    obj.modulation.mcsValues(11).codingRateTimes1024 = 567;
                    obj.modulation.mcsValues(11).efficiency = 3.3223;
                    
                    obj.modulation.mcsValues(12).cqi = 12;
                    obj.modulation.mcsValues(12).alphabet = '64QAM';
                    obj.modulation.mcsValues(12).modulationOrder =64;
                    obj.modulation.mcsValues(12).codingRateTimes1024 = 666;
                    obj.modulation.mcsValues(12).efficiency = 3.9023;
                    
                    obj.modulation.mcsValues(13).cqi = 13;
                    obj.modulation.mcsValues(13).alphabet = '64QAM';
                    obj.modulation.mcsValues(13).modulationOrder = 64;
                    obj.modulation.mcsValues(13).codingRateTimes1024 = 772;
                    obj.modulation.mcsValues(13).efficiency = 4.5234;
                    
                    obj.modulation.mcsValues(14).cqi = 14;
                    obj.modulation.mcsValues(14).alphabet = '64QAM';
                    obj.modulation.mcsValues(14).modulationOrder = 64;
                    obj.modulation.mcsValues(14).codingRateTimes1024 = 873;
                    obj.modulation.mcsValues(14).efficiency = 5.1152;
                    
                    obj.modulation.mcsValues(15).cqi = 15;
                    obj.modulation.mcsValues(15).alphabet = '64QAM';
                    obj.modulation.mcsValues(15).modulationOrder = 64;
                    obj.modulation.mcsValues(15).codingRateTimes1024 = 948;
                    obj.modulation.mcsValues(15).efficiency = 5.5547;
                    
                    obj.feedback.averager.EESMbetas     = [5.01,5.01,0.84,1.67,1.61,1.64,3.87,5.06,6.4,12.59,17.59,23.33,29.45,33.05,35.41];
                    obj.feedback.averager.MIESMbetas    = [3.07,4.41,0.6,1.16,1.06,1.06,0.87,1.01,1.04,1.03,1.11,1.01,1.07,1,1.05];
                    obj.feedback.CqiMappingTable        = [-500;-5.6;-3.5;-1.5;0.7;2.6;4.6;6.5;8.5;10.5;12.5;14.3;16.1;18.1;20.3;22];
                    
                    
                case 1
                    % 1: 3GPP TS 36.213 V15.8.0 Table 7.2.3-2 (QPSK to 256 QAM)
                    obj.modulation.mcsValues(1).cqi = 1;
                    obj.modulation.mcsValues(1).alphabet = 'QPSK';
                    obj.modulation.mcsValues(1).modulationOrder = 4;
                    obj.modulation.mcsValues(1).codingRateTimes1024 = 78;
                    obj.modulation.mcsValues(1).efficiency = 0.1523;
                    
                    obj.modulation.mcsValues(2).cqi = 2;
                    obj.modulation.mcsValues(2).alphabet = 'QPSK';
                    obj.modulation.mcsValues(2).modulationOrder = 4;
                    obj.modulation.mcsValues(2).codingRateTimes1024 = 193;
                    obj.modulation.mcsValues(2).efficiency = 0.3770;
                    
                    obj.modulation.mcsValues(3).cqi = 3;
                    obj.modulation.mcsValues(3).alphabet = 'QPSK';
                    obj.modulation.mcsValues(3).modulationOrder = 4;
                    obj.modulation.mcsValues(3).codingRateTimes1024 = 449;
                    obj.modulation.mcsValues(3).efficiency = 0.8770;
                    
                    obj.modulation.mcsValues(4).cqi = 4;
                    obj.modulation.mcsValues(4).alphabet = '16QAM';
                    obj.modulation.mcsValues(4).modulationOrder = 16;
                    obj.modulation.mcsValues(4).codingRateTimes1024 = 378;
                    obj.modulation.mcsValues(4).efficiency = 1.4766;
                    
                    obj.modulation.mcsValues(5).cqi = 5;
                    obj.modulation.mcsValues(5).alphabet = '16QAM';
                    obj.modulation.mcsValues(5).modulationOrder = 16;
                    obj.modulation.mcsValues(5).codingRateTimes1024 = 490;
                    obj.modulation.mcsValues(5).efficiency = 1.9141;
                    
                    obj.modulation.mcsValues(6).cqi = 6;
                    obj.modulation.mcsValues(6).alphabet = '16QAM';
                    obj.modulation.mcsValues(6).modulationOrder = 16;
                    obj.modulation.mcsValues(6).codingRateTimes1024 = 616;
                    obj.modulation.mcsValues(6).efficiency = 2.4063;
                    
                    obj.modulation.mcsValues(7).cqi = 7;
                    obj.modulation.mcsValues(7).alphabet = '64QAM';
                    obj.modulation.mcsValues(7).modulationOrder = 64;
                    obj.modulation.mcsValues(7).codingRateTimes1024 = 466;
                    obj.modulation.mcsValues(7).efficiency = 2.7305;
                    
                    obj.modulation.mcsValues(8).cqi = 8;
                    obj.modulation.mcsValues(8).alphabet = '64QAM';
                    obj.modulation.mcsValues(8).modulationOrder = 64;
                    obj.modulation.mcsValues(8).codingRateTimes1024 = 567;
                    obj.modulation.mcsValues(8).efficiency = 3.3223;
                    
                    obj.modulation.mcsValues(9).cqi = 9;
                    obj.modulation.mcsValues(9).alphabet = '64QAM';
                    obj.modulation.mcsValues(9).modulationOrder = 64;
                    obj.modulation.mcsValues(9).codingRateTimes1024 = 666;
                    obj.modulation.mcsValues(9).efficiency = 3.9023;
                    
                    obj.modulation.mcsValues(10).cqi = 10;
                    obj.modulation.mcsValues(10).alphabet = '64QAM';
                    obj.modulation.mcsValues(10).modulationOrder = 64;
                    obj.modulation.mcsValues(10).codingRateTimes1024 = 772;
                    obj.modulation.mcsValues(10).efficiency = 4.5234;
                    
                    obj.modulation.mcsValues(11).cqi = 11;
                    obj.modulation.mcsValues(11).alphabet = '64QAM';
                    obj.modulation.mcsValues(11).modulationOrder = 64;
                    obj.modulation.mcsValues(11).codingRateTimes1024 = 873;
                    obj.modulation.mcsValues(11).efficiency = 5.1152;
                    
                    obj.modulation.mcsValues(12).cqi = 12;
                    obj.modulation.mcsValues(12).alphabet = '256QAM';
                    obj.modulation.mcsValues(12).modulationOrder = 256;
                    obj.modulation.mcsValues(12).codingRateTimes1024 = 711;
                    obj.modulation.mcsValues(12).efficiency = 5.5547;
                    
                    obj.modulation.mcsValues(13).cqi = 13;
                    obj.modulation.mcsValues(13).alphabet = '256QAM';
                    obj.modulation.mcsValues(13).modulationOrder = 256;
                    obj.modulation.mcsValues(13).codingRateTimes1024 = 797;
                    obj.modulation.mcsValues(13).efficiency = 6.2266;
                    
                    obj.modulation.mcsValues(14).cqi = 14;
                    obj.modulation.mcsValues(14).alphabet = '256QAM';
                    obj.modulation.mcsValues(14).modulationOrder = 256;
                    obj.modulation.mcsValues(14).codingRateTimes1024 = 885;
                    obj.modulation.mcsValues(14).efficiency = 6.9141;
                    
                    obj.modulation.mcsValues(15).cqi = 15;
                    obj.modulation.mcsValues(15).alphabet = '256QAM';
                    obj.modulation.mcsValues(15).modulationOrder = 256;
                    obj.modulation.mcsValues(15).codingRateTimes1024 = 948;
                    obj.modulation.mcsValues(15).efficiency = 7.4063;
                    
                    obj.feedback.averager.EESMbetas     = [5.01,0.84,1.61,3.87,5.06,6.4,12.59,17.59,23.33,29.45,33.05,100.3,105.89,130,143.8];
                    obj.feedback.averager.MIESMbetas    = [3.07,0.6,1.06,0.87,1.01,1.04,1.03,1.11,1.01,1.07,1,1.19,0.92,0.97,1.12];
                    obj.feedback.CqiMappingTable        = [-500;-3.5;0.7;4.6;6.5;8.5;10.5;12.5;14.3;16.1;18.1;19.35;21.18;23.52;26.03;28];
                    
                    
                case 2
                    % 2: 3GPP TS 36.213 V15.8.0, Table 7.2.3-4: 4-bit CQI Table 4 (QPSK to 1024-QAM)
                    obj.modulation.mcsValues(1).cqi = 1;
                    obj.modulation.mcsValues(1).alphabet = 'QPSK';
                    obj.modulation.mcsValues(1).modulationOrder = 4;
                    obj.modulation.mcsValues(1).codingRateTimes1024 = 78;
                    obj.modulation.mcsValues(1).efficiency = 0.1523;
                    
                    obj.modulation.mcsValues(2).cqi = 2;
                    obj.modulation.mcsValues(2).alphabet = 'QPSK';
                    obj.modulation.mcsValues(2).modulationOrder = 4;
                    obj.modulation.mcsValues(2).codingRateTimes1024 = 193;
                    obj.modulation.mcsValues(2).efficiency = 0.3770;
                    
                    obj.modulation.mcsValues(3).cqi = 3;
                    obj.modulation.mcsValues(3).alphabet = 'QPSK';
                    obj.modulation.mcsValues(3).modulationOrder = 4;
                    obj.modulation.mcsValues(3).codingRateTimes1024 = 449;
                    obj.modulation.mcsValues(3).efficiency = 0.8770;
                    
                    obj.modulation.mcsValues(4).cqi = 4;
                    obj.modulation.mcsValues(4).alphabet = '16QAM';
                    obj.modulation.mcsValues(4).modulationOrder = 16;
                    obj.modulation.mcsValues(4).codingRateTimes1024 = 378;
                    obj.modulation.mcsValues(4).efficiency = 1.4766;
                    
                    obj.modulation.mcsValues(5).cqi = 5;
                    obj.modulation.mcsValues(5).alphabet = '16QAM';
                    obj.modulation.mcsValues(5).modulationOrder = 16;
                    obj.modulation.mcsValues(5).codingRateTimes1024 = 616;
                    obj.modulation.mcsValues(5).efficiency = 2.4063;
                    
                    obj.modulation.mcsValues(6).cqi = 6;
                    obj.modulation.mcsValues(6).alphabet = '64QAM';
                    obj.modulation.mcsValues(6).modulationOrder = 64;
                    obj.modulation.mcsValues(6).codingRateTimes1024 = 567;
                    obj.modulation.mcsValues(6).efficiency = 3.3223;
                    
                    obj.modulation.mcsValues(7).cqi = 7;
                    obj.modulation.mcsValues(7).alphabet = '64QAM';
                    obj.modulation.mcsValues(7).modulationOrder = 64;
                    obj.modulation.mcsValues(7).codingRateTimes1024 = 666;
                    obj.modulation.mcsValues(7).efficiency = 3.9023;
                    
                    obj.modulation.mcsValues(8).cqi = 8;
                    obj.modulation.mcsValues(8).alphabet = '64QAM';
                    obj.modulation.mcsValues(8).modulationOrder = 64;
                    obj.modulation.mcsValues(8).codingRateTimes1024 = 772;
                    obj.modulation.mcsValues(8).efficiency = 4.5234;
                    
                    obj.modulation.mcsValues(9).cqi = 9;
                    obj.modulation.mcsValues(9).alphabet = '64QAM';
                    obj.modulation.mcsValues(9).modulationOrder = 64;
                    obj.modulation.mcsValues(9).codingRateTimes1024 = 873;
                    obj.modulation.mcsValues(9).efficiency = 5.1152;
                    
                    obj.modulation.mcsValues(10).cqi = 10;
                    obj.modulation.mcsValues(10).alphabet = '256QAM';
                    obj.modulation.mcsValues(10).modulationOrder = 256;
                    obj.modulation.mcsValues(10).codingRateTimes1024 = 711;
                    obj.modulation.mcsValues(10).efficiency = 5.5547;
                    
                    obj.modulation.mcsValues(11).cqi = 11;
                    obj.modulation.mcsValues(11).alphabet = '256QAM';
                    obj.modulation.mcsValues(11).modulationOrder = 256;
                    obj.modulation.mcsValues(11).codingRateTimes1024 = 797;
                    obj.modulation.mcsValues(11).efficiency = 6.2266;
                    
                    obj.modulation.mcsValues(12).cqi = 12;
                    obj.modulation.mcsValues(12).alphabet = '256QAM';
                    obj.modulation.mcsValues(12).modulationOrder = 256;
                    obj.modulation.mcsValues(12).codingRateTimes1024 = 885;
                    obj.modulation.mcsValues(12).efficiency = 6.9141;
                    
                    obj.modulation.mcsValues(13).cqi = 13;
                    obj.modulation.mcsValues(13).alphabet = '256QAM';
                    obj.modulation.mcsValues(13).modulationOrder = 256;
                    obj.modulation.mcsValues(13).codingRateTimes1024 = 948;
                    obj.modulation.mcsValues(13).efficiency = 7.4063;
                    
                    obj.modulation.mcsValues(14).cqi = 14;
                    obj.modulation.mcsValues(14).alphabet = '1024QAM';
                    obj.modulation.mcsValues(14).modulationOrder = 1024;
                    obj.modulation.mcsValues(14).codingRateTimes1024 = 853;
                    obj.modulation.mcsValues(14).efficiency = 8.3321;
                    
                    obj.modulation.mcsValues(15).cqi = 15;
                    obj.modulation.mcsValues(15).alphabet = '1024QAM';
                    obj.modulation.mcsValues(15).modulationOrder = 1024;
                    obj.modulation.mcsValues(15).codingRateTimes1024 = 948;
                    obj.modulation.mcsValues(15).efficiency = 9.2578;
                    
                    obj.feedback.averager.EESMbetas     = [5.01,0.84,1.61,3.87,17.59,29.45,33.05,100.3,105.89,130,143.8,150,150,457.29,795.73];
                    obj.feedback.averager.MIESMbetas    = [3.07,0.6,1.06,0.87,1.04,1.11,1.01,1.07,1,1.19,0.92,0.97,1.12,1.22,0.937];
                    obj.feedback.CqiMappingTable        = [-500;-3.5;0.7;4.6;8.5;12.5;14.3;16.1;18.1;19.35;21.18;23.6;26.03;27.9;34.7;38];
                otherwise
                    error('CQI table not defined');
            end
            
            obj.feedback.averager.MCS_values       = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15];         % Modulation a Coding Schemes used for the transmission
            
            % Layer Mapping
            switch obj.layerMapping.mode
                case {'LTE'}
                    obj.layerMapping.table.Uplink = {1;[1 1];[1 2];[2 2]};
                    obj.layerMapping.table.Downlink = {1;[1 1];[1 2];[2 2];[2 3];[3 3];[3 4];[4 4]};
                case {'5G'}
                    obj.layerMapping.table.Uplink = {1;2;3;4};
                    obj.layerMapping.table.Downlink = {1;2;3;4;[2 3];[3 3];[3 4];[4 4]};
                case {'custom'}
                    obj.layerMapping.table.Uplink = obj.layerMapping.table.Uplink;
                    obj.layerMapping.table.Downlink = obj.layerMapping.table.Downlink;
                otherwise
                    error('Layer mapping mode unkown!');
            end
            
        end %setConstantParameters
        
        function Links = initializeLinks(obj, Links, BS, UE, IN)
            % this function  initializes all links according to some
            % scenario setting
            L = length(Links);
            
            nBS = length(BS);
            
            % get schedule for each BS downlink
            if obj.simulation.simulateDownlink
                linkScheduleDL = cell(nBS, 1);
                for iBS = 1:nBS
                    if ~isempty(obj.schedule.fixedScheduleDL{iBS})
                        if ismember(obj.schedule.multiuserMode.Downlink{iBS},{'ZF-MUMIMO','MRT-MUMIMO','BD-MUMIMO'})
                            linkScheduleDL{iBS} = [];
                            tmpSchedule =  ones(obj.modulation.numberOfSubcarriers(iBS),1);
                            linkScheduleDL{iBS} = tmpSchedule;
                        else
                            split = strsplit(obj.schedule.fixedScheduleDL{iBS}, ',');
                            nFrequBlocks = length(split);
                            linkScheduleDL{iBS} = [];
                            for iBlock = 1:nFrequBlocks
                                split2 = strsplit( split{iBlock}, ':' );
                                if strcmp(split2{1}(1:2),'UE')
                                    if isempty(strfind(split2{2}, 'UE'))
                                        tmpSchedule = UE{str2double(split2{1}(3:end))}.ID * ones(str2double(split2{2}),1);
                                    else
                                        if str2double(split2{1}(3:end)) < str2double(split2{2}(3:end))
                                            error('The index of the near user must be smaller than the index of the far user.')
                                        else
                                            Links{BS{iBS}.ID, UE{str2double(split2{2}(3:end))}.ID}.MUSTFarUE = UE{str2double(split2{1}(3:end))}.ID;
                                            Links{BS{iBS}.ID, UE{str2double(split2{1}(3:end))}.ID}.MUSTNearUE = UE{str2double(split2{2}(3:end))}.ID;
                                            Links{BS{iBS}.ID, UE{str2double(split2{2}(3:end))}.ID}.IsMUSTNearUE = 1;
                                            Links{BS{iBS}.ID, UE{str2double(split2{1}(3:end))}.ID}.IsMUSTFarUE = 1;          
                                            tmpSchedule = [];
                                        end
                                    end
                                elseif strcmp(split2{1}(1:4), 'none')
                                    tmpSchedule = zeros(str2double(split2{2}), 1);
                                else
                                    error('Schedule input invalid!');
                                end
                                linkScheduleDL{iBS} = [linkScheduleDL{iBS}; tmpSchedule];
                            end
                        end
                        linkScheduleDL{iBS} = repmat(linkScheduleDL{iBS}, 1, obj.modulation.MCSymbols(iBS));
                    end
                end
            end
            
            % get schedule for each BS Uplink
            if obj.simulation.simulateUplink
                linkScheduleUL = cell(nBS, 1);
                for iBS = 1:nBS
                    if ~isempty(obj.schedule.fixedScheduleUL{iBS})
                        if ismember(obj.schedule.multiuserMode.Uplink{iBS},{'ZF-MUMIMO' ,'MRC-MUMIMO', 'MMSE-MUMIMO'})
                            linkScheduleUL{iBS} = [];
                            tmpSchedule =  ones(obj.modulation.numberOfSubcarriers(iBS),1);
                            linkScheduleUL{iBS} = tmpSchedule;
                        else
                            split = strsplit(obj.schedule.fixedScheduleUL{iBS}, ',');
                            nFrequBlocks = length(split);
                            linkScheduleUL{iBS} = [];
                            for iBlock = 1:nFrequBlocks
                                split2 = strsplit(split{iBlock}, ':');
                                if strcmp(split2{1}(1:2), 'UE')
                                    tmpSchedule = UE{str2double(split2{1}(3:end))}.ID * ones(str2double(split2{2}), 1);
                                elseif strcmp(split2{1}(1:4), 'none')
                                    tmpSchedule = zeros(str2double(split2{2}), 1);
                                else
                                    error('Schedule input invalid!');
                                end
                                linkScheduleUL{iBS} = [linkScheduleUL{iBS}; tmpSchedule];
                            end
                        end
                        linkScheduleUL{iBS} = repmat(linkScheduleUL{iBS}, 1, obj.modulation.MCSymbols(iBS));
                    end
                end
            end
            
            for iBS = 1:nBS
                if strcmp(obj.simulation.frameStructure, 'TDD') && ~isequal(linkScheduleUL{iBS},linkScheduleDL{iBS})
                    error('For selected FrameStructure TDD downlink and uplink must be scheduled on the same subcarriers!');
                end

                if obj.simulation.simulateDownlink
                    BS{iBS}.nTotalScheduledSubcarriers = sum(mean(linkScheduleDL{iBS} ~= 0, 2));
                end
                
                for iLink = 1:L
                    % Downlink
                    if obj.simulation.simulateDownlink
                        if ~isempty(Links{BS{iBS}.ID, iLink}) && strcmp(Links{BS{iBS}.ID, iLink}.Type, 'Primary')
                            Links{BS{iBS}.ID, iLink}.transmitPower = BS{iBS}.txPower;
                            Links{BS{iBS}.ID, iLink}.multiuserMode = obj.schedule.multiuserMode.Downlink{iBS};
                            if ismember(obj.schedule.multiuserMode.Downlink{iBS}, {'ZF-MUMIMO', 'MRT-MUMIMO', 'BD-MUMIMO'})
                                Links{BS{iBS}.ID, iLink}.schedule = linkScheduleDL{iBS} ~= 0;
                                Links{BS{iBS}.ID, iLink}.firstSubcarrier = find( mean(linkScheduleDL{iBS} ~= 0,2), 1, 'first') -1;
                                Links{BS{iBS}.ID, iLink}.scheduledSubcarriers = sum(mean(linkScheduleDL{iBS} ~= 0,2));
                                
                            else
                                if ~Links{BS{iBS}.ID, iLink}.IsMUSTFarUE
                                    Links{BS{iBS}.ID, iLink}.schedule = linkScheduleDL{iBS} == iLink;
                                    Links{BS{iBS}.ID, iLink}.firstSubcarrier = find( mean(linkScheduleDL{iBS} == iLink, 2), 1, 'first') -1;
                                    Links{BS{iBS}.ID, iLink}.scheduledSubcarriers = sum(mean(linkScheduleDL{iBS} == iLink, 2));
                                    if Links{BS{iBS}.ID, iLink}.IsMUSTNearUE
                                        FarUEID = Links{BS{iBS}.ID, iLink}.MUSTFarUE;
                                        Links{BS{iBS}.ID, FarUEID}.schedule = Links{BS{iBS}.ID, iLink}.schedule;
                                        Links{BS{iBS}.ID, FarUEID}.firstSubcarrier = Links{BS{iBS}.ID, iLink}.firstSubcarrier;
                                        Links{BS{iBS}.ID, FarUEID}.scheduledSubcarriers = Links{BS{iBS}.ID, iLink}.scheduledSubcarriers;
                                    end
                                end
                            end
                        end
                    end
                    % Uplink
                    if obj.simulation.simulateUplink
                        if ~isempty(Links{iLink, BS{iBS}.ID}) && strcmp(Links{iLink, BS{iBS}.ID}.Type, 'Primary')
                            Links{iLink, BS{iBS}.ID}.multiuserMode = obj.schedule.multiuserMode.Uplink{iBS};
                            if ismember(obj.schedule.multiuserMode.Uplink{iBS},{'ZF-MUMIMO', 'MRC-MUMIMO', 'MMSE-MUMIMO'})
                                Links{iLink, BS{iBS}.ID}.schedule = linkScheduleUL{iBS} ~= 0;
                                Links{iLink, BS{iBS}.ID}.firstSubcarrier = find( mean(linkScheduleUL{iBS} ~= 0, 2), 1, 'first') -1;
                                Links{iLink, BS{iBS}.ID}.scheduledSubcarriers = sum(mean(linkScheduleUL{iBS} ~= 0, 2));
                                
                            else
                                Links{iLink, BS{iBS}.ID}.schedule = linkScheduleUL{iBS} == iLink;
                                Links{iLink, BS{iBS}.ID}.firstSubcarrier = find( mean(linkScheduleUL{iBS} == iLink, 2), 1, 'first') -1;
                                Links{iLink, BS{iBS}.ID}.scheduledSubcarriers = sum(mean(linkScheduleUL{iBS} == iLink, 2));
                            end
                        end
                    end
                end
            end
            % added the secondary links to the primary link and vice versa
            nUE = length(UE);
            nIN = length(IN);
            for iBS = 1:nBS
                for iUE = 1:nUE
                    iSecondDL = 0;
                    iSecondUL = 0;
                    currentDL = Links{BS{iBS}.ID, UE{iUE}.ID};
                    currentUL = Links{UE{iUE}.ID, BS{iBS}.ID};
                    if (~isempty(currentDL) && strcmp(currentDL.Type,'Primary')) || (~isempty(currentUL) && strcmp(currentUL.Type,'Primary'))
                        for iIN = 1:nIN
                            % DL 
                             if (~isempty(currentDL) && strcmp(currentDL.Type,'Primary')) 
                                sLinkDL = Links{BS{iBS}.ID,IN{iIN}.ID};
                                sLinkUL = Links{IN{iIN}.ID,UE{iUE}.ID};
                                if ~isempty(sLinkDL) && ~isempty(sLinkUL) 
                                    if  strcmp(sLinkDL.Type,'Secondary') && strcmp(sLinkUL.Type,'Secondary')
                                        iSecondDL = iSecondDL + 1;
                                        currentDL.secondaryLink{iSecondDL,1} = sLinkDL;
                                        sLinkDL.primaryLink = currentDL;
                                        currentDL.secondaryLink{iSecondDL,2} = sLinkUL;
                                        sLinkUL.primaryLink = currentDL;
                                    elseif xor(strcmp(sLinkDL.Type,'Secondary'), strcmp(sLinkUL.Type,'Secondary'))
                                        error('A secondary link is missing. There must be a secondary link defined from %s to %s and %s and %s',BS{iBS}.Name,IN{iIN}.Name,IN{iIN}.Name,UE{iUE}.Name);
                                    end
                                end
                             end
                            % UL
                             if (~isempty(currentUL) && strcmp(currentUL.Type,'Primary')) 

                                sLinkUL = Links{UE{iUE}.ID, IN{iIN}.ID};
                                sLinkDL = Links{IN{iIN}.ID, BS{iBS}.ID};
                                 if ~isempty(sLinkDL) && ~isempty(sLinkUL) 
                                     if  strcmp(sLinkUL.Type,'Secondary') && strcmp(sLinkDL.Type,'Secondary')
                                        iSecondUL = iSecondUL + 1;
                                        currentUL.secondaryLink{iSecondUL,1} = sLinkUL;
                                        sLinkUL.primaryLink = currentUL;
                                        currentUL.secondaryLink{iSecondUL,2} = sLinkDL;
                                        sLinkDL.primaryLink = currentUL;
                                    elseif xor(strcmp(sLinkDL.Type,'Secondary'), strcmp(sLinkUL.Type,'Secondary'))
                                        error('A secondary link is missing. There must be a secondary link defined from %s to %s and %s and %s',UE{iUE}.Name, IN{iIN}.Name,IN{iIN}.Name,UE{iUE}.NameBS{iBS}.Name);
                                     end
                                 end
                             end
                        end % iIN
                    end %
                end % iUE
            end % iBS 
            

            % check if each secondary link has a primary link
            for linkX = 1:L
                for linkY = 1:L
                    if ~isempty(Links{linkX, linkY}) && strcmp(Links{linkX, linkY}.Type, 'Secondary') && isempty(Links{linkX, linkY}.primaryLink)
                        error('Each secondray link must have a primary link. The secondray link connecting node %d and %d does not have a primary link.',Links{linkX, linkY}.Transmitter, Links{linkX, linkY}.Receiver);
                    end
                end
            end

            % assign parameters to desired primary links
            for linkX = 1:L
                for linkY = 1:L
                    if ~isempty(Links{linkX, linkY})
                        
                        % common objects and properties for primary and interfering links                        
                        % set objects and parameters for primary links
                        if strcmp(Links{linkX, linkY}.Type, 'Primary')
                            
                            % get base station ID of current link
                            split1 = strsplit(obj.topology.nodes(1:end),',');
                            switch Links{linkX, linkY}.Direction
                                case 'Downlink'
                                    BSiD = str2double(split1{Links{linkX, linkY}.Transmitter}(3:end));
                                case 'Uplink'
                                    BSiD = str2double(split1{Links{linkX, linkY}.Receiver}(3:end));
                                otherwise
                                    error('Link type unkown!');
                            end
                            
                            % get MCS
                            mcs = obj.modulation.mcsValues(obj.modulation.mcs(Links{linkX, linkY}.ID));
                            
                            % pathloss
                            Links{linkX, linkY}.pathloss = obj.simulation.pathloss(Links{linkX, linkY}.ID);
                            
                            % get link direction specific parameters
                            switch Links{linkX, linkY}.Direction
                                case 'Downlink'
                                    maxNCodewords = length(obj.layerMapping.table.Downlink{end});
                                    spreadingTransform = obj.modulation.spreadingTransformDownlink;
                                case 'Uplink'
                                    maxNCodewords = length(obj.layerMapping.table.Uplink{end});
                                    spreadingTransform = obj.modulation.spreadingTransformUplink;
                                otherwise
                                    error('Layer mapping table for this connection unknown');
                            end
                            
                            % channel coding
                            for iCodeword = 1:maxNCodewords
                                Links{linkX, linkY}.ChannelCoder{iCodeword} = Coding.ChannelCoding( obj.coding.code{Links{linkX, linkY}.ID}, ...                % Coding scheme
                                    obj.coding.decoding{Links{linkX, linkY}.ID}, ...            % Decoding algorithim
                                    mcs.codingRateTimes1024/1024, ...                           % Code rate
                                    obj.coding.decodingIterations(Links{linkX, linkY}.ID) ...   % Decoding iterations
                                    );
                                Links{linkX, linkY}.ChannelCoder{iCodeword}.SoftBufferRatio = obj.coding.softBufferRatio(Links{linkX, linkY}.ID);
                                if Links{linkX, linkY}.ChannelCoder{iCodeword}.SoftBufferRatio <= 0 || Links{linkX, linkY}.ChannelCoder{iCodeword}.SoftBufferRatio > 1
                                    error('The soft buffer ratio must be greater than zero, and less than or equal to one (100%).');
                                end
                            end
                            
                            % modulation
                            switch obj.modulation.waveform{BSiD}
                                case{'SC'}
                                    Links{linkX, linkY}.Modulator = Modulation.Modulator('QAM', mcs.modulationOrder, 'SC',...
                                        spreadingTransform,...                          % data symbol spreading type
                                        obj.simulation.noisePowerEstimation,...         % noise power estimation
                                        maxNCodewords,...                               % maximum number of codewords
                                        obj.coding.LLRsCalculationMethod, ...           % the method for calculating the LLRs
                                        obj.modulation.MCSymbols(BSiD),...              % number of symbols
                                        obj.modulation.subcarrierSpacing(BSiD),...      % symbol rate
                                        obj.modulation.samplingRate,...                 % Sampling rate (Samples/s)
                                        obj.modulation.pulseShapeFilter,...             % pulse shape filter
                                        10,...                                          % pulse shape filter impulse response length in symbol durations
                                        obj.modulation.rollOffFactor ,...               % pulse shape filter rolloff factor
                                        Links{linkX, linkY}.firstSubcarrier*...         % Intermediate frequency first subcarrier (Hz)
                                        obj.modulation.subcarrierSpacing(BSiD),...
                                        0 ...                                           % Zero guard length (s)
                                        );
                                    
                                case{'OFDM'}
                                    Links{linkX, linkY}.Modulator = Modulation.Modulator('QAM', mcs.modulationOrder, 'OFDM',...
                                        spreadingTransform,...                          % data symbol spreading type
                                        obj.simulation.noisePowerEstimation,...         % noise power estimation
                                        maxNCodewords,...                               % maximum number of codewords
                                        obj.coding.LLRsCalculationMethod, ...           % the method for calculating the LLRs
                                        Links{linkX, linkY}.scheduledSubcarriers,...    % Number subcarriers
                                        obj.modulation.MCSymbols(BSiD),...              % Number OFDM Symbols
                                        obj.modulation.subcarrierSpacing(BSiD),...      % Subcarrier spacing (Hz)
                                        obj.modulation.samplingRate,...                 % Sampling rate (Samples/s)
                                        Links{linkX, linkY}.firstSubcarrier*...         % Intermediate frequency first subcarrier (Hz)
                                        obj.modulation.subcarrierSpacing(BSiD),...
                                        false,...                                       % Transmit real valued signal
                                        obj.modulation.nGuardSymbols(BSiD)/...          % Cyclic prefix length (s)
                                        (obj.modulation.subcarrierSpacing(BSiD)*...
                                        obj.modulation.MCSymbols(BSiD)), ...
                                        0 ...                                           % Zero guard length (s)
                                        );
                                case{'f-OFDM'}
                                    Links{linkX, linkY}.Modulator = Modulation.Modulator('QAM', mcs.modulationOrder, 'f-OFDM', ...
                                        spreadingTransform,...                          % data symbol spreading type
                                        obj.simulation.noisePowerEstimation,...         % noise power estimation
                                        maxNCodewords,...                               % maximum number of codewords
                                        obj.coding.LLRsCalculationMethod, ...           % the method for calculating the LLRs
                                        Links{linkX, linkY}.scheduledSubcarriers,...    % Number subcarriers
                                        obj.modulation.MCSymbols(BSiD),...              % Number OFDM Symbols
                                        obj.modulation.subcarrierSpacing(BSiD),...      % Subcarrier spacing (Hz)
                                        obj.modulation.samplingRate,...                 % Sampling rate (Samples/s)
                                        Links{linkX, linkY}.firstSubcarrier*...         % Intermediate frequency first subcarrier (Hz)
                                        obj.modulation.subcarrierSpacing(BSiD),...
                                        false,...                                       % Transmit real valued signal
                                        0,...                                           % Cyclic prefix length (s)
                                        0, ...                                          % Zero guard length (s)
                                        1.5*obj.modulation.nGuardSymbols(BSiD)/...      % Length of the transmit filter (s)
                                        ((obj.modulation.nSymbolsTotal(BSiD)- ...
                                        obj.modulation.nGuardSymbols(BSiD))*...
                                        obj.modulation.subcarrierSpacing(BSiD)),...
                                        1.5*obj.modulation.nGuardSymbols(BSiD)/...      % Length of the receive filter (s)
                                        (obj.modulation.MCSymbols(BSiD)*...
                                        obj.modulation.subcarrierSpacing(BSiD)),...
                                        obj.modulation.nGuardSymbols(BSiD)/...          % Length of the additional cyclic prefix (s)
                                        (obj.modulation.MCSymbols(BSiD)*...
                                        obj.modulation.subcarrierSpacing(BSiD))...
                                        );
                                case{'WOLA'}
                                    Links{linkX, linkY}.Modulator = Modulation.Modulator('QAM', mcs.modulationOrder, 'WOLA', ...
                                        spreadingTransform,...                          % data symbol spreading type
                                        obj.simulation.noisePowerEstimation,...         % noise power estimation
                                        maxNCodewords,...                               % maximum number of codewords
                                        obj.coding.LLRsCalculationMethod, ...           % the method for calculating the LLRs
                                        Links{linkX, linkY}.scheduledSubcarriers,...    % Number subcarriers
                                        obj.modulation.MCSymbols(BSiD),...              % Number OFDM Symbols
                                        obj.modulation.subcarrierSpacing(BSiD),...      % Subcarrier spacing (Hz)
                                        obj.modulation.samplingRate,...                 % Sampling rate (Samples/s)
                                        Links{linkX, linkY}.firstSubcarrier*...         % Intermediate frequency first subcarrier (Hz)
                                        obj.modulation.subcarrierSpacing(BSiD),...
                                        false,...                                       % Transmit real valued signal
                                        0,...                                           % Cyclic prefix length (s)
                                        0,...                                           % Zero guard length (s)
                                        0.5*obj.modulation.nGuardSymbols(BSiD)/...      % Length of the window overlapping (s) at the transmitter
                                        (obj.modulation.MCSymbols(BSiD)*...
                                        obj.modulation.subcarrierSpacing(BSiD)),...
                                        0.5*obj.modulation.nGuardSymbols(BSiD)/...      % Length of the window overlapping (s) at the receiver
                                        (obj.modulation.MCSymbols(BSiD)*...
                                        obj.modulation.subcarrierSpacing(BSiD))...
                                        );
                                case{'FBMC'}
                                    Links{linkX, linkY}.Modulator  = Modulation.Modulator('PAM', sqrt(mcs.modulationOrder), 'FBMC',...
                                        spreadingTransform,...                          % data symbol spreading type
                                        obj.simulation.noisePowerEstimation,...         % noise power estimation
                                        maxNCodewords,...                               % maximum number of codewords
                                        obj.coding.LLRsCalculationMethod, ...           % the method for calculating the LLRs
                                        Links{linkX, linkY}.scheduledSubcarriers,...    % Number subcarriers
                                        obj.modulation.MCSymbols(BSiD),...              % Number OFDM Symbols
                                        obj.modulation.subcarrierSpacing(BSiD),...      % Subcarrier spacing (Hz)
                                        obj.modulation.samplingRate,...                 % Sampling rate (Samples/s)
                                        Links{linkX, linkY}.firstSubcarrier*...         % Intermediate frequency first subcarrier (Hz)
                                        obj.modulation.subcarrierSpacing(BSiD),...
                                        false,...                                       % Transmit real valued signal
                                        obj.modulation.prototypeFilter, ...             % prototype filter
                                        4, ...                                          % overlapping factor
                                        0, ...
                                        true...
                                        );
                                case{'UFMC'}
                                    Links{linkX, linkY}.Modulator = Modulation.Modulator('QAM', mcs.modulationOrder, 'UFMC', ...
                                        spreadingTransform,...                          % data symbol spreading type
                                        obj.simulation.noisePowerEstimation,...         % noise power estimation
                                        maxNCodewords,...                               % maximum number of codewords
                                        obj.coding.LLRsCalculationMethod, ...           % the method for calculating the LLRs
                                        Links{linkX, linkY}.scheduledSubcarriers,...    % Number subcarriers
                                        obj.modulation.MCSymbols(BSiD),...              % Number UFMC Symbols
                                        obj.modulation.subcarrierSpacing(BSiD),...      % Subcarrier spacing (Hz)
                                        obj.modulation.samplingRate,...                 % Sampling rate (Samples/s)
                                        Links{linkX, linkY}.firstSubcarrier*...         % Intermediate frequency first subcarrier (Hz)
                                        obj.modulation.subcarrierSpacing(BSiD),...
                                        false,...                                       % Transmit real valued signal
                                        obj.modulation.nSubcarriersPerSubband(BSiD),... % number of subcarriers per subband
                                        round(obj.modulation.nGuardSymbols(BSiD)/...    % Zero prefix length in samples
                                        (obj.modulation.subcarrierSpacing(BSiD)*...
                                        obj.modulation.MCSymbols(BSiD))*obj.modulation.samplingRate),...
                                        0,...                                           % no overhead
                                        1.5*obj.modulation.nGuardSymbols(BSiD)/...      % Length of the filter (s)
                                        (obj.modulation.MCSymbols(BSiD)*...
                                        obj.modulation.subcarrierSpacing(BSiD))...
                                        );
                                otherwise
                                    error('Waveform unkown!');
                            end
                            % assign MIMO receiver type
                            Links{linkX, linkY}.Modulator.ReceiverTypeMIMO = obj.simulation.receiverTypeMIMO;
                            
                            % MUST power allocation
                            if Links{linkX, linkY}.IsMUSTNearUE
                                % initial setup
                                Links{linkX, linkY}.MUSTIdx = obj.modulation.MUSTIdx(BSiD);
                                Links{linkX, linkY}.Modulator.SignalConstellation{1} = Modulation.SignalConstellation(mcs.modulationOrder, 'QAM', Links{linkX, linkY}.MUSTIdx, obj.coding.LLRsCalculationMethod);
                            else
                                Links{linkX, linkY}.MUSTIdx  = 0; % For normal links and farUE link (MUST operation is transparent to farUE).
                            end
                            
                            % assign channel estimation method
                            Links{linkX, linkY}.ChannelEstimationMethod    = obj.simulation.channelEstimationMethod;
                            
                            % toggle PAPR calculation
                            Links{linkX, linkY}.plotPAPR                   = obj.simulation.plotPAPR;
                            
                            % assign nonlinearity parameters
                            Links{linkX, linkY}.nonlinearity              = obj.simulation.nonlinearity;
                            Links{linkX, linkY}.amplifierOBO              = obj.simulation.amplifierOBO(Links{linkX, linkY}.ID);
                            Links{linkX, linkY}.smoothnessFactor          = obj.simulation.smoothnessFactor(Links{linkX, linkY}.ID);
                            
                            
                            %% Setting of the Channel Estimator and Equalizer
                            % get temporary pilot pattern
                            switch Links{linkX, linkY}.Direction
                                case 'Downlink'
                                    tempPilotPattern = obj.simulation.pilotPatternDownlink;
                                case 'Uplink'
                                    tempPilotPattern = obj.simulation.pilotPatternUplink;
                                otherwise
                                    error('Link must be either Downlink or Uplink!');
                            end
                            % get temporary channel interpolation method
                            if strcmp(tempPilotPattern, 'LTE Uplink')
                                % for the LTE Uplink pilot pattern, interpolation should be done only in time domain
                                tempInterpolationMethod = 'linear-time';
                            else
                                % for all other pilot patterns, perform 2D linear interpolation
                                tempInterpolationMethod = 'linear';
                            end
                            
                            switch Links{linkX, linkY}.ChannelEstimationMethod
                                case 'Approximate-Perfect'
                                    % artificially add pilots to get the same throughput as with channel estimation
                                    ChannelEstimator = ChannelEstimation.PilotSymbolAidedChannelEstimation( ...
                                        tempPilotPattern,...                                                % Pilot pattern
                                        [...                                                                % Matrix that represents the pilot pattern parameters
                                        Links{linkX, linkY}.Modulator.WaveformObject.Nr.Subcarriers,...     % Number of subcarriers
                                        obj.simulation.pilotSpacingFrequency; ...                           % Pilot spacing in the frequency domain
                                        Links{linkX, linkY}.Modulator.WaveformObject.Nr.MCSymbols,...       % Number of Symbols
                                        obj.simulation.pilotSpacingTime ...                                 % Pilot spacing in the time domain
                                        ],...
                                        obj.simulation.pilotSequenceLength,...                              % orthogonal pilot sequence length
                                        tempInterpolationMethod,...                                         % Interpolation(Extrapolation) method
                                        Links{linkX, linkY}.nTxAntennaPorts ...
                                        );
                                    
                                    Links{linkX, linkY}.Modulator.ChannelEstimationMethod = 'Approximate-Perfect';
                                    Links{linkX, linkY}.Modulator.ChannelEstimator = ChannelEstimator;
                                case 'PilotAided'
                                    ChannelEstimator = ChannelEstimation.PilotSymbolAidedChannelEstimation( ...
                                        tempPilotPattern,...                                                % Pilot pattern
                                        [...                                                                % Matrix that represents the pilot pattern parameters
                                        Links{linkX, linkY}.Modulator.WaveformObject.Nr.Subcarriers,...     % Number of subcarriers
                                        obj.simulation.pilotSpacingFrequency; ...                           % Pilot spacing in the frequency domain
                                        Links{linkX, linkY}.Modulator.WaveformObject.Nr.MCSymbols,...       % Number of Symbols
                                        obj.simulation.pilotSpacingTime ...                                 % Pilot spacing in the time domain
                                        ],...
                                        obj.simulation.pilotSequenceLength,...                              % orthogonal pilot sequence length
                                        tempInterpolationMethod,...                                         % Interpolation(Extrapolation) method
                                        Links{linkX, linkY}.nTxAntennaPorts ...
                                        );
                                    Links{linkX, linkY}.Modulator.ChannelEstimationMethod = 'PilotAided';
                                    Links{linkX, linkY}.Modulator.ChannelEstimator = ChannelEstimator;
                                otherwise
                                    error('Channel estimation method unknown.');
                            end
                            
                            % check pilot pattern for MU-MIMO
                            if ~strcmp(obj.simulation.channelEstimationMethod, 'Approximate-Perfect') && ~strcmp(obj.simulation.channelEstimationMethod, 'Perfect')
                                if strcmp(Links{linkX, linkY}.Direction, 'Uplink')
                                    if ~Links{linkX, linkY}.Modulator.ChannelEstimator.OverlappingPilots && ~any(strcmp(obj.schedule.multiuserMode.Uplink, 'none'))
                                        error('For multi-user MIMO uplink with channel estimation, a pilot pattern supporting orthogonal pilot symbols sequences (for example LTE Uplink pattern) must be used!');
                                    end
                                end
                            end
                            
                            % assign spatial correlation according to TS36.101, Annex B
                            if strcmp(obj.channel.spatialCorrelation,'none')
                                % no spatial correlation
                                correlationCoefficientTX = 0;
                                correlationCoefficientRX = 0;
                            else
                                switch Links{linkX, linkY}.Direction
                                    case 'Downlink'
                                        % for downlink the BS is the TX
                                        correlationCoefficientTX = obj.channel.spatialCorrBS;
                                        correlationCoefficientRX = obj.channel.spatialCorrUE;
                                    case 'Uplink'
                                        % for uplink the UE is the TX
                                        correlationCoefficientTX = obj.channel.spatialCorrUE;
                                        correlationCoefficientRX = obj.channel.spatialCorrBS;
                                    otherwise
                                        error('Link type unkown!');
                                end
                            end
                            
                            Links{linkX, linkY}.nTxAnalogPrecoder = obj.modulation.analogPrecoder{linkX};
                            Links{linkX, linkY}.nRxAnalogPrecoder = obj.modulation.analogReceiveFilter{linkY};
                            
                            Links{linkX, linkY}.frameStructure = obj.simulation.frameStructure;
                            
                            if obj.channel.spatialChannelModel
                                Links{linkX, linkY}.spatialModelParameters.spatialChannelModel  = obj.channel.spatialChannelModel;
                                Links{linkX, linkY}.spatialModelParameters.nSpatialPaths        = obj.channel.nSpatialPaths;
                                Links{linkX, linkY}.spatialModelParameters.LOSangleSigmaAOA      = obj.channel.LOSangleSigmaAOA;
                                Links{linkX, linkY}.spatialModelParameters.LOSangleSigmaZOA      = obj.channel.LOSangleSigmaZOA;
                                Links{linkX, linkY}.spatialModelParameters.NLOSangleSigmaAOA      = obj.channel.NLOSangleSigmaAOA;
                                Links{linkX, linkY}.spatialModelParameters.NLOSangleSigmaZOA      = obj.channel.NLOSangleSigmaZOA;
                                Links{linkX, linkY}.spatialModelParameters.antennaSpacingTx       = obj.channel.antennaSpacing(Links{linkX, linkY}.Transmitter);
                                Links{linkX, linkY}.spatialModelParameters.antennaSpacingRx       = obj.channel.antennaSpacing(Links{linkX, linkY}.Receiver);
                                Links{linkX, linkY}.spatialModelParameters.nodesOrientationTx       = obj.channel.nodesOrientation{Links{linkX, linkY}.Transmitter};
                                Links{linkX, linkY}.spatialModelParameters.nodesOrientationRx       = obj.channel.nodesOrientation{Links{linkX, linkY}.Receiver};
                                Links{linkX, linkY}.spatialModelParameters.kFactor              = obj.channel.kFactor(Links{linkX, linkY}.ID);
                                if obj.topology.geometricLayout
                                    Links{linkX, linkY}.spatialModelParameters.angleMeanAOA         = 0;
                                    Links{linkX, linkY}.spatialModelParameters.angleMeanZOA         = 0; 
                                else
                                    Links{linkX, linkY}.spatialModelParameters.angleMeanAOA         = obj.channel.angleMeanAOA(Links{linkX, linkY}.ID);
                                    Links{linkX, linkY}.spatialModelParameters.angleMeanZOA         = obj.channel.angleMeanZOA(Links{linkX, linkY}.ID); 
                                end

                            else
                                Links{linkX, linkY}.spatialModelParameters.spatialChannelModel  = false;
                            end
                            
                            % generate channel object for primary links
                            Links{linkX, linkY}.Channel             = Channel.FastFading(   obj.modulation.samplingRate,...
                                                                                            obj.channel.powerDelayProfile,...
                                                                                            Links{linkX, linkY}.Modulator.WaveformObject.Nr.SamplesTotal,...
                                                                                            Links{linkX, linkY}.Velocity / obj.constants.SPEED_OF_LIGHT * obj.simulation.centerFrequency,...
                                                                                            obj.channel.dopplerModel,...
                                                                                            obj.channel.nPaths,...
                                                                                            obj.channel.correlatedFrames,...
                                                                                            obj.channel.spatialCorrelation,...
                                                                                            correlationCoefficientTX,...
                                                                                            correlationCoefficientRX,...
                                                                                            Links{linkX, linkY}.nTxAntennas,...
                                                                                            Links{linkX, linkY}.nRxAntennas,...
                                                                                            false,...
                                                                                            obj.channel.K,...
                                                                                            obj.channel.delta,...
                                                                                            Links{linkX, linkY}.spatialModelParameters,...
                                                                                            Links{linkX, linkY}.txArrayConfiguration,...
                                                                                            Links{linkX, linkY}.rxArrayConfiguration,...
                                                                                            obj.simulation.centerFrequency, ...
                                                                                            obj.channel.timeSubsamplingFactor ...
                                                                                            );

                            try
                                if strcmp(obj.simulation.frameStructure,'TDD') && ~isempty(Links{linkY, linkX}.Channel)
                                    Links{linkX, linkY}.Channel.generateTimeCorrelationParameters(Links{linkY, linkX}.Channel);
                                end
                            catch ME
                                if strcmp(ME.identifier,'MATLAB:structRefFromNonStruct')
                                    error('Link missing! In TDD mode each link connecting two nodes should be defined in uplink and downlink both!')
                                else
                                    error('Topology error of unknown origin!')
                                end
                            end
                            
                            % MIMO
                            Links{linkX, linkY}.MIMO = MIMO.MimoProcessing(obj.modulation.transmissionMode);
                            
                            switch Links{linkX, linkY}.Direction
                                case 'Downlink'
                                    layerMappingTable = obj.layerMapping.table.Downlink;
                                case 'Uplink'
                                    layerMappingTable = obj.layerMapping.table.Uplink;
                            end
                            if  obj.feedback.enable
                                if obj.feedback.pmi
                                    Links{linkX, linkY}.Feedback        = Feedback.Feedback(obj.feedback, Links{linkX, linkY}.nTxAntennaPorts, Links{linkX, linkY}.nRxAntennaPorts, layerMappingTable);
                                elseif ismember(Links{linkX, linkY}.multiuserMode,{'ZF-MUMIMO','MMSE-MUMIMO','MRT-MUMIMO','MRC-MUMIMO','BD-MUMIMO'})  && obj.feedback.cqi
                                    Links{linkX, linkY}.Feedback        = Feedback.Feedback(obj.feedback, Links{linkX, linkY}.nTxAntennaPorts, Links{linkX, linkY}.nRxAntennaPorts, layerMappingTable, obj.modulation.nStreams(Links{linkX, linkY}.ID));
                                else
                                    Links{linkX, linkY}.Feedback        = Feedback.Feedback(obj.feedback, Links{linkX, linkY}.nTxAntennaPorts, Links{linkX, linkY}.nRxAntennaPorts, layerMappingTable, obj.modulation.nStreams(Links{linkX, linkY}.ID), obj.modulation.precodingMatrix{Links{linkX, linkY}.ID});
                                end
                            end
                            
                            switch obj.modulation.transmissionMode
                                case {'TxD', 'CLSM', 'OLSM'}
                                    if ~isfield(obj.modulation,'delayDiversity')
                                        if strcmp(obj.modulation.transmissionMode,'OLSM') 
                                            error('The parameter modulation.delayDiversity is missing')
                                        else
                                            obj.modulation.delayDiversity = 0;
                                        end
                                    end
                                    if strcmp(obj.simulation.codebook, '5G')
                                        if strcmp(Links{linkX, linkY}.Direction, 'Downlink')
                                            codebook = Parameters.getCodebook_5G(Links{linkX, linkY}.txAntennaConfiguration,Links{linkX, linkY}.Direction,obj.modulation.transmissionMode,obj.modulation.delayDiversity);
                                        else
                                            codebook = Parameters.getCodebook_5G(Links{linkX, linkY}.nTxAntennas,Links{linkX, linkY}.Direction,obj.modulation.transmissionMode,obj.modulation.delayDiversity);
                                        end
                                        
                                    else
                                        codebook = Parameters.getCodebook(Links{linkX, linkY}.nTxAntennas,Links{linkX, linkY}.Direction,obj.modulation.transmissionMode,obj.modulation.delayDiversity);
                                    end
                                    
                                    Links{linkX, linkY}.MIMO.codebook = codebook;
                                    if ~isempty(Links{linkX, linkY}.Feedback)
                                        Links{linkX, linkY}.Feedback.codebook = codebook;
                                    end
                                case 'custom'
                                    if (~obj.feedback.enable || ~obj.feedback.pmi)
                                        if ~ismember(Links{linkX, linkY}.multiuserMode,{'ZF-MUMIMO','MRT-MUMIMO','BD-MUMIMO','MMSE-MUMIMO','MRC-MUMIMO'}) && (size(obj.modulation.precodingMatrix{Links{linkX, linkY}.ID},1) ~= Links{linkX, linkY}.nTxAntennaPorts || size(obj.modulation.precodingMatrix{Links{linkX, linkY}.ID},2)~= obj.modulation.nStreams(Links{linkX, linkY}.ID))
                                            error('The precoding matrix defined for link %d does not fit number of antenna ports and streams defined for the link.',Links{linkX, linkY}.ID);
                                        end
                                        if obj.modulation.nStreams(Links{linkX, linkY}.ID) >  min(Links{linkX, linkY}.nTxAntennaPorts,Links{linkX, linkY}.nRxAntennaPorts)
                                            if Links{linkX, linkY}.nTxAntennaPorts < Links{linkX, linkY}.nRxAntennaPorts
                                                error('The maximum number of streams for link %d cannot be larger than the number of transmit antenna ports.',Links{linkX, linkY}.ID);
                                            else
                                                error('The maximum number of streams for link %d cannot be larger than the number of receive antenna ports.',Links{linkX, linkY}.ID);
                                            end
                                        end
                                        if ~ismember(Links{linkX, linkY}.multiuserMode,{'ZF-MUMIMO','MRT-MUMIMO','BD-MUMIMO','MMSE-MUMIMO','MRC-MUMIMO'})
                                            Links{linkX, linkY}.MIMO.setPrecodingMatrix(obj.modulation.precodingMatrix{Links{linkX, linkY}.ID});
                                        end
                                    else
                                        if strcmp(obj.simulation.codebook,'5G')
                                            if strcmp(Links{linkX, linkY}.Direction,'Downlink')
                                                codebook = Parameters.getCodebook_5G(Links{linkX, linkY}.txAntennaConfiguration,Links{linkX, linkY}.Direction,'CLSM',0);
                                            else
                                                codebook = Parameters.getCodebook_5G(Links{linkX, linkY}.nTxAntennas,Links{linkX, linkY}.Direction,'CLSM',0);
                                            end
                                        else
                                            codebook = Parameters.getCodebook(Links{linkX, linkY}.nTxAntennas,Links{linkX, linkY}.Direction,'CLSM',0);
                                        end
                                    end
                                    
                                    if ~isempty(Links{linkX, linkY}.Feedback) && Links{linkX, linkY}.Feedback.Pmi.enable
                                        Links{linkX, linkY}.Feedback.codebook = codebook;
                                    end
                            end
                            Links{linkX, linkY}.MIMO.LayerMappingTable = obj.layerMapping.table;
                            
                        elseif strcmp(Links{linkX, linkY}.Type, 'Interference')
                            Links{linkX, linkY}.ChannelCoder = [];
                            Links{linkX, linkY}.Modulator = [];
                            Links{linkX, linkY}.schedule = [];
                        end % if link type
                    end % if isempty link
                end % for linkY
            end % for linkX
             
            % assign the independent parameters to secondary links
            for linkX = 1:L
                for linkY = 1:L
                    if ~isempty(Links{linkX, linkY}) && strcmp(Links{linkX, linkY}.Type, 'Secondary')
                        
                        %add pathloss to the current link  simParams.topology.secondary.pathloss
                        if strcmp(obj.topology.secondaryGeneration,'Automatic')
                            Links{linkX, linkY}.pathloss = obj.topology.secondary.pathloss;
                        elseif ~obj.topology.geometricLayout
                            Links{linkX, linkY}.pathloss = obj.topology.secondary.pathloss(Links{linkX, linkY}.Transmitter,Links{linkX,linkY}.Receiver);
                        end
                        
                        nSamplesTotalTmp = Links{linkX, linkY}.primaryLink.Modulator.WaveformObject.Nr.SamplesTotal;
                        
                        % generate spatial channel model
                        if obj.channel.spatialChannelModel
                            Links{linkX, linkY}.spatialModelParameters.spatialChannelModel  = obj.channel.spatialChannelModel;
                            Links{linkX, linkY}.spatialModelParameters.nSpatialPaths        = obj.channel.nSpatialPaths;
                            Links{linkX, linkY}.spatialModelParameters.LOSangleSigmaAOA     = obj.channel.LOSangleSigmaAOA;
                            Links{linkX, linkY}.spatialModelParameters.LOSangleSigmaZOA     = obj.channel.LOSangleSigmaZOA;
                            Links{linkX, linkY}.spatialModelParameters.NLOSangleSigmaAOA    = obj.channel.NLOSangleSigmaAOA;
                            Links{linkX, linkY}.spatialModelParameters.NLOSangleSigmaZOA    = obj.channel.NLOSangleSigmaZOA;
                            Links{linkX, linkY}.spatialModelParameters.antennaSpacingTx     = obj.channel.antennaSpacing(Links{linkX, linkY}.Transmitter);
                            Links{linkX, linkY}.spatialModelParameters.antennaSpacingRx     = obj.channel.antennaSpacing(Links{linkX, linkY}.Receiver);
                            Links{linkX, linkY}.spatialModelParameters.nodesOrientationTx   = obj.channel.nodesOrientation{Links{linkX, linkY}.Transmitter};
                            Links{linkX, linkY}.spatialModelParameters.nodesOrientationRx   = obj.channel.nodesOrientation{Links{linkX, linkY}.Receiver};
                            Links{linkX, linkY}.spatialModelParameters.kFactor              = obj.topology.secondary.kFactors(linkX, linkY);
                            if obj.topology.geometricLayout
                                Links{linkX, linkY}.spatialModelParameters.angleMeanAOA         = 0;
                                Links{linkX, linkY}.spatialModelParameters.angleMeanZOA         = 0; 
                            else
                                Links{linkX, linkY}.spatialModelParameters.angleMeanAOA         = obj.topology.secondary.angleMeanAOA(linkX, linkY);
                                Links{linkX, linkY}.spatialModelParameters.angleMeanZOA         = obj.topology.secondary.angleMeanZOA(linkX, linkY); 
                            end
                        else   
                            Links{linkX, linkY}.spatialModelParameters.spatialChannelModel  = false;
                        end
                        
                        % generate channel object for interfering links
                        Links{linkX, linkY}.Channel             = Channel.FastFading(   obj.modulation.samplingRate,...
                            obj.channel.powerDelayProfile,...
                            nSamplesTotalTmp,...
                            Links{linkX, linkY}.Velocity / obj.constants.SPEED_OF_LIGHT * obj.simulation.centerFrequency,...
                            obj.channel.dopplerModel,...
                            obj.channel.nPaths,...
                            obj.channel.correlatedFrames,...
                            obj.channel.spatialCorrelation,...
                            correlationCoefficientTX,...
                            correlationCoefficientRX,...
                            Links{linkX, linkY}.nTxAntennas,...
                            Links{linkX, linkY}.nRxAntennas,...
                            false,...
                            obj.channel.K,...
                            obj.channel.delta,...
                            Links{linkX, linkY}.spatialModelParameters,...
                            Links{linkX, linkY}.txArrayConfiguration,...
                            Links{linkX, linkY}.rxArrayConfiguration,...
                            obj.simulation.centerFrequency, ...
                            obj.channel.timeSubsamplingFactor ...
                            );
                        try
                            if strcmp(obj.simulation.frameStructure,'TDD') && ~isempty(Links{linkY, linkX}.Channel)
                                Links{linkX, linkY}.Channel.generateTimeCorrelationParameters(Links{linkY, linkX}.Channel);
                            end
                        catch ME
                            if strcmp(ME.identifier,'MATLAB:structRefFromNonStruct')
                                error('Link missing! In TDD mode each link connecting two nodes should be defined in uplink and downlink both!')
                            else
                                error('Topology error of unknown origin!')
                            end
                        end
                        
                    end % if isempty link
                end % for linkY
            end % for linkX
            
            for iBS = 1:length(BS)
                if strcmp(obj.modulation.precodingScheme,'hybrid')
                    if  size(obj.modulation.analogPrecoder{ BS{iBS}.ID},1) ~= BS{iBS}.nAntennas || size(obj.modulation.analogPrecoder{ BS{iBS}.ID},2) ~= BS{iBS}.nAntennaPorts
                        error('The analog precoder defined for base station %d does not the fit number of antenna ports and antennas defined for the base station.', BS{iBS}.ID);
                    end
                    if size(obj.modulation.analogReceiveFilter{ BS{iBS}.ID},1) ~= BS{iBS}.nAntennaPorts || size(obj.modulation.analogReceiveFilter{ BS{iBS}.ID},2) ~= BS{iBS}.nAntennas
                        error('The analog receive filter defined for base station %d does not the fit number of antenna ports and antennas defined for the base station.', BS{iBS}.ID);
                    end
                end
                for iLink = 1:length(BS{iBS}.ReceiverDL)
                    if strcmp(Links{BS{iBS}.ID,BS{iBS}.ReceiverDL(iLink)}.Type,'Primary')
                        Links{BS{iBS}.ID,BS{iBS}.ReceiverDL(iLink)}.transmitPower = BS{iBS}.txPower;
                        Links{BS{iBS}.ID,BS{iBS}.ReceiverDL(iLink)}.powerScale = sqrt(Links{BS{iBS}.ID,BS{iBS}.ReceiverDL(iLink)}.Modulator.WaveformObject.Nr.Subcarriers / BS{iBS}.nTotalScheduledSubcarriers);
                    end
                end
            end
            for iUE = 1:length(UE)
                if strcmp(obj.modulation.precodingScheme,'hybrid')
                    if size(obj.modulation.analogPrecoder{ UE{iUE}.ID},1) ~= UE{iUE}.nAntennas || size(obj.modulation.analogPrecoder{ UE{iUE}.ID},2) ~= UE{iUE}.nAntennaPorts
                        error('The analog precoder defined for base station %d does not fit number of antenna ports and antennas defined for the base station.', BS{iBS}.ID);
                    end
                    if size(obj.modulation.analogReceiveFilter{ UE{iUE}.ID},1) ~= UE{iUE}.nAntennaPorts || size(obj.modulation.analogReceiveFilter{ UE{iUE}.ID},2) ~= UE{iUE}.nAntennas
                        error('The analog receive filter defined for base station %d does not fit number of antenna ports and antennas defined for the base station.', BS{iBS}.ID);
                    end
                end
                for iLink = 1:length(UE{iUE}.ReceiverUL)
                    if strcmp(Links{UE{iUE}.ID,UE{iUE}.ReceiverUL(iLink)}.Type,'Primary')
                        Links{UE{iUE}.ID,UE{iUE}.ReceiverUL(iLink)}.transmitPower = UE{iUE}.txPower;
                        Links{UE{iUE}.ID,UE{iUE}.ReceiverUL(iLink)}.powerScale = 1;
                    end
                end
            end
            
            % assign channel objects to interfering links
            for linkX = 1:L
                for linkY = 1:L
                    if ~isempty(Links{linkX, linkY}) && strcmp(Links{linkX, linkY}.Type, 'Interference')                       
                        % find primary BS and get total number of samples
                        switch Links{linkX, linkY}.Direction
                            case 'Downlink'
                                for iLink = 1:L
                                    if ~isempty(Links{linkX, iLink}) && strcmp(Links{linkX, iLink}.Type, 'Primary')
                                        nSamplesTotalTmp = Links{linkX, iLink}.Modulator.WaveformObject.Nr.SamplesTotal;
                                    end
                                    if ~isempty(Links{linkX, iLink}) && strcmp(Links{linkX, iLink}.Type, 'Secondary')
                                        nSamplesTotalTmp = Links{linkX, iLink}.primaryLink.Modulator.WaveformObject.Nr.SamplesTotal;
                                    end
                                end
                                RxID = linkX;
                                
                            case 'Uplink'
                                for iLink = 1:L
                                    if ~isempty(Links{linkX, iLink}) && strcmp(Links{linkX, iLink}.Type, 'Primary')
                                        nSamplesTotalTmp = Links{linkX, iLink}.Modulator.WaveformObject.Nr.SamplesTotal;
                                    end
                                    if ~isempty(Links{linkX, iLink}) && strcmp(Links{linkX, iLink}.Type, 'Secondary')
                                        nSamplesTotalTmp = Links{linkX, iLink}.primaryLink.Modulator.WaveformObject.Nr.SamplesTotal;
                                    end
                                end
                                RxID = linkX - nBS;
                            otherwise
                                error('Link type unkown!');
                        end
                        
                        if obj.channel.spatialChannelModel
                            Links{linkX, linkY}.spatialModelParameters.spatialChannelModel  = obj.channel.spatialChannelModel;
                            Links{linkX, linkY}.spatialModelParameters.nSpatialPaths        = obj.channel.nSpatialPaths;
                            Links{linkX, linkY}.spatialModelParameters.LOSangleSigmaAOA     = obj.channel.LOSangleSigmaAOA;
                            Links{linkX, linkY}.spatialModelParameters.LOSangleSigmaZOA     = obj.channel.LOSangleSigmaZOA;
                            Links{linkX, linkY}.spatialModelParameters.NLOSangleSigmaAOA    = obj.channel.NLOSangleSigmaAOA;
                            Links{linkX, linkY}.spatialModelParameters.NLOSangleSigmaZOA    = obj.channel.NLOSangleSigmaZOA;
                            Links{linkX, linkY}.spatialModelParameters.antennaSpacingTx     = obj.channel.antennaSpacing(Links{linkX, linkY}.Transmitter);
                            Links{linkX, linkY}.spatialModelParameters.antennaSpacingRx     = obj.channel.antennaSpacing(Links{linkX, linkY}.Receiver);
                            Links{linkX, linkY}.spatialModelParameters.nodesOrientationTx   = obj.channel.nodesOrientation{Links{linkX, linkY}.Transmitter};
                            Links{linkX, linkY}.spatialModelParameters.nodesOrientationRx   = obj.channel.nodesOrientation{Links{linkX, linkY}.Receiver};
                            Links{linkX, linkY}.spatialModelParameters.kFactor              = obj.topology.interferer.kFactors(linkX, linkY);
                            if obj.topology.geometricLayout
                                Links{linkX, linkY}.spatialModelParameters.angleMeanAOA         = 0;
                                Links{linkX, linkY}.spatialModelParameters.angleMeanZOA         = 0; 
                            else
                                Links{linkX, linkY}.spatialModelParameters.angleMeanAOA         = obj.topology.interferer.angleMeanAOA(linkX, linkY);
                                Links{linkX, linkY}.spatialModelParameters.angleMeanZOA         = obj.topology.interferer.angleMeanZOA(linkX, linkY); 
                            end
                        else
                            Links{linkX, linkY}.spatialModelParameters.spatialChannelModel  = false;
                        end
                        
                        % generate channel object for interfering links
                        Links{linkX, linkY}.Channel             = Channel.FastFading(   obj.modulation.samplingRate,...
                                                                                        obj.channel.powerDelayProfile,...
                                                                                        nSamplesTotalTmp,...
                                                                                        Links{linkX, linkY}.Velocity / obj.constants.SPEED_OF_LIGHT * obj.simulation.centerFrequency,...
                                                                                        obj.channel.dopplerModel,...
                                                                                        obj.channel.nPaths,...
                                                                                        obj.channel.correlatedFrames,...
                                                                                        obj.channel.spatialCorrelation,...
                                                                                        correlationCoefficientTX,...
                                                                                        correlationCoefficientRX,...
                                                                                        Links{linkX, linkY}.nTxAntennas,...
                                                                                        Links{linkX, linkY}.nRxAntennas,...
                                                                                        false,...
                                                                                        obj.channel.K,...
                                                                                        obj.channel.delta,...
                                                                                        Links{linkX, linkY}.spatialModelParameters,...
                                                                                        Links{linkX, linkY}.txArrayConfiguration,...
                                                                                        Links{linkX, linkY}.rxArrayConfiguration,...
                                                                                        obj.simulation.centerFrequency, ...
                                                                                        obj.channel.timeSubsamplingFactor ...
                                                                                        );
                                                                                    
                       try
                           if strcmp(obj.simulation.frameStructure,'TDD') && ~isempty(Links{linkY, linkX}.Channel)
                               Links{linkX, linkY}.Channel.generateTimeCorrelationParameters(Links{linkY, linkX}.Channel);
                           end
                       catch ME
                           if strcmp(ME.identifier,'MATLAB:structRefFromNonStruct')
                               error('Link missing! In TDD mode each link connecting two nodes should be defined in uplink and downlink both!')
                           else
                               error('Topology error of unknown origin!')
                           end
                       end
                    end
                end
            end
            if obj.topology.geometricLayout
                obj.setGeometricParameters(Links);
            end
            % check the generated links
            obj.checkLinks(Links);
            
        end %initializeLinks
        
        function checkLinks(obj, Links)
            % this method checks if parameters of the generated links are
            % consistent and correct
            
            L = length(Links);
            
            % check if all modulation schemes (in all cells) approximately
            % fit to the same frame duration
            
            linkCounter = 1;
            for linkX = 1:L
                for linkY = 1:L
                    if ~isempty(Links{linkX, linkY}) && ~strcmp(Links{linkX, linkY}.Type, 'Interference') && ~strcmp(Links{linkX, linkY}.Type, 'Secondary')
                        % for all primary links
                        % for all primary links
                        
                        % save frame duration and symbol time spacing
                        frameDuration(linkCounter, 1) 	= Links{linkX, linkY}.Modulator.WaveformObject.PHY.TimeSpacing * Links{linkX, linkY}.Modulator.WaveformObject.Nr.MCSymbols;
                        timeSpacing(linkCounter, 1)     = Links{linkX, linkY}.Modulator.WaveformObject.PHY.TimeSpacing;
                        
                        linkCounter = linkCounter + 1;
                    end
                end
            end
            
            % check if the difference from maximum to minimum frame
            % duration of all cells is small compared to the symbol time
            if abs(max(frameDuration) - min(frameDuration)) > 0.5 * min(timeSpacing)
                error('Frame durations of cells do not match!');
            end
            
            % save mean frame duration
            obj.simulation.averageFrameDuration = mean(frameDuration);
            
        end %checkLinks
        
        function  setGeometricParameters(obj, Links)
            nNodes = size(Links,1);
            c0 = 299792458; % speed of light
            
            for i = 1:nNodes
                for j = 1:i
                    if ~isempty(Links{i,j}) || ~isempty(Links{j,i})
                        if obj.simulation.simulateUplink == 1
                            txPosition = obj.topology.nodesPosition{i};
                            rxPosition = obj.topology.nodesPosition{j};
                        end
                        if obj.simulation.simulateDownlink == 1
                            txPosition = obj.topology.nodesPosition{j};
                            rxPosition = obj.topology.nodesPosition{i};
                        end
                        distance = norm(txPosition - rxPosition);
                        direction = (rxPosition - txPosition);
                        
                        % Path loss calculation
                        switch obj.simulation.pathLossModel.Type
                            case 'freeSpace'
                                PL = obj.simulation.pathLossModel.alpha * 10*log10(4 * pi * distance *  obj.simulation.centerFrequency / c0);
                                
                            case 'breakPoint'
                                if distance < obj.simulation.pathLossModel.breakDistance
                                    PL = obj.simulation.pathLossModel.alpha * 10*log10(4 * pi * distance *  obj.simulation.centerFrequency / c0);
                                else
                                    PL = obj.simulation.pathLossModel.alpha * 10*log10(4 * pi * obj.simulation.pathLossModel.breakDistance *  obj.simulation.centerFrequency / c0) ...
                                        + obj.simulation.pathLossModel.alpha2 * 10*log10(distance / obj.simulation.pathLossModel.breakDistance);
                                end
                            case 'rural'
                                %according to 3GPP TS 36.942, subclause 4.5.3
                                distance2Dkm=norm(txPosition(1,1:2)-rxPosition(1,1:2))*1e-3;
                                ruralPL = 69.55 + 26.16*log10( obj.simulation.centerFrequency*1e-6)...
                                    - 13.82*log10(txPosition(1,3)) ...
                                    + (44.9 - 6.55*log10(txPosition(1,3))) * log10(distance2Dkm)...
                                    - 4.78 * log10( obj.simulation.centerFrequency*1e-6)^2 + 18.33*log10( obj.simulation.centerFrequency*1e-6) - 40.94;
                                FSPL=obj.simulation.pathLossModel.alpha * 10*log10(4 * pi * distance *  obj.simulation.centerFrequency / c0);
                                PL=max(ruralPL,FSPL);
                                
                            case 'urban'
                                %according to 3GPP TS 36.942, subclause 4.5.2
                                distance2Dkm = norm(txPosition(1,1:2)-rxPosition(1,1:2))*1e-3;
                                BSheightsFromRooftop = txPosition(1,3)-obj.simulation.pathLossModel.averageBuildingHeight;
                                urbanPL = 40 * (1 - 4e-3 * BSheightsFromRooftop) .* log10(distance2Dkm) ...
                                    - 18*log10(BSheightsFromRooftop) + 21*log10( obj.simulation.centerFrequency*1e-6) + 80;
                                
                                if(isinf(urbanPL))
                                    error('The pathloss model results in infinite pathloss due to the same height of transmiter and averageBuildingHeight');
                                end
                                FSPL = obj.simulation.pathLossModel.alpha * 10*log10(4 * pi * distance *  obj.simulation.centerFrequency / c0);
                                PL = max(urbanPL,FSPL);
                                
                            case 'subUrbanMacro'
                                %according to COST 231 Chapter 4.4.1 for Cm=0
                                a = (1.1*log10( obj.simulation.centerFrequency*1e-6) - 0.7).*rxPosition(1,3) - ...
                                    (1.56*log10( obj.simulation.centerFrequency*1e-6)-0.8);
                                distance2Dkm = norm(txPosition(1,1:2)-rxPosition(1,1:2))*1e-3;
                                PL = 46.3 + 33.9*log10( obj.simulation.centerFrequency*1e-6) ...
                                    - 13.82*log10(txPosition(1,3)) - a ...
                                    + (44.9 - 6.55*log10(txPosition(1,3))).*log10(distance2Dkm);
                                
                                % check frequency range
                                if  obj.simulation.centerFrequency*1e-6 < 1500 ||  obj.simulation.centerFrequency*1e-6 > 2000
                                    warning('warning:frequency', 'The frequency is out of the scope of this model. Cost231 pathloss model is defined for frequencies in the range of 1.5 GHz to 2 GHz.');
                                end
                                
                                % check base station antenna heights
                                if txPosition(1,3) < 30 || txPosition(1,3) > 200
                                    warning('warning:BSheight', 'The BS antenna height is out of the scope of this model. Cost231 pathloss model is defined for BS heights in the range of 30 m to 200 m.');
                                end
                                
                                % check user heights
                                if rxPosition(1,3) < 1 || rxPosition(1,3) > 10
                                    warning('warning:UEheight', 'The UE height is out of the scope of this model. Cost231 pathloss model is defined for user heights in the range of 1 m to 10 m.');
                                end
                                
                                % check distances betwen user and base station
                                if distance2Dkm < 1 || distance2Dkm > 20
                                    warning('warning:distance2D', 'The distance between UE and BS antenna is out of the scope of this model. Cost231 pathloss model is defined for BS-user distances in the range of 1 km to 20 km.');
                                end    
                            case 'urbanMacroLOS'
                                %according to 3GPP TR 36.814 B 1.2.1
                                distance2D = norm(txPosition(1,1:2)-rxPosition(1,1:2));
                                hBS = 25;
                                hUT = 1.5;
                                hBSPrime = 25-1;
                                hUTPrime = 1.5-1;
                                dBreak = 4*hBSPrime*hUTPrime*obj.simulation.centerFrequency/c0; %Break point distance
                                
                                if(distance2D<dBreak)
                                    PL = 22.0*log10(distance2D)+28.0+20.0*log10(obj.simulation.centerFrequency*1e-9);
                                else 
                                    PL = 40.0*log10(distance2D)+7.8-18.0*log10(hBSPrime)- ...
                                    18.0*log10(hUTPrime)+2.0*log10(obj.simulation.centerFrequency*1e-9);
                                end
                                
                                % check frequency range
                                if  obj.simulation.centerFrequency*1e-6 < 2000 ||  obj.simulation.centerFrequency*1e-6 > 6000
                                    warning('warning:frequency', 'The frequency is out of the scope of this model. Urban Macro LOS pathloss model is designed for frequencies in the range of 2.0 GHz to 6.0 GHz');
                                end

                                % If BS and UE heigths do not fit the specification by the model (25 m and 1.5 m), PL will be calculated using the specification and a warning will be thrown 
                                % check base station antenna heights
                                if txPosition(1,3) ~= 25
                                    warning('warning:BSheight', 'The BS antenna height is out of the scope of this model. Urban Macro LOS pathloss model is defined for BS heights of 25 m');
                                end
                            
                                % check user heights
                                if rxPosition(1,3) ~= 1.5
                                    warning('warning:UEheight', 'The UE height is out of the scope of this model. Urban Macro LOS pathloss model is defined for user heights of 1.5 m');
                                end
                                
                                % check distances betwen user and base station
                                if distance2D < 10 || distance2D > 5000
                                    warning('warning:distance2D', 'The distance between UE and BS antenna is out of the scope of this model. Urban Macro LOS pathloss model is defined for BS-user distances in the range of 10 m to 5000 m');
                                end
                            otherwise
                                error('Path loss model not implemented');
                        end
                        
                        PL = max(PL,0);
                        % Calculate azimuth AOA
                        elevationAngle  = atan2(sqrt(direction(2)^2 + direction(1)^2),direction(3))/pi * 180;
                        azimuthAngle    = atan2( direction(2) , direction(1))/pi * 180;
                        if ~isempty(Links{i,j})
                            Links{i,j}.pathloss = PL;
                            Links{i,j}.Attenuation = PL;
                            Links{i,j}.spatialModelParameters.angleMeanAOA = azimuthAngle;
                            Links{i,j}.spatialModelParameters.angleMeanZOA = elevationAngle;
                            Links{i,j}.Channel.Implementation.spatialModel.angleMeanAOA = azimuthAngle;
                            Links{i,j}.Channel.Implementation.spatialModel.angleMeanZOA = elevationAngle;
                            
                        end
                        if ~isempty(Links{j,i})
                            Links{j,i}.pathloss = PL;
                            Links{j,i}.Attenuation = PL;
                            Links{j,i}.spatialModelParameters.angleMeanAOA = Utils.Extras.wrapTo360(azimuthAngle - 180);
                            Links{j,i}.spatialModelParameters.angleMeanZOA = 180 - elevationAngle;
                            Links{j,i}.Channel.Implementation.spatialModel.angleMeanAOA = Utils.Extras.wrapTo360(azimuthAngle - 180);
                            Links{j,i}.Channel.Implementation.spatialModel.angleMeanZOA = 180 - elevationAngle;
                        end
                    end
                end
            end
        end %setGeometricParameters
        
    end %methods
    
    
    
    
    
    
    
end %classdef

