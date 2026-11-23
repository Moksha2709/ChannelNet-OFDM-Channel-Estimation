% Compile the MEX C++ files.
%
fprintf('\n\nCompiling starts...\n');
fprintf('------------------------------------------------\n');
fprintf('Compiling Tail-Biting Convolutional decoder...\n');
mex '+Coding/C++sourcefiles/TBConvDecodeMEX.cpp' -output '+Coding/+ChannelCodingComponents/TBConvDecodeMEX';
fprintf('\nCompiling Turbo decoder...\n');
mex '+Coding/C++sourcefiles/turboDecodeMEX.cpp' -output '+Coding/+ChannelCodingComponents/turboDecodeMEX';
fprintf('\nCompiling LDPC decoder...\n');
mex '+Coding/C++sourcefiles/LDPCDecodeMEX.cpp' -output '+Coding/+ChannelCodingComponents/LDPCDecodeMEX';
fprintf('\nCompiling Polar decoder...\n');
mex '+Coding/C++sourcefiles/polarDecodeMEX.cpp' -output '+Coding/+ChannelCodingComponents/polarDecodeMEX';
fprintf('\nCompiling CRC function...\n');
mex '+Coding/C++sourcefiles/CRCMEX.cpp' -output '+Coding/+ChannelCodingComponents/CRCMEX';
fprintf('\nCompiling Sphere decoder...\n');
mex '+Modulation/sphereDecode.cpp' -output '+Modulation/sphereDecodeMEX';
fprintf('\nFinished compiling.\n');
fprintf('------------------------------------------------\n\n');