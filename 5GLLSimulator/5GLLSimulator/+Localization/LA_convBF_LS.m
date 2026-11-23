function [estimatedPosition, estimatedAngleAzimuth] = LA_convBF_LS(receivedSignal_raw, BS_Locations, BS_Orientations, numOfRxAntennas, antennaDistance, centerFrequency)

%% INITIALIZATION AND CONSTANTS
speedOfLight     = 299792458;
waveLength       = speedOfLight / centerFrequency;
numOfSources     = 1;
nBS              = size(BS_Locations,1);

numberOfAngleSamples = 1.8e4;

%% ANGLE ESTIMATION
% implementation of conventional beamformer algorithm, as explained in section 3.4.1 of
% Introduction to Direction-of-Arrival Estimation, by Zhizhang Chen, Gopal Gokeda, Yiqiang Yu
estimatedAngleAzimuth = zeros(1,nBS);
for iBS = 1:nBS
    x = receivedSignal_raw{iBS}';
    Ns = size(x,1);

    % covariance matrix
    Rxx = 1/Ns * x*x';

    theta = linspace(0,180,numberOfAngleSamples);
    % define array manifold, the mentioned book uses different definition of DoA
    a = exp(1i * 2*pi * (0:numOfRxAntennas{iBS}-1)' * antennaDistance{iBS} * cosd(theta) / waveLength);

    % no normalization necessary
    w = a;
    P = dot(w,(Rxx'*w));

    [~,ind_max] = maxk(P,numOfSources);

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