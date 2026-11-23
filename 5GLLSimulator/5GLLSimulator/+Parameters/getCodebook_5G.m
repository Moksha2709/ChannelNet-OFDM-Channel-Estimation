function [ codebook ] = getCodebook_5G(nAntennas, direction,transmissionMode, varargin )
% The function getCodebook generates a Type 1 Single Panel codebook
% according to the TS 38.214-f10 Tabel 5.2.2.2.1-1  to 12 with CodebookMode = 1 for the DL
% for the uplink the codebook is generated according to TS 38.211 section 6.3.1.5
    switch transmissionMode
       case 'CLSM'
            if strcmp(direction,'Uplink')
                if nAntennas~=1 && nAntennas~=2 && nAntennas~=4
                    error('Codebook for the uplink supports 2 or 4 antenna ports'); 
                end
                switch nAntennas
                    case 1
                        codebook.W{1} = 1;
                    case 2
                        % 1 Layer
                        codebook.W{1} = 1/sqrt(2)*[1;0];
                        codebook.W{2} = 1/sqrt(2)*[0;1];
                        codebook.W{3} = 1/sqrt(2)*[1;1];
                        codebook.W{4} = 1/sqrt(2)*[1;-1];
                        codebook.W{5} = 1/sqrt(2)*[1;1i];
                        codebook.W{6} = 1/sqrt(2)*[1;-1i];
                        % 2 Layers
                        codebook.W{7} = 1/sqrt(2)*[1,0;0,1];
                        codebook.W{8} = 1/2*[1,1;1,-1];
                        codebook.W{9} = 1/2*[1,1;1i,-1i];
                    case 4
                        % 1 Layer
                        codebook.W{1} = 1/2*[1;0;0;0];
                        codebook.W{2} = 1/2*[0;1;0;0];
                        codebook.W{3} = 1/2*[0;0;1;0];
                        codebook.W{4} = 1/2*[0;0;0;1];
                        codebook.W{5} = 1/2*[1;0;1;0];
                        codebook.W{6} = 1/2*[1;0;-1;0];
                        codebook.W{7} = 1/2*[1;0;1i;0];
                        codebook.W{8} = 1/2*[1;0;-1i;0];
                        codebook.W{9} = 1/2*[0;1;0;1];
                        codebook.W{10} = 1/2*[0;1;0;-1];
                        codebook.W{11} = 1/2*[0;1;0;1i];
                        codebook.W{12} = 1/2*[0;1;0;-1i];
                        codebook.W{13} = 1/2*[1;1;1;1];
                        codebook.W{14} = 1/2*[1;1;1i;1i];
                        codebook.W{15} = 1/2*[1;1;-1;-1];
                        codebook.W{16} = 1/2*[1;1;-1i;-1i];
                        codebook.W{17} = 1/2*[1;1i;1;1i];
                        codebook.W{18} = 1/2*[1;1i;1i;-1];
                        codebook.W{19} = 1/2*[1;1i;-1;-1i];
                        codebook.W{20} = 1/2*[1;1i;-1i;1];
                        codebook.W{21} = 1/2*[1;-1;1;-1];
                        codebook.W{22} = 1/2*[1;-1;1i;-1i];
                        codebook.W{23} = 1/2*[1;-1;-1;1];
                        codebook.W{24} = 1/2*[1;-1;-1i;1i];
                        codebook.W{25} = 1/2*[1;-1i;1;-1i];
                        codebook.W{26} = 1/2*[1;-1i;1i;1];
                        codebook.W{27} = 1/2*[1;-1i;-1;1i];
                        codebook.W{28} = 1/2*[1;-1i;-1i;-1];

                        % 2 Layers
                        codebook.W{29} = 1/2*[1,0;0,1;0,0;0,0];
                        codebook.W{30} = 1/2*[1,0;0,0;0,1;0,0];
                        codebook.W{31} = 1/2*[1,0;0,0;0,0;0,1];
                        codebook.W{32} = 1/2*[0,0;1,0;0,1;0,0];

                        codebook.W{33} = 1/2*[0,0;1,0;0,0;0,1];
                        codebook.W{34} = 1/2*[0,0;0,0;1,0;0,1];
                        codebook.W{35} = 1/2*[1,0; 0,1; 1,0; 0,-1i];
                        codebook.W{36} = 1/2*[1,0; 0,1; 1,0; 0,1i];

                        codebook.W{37} = 1/2*[1,0; 0,1; -1i,0; 0,1];
                        codebook.W{38} = 1/2*[1,0; 0,1; -1i,0; 0,-1];
                        codebook.W{39} = 1/2*[1,0; 0,1; -1,0; 0,-1i];
                        codebook.W{40} = 1/2*[1,0; 0,1; -1,0; 0,1i];

                        codebook.W{41} = 1/2*[1,0; 0,1; 1i,0; 0,1];
                        codebook.W{42} = 1/2*[1,0; 0,1; 1i,0; 0,-1];
                        codebook.W{43} = 1/(2*sqrt(2))*[1,1; 1,1; 1,-1; 1,-1];
                        codebook.W{44} = 1/(2*sqrt(2))*[1,1; 1,1; 1i,-1i; 1i,-1i];

                        codebook.W{45} = 1/(2*sqrt(2))*[1,1; 1i,1i; 1,-1; 1i,-1i];
                        codebook.W{46} = 1/(2*sqrt(2))*[1,1; 1i,1i; 1i,-1i; -1,1];
                        codebook.W{47} = 1/(2*sqrt(2))*[1,1; -1,-1; 1,-1; -1,1];
                        codebook.W{48} = 1/(2*sqrt(2))*[1,1; -1,-1; 1i,-1i; -1i,1i];

                        codebook.W{49} = 1/(2*sqrt(2))*[1,1; -1i,-1i; 1,-1; -1i,1i];
                        codebook.W{50} = 1/(2*sqrt(2))*[1,1; -1i,-1i ;1i,-1i; 1,-1];

                        % 3 Layers
                        codebook.W{51} = 1/2*[1,0,0; 0,1,0; 0,0,1; 0,0,0];
                        codebook.W{52} = 1/2*[1,0,0; 0,1,0; 1,0,0; 0,0,1];
                        codebook.W{53} = 1/2*[1,0,0; 0,1,0; -1,0,0; 0,0,1];
                        codebook.W{54} = 1/(2*sqrt(3))*[1,1,1; 1,-1,1; 1,1,-1; 1,-1,-1];

                        codebook.W{55} = 1/(2*sqrt(3))*[1,1,1; 1,-1,1; 1i,1i,-1i; 1i,-1i,-1i];
                        codebook.W{56} = 1/(2*sqrt(3))*[1,1,1; -1,1,-1; 1,1,-1; -1,1,1];
                        codebook.W{57} = 1/(2*sqrt(3))*[1,1,1; -1,1,-1; 1i,1i,-1i; -1i,1i,1i];

                        % 4 Layers
                        codebook.W{58} = 1/2*[1,0,0,0;0,1,0,0;0,0,1,0;0,0,0,1];
                        codebook.W{59} = 1/(2*sqrt(2))*[1,1,0,0; 0,0,1,1; 1,-1,0,0; 0,0,1,-1];
                        codebook.W{60} = 1/(2*sqrt(2))*[1,1,0,0; 0,0,1,1; 1i,-1i,0,0; 0,0,1i,-1i];
                        codebook.W{61} = 1/4*[1,1,1,1; 1,-1,1,-1; 1,1,-1,-1; 1,-1,-1,1];
                        codebook.W{61} = 1/4*[1,1,1,1; 1,-1,1,-1; 1i,1i,-1i,-1i; 1i,-1i,-1i,1i];                

                end
            else
                N1 = nAntennas(1);
                N2 = nAntennas(2);
                config = [21,22,41,32,61,42,81,43,62,121,44,82,161];
                O1 = 4;
                if N2 > 1
                    O2 = 4;
                else
                    O2 = 1;
                end
                % Layer 1 and 2
                if N1>N2 && N2>1
                    mapping{1}.i13{1} = [0,0];
                    mapping{1}.i13{2} = [O1,0];
                    mapping{1}.i13{3} = [0,O2];
                    mapping{1}.i13{4} = [2*O1,0];
                elseif N1 == N2
                    mapping{1}.i13{1} = [0,0];
                    mapping{1}.i13{2} = [O1,0];
                    mapping{1}.i13{3} = [0,O2];
                    mapping{1}.i13{4} = [O1,O2];   
                elseif N1==2 && N2==1
                    mapping{1}.i13{1} = [0,0];
                    mapping{1}.i13{2} = [O1,0];
                else
                    mapping{1}.i13{1} = [0,0];
                    mapping{1}.i13{2} = [O1,0];
                    mapping{1}.i13{3} = [2*O1,0];
                    mapping{1}.i13{4} = [3*O1,0];
                end
                % Layer 3 and 4
                if N1 == 2 && N2 == 1
                    mapping{2}.i13{1} = [O1,0];
                elseif N1 == 4 && N2 == 1
                    mapping{2}.i13{1} = [O1,0];
                    mapping{2}.i13{2} = [2*O1,0];
                    mapping{2}.i13{3} = [3*O1,0];  
                elseif N1==6 && N2==1
                    mapping{2}.i13{1} = [O1,0];
                    mapping{2}.i13{2} = [2*O1,0];
                    mapping{2}.i13{3} = [3*O1,0];
                    mapping{2}.i13{4} = [4*O1,0];
                elseif N1 == 2 && N2 == 2
                    mapping{2}.i13{1} = [O1,0];
                    mapping{2}.i13{2} = [0,O2];
                    mapping{2}.i13{3} = [O1,O2];
                elseif N1 == 3 && N2 == 2
                    mapping{2}.i13{1} = [O1,0];
                    mapping{2}.i13{2} = [0,O2];
                    mapping{2}.i13{3} = [O1,O2];
                    mapping{2}.i13{4} = [2*O1,0];
                end

                u = @(m) exp(2i*pi*m/(O2*N2)*(0:N2-1));

                v = @(l,m) kron(exp(2i*pi*l/(O1*N1)*(0:N1-1)),u(m))';

                v_tilda = @(l,m) kron(exp(4i*pi*l/(O1*N1)*(0:(N1/2)-1)),u(m))';

                phi = @(n) exp(1i*pi*n/2);

                theta = @(p) exp(1i*pi*p/4);

                index = 1;
                P = 2*N1*N2; 

                if N1+N2==1
                    codebook.W{1} = 1;
                elseif N1+N2==2
                    codebook.W{1} = 1/sqrt(2)*[1;1];
                    codebook.W{2} = 1/sqrt(2)*[1;1i];
                    codebook.W{3} = 1/sqrt(2)*[1;-1];
                    codebook.W{4} = 1/sqrt(2)*[1;-1i];
                    codebook.W{5} = 1/2*[1,1;1,-1];
                    codebook.W{6} = 1/2*[1,1;1i,-1i];
                else

                    N = N1*10+N2;
                    if isempty(find(config == N,1))
                        error('The combination of N1 and N2 is not supported');
                    end
                    % 1 Layer
                    for i2 = 0:3
                        for i12 = 0:(N2*O2-1)
                            for i11 = 0:(N1*O1-1)
                                vlm = v(i11,i12);
                                codebook.W{index} = 1/sqrt(P)*[vlm;...
                                                      phi(i2)*vlm];
                                index = index + 1;
                            end
                        end
                    end % end 1 Layer

                    % 2 Layers
                    for i2 = 0:1
                        for i13 = 1:size(mapping{1}.i13,2)
                            k1 =  mapping{1}.i13{i13}(1);
                            k2 =  mapping{1}.i13{i13}(2);
                            for i12 = 0:(N2*O2-1)
                                for i11 = 0:(N1*O1-1)
                                    vlm = v(i11,i12);
                                    vlm_prim = v(i11+k1,i12+k2);
                                    codebook.W{index} = 1/sqrt(2*P)*[vlm ,vlm_prim;...
                                                            phi(i2)*vlm ,-phi(i2)*vlm_prim];
                                    index = index + 1;
                                end
                            end
                        end
                    end % end 2 layers

                    % 3 Layers
                    for i2 = 0:1
                        if P < 16
                            for i13 = 0:size(mapping{2}.i13,2)-1
                                k1 =  mapping{2}.i13{i13+1}(1);
                                k2 =  mapping{2}.i13{i13+1}(2);
                                for i12 = 0:(N2*O2-1)
                                    for i11 = 0:(N1*O1-1)
                                            vlm = v(i11,i12);
                                            vlm_prim = v(i11+k1,i12+k2);
                                            phin = phi(i2);
                                            codebook.W{index} = 1/sqrt(3*P)*[vlm,  vlm_prim, vlm;...
                                                               phin*vlm, phin*vlm_prim, -phin*vlm]; 

                                            index = index + 1;
                                    end
                                end
                            end         
                        else
                            for i13 = 0:3
                                for i12 = 0:(N2*O2-1)
                                    for i11 = 0:(N1*O1/2-1)
                                       vlm_tilda = v_tilda(i11,i12);
                                       phin = phi(i2);
                                       thetap = theta(i13);
                                       codebook.W{index} = 1/sqrt(3*P)*[vlm_tilda,vlm_tilda,vlm_tilda;...
                                                                thetap*vlm_tilda,-thetap*vlm_tilda,thetap*vlm_tilda;... 
                                                                phin*vlm_tilda,phin*vlm_tilda,-phin*vlm_tilda;...
                                                                phin*thetap*vlm_tilda,-phin*thetap*vlm_tilda,-phin*thetap*vlm_tilda];

                                        index = index + 1;

                                    end 
                                end
                            end
                        end
                    end % end 3 layers

                    % 4 Layers
                    for i2 = 0:1
                        if P < 16
                            for i13 = 0:size(mapping{2}.i13,2)-1
                                k1 =  mapping{2}.i13{i13+1}(1);
                                k2 =  mapping{2}.i13{i13+1}(2);
                                for i12 = 0:(N2*O2-1)
                                    for i11 = 0:(N1*O1-1)
                                        vlm = v(i11,i12); 
                                        vlm_prim = v(i11+k1,i12+k2);
                                        codebook.W{index} = 1/sqrt(4*P)*[vlm,  vlm_prim,   vlm,  vlm_prim;...
                                                            phi(i2)*vlm, phi(i2)*vlm_prim, -phi(i2)*vlm, -phi(i2)*vlm_prim]; 

                                            index = index + 1;
                                    end
                                end
                            end         
                        else
                            for i13 = 0:3
                                for i12 = 0:(N2*O2-1)
                                    for i11 = 0:(N1*O1/2-1)
                                        vlm_tilda = v_tilda(i11,i12);
                                        phin = phi(i2);
                                        thetap = theta(i13);
                                        codebook.W{index} = 1/sqrt(4*P)*[vlm_tilda,vlm_tilda,vlm_tilda,vlm_tilda;...
                                                                thetap*vlm_tilda,-thetap*vlm_tilda,thetap*vlm_tilda,-thetap*vlm_tilda;... 
                                                                phin*vlm_tilda,phin*vlm_tilda,-phin*vlm_tilda,-phin*vlm_tilda;...
                                                                phin*thetap*vlm_tilda,-phin*thetap*vlm_tilda,-phin*thetap*vlm_tilda,phin*thetap*vlm_tilda];

                                        index = index + 1;

                                    end 
                                end
                            end
                        end
                    end % end 4 layers


                    % 5 Layers
                    for i2 = 0:1
                        phin = phi(i2);
                        for i12 = 0:(N2*O2-1)
                            for i11 = 0:(N1*O1-1)
                                vlm = v(i11,i12);
                                vlm_p = v(i11+O1,i12);
                                if N1> 2 && N2 == 1
                                    vlm_pp = v(i11+2*O1,0);
                                else                                    
                                    vlm_pp = v(i11+O1,i12+O2);
                                end
                                    codebook.W{index} = 1/sqrt(5*P)*[vlm, vlm,vlm_p,vlm_p,vlm_pp;...
                                                          phin*vlm, -phin*vlm, vlm_p, -vlm_p, vlm_pp];
                                
                                index = index + 1;
                            end
                        end
                    end % end 5 layers

                    % 6 Layers
                    for i2 = 0:1
                        phin = phi(i2);
                        for i12 = 0:(N2*O2-1)
                            for i11 = 0:(N1*O1-1)
                                vlm = v(i11,i12);
                                vlm_p = v(i11+O1,i12);                                
                                if N1 > 2 && N2 == 1
                                    vlm_pp = v(i11+2*O1,0);
                                else
                                   vlm_pp = v(i11+O1,i12+O2); 
                                end
                                codebook.W{index} = 1/sqrt(6*P)*[vlm, vlm,vlm_p,vlm_p,vlm_pp,vlm_pp;...
                                                      phin*vlm, -phin*vlm, phin*vlm_p, -phin*vlm_p, vlm_pp, -vlm_pp];
                                index = index + 1;
                            end
                        end
                    end % end 6 layers

                    % 7 Layers
                    if N1 == 4 && N2 == 1
                        ni11 = N1*O1/2-1;
                    else
                        ni11 = N1*O1-1;
                    end
                    if N1 > 2 && N2 == 2
                            ni12 = N2*O2/2-1;
                    else
                        ni12 = N2*O2-1;
                    end
                    for i2 = 0:1
                        phin = phi(i2);

                        for i12 = 0:ni12
                            for i11 = 0:ni11
                                if N2 == 1
                                    vlm = v(i11,i12);
                                    vlm_p = v(i11+O1,0);
                                    vlm_pp = v(i11+2*O1,0);
                                    vlm_ppp = v(i11+3*O1,0);
                                else
                                    vlm = v(i11,i12);
                                    vlm_p = v(i11+O1,i12);
                                    vlm_pp = v(i11,i12+O2);
                                    vlm_ppp = v(i11+O1,i12+O2);
                                end


                                codebook.W{index} = 1/sqrt(7*P)*[vlm, vlm,vlm_p,vlm_pp,vlm_pp,vlm_ppp,vlm_ppp;...
                                                      phin*vlm, -phin*vlm, phin*vlm_p, vlm_pp, -vlm_pp, vlm_ppp, -vlm_ppp];
                                index = index + 1;
                            end
                        end
                    end % end 7 layers

                    % 8 Layers
                    for i2 = 0:1
                        phin = phi(i2);

                        for i12 = 0:ni12
                            for i11 = 0:ni11
                                if N2 == 1
                                    vlm = v(i11,i12);
                                    vlm_p = v(i11+O1,0);
                                    vlm_pp = v(i11+2*O1,0);
                                    vlm_ppp = v(i11+3*O1,0);
                                else
                                    vlm = v(i11,i12);
                                    vlm_p = v(i11+O1,i12);
                                    vlm_pp = v(i11,i12+O2);
                                    vlm_ppp = v(i11+O1,i12+O2);
                                end


                                codebook.W{index} = 1/sqrt(7*P)*[vlm, vlm,vlm_p,vlm_p,vlm_pp,vlm_pp,vlm_ppp,vlm_ppp;...
                                                      phin*vlm, -phin*vlm, phin*vlm_p, -phin*vlm_p, vlm_pp, -vlm_pp, vlm_ppp, -vlm_ppp];
                                index = index + 1;
                            end
                        end
                    end % end 8 layers 
                end %end if
            end
            codebook.U = 0;
            codebook.D = 0;
            codebook.methode = 'CLSM';
            
        case 'OLSM'
            nAntennas = nAntennas(1)*nAntennas(2)*2;
            if nAntennas~=1 &&  nAntennas~=2 && nAntennas~=4
                error('The transmission mode %s only supports 2 or 4 transmit antennas',transmissionMode);
            end
            switch nAntennas
                case 1
                    codebook.W{1}=1;

                case 2   % precoding matrix according to Table 6.3.4.2.3-1
                    codebook.W = cell(1,2);
                    codebook_index = 1;
                    switch codebook_index
                        case 0

                               codebook.W{1,2} = 1/sqrt(2)*[1,0;0,1];
                               codebook.W{1,1} = 1/sqrt(2)*[1;1];

                        case 1

                                codebook.W{1,2} = 1/(2)*[1,1;1,-1];
                                codebook.W{1,1} = 1/sqrt(2)*[1;-1];

                        case 2

                                codebook.W{1,2} = 1/(2)*[1,1;1i,-1i];
                                codebook.W{1,1} = 1/sqrt(2)*[1;1i];

                        case 3

                                codebook.W{1,2} = 0;
                                codebook.W{1,1} = 1/sqrt(2)*[1;-1];

                        otherwise
                            error('codebook index not supported');
                    end
                case 4

                    codebook_index = [12,13,14,15];
                    codebook.W = cell(size(codebook_index,2),nAntennas);
                    for i = 1:length(codebook_index)    % for open loop spatial multiplexing 
                                                            % codebook_index = [12,13,14,15]
                                                            % see 3GPP TS 36.213-820, Section 7.1.3 
                                                            % NOTE: store this in some pre-stored variable
                            switch codebook_index(i)
                                case 0
                                    u= [1;-1;-1;-1];
                                case 1
                                    u= [1;-1i;1;1i];
                                case 2
                                    u= [1;1;-1;1];
                                case 3
                                    u= [1;1i;1;-1i];
                                case 4
                                    u= [1;(-1-1i)/sqrt(2); -1i;(1-1i)/sqrt(2)];
                                case 5
                                    u= [1;(1-1i)/sqrt(2); 1i;(-1-1i)/sqrt(2)];
                                case 6
                                    u= [1;(1+1i)/sqrt(2); -1i;(-1+1i)/sqrt(2)];
                                case 7
                                    u= [1;(-1+1i)/sqrt(2); 1i;(1+1i)/sqrt(2)];
                                case 8
                                    u= [1;-1;1;1];
                                case 9
                                    u= [1;-1i;-1;-1i];
                                case 10
                                    u= [1;1;1;-1];
                                case 11
                                    u= [1;1i;-1;1i];
                                case 12
                                    u= [1;-1;-1;1];
                                case 13
                                    u= [1;-1;1;-1];
                                case 14
                                    u= [1;1;-1;-1];
                                case 15
                                    u= [1;1;1;1];
                                otherwise
                                    error('codebook index not supported');
                            end
                            W1 = diag(ones(1,4))-2*u*u'/(u'*u);
                            for RI = 1:nAntennas
                                    switch RI  
                                    case 1
                                        codebook.W{i,RI} = W1(:,1);
                                    case 2
                                        switch codebook_index(i)
                                            case {0,4,5,9}
                                                codebook.W{i,RI} = W1(:,[1 4])/sqrt(2);
                                            case {1,2,3,8,12,15}
                                                codebook.W{i,RI} = W1(:,[1 2])/sqrt(2);
                                            otherwise
                                                codebook.W{i,RI} = W1(:,[1 3])/sqrt(2);
                                        end
                                    case 3
                                        switch codebook_index(i)
                                            case {0,4,5,8}
                                                codebook.W{i,RI} = W1(:,[1 2 4])/sqrt(3);
                                            case {1,2,3,10,12,13,14,15}
                                                codebook.W{i,RI} = W1(:,[1 2 3])/sqrt(3);
                                            otherwise
                                                codebook.W{i,RI} = W1(:,[1 3 4])/sqrt(3);
                                        end
                                    case 4
                                        switch codebook_index(i)
                                            case {0,1,4,5,8,9,12,15}
                                                codebook.W{i,RI} = W1(:,[1 2 3 4])/2;
                                            case {6,7,10,11,13}
                                                codebook.W{i,RI} = W1(:,[1 3 2 4])/2;
                                            otherwise
                                                codebook.W{i,RI} = W1(:,[3 2 1 4])/2;
                                        end
                                    otherwise
                                        error('RI not supported');
                                    end
                            end
                    end
                otherwise
                    error('No codebook for %d transmit antennas',nAntennas);
            end


            if length(varargin)<1
                CDD = 0; % default mode?
            else
                CDD = varargin{1};
            end
            switch CDD  % cyclic delay diversity, precoding according to Section 6.3.4.2
                case 0  % zero delay CDD
                    codebook.D{1} = 1;  
                    codebook.U{1} = 1;
                    codebook.D{2} = 1;  
                    codebook.U{2} = 1;
                    codebook.D{3} = 1;  
                    codebook.U{3} = 1;
                    codebook.D{4} = 1;  
                    codebook.U{4} = 1;

                case 1  % large delay CDD
                    % RI = 1
                        codebook.D{1} = 1;  
                        codebook.U{1} = 1;
                     % RI = 2
                        codebook.U{2} = 1/sqrt(2)*[1,1;1,exp(-1i*pi)];
                        codebook.D{2} = [1,0;0,exp(-1i*pi)];
                    % RI = 3
                       codebook.U{3} = 1/sqrt(3)*[1,1,1;1,exp(-1i*2*pi/3),exp(-1i*4*pi/3);1,exp(-1i*4*pi/3),exp(-1i*8*pi/3)];
                        codebook.D{3} = [1,0,0;0,exp(-1i*2*pi/3),0;0,0,exp(-1i*4*pi/3)];
                    % RI = 4
                        codebook.U{4} = 1/2*[1,1,1,1;1,exp(-1i*2*pi/4),exp(-1i*4*pi/4),exp(-1i*6*pi/4);...
                            1,exp(-1i*4*pi/4),exp(-1i*8*pi/4),exp(-1i*12*pi/4);...
                            1,exp(-1i*6*pi/4),exp(-1i*12*pi/4),exp(-1i*18*pi/4)];
                        codebook.D{4} = [1,0,0,0;0,exp(-1i*2*pi/4),0,0;0,0,exp(-1i*4*pi/4),0;0,0,0,exp(-1i*6*pi/4)];

                otherwise
                        error('RI not supported');

            end
            codebook.methode = 'OLSM';

        case 'TxD'
            % Add codebook for transmit diversity
            nAntennas = nAntennas(1)*nAntennas(2)*2;
             if nAntennas~=1 &&  nAntennas~=2 && nAntennas~=4 && nAntennas~=8
                error('The transmission mode %s only supports 2 or 4 transmit antennas',transmissionMode);
            end
            codebook.Z{1} =  [1, 0, 1i,  0;
             0,-1,  0, 1i;
             0, 1,  0, 1i;
             1, 0,-1i,  0];

            codebook.Z{2} =  [1, 0, 0, 0, 1i,  0,  0, 0;
             0, 0, 0, 0,  0,  0,  0, 0;
             0,-1, 0, 0,  0, 1i,  0, 0;
             0, 0, 0, 0,  0,  0,  0, 0;
             0, 1, 0, 0,  0, 1i,  0, 0;
             0, 0, 0, 0,  0,  0,  0, 0;
             1, 0, 0, 0,-1i,  0,  0, 0;
             0, 0, 0, 0,  0,  0,  0, 0;
             0, 0, 0, 0,  0,  0,  0, 0;
             0, 0, 1, 0,  0,  0, 1i, 0;
             0, 0, 0, 0,  0,  0,  0, 0;
             0, 0, 0,-1,  0,  0,  0,1i;
             0, 0, 0, 0,  0,  0,  0, 0;
             0, 0, 0, 1,  0,  0,  0,1i;
             0, 0, 0, 0,  0,  0,  0, 0;
             0, 0, 1, 0,  0,  0,-1i, 0];

            codebook.Z{3} = zeros(8*8,16);
            % 1st Alamouti scheme
            codebook.Z{3}(1,1) = 1;
            codebook.Z{3}(1,9) = 1i;
            codebook.Z{3}(5,2) = -1;
            codebook.Z{3}(5,10) = 1i;
            codebook.Z{3}(9,2) = 1;
            codebook.Z{3}(9,10) = 1i;
            codebook.Z{3}(13,1) = 1;
            codebook.Z{3}(13,9) = -1i;
            % 2nd Alamouti scheme
            codebook.Z{3}(1+17,1+2) = 1;
            codebook.Z{3}(1+17,9+2) = 1i;
            codebook.Z{3}(5+17,2+2) = -1;
            codebook.Z{3}(5+17,10+2) = 1i;
            codebook.Z{3}(9+17,2+2) = 1;
            codebook.Z{3}(9+17,10+2) = 1i;
            codebook.Z{3}(13+17,1+2) = 1;
            codebook.Z{3}(13+17,9+2) = -1i;
            % 3rd Alamouti scheme
            codebook.Z{3}(1+17*2,1+2*2) = 1;
            codebook.Z{3}(1+17*2,9+2*2) = 1i;
            codebook.Z{3}(5+17*2,2+2*2) = -1;
            codebook.Z{3}(5+17*2,10+2*2) = 1i;
            codebook.Z{3}(9+17*2,2+2*2) = 1;
            codebook.Z{3}(9+17*2,10+2*2) = 1i;
            codebook.Z{3}(13+17*2,1+2*2) = 1;
            codebook.Z{3}(13+17*2,9+2*2) = -1i;
            % 4th Alamouti scheme
            codebook.Z{3}(1+17*3,1+2*3) = 1;
            codebook.Z{3}(1+17*3,9+2*3) = 1i;
            codebook.Z{3}(5+17*3,2+2*3) = -1;
            codebook.Z{3}(5+17*3,10+2*3) = 1i;
            codebook.Z{3}(9+17*3,2+2*3) = 1;
            codebook.Z{3}(9+17*3,10+2*3) = 1i;
            codebook.Z{3}(13+17*3,1+2*3) = 1;
            codebook.Z{3}(13+17*3,9+2*3) = -1i;

            codebook.methode = 'TxD';
    otherwise
            error('Transmission mode not supported');

	end

end

