classdef ChannelCoding < handle
% Channel Coding Object (ChannelCoding)
%
%   The object supports the following coding schemes
%       - Tail-baiting convolutional code, LTE-A encoding.
%       - Turbo code, LTE-A encoding.
%       - Low density parity check (LDPC) code, 5G-NR encoding.
%       - Polar code, custom construction.
%     
%   Decoding Algorithms
%       - TB convolutional and turbo codes: Maximum a posteriori (Log-MAP, Max-Log-MAP, Linear-Log-MAP).
%       - LDPC code: Layered belief propagation (Sum-Product, Min-Sum, PWL-Min-Sum).
%       - Polar code: Successive cancellation (List-SC, CRC-List-SC).
%
%   Author
%       - Bashar Tahir, bashar.tahir@tuwien.ac.at
%         (c) 2020 Institute of Telecommunications, TU Wien.
%         www.nt.tuwien.ac.at 
%
%% Public properties
properties (SetAccess = public)
    CodingScheme         % The coding scheme: 'TB-Convolutional', 'Turbo', 'LDPC', 'Polar'
    DecodingAlgorithm    % The decoding algorithm: 'Log-MAP', 'Max-Log-MAP', 'Linear-Log-MAP', 'Sum-Product', 'Min-Sum', 'PWL-Min-Sum', 'List-SC', 'CRC-List-SC'
    CodeRate             % Code rate
    CodedBitsLength      % Total length of coded bits at the encoder output
    CustomCRC = 0        % Indicates whether non-standard CRC is selected
    CRCPoly              % Outter CRC polynomial
    CRCLength            % Outter CRC length
    CRCDetectionResult   % Outter CRC detection result
    HARQType = 'CC'      % HAQR Type: Chase combining (CC) or Incremental redundancy (IR)
    RV = 0;              % Current redundancy version
    SoftBufferRatio = 1  % Control the length of rate matching soft buffer.
    ModulationOrder      % The used modulation order.
    Layers               % The number of spatial layers the codeword is mapped to.
end

%% Read-only public properties
properties (SetAccess = private, Hidden = false)
    NrCodeBlocks         % Number of code blocks
    Blocks = [];         % Blocks container based on the Block class
    Iterations           % Number of decoding iterations   
end

%% CodingComponents objects
properties (SetAccess = private, Hidden = false)
    TBConvCoding         % The TBConvCoding object
    TurboCoding          % The TurboCoding object
    LDPCCoding           % The LDPCCoding object
    PolarCoding          % The PolarCoding object  
    RateMatching         % The RateMatching object 
end

%% Turbo and Convolutional Code properties
properties
    InputBlockSizes   = [40,48,56,64,72,80,88,96,104,112,120,128,136,144,152,160,168,176,184,192,200,208,216,224,232,240,248,256,264,272,280,288,296,304,312,320,328,336,344,352,360,368,376,384,392,400,408,416,424,432,440,448,456,464,472,480,488,496,504,512,528,544,560,576,592,608,624,640,656,672,688,704,720,736,752,768,784,800,816,832,848,864,880,896,912,928,944,960,976,992,1008,1024,1056,1088,1120,1152,1184,1216,1248,1280,1312,1344,1376,1408,1440,1472,1504,1536,1568,1600,1632,1664,1696,1728,1760,1792,1824,1856,1888,1920,1952,1984,2016,2048,2112,2176,2240,2304,2368,2432,2496,2560,2624,2688,2752,2816,2880,2944,3008,3072,3136,3200,3264,3328,3392,3456,3520,3584,3648,3712,3776,3840,3904,3968,4032,4096,4160,4224,4288,4352,4416,4480,4544,4608,4672,4736,4800,4864,4928,4992,5056,5120,5184,5248,5312,5376,5440,5504,5568,5632,5696,5760,5824,5888,5952,6016,6080,6144];   % Supported input codeblock sizes (Based on LTE-A)   
end

%% LDPC Code properties
properties
    LDPCBaseGraph        % Indicates which LDPC basegraph is used
    LDPCZc               % Indicates which extension factor is used.
    TBSTable_NR1 = [24;32;40;48;56;64;72;80;88;96;104;112;120;128;136;144;152;160;168;176;184;192;208;224;240;256;272;288;304;320;336;352;368;384;408;432;456;480;504;528;552;576;608;640;672;704;736;768;808;848;888;928;984;1032;1064;1128;1160;1192;1224;1256;1288;1320;1352;1416;1480;1544;1608;1672;1736;1800;1864;1928;2024;2088;2152;2216;2280;2408;2472;2536;2600;2664;2728;2792;2856;2976;3104;3240;3368;3496;3624;3752;3824]; % TBS mapping for LDPC 5G NR
end

%% Polar Code properties
properties
    ListSize              % The list size for the polar list decoder
end

%% Public Methods
methods (Access = public, Hidden = false) 
%%
    function obj = ChannelCoding(varargin)
    % Construct a new ChannelCoding object
    % ChannelCoding1 = ChannelCoding(CodingScheme, DecodingAlgorithm,
    % CodeRate, Iterations)
            obj.CodingScheme = varargin{1};
            obj.DecodingAlgorithm = varargin{2};
            obj.CodeRate = varargin{3}; 
            switch obj.CodingScheme
                case 'TB-Convolutional'
                case 'Turbo'
                    obj.Iterations = varargin{4};
                case 'LDPC'
                    obj.Iterations = varargin{4};
                case 'Polar'
                    obj.ListSize = varargin{4};
                otherwise
                    error('The coding scheme is not valid.');
            end 
            
    end
%%
    function CodedBits = encode(varargin)
    % encode Encode the input bits
    % Pass the input bits to the specific encoder based on the selected
    % CodingScheme, and updates the HARQ parameters.
    %
    % CodedBits = ChannelObject1.Decode(Input bits)
        obj = varargin{1};
        obj.RateMatching.HARQType = obj.HARQType;
        
        InputBits = varargin{2}';
        InputBits = Coding.ChannelCodingComponents.CRC.Attach(InputBits, obj.CRCPoly);

        CodedBits = [];
        BlockStartIndex = 1;
        
        % Add filler bits if needed for TB-Convolutional and Turbo.
        switch obj.CodingScheme
            case {'TB-Convolutional', 'Turbo', 'Polar'}
                InputBits = [zeros(1, obj.Blocks(1).NrFillerBits) InputBits];
        end
 
        for CBi = 1:obj.NrCodeBlocks
            switch obj.CodingScheme
                case {'TB-Convolutional', 'Turbo', 'Polar'}
                    if obj.NrCodeBlocks == 1
                        BlockBits = InputBits(BlockStartIndex:BlockStartIndex + obj.Blocks(CBi).InputBlockSize - 1);
                        BlockStartIndex = BlockStartIndex + obj.Blocks(CBi).InputBlockSize;
                    else
                        BlockBits = Coding.ChannelCodingComponents.CRC.Attach(InputBits(BlockStartIndex:BlockStartIndex + obj.Blocks(CBi).InputBlockSize - 25), '24B');
                        BlockStartIndex = BlockStartIndex + obj.Blocks(CBi).InputBlockSize - 24;
                    end
                case 'LDPC'
                    if obj.NrCodeBlocks == 1
                        BlockBits = [InputBits(BlockStartIndex:BlockStartIndex + obj.Blocks(CBi).InputBlockSize - obj.Blocks(CBi).NrFillerBits - 1) zeros(1,obj.Blocks(CBi).NrFillerBits)];
                        BlockStartIndex = BlockStartIndex + obj.Blocks(CBi).InputBlockSize;
                    else
                        BlockBits = [Coding.ChannelCodingComponents.CRC.Attach(InputBits(BlockStartIndex:BlockStartIndex + obj.Blocks(CBi).InputBlockSize - obj.Blocks(CBi).NrFillerBits - 25), '24B') zeros(1,obj.Blocks(CBi).NrFillerBits)];
                        BlockStartIndex = BlockStartIndex + obj.Blocks(CBi).InputBlockSize - obj.Blocks(CBi).NrFillerBits - 24;
                    end
            end
            
            switch obj.CodingScheme
                case 'TB-Convolutional'
                    CodedBitsBlock = obj.TBConvCoding.Encode(BlockBits, obj.Blocks(CBi));            
                case 'Turbo'
                    CodedBitsBlock = obj.TurboCoding.Encode(BlockBits, obj.Blocks(CBi)); 
                case 'LDPC'
                    CodedBitsBlock = obj.LDPCCoding.Encode(BlockBits, obj.Blocks(CBi)); 
                case 'Polar'
                    CodedBitsBlock = obj.PolarCoding.Encode(BlockBits, obj.Blocks(CBi)); 
                otherwise
                    error('The coding scheme is not valid.');
            end
            
            % Concatenate the coded blocks
            CodedBits = [CodedBits CodedBitsBlock];
        end
        CodedBits = transpose(CodedBits);
    end
 %%   
    function DecodedBits = decode(varargin)
    % decode Decode the input Log-Likelihood Ratios (LLRs)
    % Passes the input LLRs to the specific decoder based on the selected
    % CodingScheme, and performs outter CRC error detection.
    %
    % DecodedBits = ChannelObject1.Decode(Channel LLRs)
        obj = varargin{1};
        UnpuncturedLength = 0;
        for CBi = 1:obj.NrCodeBlocks
            UnpuncturedLength = UnpuncturedLength + obj.Blocks(CBi).MatchedLength;
        end
        ChannelLLRs = zeros(1, UnpuncturedLength);
        ChannelLLRs(1:length(varargin{2})) = varargin{2}';
        
        DecodedBits = [];
        BlockStartIndex = 1;
    
        for CBi = 1:obj.NrCodeBlocks
            ChannelLLRsBlock = ChannelLLRs(BlockStartIndex:BlockStartIndex + obj.Blocks(CBi).MatchedLength - 1);
            BlockStartIndex = BlockStartIndex + obj.Blocks(CBi).MatchedLength;
            
            switch obj.CodingScheme
                case 'TB-Convolutional'
                    DecodedBlockBits = obj.TBConvCoding.Decode(ChannelLLRsBlock, obj.Blocks(CBi));    
                case 'Turbo'
                    DecodedBlockBits = obj.TurboCoding.Decode(ChannelLLRsBlock, obj.Blocks(CBi));    
                case 'LDPC'
                    DecodedBlockBits = obj.LDPCCoding.Decode(ChannelLLRsBlock, obj.Blocks(CBi));    
                case 'Polar'
                    DecodedBlockBits = obj.PolarCoding.Decode(ChannelLLRsBlock, obj.Blocks(CBi)); 
                otherwise
                    error('The coding scheme is not valid.');
            end 
            
            DecodedBits = [DecodedBits DecodedBlockBits];
        end

        if obj.NrCodeBlocks == 1
            obj.CRCDetectionResult = obj.Blocks(1).CRCDetectionResult;
        else
            obj.CRCDetectionResult = Coding.ChannelCodingComponents.CRC.Detect(DecodedBits, obj.CRCPoly); 
        end
        switch obj.CodingScheme
            case {'TB-Convolutional', 'Turbo', 'Polar'}
                % Remove Filler bits
                DecodedBits = transpose(DecodedBits(obj.Blocks(1).NrFillerBits+1:end-obj.CRCLength));
            case 'LDPC'
                % Filler bits are already removed at prior stage
                DecodedBits = transpose(DecodedBits(1:end-obj.CRCLength));
        end
        
    end
 %%   
function requiredInputLength = update(varargin)
    % Updates the object, performs code block segmentation and returns the required input length
    obj                 = varargin{1};  
    obj.Layers          = varargin{4};
    obj.CodeRate        = varargin{5};
    obj.ModulationOrder = varargin{6};
    obj.SoftBufferRatio = varargin{7};

    % Find the required input length if needed, depending on whether
    % the input parameter is the information length or code length.
    switch varargin{2}
        case 'Input'
            inputLength         = varargin{3};
            obj.CodedBitsLength = ceil(inputLength / obj.CodeRate); 
            requiredInputLength = []; 
        case 'Output'
            obj.CodedBitsLength = varargin{3}*obj.Layers;
            inputLength         = obj.determineTBS();
            requiredInputLength = inputLength;
        otherwise
            error(['The length indicator is either ' char(39) 'Input' char(39) ' or ' char(39) 'Output' char(39) '.']);
    end

    % Code block segmenation
    switch obj.CodingScheme
        case {'Turbo', 'TB-Convolutional'}
            % LTE
            if obj.CustomCRC == 0
                obj.CRCPoly = '24A';
                obj.CRCLength = 24;
            end
            B = inputLength + obj.CRCLength;

            Z = 6144;
            if B <= Z
                L = 0;
                C = 1;
                Bp = B;
            else
                L = 24;
                C = ceil(B/(Z-L));
                Bp = B + C*L;
            end
            obj.NrCodeBlocks = C;

            for iKplus = 1:length(obj.InputBlockSizes)
                if C*obj.InputBlockSizes(iKplus) >= Bp
                    Kplus = obj.InputBlockSizes(iKplus);
                    break;
                end
            end
            if C == 1
                Cplus = 1;
                Kminus = 0;
                Cminus = 0;
            elseif C > 1
                Kminus = obj.InputBlockSizes(iKplus - 1);
                dK = Kplus - Kminus;
                Cminus = floor((C*Kplus-Bp)/dK);
                Cplus = C - Cminus;
            end
            F = Cplus*Kplus + Cminus*Kminus - Bp;

            obj.Blocks = [];
            BlkIndex = 1;
            obj.Blocks = [obj.Blocks Coding.ChannelCodingComponents.Block(obj, Kplus, BlkIndex, F)];
            BlkIndex = BlkIndex + 1;
            for i = 2:Cplus
                obj.Blocks = [obj.Blocks Coding.ChannelCodingComponents.Block(obj, Kplus, BlkIndex, 0)];
                BlkIndex = BlkIndex + 1;
            end
            for i = 1:Cminus
                obj.Blocks = [obj.Blocks Coding.ChannelCodingComponents.Block(obj, Kminus, BlkIndex, 0)];
                BlkIndex = BlkIndex + 1;
            end 

        case {'LDPC'} 
            % 5G-NR
            if obj.CustomCRC == 0
                if inputLength > 3824
                    obj.CRCPoly = '24A';
                    obj.CRCLength = 24;
                else
                    obj.CRCPoly = '16';
                    obj.CRCLength = 16;
                end
            end
            B = inputLength + obj.CRCLength;

            if (inputLength <= 292) || (inputLength <=3824 && obj.CodeRate <= 2/3) || (obj.CodeRate <=1/4)
                obj.LDPCBaseGraph = 2;
            else
                obj.LDPCBaseGraph = 1;
            end

            if obj.LDPCBaseGraph == 1
               Kcb = 8448;
            else
               Kcb = 3840;
            end

            if B <= Kcb
                L = 0;
                C = 1;
                Bp = B;
            else
                L = 24;
                C = ceil(B/(Kcb-L));
                Bp = B + C*L;
            end
            obj.NrCodeBlocks = C;

            Kp = Bp/C;
            if obj.LDPCBaseGraph == 1
                Kb = 22;
            else
                if B > 640
                    Kb = 10;
                elseif B > 560
                    Kb = 9;
                elseif B > 192
                    Kb = 8;
                else
                    Kb = 6;
                end
            end
            Zlist = Coding.ChannelCodingComponents.LDPCCoding.LiftingSizeSets;
            Zc = min(Zlist(Kb.*Zlist>=Kp)); 
            obj.LDPCZc = Zc;
            [iSet,~] = find(Zlist==Zc);
            if obj.LDPCBaseGraph == 1
                K = 22*Zc;
            else
                K = 10*Zc;
            end
            obj.Blocks = [];
            for r = 0:C-1
                NrFillerBits = K-Kp;
                obj.Blocks = [obj.Blocks Coding.ChannelCodingComponents.Block(obj, Kp + NrFillerBits, r + 1, NrFillerBits)];
            end
        case {'Polar'}
            if obj.CustomCRC == 0
                obj.CRCPoly = '24A';
                obj.CRCLength = 24;
            end
            B = inputLength + obj.CRCLength;

            Z = 6144;
            if B <= Z
                L = 0;
                C = 1;
                Bp = B;
            else
                L = 24;
                C = ceil(B/(Z-L));
                Bp = B + C*L;
            end
            obj.NrCodeBlocks = C;

            Kplus = ceil(Bp/C);
            Cplus = C;

            obj.Blocks = [];
            BlkIndex = 1;
            for i = 1:Cplus
                if i == Cplus
                    Kplus = Kplus + (Bp - C*Kplus);
                end
                obj.Blocks = [obj.Blocks Coding.ChannelCodingComponents.Block(obj, Kplus, BlkIndex, 0)];
                BlkIndex = BlkIndex + 1;
            end
    end

    obj.RateMatching = Coding.ChannelCodingComponents.RateMatching(obj);
    switch obj.CodingScheme
        case 'TB-Convolutional'       
            obj.TBConvCoding = Coding.ChannelCodingComponents.TBConvCoding(obj);
        case 'Turbo'
            obj.TurboCoding = Coding.ChannelCodingComponents.TurboCoding(obj);
        case 'LDPC'
            obj.LDPCCoding = Coding.ChannelCodingComponents.LDPCCoding(obj, iSet, obj.LDPCBaseGraph, Zc);
        case 'Polar'
            Coding.ChannelCodingComponents.PolarCoding.ConstructPolarCode(obj);
            obj.PolarCoding = Coding.ChannelCodingComponents.PolarCoding(obj);
        otherwise
            error('The coding scheme is not valid.');
    end
end
 
function TBS = determineTBS(varargin)
    % Determine the transport block size (TBS).
    
    obj = varargin{1};  
    switch obj.CodingScheme
        case {'TB-Convolutional', 'Turbo', 'Polar'}  
            TBS = floor(obj.CodedBitsLength * obj.CodeRate);
        case 'LDPC'
            % 5G-NR specs
            N_info = obj.CodedBitsLength * obj.CodeRate;
            if N_info <= 3824
                n          = max(3, floor(log2(N_info)) - 6);
                N_infop    = max(24, 2^n * floor(N_info / 2^n));
                largerTBSs = obj.TBSTable_NR1(obj.TBSTable_NR1 >= N_infop);
                TBS        = largerTBSs(1);
            else
               n       = floor(log2(N_info - 24)) - 5;
               N_infop = max(3840, 2^n * round((N_info - 24) / 2^n));
               if obj.CodeRate <= 1/4
                   C   = ceil((N_infop + 24)/3816);
                   TBS = 8*C*ceil((N_infop + 24) / (8*C)) - 24;
               else
                   if N_infop > 8424
                       C    = ceil((N_infop + 24)/8424);
                       TBS = 8*C*ceil((N_infop + 24) / (8*C)) - 24;
                   else
                       TBS = 8*ceil((N_infop + 24) / 8) - 24;
                   end
               end
            end
        otherwise
            error('The coding scheme is not valid.');
    end
end
end
end
