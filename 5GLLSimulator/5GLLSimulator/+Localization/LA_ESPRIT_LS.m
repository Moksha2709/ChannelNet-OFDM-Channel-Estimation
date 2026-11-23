function [estimatedPosition, estimatedAngleAzimuth] = LA_ESPRIT_LS(receivedSignal_raw, BS_Locations, BS_Orientations, numOfRxAntennas, antennaDistance, centerFrequency)

    %% INITIALIZATION AND CONSTANTS
    speedOfLight     = 299792458;
    angularFrequency = 2*pi*centerFrequency;
    numOfSources     = 1;
    nBS              = size(BS_Locations,1);
    
    %% ANGLE ESTIMATION
    % implementation of standard ESPRIT algorithm, as explained in section 5.3 of
    % Introduction to Direction-of-Arrival Estimation, by Zhizhang Chen, Gopal Gokeda, Yiqiang Yu
    
    estimatedAngleAzimuth = zeros(1,nBS);
    for iBS = 1:nBS
        X = receivedSignal_raw{iBS}';
        [U,S,~] = svd(X,'econ');
        [~,index] = sort(abs(diag(S)),'descend');
        U_S = U(:,index(1:numOfSources));
            
        J_1__U_S = U_S(1:end-1,:);
        J_2__U_S = U_S(2:end,:);
        
        % LS cf. 5.2.3
        %Psi = inv(J_1__U_S'*J_1__U_S)*J_1__U_S' * J_2__U_S;
        Psi = (J_1__U_S'*J_1__U_S)\J_1__U_S' * J_2__U_S;
        Phi = eig(Psi);
        %Theta_est = asind( angle(Phi) * (speedOfLight/antennaDistance{iBS}*angularFrequency) );    % Theta=0 perpendicular to ULA
        Theta_est = acosd( angle(Phi) * (speedOfLight/(antennaDistance{iBS}*angularFrequency)) );   % Theta=0 parallel to ULA
    
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