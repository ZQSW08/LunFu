function [D, diagnostics] = phase_affine_increment(reference, movingWarped, params)
%PHASE_AFFINE_INCREMENT Fit paper phase constraints to translation/affine motion.
% D maps reference coordinates to coordinates in MOVINGWARPED.

[height, width] = size(reference);
if ~isfield(params, 'directions'), params.directions = [0 45 90 135]; end
if ~isfield(params, 'bandwidth'), params.bandwidth = 1.0; end
if ~isfield(params, 'psi'), params.psi = 0; end
if ~isfield(params, 'supportSigma'), params.supportSigma = 2.0; end
if ~isfield(params, 'confidenceThreshold'), params.confidenceThreshold = 0; end
if ~isfield(params, 'confidencePercentile'), params.confidencePercentile = 60; end
if ~isfield(params, 'useDirectionMask'), params.useDirectionMask = false; end
if ~isfield(params, 'sampleStep'), params.sampleStep = 1; end
if ~isfield(params, 'model'), params.model = 'affine'; end
if ~isfield(params, 'primaryAxis'), params.primaryAxis = 'xy'; end
if ~isfield(params, 'usePhaseNonlinearityWeight'), params.usePhaseNonlinearityWeight = false; end
if ~isfield(params, 'phaseNonlinearityWindow'), params.phaseNonlinearityWindow = 7; end
if ~isfield(params, 'phaseNonlinearityScale'), params.phaseNonlinearityScale = 0.35; end
if ~isfield(params, 'phaseNonlinearityPercentile'), params.phaseNonlinearityPercentile = 88; end
if ~isfield(params, 'mask') || isempty(params.mask)
    analysisMask = true(height, width);
else
    analysisMask = logical(params.mask);
end

margin = min(max(2, round(params.lambda / 4)), ...
    max(1, floor(min(height, width) / 10)));
borderMask = false(height, width);
if height > 2 * margin && width > 2 * margin
    borderMask(1+margin:end-margin, 1+margin:end-margin) = true;
else
    borderMask(:) = true;
end
analysisMask = analysisMask & borderMask;

[xGrid, yGrid] = meshgrid(0:width-1, 0:height-1);
centerX = (width - 1) / 2;
centerY = (height - 1) / 2;
xCentered = xGrid - centerX;
yCentered = yGrid - centerY;

allA = cell(numel(params.directions), 1);
allB = cell(numel(params.directions), 1);
validCounts = zeros(numel(params.directions), 1);
confidenceCutoffs = zeros(numel(params.directions), 1);
nonlinearityCutoffs = nan(numel(params.directions), 1);
meanNonlinearityWeights = ones(numel(params.directions), 1);

for directionIndex = 1:numel(params.directions)
    theta = params.directions(directionIndex);
    if isfield(params,'referenceGaborResponses') && ...
            numel(params.referenceGaborResponses)>=directionIndex && ...
            ~isempty(params.referenceGaborResponses{directionIndex})
        q1 = params.referenceGaborResponses{directionIndex};
    else
        q1 = gabor_response(reference, params.lambda, theta, params.bandwidth, ...
            params.psi, params.supportSigma);
    end
    q2 = gabor_response(movingWarped, params.lambda, theta, params.bandwidth, ...
        params.psi, params.supportSigma);
    [gx1, gy1] = localPhaseGradient(q1);
    [gx2, gy2] = localPhaseGradient(q2);
    cx = 0.5 * (gx1 + gx2);
    cy = 0.5 * (gy1 + gy2);
    ct = angle(q2 .* conj(q1));

    amplitude1 = abs(q1).^2;
    amplitude2 = abs(q2).^2;
    confidence = (amplitude1 .* amplitude2) ./ ...
        max((amplitude1 + amplitude2).^(3/2), eps);

    % PNOF 启发的相位非线性可靠度：稳定载波的局部相位梯度应接近其邻域均值。
    % 偏差越大，说明纹理、噪声、遮挡或滤波方向使相位约束越不可信。
    if params.usePhaseNonlinearityWeight
        windowSize = max(3, 2*floor(params.phaseNonlinearityWindow/2)+1);
        meanGx = imboxfilt(cx, windowSize, 'Padding', 'symmetric');
        meanGy = imboxfilt(cy, windowSize, 'Padding', 'symmetric');
        carrierFloor = 0.1 * 2*pi / params.lambda;
        phaseNonlinearity = hypot(cx-meanGx, cy-meanGy) ./ ...
            max(hypot(meanGx, meanGy), carrierFloor);
        nonlinearityWeight = 1 ./ ...
            (1 + (phaseNonlinearity/max(params.phaseNonlinearityScale,eps)).^2);
        confidence = confidence .* nonlinearityWeight;
    else
        phaseNonlinearity = zeros(height, width);
        nonlinearityWeight = ones(height, width);
    end

    candidate = analysisMask & isfinite(cx) & isfinite(cy) & isfinite(ct) & ...
        isfinite(confidence);
    if params.useDirectionMask
        thetaRad = deg2rad(theta);
        candidate = candidate & ...
            (cos(thetaRad) * cx + sin(thetaRad) * cy > 0);
    end
    if params.usePhaseNonlinearityWeight
        finiteNonlinearity = phaseNonlinearity(candidate & isfinite(phaseNonlinearity));
        nonlinearityCutoff = localPercentile(finiteNonlinearity, ...
            params.phaseNonlinearityPercentile);
        nonlinearityCutoffs(directionIndex) = nonlinearityCutoff;
        candidate = candidate & phaseNonlinearity <= nonlinearityCutoff;
        selectedWeights = nonlinearityWeight(candidate);
        if ~isempty(selectedWeights)
            meanNonlinearityWeights(directionIndex) = mean(selectedWeights);
        end
    end
    positiveConfidence = confidence(candidate & confidence > 0);
    percentileCutoff = localPercentile(positiveConfidence, params.confidencePercentile);
    cutoff = max(params.confidenceThreshold, percentileCutoff);
    valid = candidate & confidence >= cutoff;
    if params.sampleStep > 1
        sampled = false(height, width);
        sampled(1:params.sampleStep:end, 1:params.sampleStep:end) = true;
        valid = valid & sampled;
    end

    index = find(valid);
    validCounts(directionIndex) = numel(index);
    confidenceCutoffs(directionIndex) = cutoff;
    if isempty(index)
        continue;
    end
    weight = confidence(index);
    weight = weight / max(max(weight), eps);
    if strcmpi(params.model, 'translation')
        switch lower(params.primaryAxis)
            case 'x'
                design = cx(index);
            case 'y'
                design = cy(index);
            otherwise
                design = [cx(index), cy(index)];
        end
    elseif strcmpi(params.model, 'rotation')
        if ~isfield(params,'rigidCenter') || isempty(params.rigidCenter)
            rotationCenter = [centerX centerY];
        else
            rotationCenter = double(params.rigidCenter(:).');
        end
        xFromCenter = xGrid-rotationCenter(1);
        yFromCenter = yGrid-rotationCenter(2);
        % 小转角刚体位移 u=-omega*y、v=omega*x。直接解一个角速度参数，
        % 避免先拟合六参数仿射再投影时由背景、遮挡引起的病态与跳变。
        design = -cx(index).*yFromCenter(index)+cy(index).*xFromCenter(index);
    else
        design = [cx(index).*xCentered(index), cx(index).*yCentered(index), cx(index), ...
            cy(index).*xCentered(index), cy(index).*yCentered(index), cy(index)];
    end
    allA{directionIndex} = design .* weight;
    allB{directionIndex} = -ct(index) .* weight;
end

A = vertcat(allA{:});
b = vertcat(allB{:});
if strcmpi(params.model,'affine')
    parameterCount = 6;
elseif strcmpi(params.model,'rotation')
    parameterCount = 1;
elseif any(strcmpi(params.primaryAxis,{'x','y'}))
    parameterCount = 1;
else
    parameterCount = 2;
end
if size(A, 1) < max(20, 4 * parameterCount)
    D = eye(3);
    diagnostics = struct('validCount', size(A,1), 'rank', rank(A), ...
        'condition', Inf, 'residualRms', NaN, 'confidenceCutoffs', confidenceCutoffs);
    diagnostics.nonlinearityCutoffs = nonlinearityCutoffs;
    diagnostics.meanNonlinearityWeights = meanNonlinearityWeights;
    return;
end

normalMatrix = A.' * A;
normalRhs = A.' * b;
matrixCondition = cond(normalMatrix);
if isfinite(matrixCondition) && matrixCondition < 1e10
    coefficients = normalMatrix \ normalRhs;
else
    coefficients = pinv(A, 1e-8) * b;
end

if strcmpi(params.model, 'translation')
    switch lower(params.primaryAxis)
        case 'x'
            D = [1 0 coefficients(1); 0 1 0; 0 0 1];
        case 'y'
            D = [1 0 0; 0 1 coefficients(1); 0 0 1];
        otherwise
            D = [1 0 coefficients(1); 0 1 coefficients(2); 0 0 1];
    end
elseif strcmpi(params.model,'rotation')
    if ~isfield(params,'rigidCenter') || isempty(params.rigidCenter)
        rotationCenter = [centerX centerY];
    else
        rotationCenter = double(params.rigidCenter(:).');
    end
    rotationAngle = coefficients(1);
    rotation = [cos(rotationAngle) -sin(rotationAngle); ...
        sin(rotationAngle) cos(rotationAngle)];
    centre = rotationCenter(:);
    translation = centre-rotation*centre;
    D = [rotation translation; 0 0 1];
else
    a1 = coefficients(1); a2 = coefficients(2); txCenter = coefficients(3);
    a4 = coefficients(4); a5 = coefficients(5); tyCenter = coefficients(6);
    tx = txCenter - a1 * centerX - a2 * centerY;
    ty = tyCenter - a4 * centerX - a5 * centerY;
    D = [1+a1 a2 tx; a4 1+a5 ty; 0 0 1];
end
residual = A * coefficients - b;
diagnostics = struct('validCount', sum(validCounts), 'validByDirection', validCounts, ...
    'rank', rank(A), 'condition', matrixCondition, ...
    'residualRms', sqrt(mean(residual.^2)), ...
    'confidenceCutoffs', confidenceCutoffs, ...
    'nonlinearityCutoffs', nonlinearityCutoffs, ...
    'meanNonlinearityWeights', meanNonlinearityWeights);
end

function [gx, gy] = localPhaseGradient(q)
[height, width] = size(q);
gx = zeros(height, width);
gy = zeros(height, width);
if width > 2
    gx(:, 2:end-1) = 0.5 * angle(q(:, 3:end) .* conj(q(:, 1:end-2)));
    gx(:, 1) = angle(q(:, 2) .* conj(q(:, 1)));
    gx(:, end) = angle(q(:, end) .* conj(q(:, end-1)));
end
if height > 2
    gy(2:end-1, :) = 0.5 * angle(q(3:end, :) .* conj(q(1:end-2, :)));
    gy(1, :) = angle(q(2, :) .* conj(q(1, :)));
    gy(end, :) = angle(q(end, :) .* conj(q(end-1, :)));
end
end

function value = localPercentile(values, percentile)
if isempty(values) || percentile <= 0
    value = 0;
    return;
end
values = sort(values(:));
position = 1 + (numel(values) - 1) * min(max(percentile, 0), 100) / 100;
lowerIndex = floor(position);
upperIndex = ceil(position);
if lowerIndex == upperIndex
    value = values(lowerIndex);
else
    fraction = position - lowerIndex;
    value = values(lowerIndex) * (1 - fraction) + values(upperIndex) * fraction;
end
end
