classdef Extras
    %% This class contains extra functions / variables that are to be used by the simulator.
    
    %%
    methods(Static)
        function b = de2bi(varargin) 
            % Extras.DE2BI Converts the number from decimal base to binary. Usage
            % is similar to the MATLAB built-in function.
            %
            %   b = Extras.DE2BI(d) converts d from decimal base to binary. The
            %   ouput b is a row-vector containing the bits. If d is a
            %   vector, then b will be a matrix with each row being the
            %   bits of the corresponding element of d.
            %
            %   b = Extras.DE2BI(d,n) converts d from decimal base to binary, with
            %   the specified number of output bits n.
            %
            %   b = Extras.DE2BI(d,n,flag) converts d from decimal base to binary, with
            %   the specified number of output bits n. Choose the position of
            %   the most-significant-bit through flag = 'right-msb' or
            %   'left-msb'. flag = 'right-msb' is default.
            %
            %   b = Extras.DE2BI(d,[],flag) converts d from decimal base to binary.
            %   Choose the position of the most-significant-bit through flag = 'right-msb' or
            %   'left-msb'. flag = 'right-msb' is default.
            %
            % Author: Bashar Tahir, bashar.tahir@tuwien.ac.at
            %%
            narginchk(1,3);

            d = varargin{1};
            % Check inputs & number of required bits to represent the decimal
            % number (or vector)
            [s1,s2] = size(d);
            if s1 > 1 && s2 > 1
                error('Matrix input is not allowed.');
            end
            if length(varargin) == 1 || isempty(varargin{2})
                nBitsReq = ceil(log2(max(d)+1));
                if max(d) == 0
                    nBitsReq = 1;
                end
                b = zeros(length(d),nBitsReq);
            elseif ~isempty(varargin{2})
                n = varargin{2};
                nBitsReq = ceil(log2(max(d)+1));
                if max(d) == 0
                    nBitsReq = 1;
                end
                if n < nBitsReq
                    error('The number of bits n is too small for the representation.');
                else
                    b = zeros(length(d), n);
                end
            end

            % Conversion
            dint = int32(d);
            for ii = 1:nBitsReq
                b(:,ii) = rem(dint,2);
                dint = idivide(dint,2);
            end

            % MSB order
            if length(varargin) == 3
                switch varargin{3}
                    case 'right-msb'
                        % Do nothing
                    case 'left-msb'
                        b = fliplr(b);
                    otherwise
                        error('Selected flag is not valid.');
                end
            end
        end 
        function d = bi2de(varargin)
            % Extras.BI2DE Converts the number from binary base to decimal. Usage
            % is similar to the MATLAB built-in function.
            %
            %   d = Extras.BI2DE(b) converts the bits in the row-vector b to the
            %   decimal base. If b is a matrix, then the output will be a 
            %   column-vector with each element being the decimal number
            %   of the corresponding row.
            %
            %   d = Extras.BI2DE(b,flag) converts the bits in the row-vector b to the
            %   decimal base. Choose the position of the most-significant-bit
            %   through flag = 'right-msb' or 'left-msb'. flag = 'right-msb' is default.
            %
            % Author: Bashar Tahir, bashar.tahir@tuwien.ac.at
            %%
            narginchk(1,2);

            b = varargin{1};
            [s1,s2] = size(b);
            if length(varargin) == 1
                powMat = 2.^repmat(0:(s2-1), s1, 1);
            else 
                switch varargin{2}
                    case 'right-msb'
                        powMat = 2.^repmat(0:(s2-1), s1, 1);
                    case 'left-msb'
                        powMat = 2.^repmat((s2-1):-1:0, s1, 1);
                    otherwise
                        error('Selected flag is not valid.');
                end
            end
            d = sum(b.*powMat,2);
        end
        
        function [bitRevOut, bitRevInd] = bitrevorder(x)
            % Extras.BITREVORDER Permutes the input into bit-reversed order. Usage
            % is similar to the MATLAB built-in function.
            %
            %   bitRevOut = Extras.BITREVORDER(x) permutes the input x into
            %   bit-reversed order. The length of x must be a power of 2. 
            %   If x is a matrix, then every column of x is permuted individually.
            %
            %   [bitRevOut, bitRevInd] = Extras.BITREVORDER(x) permutes the input x into
            %   bit-reversed order, with the permutation indices stored in
            %   bitRevInd.
            %
            % Author: Bashar Tahir, bashar.tahir@tuwien.ac.at
            %%
            narginchk(1,1);
            [s1,s2] = size(x);
            if s1 == 1 && s2 > 1
                if s2 ~= 2^nextpow2(s2)
                    error('Input length must be a power of two.');
                end
                range = 0:(s2-1);
                bitRevInd = Utils.Extras.bi2de(fliplr(Utils.Extras.de2bi(range))) + 1;
                bitRevOut = x(bitRevInd);
            else
                if s1 ~= 2^nextpow2(s1)
                    error('Input length must be a power of two.');
                end
                range = 0:(s1-1);
                bitRevInd = Utils.Extras.bi2de(fliplr(Utils.Extras.de2bi(range))) + 1;
                bitRevOut = x(bitRevInd, :);
            end
        end
        
        function A = convmtx(h, n)
            % Extras.CONVMTX Produces a convolution matrix. Usage is similar to the 
            % MATLAB built-in function.
            %
            %   A = Extras.CONVMTX(h, n) returns the convolution matrix A, such
            %   that the product of A and a vector x of length n, is the
            %   convolution between the vectors h and x.
            %
            % Author: Bashar Tahir, bashar.tahir@tuwien.ac.at
            %%
            narginchk(1,2);
            [s1,s2] = size(h);
            if s1 > 1 && s2 > 1
                error('Matrix input is not allowed.');
            end
            if s2 == 1
                col = [h;zeros(n-1,1)];
                row = [h(1), zeros(1,n-1)];
            else
                row = [h,zeros(1,n-1)];
                col = [h(1); zeros(n-1,1)];
            end
            A = toeplitz(col,row);   
        end
        
        function wind = chebwin(varargin)
            % Extras.CHEBWIN Creates a Chebyshev window. Usage is similar to the 
            % MATLAB built-in function.
            %
            %   wind = Extras.CHEBWIN(L) returns a Chebyshev window of length L
            %   with a default sidelobe attenuation equal to 100 dB.
            %
            %   wind = Extras.CHEBWIN(L,r) returns the Chebyshev window of length
            %   L with a sidelobe attenuation equal to r dB. 
            %
            % Author: Bashar Tahir, bashar.tahir@tuwien.ac.at
            %%
            narginchk(1,2);

            L = varargin{1};
            if L == 1
                wind = 1;
                return;
            elseif L < 0
                error('The window length L cannot be negative.');
            end
            M = L - 1;
            if length(varargin) == 2
                A = varargin{2};
            else
                A = 100;
            end
            k = 0:1:(M-1);
            beta = cosh((1/M)*acosh(10^(A/20)));
            W = (-1).^k .* cos(M.*acos(beta.*cos(pi.*k./M)));
            wind = real(ifft(W));
            wind(1) = wind(1) / 2;
            wind = [wind, wind(1)];
            wind = wind.'./max(wind);
        end
        
        function wind = hann(varargin)
            % Extras.HANN Creates a Hann window. Usage is similar to the MATLAB
            % built-in function.
            %
            %   wind = Extras.HANN(L) returns a symmetric Hann window of length L.
            %
            %   wind = Extras.HANN(L, flag) returns a Hann window of length L,
            %   with the window sampling specified by flag = 'symmetric' or
            %   flag = 'periodic';
            %
            % Author: Bashar Tahir, bashar.tahir@tuwien.ac.at
            %%
            narginchk(1,2);

            L = varargin{1};
            if L == 1
                wind = 1;
                return;
            elseif L < 0
                error('The window length L cannot be negative.');
            end
            if length(varargin) == 2
                switch varargin{2}
                    case 'symmetric'
                        flag = 0;
                    case 'periodic'
                        flag = 1;
                    otherwise
                        error('The specified flag is not valid.');
                end
            else
                flag = 0;
            end
            if flag == 0
                N = L - 1;
                wind = (1 - cos(2.*pi.*([0:N].')./N))/2;
            else
                N = L;
                wind = (1 - cos(2.*pi.*([0:N].')./N))/2;
                wind = wind(1:end-1);
            end
        end
        
        function y = sinc(x)
            % Extras.SINC Sinc function. Usage is similar to the MATLAB built-in function.
            %
            %   y = Extras.SINC(x) returns the sinc of the input x.
            %
            % Author: Bashar Tahir, bashar.tahir@tuwien.ac.at
            %%
            narginchk(1,1);
            
            y = sin(pi.*x)./(pi.*x);
            y(x==0) = 1;
            y(x==inf) = 0;
            y(x==-inf) = 0;
        end
        
        function y = fwht(varargin)
            % Extras.FWHT Performs a fast Walsh-Hadamard transform. Usage is 
            % similar to the MATLAB built-in function.
            %
            %   y = Extras.FWHT(x) returns the discrete Walsh-Hadamard transform
            %   of the input x. The input length has to be a power of 2. If
            %   the length is less than a power of 2, then the input is
            %   zero padded till the next power of 2.
            %
            %   y = Extras.FWHT(x,n) returns the discrete Walsh-Hadamard transform
            %   of the input x with length exactly equal to n. The
            %   transform is performed on lengths of power 2. If n is less
            %   than the length of x, then the output y will be
            %   truncated. If it is larger, then the input x is zero padded
            %   till the next power of 2.
            %
            %   y = Extras.FWHT(x,n,ordering) returns the discrete Walsh-Hadamard transform
            %   of the input x with length exactly equal to n, and
            %   coefficients ordering given by the 'ordering' flag. The
            %   following ordering is supported: 'sequency', 'hadamard',
            %   and 'dyadic'. The default ordering is 'hadamard'.
            %
            % Author: Bashar Tahir, bashar.tahir@tuwien.ac.at
            %%
            narginchk(1,3);

            x = varargin{1};
            [s1,s2] = size(x);
            transposeLater = 0;
            ordering = 1;

            % Setting up sizes
            if s1 == 1 && s2 == 1
                y = x;
                return;
            end
            if length(varargin) == 1 || isempty(varargin{2})
                if s1 == 1 && s2 > 1
                    transposeLater = 1;
                    x = x.';
                    s1 = s2;
                    s2 = 1;
                end
                y = zeros(2^nextpow2(s1),s2);
                y(1:s1, :) = x;
            else
                n = varargin{2};
                if n ~= 2^nextpow2(n)
                    error('Transform length n must be a power of two.');
                end
                if s1 == 1 && s2 > 1
                    transposeLater = 1;
                    x = x.';
                    s1 = s2;
                    s2 = 1;
                end
                y = zeros(n,s2);
                if s1 > n                        
                    y = x(1:n,:);
                else
                    y(1:s1,:) = x;
                end
            end
            if length(varargin) == 3
                switch varargin{3}
                    case 'sequency'
                        ordering = 1;
                    case 'hadamard'
                        ordering = 2;
                    case 'dyadic'
                        ordering = 3;
                    otherwise
                        error('Ordering mode is not supported');
                end
            end

            % The FWHT 
            odr = 1;
            while odr < size(y,1)
                for ii = 1:odr*2:size(y,1)
                    selInd = ii:(ii + odr - 1);
                    a = y(selInd,:);
                    b = y(selInd+odr,:);
                    y(selInd,:) = a + b;
                    y(selInd+odr,:) = a - b;
                end
                odr = odr * 2;
            end
            % Normalize with 1/n
            y = y./(odr);

            % Ordering
            switch ordering
                case 1
                    [~,I] = Utils.Extras.bitrevorder(1:size(y,1));
                    y = y(I,:);
                    ind = Utils.Extras.de2bi(0:(size(y,1)-1),[],'left-msb');
                    grayInd = Utils.Extras.bi2de(xor(ind, [zeros(size(y,1),1), ind(:,1:(end-1))]), 'left-msb') + 1;
                    y = y(grayInd,:);
                case 2
                    % Do nothing
                case 3
                    [~,I] = Utils.Extras.bitrevorder(1:size(y,1));
                    y = y(I,:);
            end
            if transposeLater == 1; y = y.';
            end
        end
        
        function y = wrapTo360(x)
            % Extras.WRAPTO360 Wraps to [0,360] degrees. Usage is similar to 
            % the MATLAB built-in function.
            %
            %   y = Extras.WRAPTO360(x) wraps the input angles to the range [0,360].
            %   Zeros are mapped to zeros, and multiples of 360 to 360.
            %
            % Author: Bashar Tahir, bashar.tahir@tuwien.ac.at
            %%
            narginchk(1,1);
            
            y = mod(x, 360);
            y(y == 0 & x>0) = 360;
        end
        
        function y = mirrorTo180(x)
            % Extras.MIRRORTO180 Mirrors the interval [180,360) to [0,180) degrees.
            %
            %   y = Extras.MIRRORTO180(x) maps the input angles from [180,360) onto the range [0,180).
            %   Specifically, it sets the angle phi in [180, 360)deg to (360 - phi)deg.
            %   The function assumes input angles are pre-wrapped to [0, 360) for correct usage.
            %
            % Author: Kiril Kirev, kiril.kirev@tuwien.ac.at
            %%
            narginchk(1,1);
            
            y = zeros(size(x));
            y(x<180) = x(x<180);
            y(x>=180) = 360 - x(x>=180);
        end

        
        function ci = bootci(x, cl, nSamples, func_x, isParallel)
            % Extras.BOOTCI Confidence interval by bootstrapping. 
            %
            %   ci = Extras.BOOTCI(x, cl, nSamples, func_x, isParallel) returns
            %   the confidence interval with confidence level cl by
            %   bootstraping the input observations x using nSamples samples. 
            %   The function func_x computes the target statistic of x, and
            %   currently only supports a single input, e.g., @(x) mean(x).
            %   Set the flag IsParallel to true in order to enable
            %   bootstrapping of the samples in parallel using the Parallel 
            %   Computing Toolbox.   
            %   If x is a matrix, the bootstrapping is performed columns-wise, 
            %   and the confidence interval is returned as a two-rows
            %   matrix.
            %
            % Author: Bashar Tahir, bashar.tahir@tuwien.ac.at
            %%
            if (cl <= 0 || cl>=1) 
                error("The valid range for the confidence level is 0 < cl < 1 .");
            end
            if ~islogical(isParallel)
                error("The isParallel flag can only be a logical (false or true).");
            end
            
            sampleParameter = nan(nSamples, size(x,2));
            
            % Sampling with replacement
            if ~isParallel  
                for iS = 1:nSamples
                    s = x(randi([1 size(x,1)], size(x,1), 1), :);
                    sampleParameter(iS,:) = func_x(s);
                end
            else
                parfor iS = 1:nSamples
                    s = x(randi([1 size(x,1)], size(x,1), 1), :);
                    sampleParameter(iS,:) = func_x(s);
                end
            end
            
            % Calculate the percentiles based on the nearest-rank method (for
            % nSamples less than 100, the method might return the same value for
            % close percentiles).
            sorted  = sort(sampleParameter, 'ascend');
            alpha = 1 - cl;
            lower_i = ceil(nSamples * alpha / 2);
            upper_i = ceil(nSamples * (1 - alpha / 2));

            ci = [sorted(lower_i,:); sorted(upper_i,:)];
        end
        
        function [f,x] = ecdf(y, varargin)
            % Extras.ecdf Empirical cumulative distribution function (ecdf).
            %
            %   [f,x] = Extras.ecdf(y) computes the empirical cumulative
            %   distribution function of the input y. The returned values is
            %   the ecdf f evaluated at points x. The input y must be a
            %   vector.
            %   
            %   Extras.ecdf(y) plots the empirical cumulative distribution
            %   function of the input y. Note that the ecdf is plotted only 
            %   when there are no output arguments.
            %  
            %   Extras.ecdf(y, plotOptions) plots the empirical cumulative
            %   distribution function of the input y, with plotting options
            %   specified as a char array.
            %
            % Author: Bashar Tahir, bashar.tahir@tuwien.ac.at
            %% 
            if min(size(y)) > 1
                error("The input y must be a vector.");
            end
            switch numel(varargin)
                case 0
                    plotOptions = '';
                case 1
                    if ~ischar(varargin{1})
                        error("The plot options can only be a char array, e.g., '-ro'.");
                    else
                        plotOptions = varargin{1};
                    end
                otherwise
                    error("Too many input arguments.")
            end
            nElementsTotal = length(y);

            % Sort the data
            sorted = sort(y, 'ascend');

            % Find number of unique elements
            nUnique = 1;
            for iE = 2:nElementsTotal
                if sorted(iE) ~= sorted(iE-1)
                    nUnique = nUnique + 1;
                end
            end

            % Compute the ECDF
            x = nan(nUnique+1,1);
            f = nan(nUnique+1,1);

            x(1) = sorted(1);
            f(1) = 0;
            binCount = 2;
            for iE = 2:nElementsTotal
                if sorted(iE) ~= sorted(iE-1)
                    x(binCount) = sorted(iE-1);
                    f(binCount) = iE - 1;
                    binCount = binCount + 1;
                end
            end
            f = f ./ nElementsTotal;
            x(end) = sorted(end);
            f(end) = 1;
            
            % Plot the ecdf if there are no output arguments
            if nargout == 0
                stairs(x,f, plotOptions);
            end
        end
    end
    
end

