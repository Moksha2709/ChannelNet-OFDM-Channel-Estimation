classdef Block < handle
% Block Object (Block)
%
%   Contains all the necessary information about the transmitted block.
%   Makes the decoding process much faster, since the decoder can obtain all
%   the needed information from this class, instead of having to redo the
%   calculation by itself.  
%
%   Author
%       - Bashar Tahir, bashar.tahir@tuwien.ac.at
%         (c) 2020 Institute of Telecommunications, TU Wien.
%         www.nt.tuwien.ac.at 
%
%%
properties
    InputBlockSize          % Size of the input code block including subblock CRC
    CodedBlockSize          % Size of punctured output coded block
    BaseCodedBlockSize      % Size of unpunctured output coded block
    Index                   % Block index with respect to other blocks
    CRCDetectionResult      % Result of CRC calculation at the decoder
    NrFillerBits = 0        % The number of filler bits used for this block
    NullsMap                % The location of nulls in this block
    SoftBufferLength        % The soft length of the rate matching buffer
    BaseBufferLength        % The base length of rate matching buffer
    HARQBuffer = []         % Stores the previous transmission channel LLRs
    InterleaverRowLength    % For TB-C, Turbo, Polar
    k0                      % The starting position of the current transmission
    K_PI                    % Stream size for Convolutional and Turbo
    MatchedLength           % Length of block after rate matching.
end
% TB-C properties
properties
    InitialState            % Initial state of the TB-C encoder,
end
% Turbo properties
properties 
end
% LDPC properties
properties
% Decoder Part (Tanner Graph)

    LDPCcnMat               % Variable nodes connected to Check nodes
    LDPCvnMat               % Check nodes connected to Variable Node
end
% Polar properties
properties
    Power2Size               % The butterfly size of the Polar encoder
    FrozenSet                % The construced Frozen set for the Polar code
end
%%
methods (Access = public, Hidden = false) 
    function obj = Block(varargin)
    % Construct a new Block class
        obj.InputBlockSize = varargin{2};
        obj.Index          = varargin{3};
        obj.NrFillerBits   = varargin{4};

        C  = varargin{1}.NrCodeBlocks;
        Nl = varargin{1}.Layers;
        Qm = varargin{1}.ModulationOrder;
        G  = varargin{1}.CodedBitsLength;
        
        Gp = G / (Nl * Qm);
        if (obj.Index - 1) <= C - mod(Gp, C) - 1
            obj.MatchedLength = Nl * Qm * floor(Gp / C);
        else
            obj.MatchedLength = Nl * Qm * ceil(Gp / C);
        end    
        
    end
end

end

