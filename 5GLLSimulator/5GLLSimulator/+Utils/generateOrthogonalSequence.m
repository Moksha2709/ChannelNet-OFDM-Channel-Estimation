function pilotSequence = generateOrthogonalSequence(sequenceLength, sequenceIndex_input, sequenceType)
% this function generates an orthogonal sequence of a certain lenght such that there exist sequenceLength sequences with different sequence indices

% check input
if sequenceIndex_input < 0
    error('Pilot sequence index must be non-negative!');
end

if sequenceLength < 2
    error('Pilot sequence length must be at least two!');
end

sequenceIndex = mod(sequenceIndex_input, sequenceLength);

switch sequenceType
    case 'Zadoff-Chu'
        % find a Zadoff-Chu root (the biggest posible)
        for ii = fliplr(1:sequenceLength-1)
            if gcd(ii, sequenceLength) == 1
                zc_root = ii;
                break;         
            end
        end
        
        % generate ZC sequence
        pilotSequence = exp(-1i .* (pi .* (0:sequenceLength - 1) .* zc_root .* ((0:sequenceLength - 1) + mod(sequenceLength, 2) + 2 * sequenceIndex)) ./ sequenceLength).';
    case 'Hadamard'
        % check input
        if sequenceLength > 2 && rem(sequenceLength, 4) ~= 0
            error('Hadamard sequence of length %d does not exist!', sequenceLength);
        end
        
        % generate Hadamard matrix
        Hadamard_matrix = hadamard(sequenceLength);
        pilotSequence = Hadamard_matrix(:, sequenceIndex + 1);
    otherwise
        error('Orthogonal sequence type not supported!');
end

end

