classdef CRC < handle
% Cyclic Redundancy Check Class (CRC)
%
%   Performs CRC calclation and attachment.
%   Performs CRC error detection.
% 
%   The class supports CRC polynomials based on LTE/5G-NR.
%
%   Author
%       - Bashar Tahir, bashar.tahir@tuwien.ac.at
%         (c) 2020 Institute of Telecommunications, TU Wien.
%         www.nt.tuwien.ac.at 
%
properties (SetAccess = private, Hidden = true)
    % CRC ploymoials from LTE/5G-NR
    
    CRC24A = [1,1,0,0,0,0,1,1,0,0,1,0,0,1,1,0,0,1,1,1,1,1,0,1,1];
    CRC24B = [1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0,1,1];
    CRC24C = [1,1,0,1,1,0,0,1,0,1,0,1,1,0,0,0,1,0,0,0,1,0,1,1,1];
    CRC16 = [1,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,1];
    CRC11 = [1,1,1,0,0,0,1,0,0,0,0,1];
    CRC8 = [1,1,0,0,1,1,0,1,1];
end

methods (Static)
%%
    function CRCAttached = Attach(varargin)
    % Calculates the CRC and attaches it to the input block
    % Calculates the CRC and attaches it to the input block 
    % based on the selected polynomial.
        obj = Coding.ChannelCodingComponents.CRC;
        InputBits = varargin{1};
        switch varargin{2}
            case '24A'
                CRCPoly = obj.CRC24A;
            case '24B'
                CRCPoly = obj.CRC24B;
            case '24C'
                CRCPoly = obj.CRC24C;
            case '16'
                CRCPoly = obj.CRC16;
            case '11'
                CRCPoly = obj.CRC11;
            case '8'
               CRCPoly = obj.CRC8;
        end
        
        CRCAttached = Coding.ChannelCodingComponents.CRCMEX(InputBits, CRCPoly, 0);
        
    end
%%
    function CRCDetected = Detect(varargin)
        % Performs CRC error detection calculation and returns the result
        obj = Coding.ChannelCodingComponents.CRC;
        InputBits = varargin{1};
        switch varargin{2}
            case '24A'
                CRCPoly = obj.CRC24A;
            case '24B'
                CRCPoly = obj.CRC24B;
            case '24C'
                CRCPoly = obj.CRC24C;
            case '16'
                CRCPoly = obj.CRC16;
            case '11'
                CRCPoly = obj.CRC11;
            case '8'
               CRCPoly = obj.CRC8;
        end
        
        CRCDetected = Coding.ChannelCodingComponents.CRCMEX(InputBits, CRCPoly, 1);
        
    end
end
end