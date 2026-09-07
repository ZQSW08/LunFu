function [transforms, diagnostics] = track_sequence_affine(frames, params, referenceMode)
%TRACK_SEQUENCE_AFFINE Estimate transforms from frame 1 to every frame.

if nargin < 3 || isempty(referenceMode), referenceMode = 'adjacent'; end
frameCount = size(frames, 3);
transforms = repmat(eye(3), 1, 1, frameCount);
diagnostics = cell(frameCount, 1);
fixedParams = params;
if strcmpi(referenceMode, 'fixed') && ...
        (~isfield(params,'cacheFixedReference') || params.cacheFixedReference)
    % 固定参考模式下，首帧的金字塔和 Gabor 响应对所有后续帧都不变。
    % 缓存只改变计算顺序，不改变相位约束或最终解。
    fixedParams.referencePyramid = build_gaussian_pyramid( ...
        frames(:, :, 1), params.levels);
    fixedParams.referenceGaborResponses = ...
        localReferenceGaborCache(fixedParams.referencePyramid, params);
end
for frameIndex = 2:frameCount
    if strcmpi(referenceMode, 'fixed')
        [transforms(:, :, frameIndex), diagnostics{frameIndex}] = ...
            mpme_estimate_affine(frames(:, :, 1), frames(:, :, frameIndex), fixedParams);
    else
        [stepTransform, diagnostics{frameIndex}] = mpme_estimate_affine( ...
            frames(:, :, frameIndex-1), frames(:, :, frameIndex), params);
        if isfield(params, 'enforceRigid') && params.enforceRigid
            stepTransform = localProjectRigid(stepTransform, size(frames, 1), ...
                size(frames, 2), params);
        end
        transforms(:, :, frameIndex) = stepTransform * transforms(:, :, frameIndex-1);
    end
end
end

function responseCache = localReferenceGaborCache(referencePyramid, params)
responseCache = cell(numel(referencePyramid),1);
for level = 1:numel(referencePyramid)
    responseCache{level} = cell(numel(params.directions),1);
    for directionIndex = 1:numel(params.directions)
        responseCache{level}{directionIndex} = gabor_response( ...
            referencePyramid{level},params.lambda,params.directions(directionIndex), ...
            params.bandwidth,params.psi,params.supportSigma);
    end
end
end

function rigid = localProjectRigid(affine, height, width, params)
linearPart = affine(1:2, 1:2);
[left, ~, right] = svd(linearPart);
rotation = left * diag([1 sign(det(left*right.'))]) * right.';
if isfield(params, 'rigidCenter') && ~isempty(params.rigidCenter)
    centre = params.rigidCenter(:);
    mappedCentre = centre;
else
    centre = [(width-1)/2; (height-1)/2];
    mappedCentre = affine(1:2, 1:2) * centre + affine(1:2, 3);
end
translation = mappedCentre - rotation * centre;
rigid = [rotation translation; 0 0 1];
end
