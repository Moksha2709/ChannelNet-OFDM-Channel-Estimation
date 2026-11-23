%%
%   Short block length comparison between Convolutional, Turbo, LDPC, and Polar
%   Codes (journal example).
%
%   Author
%       - Bashar Tahir, bashar.tahir@tuwien.ac.at
%         (c) 2020 Institute of Telecommunications, TU Wien.
%         www.nt.tuwien.ac.at 
%
%%
clc;clear;
cd('..');

%% Simulation setup
SNRvecdB = -7:0.5:-1;  % SNR range
numR     = 1000;       % number of simulated frames

%% Information length and code rate
K = 48;

% We take the CRC into account; therefore, the code rate is set to 1/8.
% After the addition of CRC (16 bits), the effective code rate will increase to 1/6.
R = 1/8; 

% (Note that in release 1.1 of the simulator, there was an additional code
% rate defined for LDPC to take into account the impact of filler bits.
% This is no longer needed, since it is now taken care of within the
% channel coding object automatically).

%% Modulation
modOrder = 4;
Mapper = Modulation.SignalConstellation(modOrder, 'QAM', 0, 'Max-Log');

%% The channel coders
coderLDPC = Coding.ChannelCoding('LDPC', 'PWL-Min-Sum', R, 32);  
coderPolar = Coding.ChannelCoding('Polar', 'CRC-List-SC', R, 32);
coderTurbo = Coding.ChannelCoding('Turbo', 'Linear-Log-MAP', R, 16);      
coderConv = Coding.ChannelCoding('TB-Convolutional', 'Max-Log-MAP', R);      

%% Initialization
% Force CRC-16
coderLDPC.CustomCRC  = 1;
coderPolar.CustomCRC = 1;
coderTurbo.CustomCRC = 1;
coderConv.CustomCRC  = 1;

coderLDPC.CRCPoly    = '16';
coderLDPC.CRCLength  = 16;
coderPolar.CRCPoly   = '16';
coderPolar.CRCLength = 16;
coderTurbo.CRCPoly   = '16';
coderTurbo.CRCLength = 16;
coderConv.CRCPoly    = '16';
coderConv.CRCLength  = 16;

% Update the objects
coderLDPC.update ('Input', K, 1, R, log2(modOrder), 1);
coderPolar.update('Input', K, 1, R, log2(modOrder), 1);
coderTurbo.update('Input', K, 1, R, log2(modOrder), 1);
coderConv.update ('Input', K, 1, R, log2(modOrder), 1);

%% Simulation loop
Results = zeros(numR, length(SNRvecdB), 4);
fprintf(['------- Started -------', '\n']);
d = tic;
parfor m = 1:numR
    st = tic;
    ind = 1;
    resultsPerCoder = zeros(length(SNRvecdB), 4);
    for coder = [coderConv, coderTurbo, coderLDPC, coderPolar]
        coderIn = coder;
        Resultsin = zeros(1, length(SNRvecdB));
        for iSNR = 1:length(SNRvecdB)
            SNRlinear = 10^(SNRvecdB(iSNR)/10);   
            sigma_n2 = 1/SNRlinear;
            
            InputBits = randi([0 1], K, 1);
            CodedBits = coderIn.encode(InputBits);
            yCoded = Mapper.Bit2Symbol(CodedBits);

            yCoded = yCoded + sqrt(sigma_n2/2) .* complex(randn(length(yCoded),1), randn(length(yCoded),1));

            ChannelLLRsCoded = -Mapper.LLR_AWGN(yCoded, sigma_n2);
            DecodedBits = coderIn.decode(ChannelLLRsCoded);

%             Resultsin(iSNR) =  sum(DecodedBits~=InputBits)/(K);          % uncomment this to get BER results.
%             Resultsin(iSNR) = double(sum(DecodedBits~=InputBits)>0);     % uncomment this to get ideal FER results.
            Resultsin(iSNR) = coderIn.CRCDetectionResult;                  % uncomment this to get FER results based on the CRC calculation.
        end
        resultsPerCoder(:,ind) = Resultsin;
        ind = ind + 1;
    end  
    Results(m,:,:) = resultsPerCoder;
    en = toc(st);
    fprintf('Repetition %i/%i.\n',m,numR); 
end
fprintf(['-------- Done --------', '\n']);
toc(d)
%% Plot results
ind = 1;
for coder = [coderConv, coderTurbo, coderLDPC, coderPolar]
    proResults = Results(:,:,ind);
    ind = ind + 1;
    fprintf(['Calculating confidence intervals...', '\n']);
    
    mean_func  = @(inputValue) mean(inputValue);
    framesSent = double(ones(size(proResults)));
    values     = proResults ./ framesSent;
    meanVal    = mean(values);
    mask       = ~isnan(values);
    if mask
        FERMasked  = reshape(values(mask), [], length(SNRvecdB));
        conf       = Utils.Extras.bootci(FERMasked, 0.95, 10^4, mean_func, false);
        conf       = repmat([-1;1], 1, length(SNRvecdB)) .* (conf - repmat(meanVal, 2, 1));
    else
        conf = NaN(2, length(SNRvecdB));
    end

    fprintf(['Done.', '\n']);
    errorbar(SNRvecdB, meanVal, conf(1,:),conf(2,:)); hold on;
end
% plot settings
hold off;
set(gca, 'YScale', 'log');
xlabel('SNR (dB)');
ylabel('FER');
grid on;
ylim([1e-4 1e0]);
legend('convolutional', 'turbo', 'LDPC', 'polar', 'location', 'best')
cd('Examples')