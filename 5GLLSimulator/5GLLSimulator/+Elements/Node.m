classdef Node < handle
%% The Node Class (Node)
%   Authors
%   (c) 2016 Institute of Telecommunications, TU Wien.
%   www.nt.tuwien.ac.at 

%% The Node Properties
% Accessibility
    properties
        Name            % Node name (optional)
        ID              % The unique identifier of this Node
        Type            % Node type: {'BaseStation', 'User', 'RIS or Relay'}
        PlotResults     % Indicate whether this node will get its results plotted or not.
    end
% Connectivity
    properties
        TransmitterDL       % Node transmitting to this Node (ID).
        ReceiverUL          % Node receiving from this Node (ID).
        TransmitterUL          % Node transmitting to this Node (ID).
        ReceiverDL           % Node receiving rom this Nodee (ID).
    end
    
%% The Node Functions
    methods
        function obj = Node(name, id, type, plotResults)
            obj.Name = name;
            obj.ID = id;
            obj.Type = type;
            obj.PlotResults = plotResults;
        end
        function attachTransmitNode(obj, txNodeID, txNodeType)
            switch obj.Type
                case 'BaseStation'
                    obj.TransmitterUL = [obj.TransmitterUL txNodeID];
                case 'User'
                    obj.TransmitterDL = [obj.TransmitterDL txNodeID];
                case 'RIS'
                    switch txNodeType
                        case 'BaseStation'
                            obj.TransmitterDL = [obj.TransmitterDL txNodeID];
                        case 'User'
                            obj.TransmitterUL = [obj.TransmitterUL txNodeID];
                    end                   
            end
        end 

        function attachReceiveNode(obj, rxNodeID, rxNodeType)
            switch obj.Type
                case 'BaseStation'
                    obj.ReceiverDL = [obj.ReceiverDL rxNodeID];
                case 'User'
                    obj.ReceiverUL = [obj.ReceiverUL rxNodeID];
                case 'RIS'
                    switch rxNodeType
                        case 'BaseStation'
                            obj.ReceiverUL = [obj.ReceiverUL rxNodeID];
                        case 'User'
                            obj.ReceiverDL = [obj.ReceiverDL rxNodeID];
                    end
            end
        end
     end   
end

