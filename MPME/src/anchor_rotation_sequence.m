function [anchored, anchoredAngles, anchorAngles, anchorQuality] = ...
    anchor_rotation_sequence(frames, adjacentTransforms, rigidCenter, options)
%ANCHOR_ROTATION_SEQUENCE 用首帧绝对转角修正相邻帧累计漂移，避免时程后半段滞后。

if nargin < 4, options = struct; end
if ~isfield(options,'minimumQuality'), options.minimumQuality = 1.05; end
if ~isfield(options,'symmetryOrder'), options.symmetryOrder = 1; end
if ~isfield(options,'maximumCorrectionDegrees'), options.maximumCorrectionDegrees = 3; end
imageSize = [size(frames,1) size(frames,2)];
[~, ~, adjacentSteps] = stabilize_rotation_sequence( ...
    adjacentTransforms, imageSize, 5, rigidCenter);
predictedAngles = cumsum(adjacentSteps);
frameCount = size(frames,3);
anchorAngles = zeros(frameCount,1);
anchorQuality = inf(frameCount,1);
anchoredAngles = predictedAngles;
anchorAccepted = false(frameCount,1);
anchorAccepted(1) = true;
anchorCorrection = nan(frameCount,1);
anchorCorrection(1) = 0;

for frameIndex = 2:frameCount
    [wrappedAngle, anchorQuality(frameIndex)] = estimate_rotation_phase_anchor( ...
        frames(:,:,1), frames(:,:,frameIndex), rigidCenter, options);
    period = 360 / max(1, options.symmetryOrder);
    candidate = wrappedAngle + period * round((predictedAngles(frameIndex)-wrappedAngle)/period);
    anchorAngles(frameIndex) = candidate;
    correction = candidate-predictedAngles(frameIndex);
    if isfinite(candidate) && anchorQuality(frameIndex) >= options.minimumQuality && ...
            abs(correction)<=options.maximumCorrectionDegrees
        anchoredAngles(frameIndex) = candidate;
        anchorAccepted(frameIndex) = true;
        anchorCorrection(frameIndex) = correction;
    end
end

% 只插值“锚相对连续预测的修正量”，不能直接插值绝对角度；否则早期几个
% 错周期锚会把后半段连续转角压平，表现成明显延迟甚至停转。
valid = isfinite(anchoredAngles) & anchorAccepted;
if nnz(valid) >= 2
    interpolatedCorrection = interp1(find(valid),anchorCorrection(valid), ...
        (1:frameCount).','linear','extrap');
    interpolatedCorrection = min(max(interpolatedCorrection, ...
        -options.maximumCorrectionDegrees),options.maximumCorrectionDegrees);
    anchoredAngles = predictedAngles+interpolatedCorrection;
end

anchored = repmat(eye(3),1,1,frameCount);
centre = rigidCenter(:);
for frameIndex = 2:frameCount
    angle = deg2rad(anchoredAngles(frameIndex));
    rotation = [cos(angle) -sin(angle); sin(angle) cos(angle)];
    translation = centre - rotation*centre;
    anchored(:,:,frameIndex) = [rotation translation; 0 0 1];
end
end
