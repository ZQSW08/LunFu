function [H, diagnostics] = mpme_estimate_affine(reference, moving, params)
%MPME_ESTIMATE_AFFINE Coarse-to-fine phase motion estimate for one frame pair.

if isfield(params,'referencePyramid') && ~isempty(params.referencePyramid)
    referencePyramid = params.referencePyramid;
else
    referencePyramid = build_gaussian_pyramid(reference, params.levels);
end
movingPyramid = build_gaussian_pyramid(moving, params.levels);
if isfield(params, 'mask') && ~isempty(params.mask)
    maskPyramid = build_gaussian_pyramid(double(params.mask), params.levels);
else
    maskPyramid = cell(params.levels, 1);
end

H = eye(3);
diagnostics = cell(params.levels, 1);
for level = params.levels:-1:1
    if level < params.levels
        scale = diag([2 2 1]);
        H = scale * H / scale;
    end
    currentParams = params;
    if isfield(params,'referenceGaborResponses') && ...
            numel(params.referenceGaborResponses)>=level
        currentParams.referenceGaborResponses = ...
            params.referenceGaborResponses{level};
    end
    if isfield(params,'rigidCenter') && ~isempty(params.rigidCenter)
        pyramidScale = 2^(level-1);
        % imresize 金字塔采用像素中心坐标，轮毂中心也必须同步缩放。
        currentParams.rigidCenter = (double(params.rigidCenter)+0.5) / ...
            pyramidScale-0.5;
    end
    if ~isempty(maskPyramid{level})
        currentParams.mask = maskPyramid{level} > 0.5;
    end
    iterations = 1;
    if isfield(params, 'iterationsPerLevel')
        iterations = params.iterationsPerLevel;
    end
    levelDiagnostics = cell(iterations, 1);
    for iteration = 1:iterations
        [movingWarped, validWarp] = warp_image_h(movingPyramid{level}, H, ...
            median(movingPyramid{level}(:)));
        if isfield(currentParams, 'mask') && ~isempty(currentParams.mask)
            currentParams.mask = currentParams.mask & validWarp;
        else
            currentParams.mask = validWarp;
        end
        [increment, levelDiagnostics{iteration}] = phase_affine_increment( ...
            referencePyramid{level}, movingWarped, currentParams);
        H = H * increment;
    end
    diagnostics{level} = levelDiagnostics;
end
end
