classdef IntermediateNode < handle & Elements.Node
    %% The IntermediateNode Class (IntermediateNode)
    %   Authors
    %     - Zeyu Huang
    %   (c) 2021 Institute of Telecommunications, TU Wien.
    %   www.nt.tuwien.ac.at
    %% IntermediateNode Properties
    properties
        TransmitSignal
        ReceiveSignal
        nAntennas
        nAntennaPorts
        nElements
        arrayConfiguration
        phaseShiftPerElement
        reflectCoefficient
    end
    
    %% The IntermediateNode function
    
    %% Initialization
    methods
        %%
        function obj = IntermediateNode(name, type, id, nElements, reflectCoefficient, plotResults)
            obj = obj@Elements.Node(name, id,type, plotResults);
            obj.nElements = nElements(1)*nElements(2);
            obj.arrayConfiguration = nElements;
            obj.reflectCoefficient     = reflectCoefficient;
            obj.nAntennas = nElements(1)*nElements(2);
        end
    end
    %% Transceive Functions
    methods
        function generateTransmitSignal(obj, totalSignal, Links)
            
            % obj.phaseShiftPerElement is  avector
            obj.TransmitSignal = totalSignal*diag(exp(1i*obj.phaseShiftPerElement));
            
            % Just copy it to all connected links. Since they all share the same transmit signal
            for iNODE = 1:length(obj.ReceiverDL)
                Links{obj.ID, obj.ReceiverDL(iNODE)}.TransmitSignal = obj.TransmitSignal;
            end
            for iNODE = 1:length(obj.ReceiverUL)
                Links{obj.ID, obj.ReceiverUL(iNODE)}.TransmitSignal = obj.TransmitSignal;
            end
        end
    end
    
    %% Phase Shift Configuration Functions
    methods
        function update(obj, phaseShifts)
            obj.phaseShiftPerElement = phaseShifts;
        end

        function generateRandomPhaseShiftPerElement(obj)
            obj.phaseShiftPerElement = 2*pi*(0.5-rand(1,obj.nElements));
        end     
    end   
end

