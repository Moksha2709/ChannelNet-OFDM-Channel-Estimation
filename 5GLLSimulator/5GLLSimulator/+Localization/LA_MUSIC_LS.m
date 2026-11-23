function [estimatedPosition, estimatedAngleAzimuth] = LA_MUSIC_LS(receivedSignal_raw, BS_Locations, BS_Orientations, numOfRxAntennas, antennaDistance, centerFrequency)

%% INITIALIZATION AND CONSTANTS
speedOfLight     = 299792458;
waveLength       = speedOfLight / centerFrequency;
numOfSources     = 1;
nBS              = size(BS_Locations,1);

numberOfAngleSamples = 1.8e4;

%% ANGLE ESTIMATION
% implementation of MUSIC algorithm, as published in
% Multiple emitter location and signal parameter estimation, in 1986, by R. Schmidt
estimatedAngleAzimuth = zeros(1,nBS);
for iBS = 1:nBS
    % multiply receive signal for numerical stability
    x_amp = 1e6 * receivedSignal_raw{iBS}';

    % covariance matrix
    S = x_amp * x_amp';
    
    % calculate noise subspace
    [V,D] = eig(S);
    [~,ind] = sort( abs(diag(D)) );
    E_N = V( :, ind(1:end-numOfSources) );
    
    % equ. (6) The Algorithm
    theta = linspace(0,180,numberOfAngleSamples);
    % define array
    a = exp(1i * 2*pi * (0:numOfRxAntennas{iBS}-1)' * antennaDistance{iBS} * cosd(theta) / waveLength);

    % original version
    %P_MU = 1 ./ diag(a' * E_N * E_N' * a);
    % faster version
    P_MU = 1 ./ dot(a,(E_N*E_N'*a));
    
        [~,ind_max] = max(P_MU);
    
    estimatedAngleAzimuth(iBS) = Utils.Extras.wrapTo360(theta(ind_max) + BS_Orientations{iBS}(1));
end
% todo: detect if signal is coming from front or back of the ULA

%% LS TRIANGULATION METHOD
% implementation of LS triangulation method, as published in
% An LS Localisation Method for Massive MIMO Transmission Systems, in 2019, by M. Rupp, S. Schwarz
slope_apprx = tand(estimatedAngleAzimuth);

BS_location = zeros(2,nBS);
for iBS = 1:nBS
    BS_location(1,iBS) = BS_Locations{iBS}(1);
    BS_location(2,iBS) = BS_Locations{iBS}(2);
    BS_location(3,iBS) = BS_Locations{iBS}(3);
end

A0 = 1              ./ (1 + slope_apprx.^2);
A1 = slope_apprx    ./ (1 + slope_apprx.^2);
A2 = slope_apprx.^2 ./ (1 + slope_apprx.^2);
L  = BS_location(2,:) - slope_apprx.*BS_location(1,:);

R = [sum(A2), -sum(A1); -sum(A1), sum(A0)];
b = [-sum(A1.*L);sum(A0.*L)];

estimatedPosition = [(R\b)', mean(BS_location(3,:))];

end