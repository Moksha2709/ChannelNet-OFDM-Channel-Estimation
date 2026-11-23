function [estimatedPosition, estimatedAngleAzimuth] = LA_unitESPRIT_LS(receivedSignal_raw, BS_Locations, BS_Orientations, numOfRxAntennas, antennaDistance, centerFrequency)

%% INITIALIZATION AND CONSTANTS
speedOfLight     = 299792458;
angularFrequency = 2*pi*centerFrequency;
numOfSources     = 1;
nBS              = size(BS_Locations,1);

%% ANGLE ESTIMATION
% implementation of unitary ESPRIT algorithm, as explained in section 5.5 of
% Introduction to Direction-of-Arrival Estimation, by Zhizhang Chen, Gopal Gokeda, Yiqiang Yu

estimatedAngleAzimuth = zeros(1,nBS);
for iBS = 1:nBS
    X = receivedSignal_raw{iBS}';
    Nx = size(X,2);
    Rxx = 1/Nx * (X * X');
    
    % generate Q_M using (3.17)
    M = numOfRxAntennas{iBS};
    n = floor(M/2);
    Pi_n = flip(eye(n));
    I_n = eye(n);
    if rem(M,2)     % M odd
        Q_M = 1/sqrt(2) * [I_n, zeros(n,1), 1i*I_n; ...
                           zeros(1,n), sqrt(2), zeros(1,n); ...
                           Pi_n, zeros(n,1), -1i*Pi_n];
    else            % M even
        Q_M = 1/sqrt(2) * [I_n, 1i*I_n;  Pi_n, -1i*Pi_n];
    end
    
    % generate Q_m using (3.17)
    m = numOfRxAntennas{iBS}-1;
    n = floor(m/2);
    Pi_n = flip(eye(n));
    I_n = eye(n);
    if rem(m,2)     % m odd
        Q_m = 1/sqrt(2) * [I_n, zeros(n,1), 1i*I_n; ...
                           zeros(1,n), sqrt(2), zeros(1,n); ...
                           Pi_n, zeros(n,1), -1i*Pi_n];
    else            % m even
        Q_m = 1/sqrt(2) * [I_n, 1i*I_n;  Pi_n, -1i*Pi_n];
    end
    
    % generate Q_2N using (3.17)
    %N = size(X,2);
    %Pi_N = flip(eye(N));
    %I_N = eye(N);
    %Q_2N = 1/sqrt(2) * [I_N, 1i*I_N;  Pi_N, -1i*Pi_N];

    % (5.27)
    %Pi_M = flip(eye(M));
    %GammaX = real(   Q_M' * [X, Pi_M*conj(X)*Pi_N]  );%* Q_2N   );
    GammaXX = real(   Q_M' * Rxx * Q_M   );
    
    % estimating signal subspace
    %[E,S,~] = svd(GammaX,'econ');
    %[~,index] = sort(abs(diag(S)),'descend');
    %E_S = E(:,index(1:numOfSources));
    [E,S] = eig(GammaXX);
    [~,index] = sort(abs(diag(S)),'descend');
    E_S = E(:,index(1:numOfSources));
    
    %J_1 = [eye(m),zeros(m,1)];
    J_2 = [zeros(m,1),eye(m)];
    K = Q_m' * J_2 * Q_M;
    K_1__E_S = 2*real(K)*E_S;
    K_2__E_S = 2*imag(K)*E_S;

    % LS cf. section 5.2.3
    %Ypsilon = inv(K_1__E_S'*K_1__E_S)*K_1__E_S' * K_2__E_S;
    Ypsilon = (K_1__E_S'*K_1__E_S)\K_1__E_S' * K_2__E_S;
    omega = eig(Ypsilon);
    %Theta_est = asind( 2*atan(omega) * (speedOfLight/antennaDistance{iBS}*angularFrequency) );     % Theta=0 perpendicular to ULA
    Theta_est = acosd( 2*atan(omega) * (speedOfLight/(antennaDistance{iBS}*angularFrequency)) );    % Theta=0 parallel to ULA

    estimatedAngleAzimuth(iBS) = Utils.Extras.wrapTo360(Theta_est + BS_Orientations{iBS}(1));
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