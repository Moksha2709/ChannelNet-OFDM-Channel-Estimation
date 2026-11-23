%% Topology Generation
%   Authors
%     - ...
%   (c) 2018 Institute of Telecommunications, TU Wien.
%   www.nt.tuwien.ac.at
%%
function [Links, BS, UE, IN] = getTopology(simParams)
% Parse simParams.topology, and construct the corresponding network/links
BSnum = 0;
UEnum = 0;
INnum = 0;
RISnum = 0;
RISIndex = [];
simParams.topology.INID = [];
nSecondaryLinks = 0;
nInterferingLinks = 0;
%/ Checks
if length(simParams.topology.nodes) < 7
    error('Alteast two nodes have to be specified in the topology.');
end
%/
IDGenerator = Topology.IDGenerator;
split1 = strsplit(simParams.topology.nodes(1:end),',');
for ii = 1:length(split1)
    %/
    switch split1{ii}(1:2)
        case 'BS'
            index = str2double(split1{ii}(3:end));
            if index == BSnum + 1
                ID = IDGenerator.generateID();
                if length(simParams.simulation.plotResultsFor) == 1
                    plotResults = simParams.simulation.plotResultsFor;
                else
                    plotResults = simParams.simulation.plotResultsFor(ID);
                end
                BS{index} = Elements.BaseStation(['BS' num2str(index)], ID, simParams.simulation.nAntennasBaseStation{index}, simParams.simulation.nAntennaPortsBaseStation(index), simParams.modulation.analogPrecoder{ID}, simParams.modulation.analogReceiveFilter{ID}, simParams.simulation.txPowerBaseStation(index), simParams.schedule.multiuserMode.Downlink{index}, simParams.schedule.multiuserMode.Uplink{index}, simParams.schedule.multiuserMode.UplinkIC(index), plotResults); %#ok
                BSnum = index;
                %/ Checks
            elseif index == BSnum
                error(['BS' num2str(index) ' already exists. Please check topology.nodes for duplicates.'])
            else
                error('The nodes indices are not entered in an ascending order. Make sure to have them in the correct order, for example: BS1,BS2,BS3,UE1,UE2,UE3.')
            end
            %/
        case 'UE'
            index = str2double(split1{ii}(3:end));
            if index == UEnum + 1
                ID = IDGenerator.generateID();
                if length(simParams.simulation.plotResultsFor) == 1
                    plotResults = simParams.simulation.plotResultsFor;
                else
                    plotResults = simParams.simulation.plotResultsFor(ID);
                end
                UE{index} = Elements.User(['UE' num2str(index)], ID, simParams.simulation.nAntennasUser(index), simParams.simulation.nAntennaPortsUser(index), simParams.modulation.analogPrecoder{ID}, simParams.modulation.analogReceiveFilter{ID}, simParams.simulation.txPowerUser(index), plotResults); %#ok
                UEnum = index;
                %/ Checks
            elseif index == UEnum
                error(['UE' num2str(index) ' already exists. Please check topology.nodes for duplicates.'])
            else
                error('The nodes indices are not entered in an ascending order. Make sure to have them in the correct order, for example: BS1,BS2,BS3,UE1,UE2,UE3.')
            end
            %/
        case 'RI'
            index = str2double(split1{ii}(4:end));
            if index == INnum + 1
                ID = IDGenerator.generateID();
                if length(simParams.simulation.plotResultsFor) == 1
                    plotResults = simParams.simulation.plotResultsFor;
                else
                    plotResults = simParams.simulation.plotResultsFor(ID);
                end
                RISnum = RISnum + 1;
                RISIndex(RISnum) = index;
                IN{index} = Elements.IntermediateNode(['RIS' num2str(index)],'RIS', ID, simParams.simulation.nElementsRIS{index}, simParams.simulation.reflectCoefficientRIS(index), plotResults); %#ok
                simParams.topology.INID(ID) = index;
                
                INnum = index;
                %/ Checks
            elseif index == INnum
                error(['RIS' num2str(index) ' already exists. Please check topology.nodes for duplicates.'])
            else
                error('The nodes indices are not entered in an ascending order. Make sure to have them in the correct order, for example: BS1,BS2,BS3,UE1,UE2,UE3.')
            end
            %/
        otherwise
            error('The nodes name must start with either "BS", "UE" or "RIS".');
    end
end

% if there is no IN node generated, set IN as 0
if INnum == 0
   IN = [];
end

%% Check and add the control BS 
if RISnum > 0 
    controllerBS = zeros(RISnum,1);
    splitController = strsplit(simParams.topology.RISControllerBS,',');
    if length(splitController) ~= RISnum
        error('A control BS must be defined for each RIS');
    else
        for iRIS = 1:RISnum
            if ~strcmp(splitController{iRIS}(1:2),'BS')
                error('The RIS must have a BS as a controller');
            else
                bs = str2double(splitController{iRIS}(3:end));
                if bs > BSnum
                     error(['BS' num2str(bs) ' does not exist. Make sure to select a valid BS in scStr.topology.RISControllerBS.']);
                else
                    BS{bs}.intermediateNodes{end+1} =  IN{RISIndex(iRIS)};
                    controllerBS(iRIS) = bs; 
                end
            end
        end
    end
end


%Start Link generation
Links = cell(length(split1));

% Generation of Primary Links
split1 = strsplit(simParams.topology.primaryLinks,',');
linkID = 1;
nUplinks = 0;
nDownlinks = 0;
nD2Dlinks = 0;
for ii = 1:length(split1)
    split2 = strsplit(split1{ii},':');
    if strcmp(split2, '') == 0
        % transmitter index
        txIndex = str2double(split2{1}(3:end));
        
        %/ Checks
        if isnan(txIndex)
            error('The nodes in topology.primaryLinks are entered incorrectly. Please make sure no extra characters or spaces are present.')
        end
        %/
        switch split2{1}(1:2)
            case 'BS'
                %/ Checks
                if txIndex > BSnum
                    error(['BS' num2str(txIndex) ' does not exist. Make sure it is added in topology.nodes.']);
                end
                %/
                if simParams.simulation.simulateDownlink
                    tx              = BS{txIndex};
                else
                    continue;
                end
            case 'UE'
                %/ Checks
                if txIndex > UEnum
                    error(['UE' num2str(txIndex) ' does not exist. Make sure it is added in topology.nodes.']);
                end
                %/
                if simParams.simulation.simulateUplink
                    tx              = UE{txIndex};
                    ueIndex         = txIndex;
                else
                    continue;
                end
            otherwise
                error('The nodes name must start with either "BS" or "UE". Please check the entered primaryLinks.');
        end
        
        % receiver index
        rxIndex = str2double(split2{2}(3:end));
        %/ Checks
        if isnan(rxIndex)
            error('The nodes in topology.primaryLinks are entered incorrectly. Please make sure no extra characters or spaces are present.')
        end
        %/
        switch split2{2}(1:2)
            case 'BS'
                %/ Checks
                if rxIndex > BSnum
                    error(['BS' num2str(rxIndex) ' does not exist. Make sure it is added in topology.nodes.']);
                end
                %/
                if simParams.simulation.simulateUplink
                    rx      = BS{rxIndex};
                else
                    continue;
                end
            case 'UE'
                %/ Checks
                if rxIndex > UEnum
                    error(['UE' num2str(rxIndex) ' does not exist. Make sure it is added in topology.nodes.']);
                end
                %/
                if simParams.simulation.simulateDownlink
                    rx      = UE{rxIndex};
                    ueIndex = rxIndex;
                else
                    continue;
                end
            otherwise
                error('The nodes name must start with either "BS" or "UE". Please check the entered primaryLinks.');
        end
        rx.attachTransmitNode(tx.ID, tx.Type);
        tx.attachReceiveNode(rx.ID, rx.Type);
        
        % assign direction for the link
        if(strcmp(tx.Type,'BaseStation') && strcmp(rx.Type,'User'))
            direction = 'Downlink';
            nDownlinks = nDownlinks + 1;
        elseif(strcmp(tx.Type,'User') && strcmp(rx.Type,'BaseStation'))
            direction = 'Uplink';
            nUplinks = nUplinks + 1;
        elseif(strcmp(tx.Type,'User') && strcmp(rx.Type,'User'))
            direction = 'D2D';
            nD2Dlinks = nD2Dlinks + 1;
        else
            direction = [];
        end
        
        %/ Checks
        if ~isempty(Links{tx.ID, rx.ID})
            error(['A link from the ' tx.Type ' with ID ' num2str(tx.ID)  ' to the ' rx.Type ' with ID ' num2str(rx.ID) ', already exists. Please check for any duplicate links in topology.primaryLinks.']);
        end
        %/
        
        Links{tx.ID, rx.ID} =  Elements.Link(ii, 'Primary', direction, tx.ID, rx.ID, 'CC', simParams.simulation.userVelocity(ueIndex) , 0, tx.nAntennaPorts, tx.nAntennas, tx.arrayConfiguration, rx.nAntennaPorts, rx.nAntennas, rx.arrayConfiguration,simParams.modulation.transmissionMode);
        linkID = linkID + 1;
    end
end
%/ Checks
if nDownlinks == 0 && simParams.simulation.simulateDownlink
    error('Downlink simulations are selected, however, there is not a single link from a user to a base station. To simulate downlink, add at least one downlink to the topology.');
end
if nUplinks == 0 && simParams.simulation.simulateUplink
    error('Uplink simulations are selected, however, there is not a single link from a base station to a user. To simulate uplink, add at least one uplink to the topology.');
end
% if nD2Dlinks == 0 && simParams.simulation.simulateD2D
%     error('D2D simulations are selected, however, there is not a single link from a user to a user. To simulate D2D, add at least one D2D link to the topology.');
% end
%/

% Generation of Secondary Links
if INnum >0
switch simParams.topology.secondaryGeneration
    case 'Manual'
        split1 = strsplit(simParams.topology.secondaryLinks,',');
        simParams.topology.secondaryLinkNumber = length(split1);
        for ii = 1:length(split1)
            split2 = strsplit(split1{ii},':');
            if strcmp(split2, '') == 0
                % transmitter index
                switch split2{1}(1:2)
                    case 'BS'
                        txIndex = str2double(split2{1}(3:end));
                    case 'UE'
                        txIndex = str2double(split2{1}(3:end));
                    case 'RI'
                        txIndex = str2double(split2{1}(4:end));
                end
                %/ Checks
                if isnan(txIndex)
                    error('The nodes in topology.SecondaryLinks are entered incorrectly. Please make sure no extra characters or spaces are present.')
                end
                
                switch split2{1}(1:2)
                    case 'BS'
                        %/ Checks
                        if txIndex > BSnum
                            error(['BS' num2str(txIndex) ' does not exist. Make sure it is added in topology.nodes.']);
                        end
                        %/
                        if simParams.simulation.simulateDownlink
                            tx              = BS{txIndex};
                        else
                            continue;
                        end
                        
                    case 'UE'
                        %/ Checks
                        if txIndex > UEnum
                            error(['UE' num2str(txIndex) ' does not exist. Make sure it is added in topology.nodes.']);
                        end
                        %/
                        if simParams.simulation.simulateUplink
                            tx              = UE{txIndex};
                            ueIndex         = txIndex;
                        else
                            continue;
                        end
                        
                    case 'RI'
                        %/ Checks
                        if txIndex > INnum
                            error(['RIS' num2str(txIndex) ' does not exist. Make sure it is added in topology.nodes.']);
                        end
                        tx              = IN{txIndex};
                end
                
                % receiver index
                split3 = strsplit(split2{2},'*');
                switch split3{1}(1:2)
                    case 'BS'
                        rxIndex = str2double(split3{1}(3:end));
                    case 'UE'
                        rxIndex = str2double(split3{1}(3:end));
                    case 'RI'
                        rxIndex = str2double(split3{1}(4:end));
                end
                
                %/ Checks
                if isnan(rxIndex)
                    error('The nodes in topology.primaryLinks are entered incorrectly. Please make sure no extra characters or spaces are present.')
                end
                
                switch split3{1}(1:2)
                    case 'BS'
                        %/ Checks
                        if rxIndex > BSnum
                            error(['BS' num2str(rxIndex) ' does not exist. Make sure it is added in topology.nodes.']);
                        end
                        %/
                        if simParams.simulation.simulateUplink
                            rx      = BS{rxIndex};
                        else
                            continue;
                        end
                    case 'UE'
                        %/ Checks
                        if rxIndex > UEnum
                            error(['UE' num2str(rxIndex) ' does not exist. Make sure it is added in topology.nodes.']);
                        end
                        %/
                        if simParams.simulation.simulateDownlink
                            rx      = UE{rxIndex};
                            ueIndex = rxIndex;
                        else
                            continue;
                        end
                    case 'RI'
                        %/ Checks
                        if rxIndex > INnum
                            error(['RIS' num2str(txIndex) ' does not exist. Make sure it is added in topology.nodes.']);
                        end
                        rx              = IN{rxIndex};
                        
                    otherwise
                        error('The nodes name must start with either "BS", "UE" or "RIS" . Please check the entered primaryLinks.');
                end
                rx.attachTransmitNode(tx.ID, tx.Type);
                tx.attachReceiveNode(rx.ID, rx.Type);
                
                % assign direction for the link
                if(strcmp(tx.Type,'BaseStation') && strcmp(rx.Type,'User'))
                    direction = 'Downlink';
                    nDownlinks = nDownlinks + 1;
                elseif(strcmp(tx.Type,'BaseStation') && strcmp(rx.Type,'RIS'))
                    direction = 'Downlink';
                    nDownlinks = nDownlinks + 1;
                elseif(strcmp(tx.Type,'RIS') && strcmp(rx.Type,'User'))
                    direction = 'Downlink';
                    nDownlinks = nDownlinks + 1;
                elseif(strcmp(tx.Type,'User') && strcmp(rx.Type,'BaseStation'))
                    direction = 'Uplink';
                    nUplinks = nUplinks + 1;
                elseif(strcmp(tx.Type,'User') && strcmp(rx.Type,'RIS'))
                    direction = 'Uplink';
                    nUplinks = nUplinks + 1;
                elseif(strcmp(tx.Type,'RIS') && strcmp(rx.Type,'BaseStation'))
                    direction = 'Uplink';
                    nUplinks = nUplinks + 1;
                elseif(strcmp(tx.Type,'User') && strcmp(rx.Type,'User'))
                    direction = 'D2D';
                    nD2Dlinks = nD2Dlinks + 1;
                else
                    direction = [];
                end
                
                %/ Checks
                if ~isempty(Links{tx.ID, rx.ID})
                    error(['A link from the ' tx.Type ' with ID ' num2str(tx.ID)  ' to the ' rx.Type ' with ID ' num2str(rx.ID) ', already exists. Please check for any duplicate links in topology.secondaryLinks.']);
                end
                
                if simParams.channel.spatialChannelModel
                    if simParams.topology.geometricLayout
                        if length(split3) ~= 2
                            error('For each secondary link you have to specify the following parameters: K-factor.')
                        else
                            simParams.topology.secondary.kFactors(tx.ID, rx.ID) = str2double(split3{2});
                        end
                    else
                        if length(split3) ~= 5
                            error('For each secondary link you have to specify the following parameters: path loss, K-factor, AOA and ZOA.')
                        else
                            if strcmp(simParams.simulation.sweepParam,'topology.secondary.pathloss') && strcmp(simParams.topology.secondaryGeneration,'Manual') && simParams.simulation.applySweepingTo(ii)
                                simParams.topology.secondary.pathloss(tx.ID, rx.ID) = simParams.topology.secondary.pathloss(ii);
                            else
                                simParams.topology.secondary.pathloss(tx.ID, rx.ID) = str2double(split3{2});
                            end
                            simParams.topology.secondary.kFactors(tx.ID, rx.ID) = str2double(split3{3});
                            simParams.topology.secondary.angleMeanAOA(tx.ID, rx.ID) = str2double(split3{4});
                            simParams.topology.secondary.angleMeanZOA(tx.ID, rx.ID) = str2double(split3{5});
                        end
                    end
                else
                    if simParams.topology.geometricLayout
                        if length(split3) ~= 1
                            error('For each secondary link you have to specify the following parameters: none.')
                        end
                    else
                        if length(split3) ~= 2
                            error('For each secondary link you have to specify the following parameters: path loss.')
                        end
                        if strcmp(simParams.simulation.sweepParam,'topology.secondary.pathloss') && strcmp(simParams.topology.secondaryGeneration,'Manual') && simParams.simulation.applySweepingTo(ii)
                            simParams.topology.secondary.pathloss(tx.ID, rx.ID) = simParams.topology.secondary.pathloss(ii);
                        else
                            simParams.topology.secondary.pathloss(tx.ID, rx.ID) = str2double(split3{2});
                        end
                    end
                    
                end
                if length(split3)>2 && str2double(split3{2}) < 0
                    error('The pathl loss of the secondary links has to be positive.');
                end
                Links{tx.ID, rx.ID} =  Elements.Link(ii, 'Secondary', direction, tx.ID, rx.ID, 'CC', simParams.simulation.userVelocity(ueIndex) , 0, tx.nAntennaPorts, tx.nAntennas, tx.arrayConfiguration, rx.nAntennaPorts, rx.nAntennas, rx.arrayConfiguration, simParams.modulation.transmissionMode);
               nSecondaryLinks = nSecondaryLinks + 1;  
            end
        end
        %/ Checks
        if nDownlinks == 0 && simParams.simulation.simulateDownlink
            error('Downlink simulations are selected, however, there is not a single link from a user to a base station. To simulate downlink, add at least one downlink to the topology.');
        end
        if nUplinks == 0 && simParams.simulation.simulateUplink
            error('Uplink simulations are selected, however, there is not a single link from a base station to a user. To simulate uplink, add at least one uplink to the topology.');
        end
%         if nD2Dlinks == 0 && simParams.simulation.simulateD2D
%             error('D2D simulations are selected, however, there is not a single link from a user to a user. To simulate D2D, add at least one D2D link to the topology.');
%         end
        simParams.topology.nSecondaryLinks = nSecondaryLinks;
    case 'Automatic'       
        % Connect the BS to the RISs it controls based on
        % simParams.topology.RISControllerBS = [{'BS1'},{'BS2'}]
        %      1, find each paar.
        %      2, set tx and rx based on down and up link, instantiate this link.
        %      3, node attach, parameter set and so on.
        SecondaryLinkID = 0;
        for iRIS = 1:length(IN)
            
            if simParams.simulation.simulateDownlink
                tx = BS{controllerBS(iRIS)};
                rx = IN{iRIS};
                %/ Checks
                if ~isempty(Links{tx.ID, rx.ID})
                    error(['A link from the ' tx.Type ' with ID ' num2str(tx.ID)  ' to the ' rx.Type ' with ID ' num2str(rx.ID) ', already exists. Please check for any duplicate links in topology.secondaryLinks.']);
                end
                SecondaryLinkID = SecondaryLinkID+1;
                Links{tx.ID, rx.ID} =  Elements.Link(SecondaryLinkID, 'Secondary', 'Downlink', tx.ID, rx.ID, 'CC', 0, 0, tx.nAntennaPorts, tx.nAntennas, tx.arrayConfiguration, rx.nAntennaPorts, rx.nAntennas, rx.arrayConfiguration, simParams.modulation.transmissionMode);
                nSecondaryLinks = nSecondaryLinks + 1;  
                rx.attachTransmitNode(tx.ID, tx.Type);
                tx.attachReceiveNode(rx.ID, rx.Type);
                
                %simParams.topology.secondary.pathloss(tx.ID, rx.ID) = simParams.topology.secondary.pathloss;
                simParams.topology.secondary.angleMeanAOA(tx.ID, rx.ID) = 360*rand(1);
                simParams.topology.secondary.angleMeanZOA(tx.ID, rx.ID) = 180*rand(1);
                simParams.topology.secondary.kFactors(tx.ID, rx.ID) = simParams.topology.secondary.kFactor;
            end
            
            if simParams.simulation.simulateUplink
                rx = BS{controllerBS(iRIS)};
                tx = IN{iRIS};
                %/ Checks
                if ~isempty(Links{tx.ID, rx.ID})
                    error(['A link from the ' tx.Type ' with ID ' num2str(tx.ID)  ' to the ' rx.Type ' with ID ' num2str(rx.ID) ', already exists. Please check for any duplicate links in topology.secondaryLinks.']);
                end
                SecondaryLinkID = SecondaryLinkID+1;
                Links{tx.ID, rx.ID} =  Elements.Link(SecondaryLinkID, 'Secondary', 'Uplink', tx.ID, rx.ID, 'CC', 0, 0, tx.nAntennaPorts, tx.nAntennas, tx.arrayConfiguration, rx.nAntennaPorts, rx.nAntennas, rx.arrayConfiguration, simParams.modulation.transmissionMode);
                nSecondaryLinks = nSecondaryLinks + 1;  
                rx.attachTransmitNode(tx.ID, tx.Type);
                tx.attachReceiveNode(rx.ID, rx.Type);
                
                %simParams.topology.secondary.pathloss(tx.ID, rx.ID) = simParams.topology.secondary.pathloss;
                simParams.topology.secondary.angleMeanAOA(tx.ID, rx.ID) = 360*rand(1);
                simParams.topology.secondary.angleMeanZOA(tx.ID, rx.ID) = 180*rand(1);
                simParams.topology.secondary.kFactors(tx.ID, rx.ID) = simParams.topology.secondary.kFactor;
            end
            
            if strcmp(simParams.simulation.codebook,'5G') || simParams.channel.spatialChannelModel
                    if strcmp(tx.Type,'BaseStation') || strcmp(tx.Type,'RIS')
                        Links{tx.ID, rx.ID}.txArrayConfiguration = tx.arrayConfiguration;
                    end
                    if strcmp(rx.Type,'BaseStation') || strcmp(rx.Type,'RIS')
                        Links{tx.ID, rx.ID}.rxArrayConfiguration = rx.arrayConfiguration;
                    end
            end
            
        end
        
        % Connect the RIS to the UE which are connected to the BS controlling the RIS
        %      1, find each paar.
        %      2, set tx and rx based on down and up link, instantiate this link.
        %      3, node attach, parameter set and so on.
        for iRIS = 1:length(IN)
            
            controlBSforCurrentRIS  = BS{controllerBS(iRIS)};
            
            if simParams.simulation.simulateDownlink
                for iUE = 1:UEnum
                    if  ismember(UE{iUE}.ID,controlBSforCurrentRIS.ReceiverDL)
                        tx = IN{iRIS};
                        rx = UE{iUE};
                        if ~isempty(Links{tx.ID, rx.ID})
                            error(['A link from the ' tx.Type ' with ID ' num2str(tx.ID)  ' to the ' rx.Type ' with ID ' num2str(rx.ID) ', already exists. Please check for any duplicate links in topology.secondaryLinks.']);
                        end
                        
                        SecondaryLinkID = SecondaryLinkID+1;
                        Links{tx.ID, rx.ID} =  Elements.Link(SecondaryLinkID, 'Secondary', 'Downlink', tx.ID, rx.ID, 'CC', simParams.simulation.userVelocity(ueIndex) , 0, tx.nAntennaPorts, tx.nAntennas, tx.arrayConfiguration, rx.nAntennaPorts, rx.nAntennas, rx.arrayConfiguration, simParams.modulation.transmissionMode);
                        nSecondaryLinks = nSecondaryLinks + 1;
                        rx.attachTransmitNode(tx.ID, tx.Type);
                        tx.attachReceiveNode(rx.ID, rx.Type);
                        
                        %simParams.topology.secondary.pathloss(tx.ID, rx.ID) = simParams.topology.secondary.pathloss;
                        simParams.topology.secondary.angleMeanAOA(tx.ID, rx.ID) = 360*rand(1);
                        simParams.topology.secondary.angleMeanZOA(tx.ID, rx.ID) = 180*rand(1);
                        simParams.topology.secondary.kFactors(tx.ID, rx.ID) = simParams.topology.secondary.kFactor;
                    end
                end
            end
            
            if simParams.simulation.simulateUplink
                for iUE = 1:UEnum
                    if  ismember(UE{iUE}.ID,controlBSforCurrentRIS.TransmitterUL)
                        rx = IN{iRIS};
                        tx = UE{iUE};
                        if ~isempty(Links{tx.ID, rx.ID})
                            error(['A link from the ' tx.Type ' with ID ' num2str(tx.ID)  ' to the ' rx.Type ' with ID ' num2str(rx.ID) ', already exists. Please check for any duplicate links in topology.secondaryLinks.']);
                        end
                        SecondaryLinkID = SecondaryLinkID+1;
                        Links{tx.ID, rx.ID} =  Elements.Link(SecondaryLinkID, 'Secondary', 'Uplink', tx.ID, rx.ID, 'CC', simParams.simulation.userVelocity(ueIndex) , 0, tx.nAntennaPorts, tx.nAntennas, tx.arrayConfiguration, rx.nAntennaPorts, rx.nAntennas, rx.arrayConfiguration, simParams.modulation.transmissionMode);
                                        rx.attachTransmitNode(tx.ID, tx.Type);
                        nSecondaryLinks = nSecondaryLinks + 1; 
                        tx.attachReceiveNode(rx.ID, rx.Type);
                        simParams.topology.secondary.angleMeanAOA(tx.ID, rx.ID) = 360*rand(1);
                        simParams.topology.secondary.angleMeanZOA(tx.ID, rx.ID) = 180*rand(1);
                        simParams.topology.secondary.kFactors(tx.ID, rx.ID) = simParams.topology.secondary.kFactor;
                    end
                end
            end
        end
        simParams.topology.secondaryLinkNumber = SecondaryLinkID;
end
end


% Generation of Interference Links
nNodes  = BSnum + UEnum + INnum;
simParams.topology.interferer.kFactors = zeros(nNodes);
simParams.topology.interferer.angleMeanAOA = zeros(nNodes);
simParams.topology.interferer.angleMeanZOA = zeros(nNodes);
switch simParams.topology.interferenceGeneration
    case 'Automatic'
        %/ Checks
        if simParams.topology.interferer.attenuation < 0
            error('The attenuation value of the interference links has to be positive. Please check topology.interferer.attenuation.');
        end
        %/
        %find the interference link between BS and UE
        for iBS = 1:length(BS)
            BSID = BS{iBS}.ID;
            for iUE = 1:length(UE)
                UEID = UE{iUE}.ID;
                if isempty(Links{BSID, UEID}) && simParams.simulation.simulateDownlink && ~isempty(BS{iBS}.ReceiverDL)
                    UE{iUE}.attachTransmitNode(BSID, 'BaseStation');
                    BS{iBS}.attachReceiveNode(UEID, 'User');
                    
                    Links{BSID, UEID} =  Elements.Link(0, 'Interference', 'Downlink', BSID, UEID, 'CC', simParams.simulation.userVelocity(iUE), simParams.topology.interferer.attenuation, BS{iBS}.nAntennaPorts, BS{iBS}.nAntennas, BS{iBS}.arrayConfiguration, UE{iUE}.nAntennaPorts, UE{iUE}.nAntennas, UE{iUE}.arrayConfiguration,simParams.modulation.transmissionMode);
                    nInterferingLinks = nInterferingLinks + 1;
                    simParams.topology.interferer.kFactors(BSID, UEID) = simParams.topology.interferer.kFactor;
                    simParams.topology.interferer.angleMeanAOA(BSID, UEID) = 360*rand(1);
                    simParams.topology.interferer.angleMeanZOA(BSID, UEID) = 180*rand(1);                    
                end
                if isempty(Links{UEID, BSID}) && simParams.simulation.simulateUplink && ~isempty(UE{iUE}.ReceiverUL)
                    BS{iBS}.attachTransmitNode(UEID, 'User');
                    UE{iUE}.attachReceiveNode(BSID, 'BaseStation');
                    
                    Links{UEID, BSID} =  Elements.Link(0, 'Interference', 'Uplink', UEID, BSID, 'CC', simParams.simulation.userVelocity(iUE), simParams.topology.interferer.attenuation, UE{iUE}.nAntennaPorts, UE{iUE}.nAntennas, UE{iUE}.arrayConfiguration, BS{iBS}.nAntennaPorts, BS{iBS}.nAntennas, BS{iBS}.arrayConfiguration, simParams.modulation.transmissionMode);
                    nInterferingLinks = nInterferingLinks + 1;
                    simParams.topology.interferer.kFactors(UEID, BSID) = simParams.topology.interferer.kFactor;
                    simParams.topology.interferer.angleMeanAOA(UEID, BSID) = 360*rand(1);
                    simParams.topology.interferer.angleMeanZOA(UEID, BSID) = 180*rand(1);

                    tx = UE{iUE};
                    rx = BS{iBS};
                    if strcmp(simParams.simulation.codebook,'5G') || simParams.channel.spatialChannelModel
                        if strcmp(tx.Type,'BaseStation')
                            Links{tx.ID, rx.ID}.txArrayConfiguration = tx.arrayConfiguration;
                        end
                        if strcmp(rx.Type,'BaseStation')
                            Links{tx.ID, rx.ID}.rxArrayConfiguration = rx.arrayConfiguration;
                        end
                    end
                end
            end
        end
        
        if INnum >0
            %find the interference link between BS and RIS
            for iBS = 1:length(BS)
                BSID = BS{iBS}.ID;
                for iRIS = 1:length(IN)
                    RISID = IN{iRIS}.ID;
                    if isempty(Links{BSID, RISID}) && simParams.simulation.simulateDownlink && ~isempty(BS{iBS}.ReceiverDL)
                        IN{iRIS}.attachTransmitNode(BSID, 'BaseStation');
                        BS{iBS}.attachReceiveNode(RISID, 'RIS');
                        
                        Links{BSID, RISID} =  Elements.Link(0, 'Interference', 'Downlink', BSID, RISID, 'CC', 0, simParams.topology.interferer.attenuation, BS{iBS}.nAntennaPorts, BS{iBS}.nAntennas, BS{iBS}.arrayConfiguration,  IN{iRIS}.nAntennaPorts, IN{iRIS}.nAntennas, IN{iRIS}.arrayConfiguration, simParams.modulation.transmissionMode);
                        nInterferingLinks = nInterferingLinks + 1;
                        simParams.topology.interferer.kFactors(BSID, RISID) = simParams.topology.interferer.kFactor;
                        simParams.topology.interferer.angleMeanAOA(BSID, RISID) = 360*rand(1);
                        simParams.topology.interferer.angleMeanZOA(BSID, RISID) = 180*rand(1);                        
                    end
                end
            end

            %find the interference link between RIS and UE
            for iUE = 1:length(UE)
                UEID = UE{iUE}.ID;
                for iRIS = 1:length(IN)
                    RISID = IN{iRIS}.ID;
                    if isempty(Links{UEID,RISID}) && simParams.simulation.simulateUplink && ~isempty(UE{iUE}.ReceiverUL)
                        UE{iUE}.attachReceiveNode(RISID, 'RIS');
                        IN{iRIS}.attachTransmitNode(UEID, 'User'); 

                        Links{UEID, RISID} =  Elements.Link(0, 'Interference', 'Uplink', UEID, RISID, 'CC', simParams.simulation.userVelocity(iUE), simParams.topology.interferer.attenuation, UE{iUE}.nAntennaPorts, UE{iUE}.nAntennas, UE{iUE}.arrayConfiguration, IN{iRIS}.nAntennaPorts, IN{iRIS}.nAntennas, IN{iRIS}.arrayConfiguration, simParams.modulation.transmissionMode);
                        nInterferingLinks = nInterferingLinks + 1;
                        simParams.topology.interferer.kFactors(RISID, UEID) = simParams.topology.interferer.kFactor;
                        simParams.topology.interferer.angleMeanAOA(RISID, UEID) = 360*rand(1);
                        simParams.topology.interferer.angleMeanZOA(RISID, UEID) = 180*rand(1);
                    end


                    if isempty(Links{RISID, UEID}) && simParams.simulation.simulateDownlink && ~isempty(IN{iRIS}.TransmitterDL)
                        UE{iUE}.attachTransmitNode(RISID, 'RIS');
                        IN{iRIS}.attachReceiveNode(UEID, 'User');
             
                        Links{RISID, UEID} =  Elements.Link(0, 'Interference', 'Downlink', RISID, UEID, 'CC', simParams.simulation.userVelocity(iUE), simParams.topology.interferer.attenuation, IN{iRIS}.nAntennaPorts, IN{iRIS}.nAntennas, IN{iRIS}.arrayConfiguration, UE{iUE}.nAntennaPorts, UE{iUE}.nAntennas, UE{iUE}.arrayConfiguration, simParams.modulation.transmissionMode);
                        nInterferingLinks = nInterferingLinks + 1;
                        simParams.topology.interferer.kFactors(RISID, UEID) = simParams.topology.interferer.kFactor;
                        simParams.topology.interferer.angleMeanAOA(RISID, UEID) = 360*rand(1);
                        simParams.topology.interferer.angleMeanZOA(RISID, UEID) = 180*rand(1);
                    end
                end
            end
            %find the interference link between RIS and UE
            for iBS = 1:length(BS)
                BSID = BS{iBS}.ID;
                for iRIS = 1:length(IN)
                    RISID = IN{iRIS}.ID;
                    if isempty(Links{RISID, BSID}) && simParams.simulation.simulateUplink && ~isempty(IN{iRIS}.TransmitterUL)
                        BS{iBS}.attachTransmitNode(RISID, 'RIS');
                        IN{iRIS}.attachReceiveNode(BSID, 'BaseStation');
                        
                        Links{RISID, BSID} =  Elements.Link(0, 'Interference', 'Uplink', RISID, BSID, 'CC', 0, simParams.topology.interferer.attenuation, IN{iRIS}.nAntennaPorts, IN{iRIS}.nAntennas, IN{iRIS}.arrayConfiguration, BS{iBS}.nAntennaPorts, BS{iBS}.nAntennas, BS{iBS}.arrayConfiguration, simParams.modulation.transmissionMode);
                        nInterferingLinks = nInterferingLinks + 1;
                        simParams.topology.interferer.kFactors(RISID, BSID) = simParams.topology.interferer.kFactor;
                        simParams.topology.interferer.angleMeanAOA(RISID, BSID) = 360*rand(1);
                        simParams.topology.interferer.angleMeanZOA(RISID, BSID) = 180*rand(1);
                    end
                end
            end        
        end
        simParams.topology.nInterferingLinks = nInterferingLinks;
    case 'Manual'
        split1 = strsplit(simParams.topology.interferingLinks,',');
        for ii = 1:length(split1)
            split2 = strsplit(split1{ii},':');
            if strcmp(split2, '') == 0
                % transmitter index
                switch split2{1}(1:2)
                    case 'BS'
                        txIndex = str2double(split2{1}(3:end));
                    case 'UE'
                        txIndex = str2double(split2{1}(3:end));
                    case 'RI'
                        txIndex = str2double(split2{1}(4:end));
                end
                %\ Checks
                if isnan(txIndex)
                    error('The nodes in topology.interferingLinks are entered incorrectly. Please make sure no extra characters or spaces are present.')
                end
                %\
                switch split2{1}(1:2)
                    case 'BS'
                        %/ Checks
                        if txIndex > BSnum
                            error(['BS' num2str(txIndex) ' does not exist. Make sure it is added in topology.nodes.']);
                        end
                        %/
                        tx              = BS{txIndex};
                    case 'UE'
                        %/ Checks
                        if txIndex > UEnum
                            error(['UE' num2str(txIndex) ' does not exist. Make sure it is added in topology.nodes.']);
                        end
                        %/
                        tx              = UE{txIndex};
                        ueIndex         = rxIndex;
                    case 'RI'
                        %/ Checks
                        if txIndex > INnum
                            error(['RIS' num2str(txIndex) ' does not exist. Make sure it is added in topology.nodes.']);
                        end
                        %/
                        tx              = IN{txIndex};
                end
                
                % receiver index
                split3 = strsplit(split2{2},'*');
                switch split3{1}(1:2)
                    case 'BS'
                        rxIndex = str2double(split3{1}(3:end));
                    case 'UE'
                        rxIndex = str2double(split3{1}(3:end));
                    case 'RI'
                        rxIndex = str2double(split3{1}(4:end));
                end
                %\ Checks
                if isnan(rxIndex)
                    error('The nodes in topology.interferingLinks are entered incorrectly. Please make sure no extra characters or spaces are present.')
                end
                %\
                switch split3{1}(1:2)
                    case 'BS'
                        %/ Checks
                        if rxIndex > BSnum
                            error(['BS' num2str(rxIndex) ' does not exist. Make sure it is added in topology.nodes.']);
                        end
                        %/
                        
                        rx      = BS{rxIndex};
                    case 'UE'
                        %/ Checks
                        if rxIndex > UEnum
                            error(['UE' num2str(rxIndex) ' does not exist. Make sure it is added in topology.nodes.']);
                        end
                        %/
                        
                        rx      = UE{rxIndex};
                        ueIndex = rxIndex;
                    case 'RI'
                        %/ Checks
                        if txIndex > INnum
                            error(['RIS' num2str(txIndex) ' does not exist. Make sure it is added in topology.nodes.']);
                        end
                        %/
                        rx              = IN{rxIndex};
                end
                % assign direction for the link
                if(strcmp(tx.Type,'BaseStation') && strcmp(rx.Type,'User'))
                    direction = 'Downlink';
                    nDownlinks = nDownlinks + 1;
                elseif(strcmp(tx.Type,'BaseStation') && strcmp(rx.Type,'RIS'))
                    direction = 'Downlink';
                    nDownlinks = nDownlinks + 1;
                elseif(strcmp(tx.Type,'RIS') && strcmp(rx.Type,'User'))
                    direction = 'Downlink';
                    nDownlinks = nDownlinks + 1;
                elseif(strcmp(tx.Type,'User') && strcmp(rx.Type,'BaseStation'))
                    direction = 'Uplink';
                    nUplinks = nUplinks + 1;
                elseif(strcmp(tx.Type,'User') && strcmp(rx.Type,'RIS'))
                    direction = 'Uplink';
                    nUplinks = nUplinks + 1;
                elseif(strcmp(tx.Type,'RIS') && strcmp(rx.Type,'BaseStation'))
                    direction = 'Uplink';
                    nUplinks = nUplinks + 1;
                elseif(strcmp(tx.Type,'User') && strcmp(rx.Type,'User'))
                    direction = 'D2D';
                else
                    direction = [];
                end
                rx.attachTransmitNode(tx.ID, tx.Type);
                tx.attachReceiveNode(rx.ID, rx.Type);
                
                %/ Checks
                if ~isempty(Links{tx.ID, rx.ID})
                    error(['A link from the ' tx.Type ' with ID ' num2str(tx.ID)  ' to the ' rx.Type ' with ID ' num2str(rx.ID) ', already exists. Please check for any duplicate links in topology.interferingLinks.']);
                end

                if simParams.channel.spatialChannelModel
                    if simParams.topology.geometricLayout
                        if length(split3) ~= 2
                            error('For each interferer link you have to specify the following parameters: K-factor.')
                        else
                            simParams.topology.interferer.kFactors(tx.ID, rx.ID) = str2double(split3{2});
                            simParams.topology.interferer.attenuation(tx.ID, rx.ID) = 0;
                        end
                    else
                        if length(split3) ~= 5
                            error('For each interferer link you have to specify the following parameters: path loss, K-factor, AOA and ZOA.')
                        else
                             if strcmp(simParams.simulation.sweepParam,'topology.interferer.attenuation') && strcmp(simParams.topology.interferenceGeneration,'Manual') && simParams.simulation.applySweepingTo(ii)
                                simParams.topology.interferer.attenuation(tx.ID, rx.ID) = simParams.topology.interferer.attenuation(ii);
                            else
                                simParams.topology.interferer.attenuation(tx.ID, rx.ID) = str2double(split3{2});
                            end
                            simParams.topology.interferer.kFactors(tx.ID, rx.ID) = str2double(split3{3});
                            simParams.topology.interferer.angleMeanAOA(tx.ID, rx.ID) = str2double(split3{4});
                            simParams.topology.interferer.angleMeanZOA(tx.ID, rx.ID) = str2double(split3{5});
                        end
                    end
                else
                    if simParams.topology.geometricLayout
                        if length(split3) ~= 1
                            error('For each interferer link you have to specify the following parameters: none.')
                        else
                            simParams.topology.interferer.attenuation(tx.ID, rx.ID) = 0;
                        end
                    else
                        if length(split3) ~= 2
                            error('For each interferer link you have to specify the following parameters: path loss.')
                        end
                        if strcmp(simParams.simulation.sweepParam,'topology.interferer.attenuation') && strcmp(simParams.topology.interferenceGeneration,'Manual') && simParams.simulation.applySweepingTo(ii)
                            simParams.topology.interferer.attenuation(tx.ID, rx.ID) = simParams.topology.interferer.attenuation(ii);
                        else
                            simParams.topology.interferer.attenuation(tx.ID, rx.ID) = str2double(split3{2});
                        end
                    end
                    
                end
                if length(split3)>2 && str2double(split3{2}) < 0
                    error('The pathl loss of the interferer links has to be positive.');
                end
                Links{tx.ID, rx.ID} =  Elements.Link(0, 'Interference', direction, tx.ID, rx.ID, 'CC', simParams.simulation.userVelocity(ueIndex), simParams.topology.interferer.attenuation(tx.ID, rx.ID), tx.nAntennaPorts, tx.nAntennas, tx.arrayConfiguration, rx.nAntennaPorts, rx.nAntennas, rx.arrayConfiguration, simParams.modulation.transmissionMode);
            end
        end
    otherwise
        error('Interference generation type is invalid. Please check topology.interferenceGeneration.');
end
end