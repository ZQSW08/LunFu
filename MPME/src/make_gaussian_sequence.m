function [frames, displacement, time] = make_gaussian_sequence(imageSize, frameCount, fps, k)
%MAKE_GAUSSIAN_SEQUENCE Paper-inspired damped Gaussian-surface translation.

height = imageSize(1);
width = imageSize(2);
time = (0:frameCount-1).' / fps;
% k=4 deliberately exceeds lambda/2=15 px for the paper lambda=30 case.
displacement = 8.0 * k * exp(-1.45 * time) .* sin(2 * pi * 3.0 * time);
[x, y] = meshgrid(0:width-1, 0:height-1);
centerX = (width - 1) / 2;
centerY = (height - 1) / 2;
surfaceSigma = min(imageSize) / 8;
reference = 20 + 235 * exp(-((x-centerX).^2 + (y-centerY).^2) / ...
    (2 * surfaceSigma^2));
frames = zeros(height, width, frameCount, 'double');
for frameIndex = 1:frameCount
    truth = [1 0 displacement(frameIndex); 0 1 0; 0 0 1];
    frames(:, :, frameIndex) = warp_image_h(reference, inv(truth), 20);
end
end
