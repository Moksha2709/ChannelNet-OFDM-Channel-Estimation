function estimatedPosition = friedlander(BSpositions,deltaPositions,deltaDistance,refBS,nBS,dataDimension,corruptedDataIndices,rep)
%This function estimates the UE position based on estimated TDOA and known BS positions
%Friedlander's method has been used. 
%Reference: Friedlander, B.: A Passive Localization Algorithm and Its Accuracy Analysis. IEEE Jour.of Oceanic Engineer. OE-12(1), 234–245 (1987)

%Author: Wilfried Wiedner
%Inputs: BS positions, BS positions relative to reference BS, estimated range differences from BS to ref BS, reference BS,
%        total number of BSs, number of potentially correct TDOA estimates (data dimension), indices of potentially corrupted TOA measurements       
%Returns: estimate of the UE position as a 2D column vector


%set up matrices

%Determine, if deltaDistance contains zero, e.g. measured TOA from BSi to ref BS is the same
zeroIndex = find(deltaDistance == 0); %get index of 
if isempty(zeroIndex) == 0
    dataDimension = dataDimension - 1; %Reduce data dimension
    if(dataDimension < 2)
        warning('Not enough Data to perform Localization');
        return;
    end
    deltaDistance(zeroIndex) = []; %delete zero delta distance
    deltaPositions(:,zeroIndex) = []; %delete delta positions corresponding to zero delta distance    
end
    
Z = zeros(dataDimension,dataDimension);
v = zeros(1,dataDimension);
v(2) = 1;
j = 1;
u = zeros(dataDimension,1);
for iBS = 1:nBS %set up u-vector and Z matrix
    if iBS <= dataDimension
        Z(iBS,:)=circshift(v,iBS-1);
    end
    if iBS == refBS %skip reference BS
        continue
    end
    if ismember(iBS,corruptedDataIndices) || ismember(iBS,zeroIndex+1) %skip data for BS with corrupted/zero TOA measurement 
        continue
    end
    u(j) = 0.5 * (dot(BSpositions{iBS},BSpositions{iBS}) - dot(BSpositions{refBS},BSpositions{refBS}) - deltaDistance(j)^2);
    j = j + 1;
end
S = deltaPositions';
D = diag(deltaDistance);
I = eye(dataDimension);
M = (I - Z)/D;

%estimate position
estimatedPosition = pinv(M*S)*M*u;
end