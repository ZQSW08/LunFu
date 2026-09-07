function [stabilized, rawStepAngles, correctedStepAngles] = ...
    stabilize_rotation_sequence(transforms, imageSize, deviationThreshold, rigidCenter)
%STABILIZE_ROTATION_SEQUENCE Reject isolated phase-fit jumps for steady rotors.

if nargin < 3 || isempty(deviationThreshold), deviationThreshold = 5; end
if nargin < 4 || isempty(rigidCenter)
    rigidCenter = [(imageSize(2)-1)/2 (imageSize(1)-1)/2];
end
frameCount = size(transforms, 3);
rawStepAngles = zeros(frameCount, 1);
correctedStepAngles = zeros(frameCount, 1);
for frameIndex = 2:frameCount
    step = transforms(:, :, frameIndex) / transforms(:, :, frameIndex-1);
    rawStepAngles(frameIndex) = atan2d(step(2,1), step(1,1));
    historyStart = max(2, frameIndex-5);
    history = correctedStepAngles(historyStart:frameIndex-1);
    history = history(isfinite(history));
    if isempty(history)
        correctedStepAngles(frameIndex) = rawStepAngles(frameIndex);
    else
        prediction = median(history);
        difference = mod(rawStepAngles(frameIndex)-prediction+180, 360)-180;
        if abs(difference) > deviationThreshold
            correctedStepAngles(frameIndex) = prediction;
        else
            correctedStepAngles(frameIndex) = rawStepAngles(frameIndex);
        end
    end
end
cumulativeAngles = cumsum(correctedStepAngles);
stabilized = repmat(eye(3), 1, 1, frameCount);
for frameIndex = 2:frameCount
    angle = deg2rad(cumulativeAngles(frameIndex));
    rotation = [cos(angle) -sin(angle); sin(angle) cos(angle)];
    centre = rigidCenter(:);
    translation = centre - rotation * centre;
    stabilized(:, :, frameIndex) = [rotation translation; 0 0 1];
end
end
