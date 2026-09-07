function csp = px_extract_csp(video, cfg)
% 使用matlabPyrTools的复数可转向金字塔提取CSP局部相位。
% 最小尺度对应最高空间频率子带，默认按照论文建议使用最小尺度。
[height, width, frames] = size(video);
if ndims(video) ~= 3
    error('输入视频必须是高度×宽度×帧数的灰度数组。');
end

sigmaCandidate = cfg.pyramid.sigmaReference * min(height, width) / min(cfg.pyramid.referenceSize);
sigma = min(max(sigmaCandidate, 1), 3);
[firstPyr, firstIndices] = buildSCFpyr(double(video(:, :, 1)), cfg.pyramid.height, cfg.pyramid.order, cfg.pyramid.twidth);
numOrientations = cfg.pyramid.order + 1;
bandIndex = cfg.pyramid.scale * numOrientations + 2;
firstBand = pyrBand(firstPyr, firstIndices, bandIndex);
[bandHeight, bandWidth] = size(firstBand);

% 第一遍只统计方向平均幅值，避免同时保存全部方向的复数系数。
orientationMean = zeros(numOrientations, 1);
for frameIndex = 1:frames
    [pyr, indices] = buildSCFpyr(double(video(:, :, frameIndex)), cfg.pyramid.height, cfg.pyramid.order, cfg.pyramid.twidth);
    for orientation = 1:numOrientations
        band = pyrBand(pyr, indices, cfg.pyramid.scale * numOrientations + orientation + 1);
        orientationMean(orientation) = orientationMean(orientation) + mean(abs(band(:)));
    end
end
orientationMean = orientationMean / frames;

% 根据用户选择的物理方向限定候选方向子带。
% x/y映射不是论文中明确给出的MATLAB编号，而是本实现为保证方向可控
% 而采用的显式配置；auto则在全部方向中按平均幅值选择。
analysisDirection = lower(strtrim(cfg.direction.analysis));
switch analysisDirection
    case 'x'
        orientationCandidates = cfg.direction.orientationMap.x;
    case 'y'
        orientationCandidates = cfg.direction.orientationMap.y;
    case 'auto'
        orientationCandidates = 1:numOrientations;
    otherwise
        error('cfg.direction.analysis必须为x、y或auto。');
end
orientationCandidates = unique(round(orientationCandidates(:)'));
orientationCandidates = orientationCandidates(orientationCandidates >= 1 & orientationCandidates <= numOrientations);
if isempty(orientationCandidates)
    error('方向配置没有对应的有效CSP方向子带。');
end
[~, localIndex] = max(orientationMean(orientationCandidates));
selectedOrientation = orientationCandidates(localIndex);

selectedCoefficients = complex(zeros(bandHeight, bandWidth, frames));
amplitude = zeros(bandHeight, bandWidth, frames, 'single');
for frameIndex = 1:frames
    [pyr, indices] = buildSCFpyr(double(video(:, :, frameIndex)), cfg.pyramid.height, cfg.pyramid.order, cfg.pyramid.twidth);
    band = pyrBand(pyr, indices, cfg.pyramid.scale * numOrientations + selectedOrientation + 1);
    selectedCoefficients(:, :, frameIndex) = band;
    amplitude(:, :, frameIndex) = single(abs(band));
end

reference = selectedCoefficients(:, :, 1);
phaseDifference = zeros(bandHeight, bandWidth, frames, 'single');
for frameIndex = 1:frames
    phaseDifference(:, :, frameIndex) = single(angle(selectedCoefficients(:, :, frameIndex) .* conj(reference)));
end

% 对加权绝对相位差进行手写高斯卷积，保证不依赖额外工具箱。
weighted = abs(phaseDifference) .* amplitude;
radius = max(1, ceil(3 * sigma));
axisValues = (-radius:radius)';
gaussianKernel = exp(-0.5 * (axisValues / sigma).^2);
gaussianKernel = gaussianKernel / sum(gaussianKernel);
foregroundResponse = zeros(size(weighted), 'single');
for frameIndex = 1:frames
    current = double(weighted(:, :, frameIndex));
    current = conv2(gaussianKernel, gaussianKernel', current, 'same');
    foregroundResponse(:, :, frameIndex) = single(current);
end

csp.phaseDifference = phaseDifference;
csp.amplitude = amplitude;
csp.foregroundResponse = foregroundResponse;
csp.orientation = selectedOrientation;
csp.direction = analysisDirection;
csp.orientationCandidates = orientationCandidates;
csp.orientationMean = orientationMean;
csp.sigma = sigma;
csp.bandSize = [bandHeight, bandWidth];
end
