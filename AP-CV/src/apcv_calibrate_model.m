function model = apcv_calibrate_model(frames, gammaMmPerPixel, cfg)
%APCV_CALIBRATE_MODEL 完成主动像素、层级和相位尺度的自标定。
% 对应论文式 (18)-(26)，不使用真值位移参与任何参数选择。

reference = double(frames(:, :, 1));
referenceFeatures = apcv_decompose_frame(reference, cfg);
cache = apcv_process_sequence(frames, referenceFeatures, cfg);
numLevels = numel(cfg.pyramidLevels);

model.referenceImage = reference;
model.referenceFeatures = referenceFeatures;
model.gammaMmPerPixel = gammaMmPerPixel;
model.levels = repmat(struct(), numLevels, 1);

for i = 1:numLevels
    [mask, rho, threshold] = apcv_select_active_pixels(cache.phaseDifference{i});
    amplitude = abs(referenceFeatures.bands{i});
    sortedAmplitude = sort(amplitude(:), 'descend');
    topCount = min(30, numel(sortedAmplitude));
    amplitudeThreshold = mean(sortedAmplitude(1:topCount)) / 5;
    amplitudeMask = amplitude >= amplitudeThreshold;

    model.levels(i).level = cfg.pyramidLevels(i);
    model.levels(i).activeMask = mask;
    model.levels(i).correlationMap = rho;
    model.levels(i).correlationThreshold = threshold;
    model.levels(i).amplitudeMask = amplitudeMask;
    model.levels(i).allMask = true(size(mask));
    % 式 (12) 的梯度尺度作为完整方法实现保留，便于单独研究。
    model.levels(i).gradientScale = apcv_existing_gradient_scale( ...
        referenceFeatures.bands{i}, mask, cfg.pyramidLevels(i));
    % 论文第 4 页指出对照文献通常直接使用平均相位而不标定 s。
    % 本工程中正位移对应负相位，因此未标定单位尺度写为 -1 px/rad。
    model.levels(i).existingScale = -1;
end

model.optimization = apcv_optimize_pyramid_level(cache.phaseDifference, ...
    cfg.pyramidLevels);
model.selectedIndex = model.optimization.selectedIndex;
model.selectedLevel = model.optimization.selectedLevel;

% 论文式 (25)-(26)：对若干均匀抽取帧分别构造 +1/-1 像素图像。
n = size(frames, 3);
sampleCount = min(n, cfg.calibrationMaxFrames);
sampleIndices = unique(round(linspace(1, n, sampleCount)));
numSamples = numel(sampleIndices);
activeResponse = nan(numLevels, numSamples);
allResponse = nan(numLevels, numSamples);
amplitudeResponse = nan(numLevels, numSamples);

for j = 1:numSamples
    image = double(cache.alignedFrames(:, :, sampleIndices(j)));
    base = apcv_decompose_frame(image, cfg);
    plus = apcv_decompose_frame(apcv_shift_image(image, +1, cfg.direction), cfg);
    minus = apcv_decompose_frame(apcv_shift_image(image, -1, cfg.direction), cfg);
    for i = 1:numLevels
        dPlus = angle(plus.bands{i} .* conj(base.bands{i}));
        dMinus = angle(base.bands{i} .* conj(minus.bands{i}));
        activeResponse(i, j) = 0.5 * ( ...
            apcv_weighted_mean(dPlus, model.levels(i).activeMask) + ...
            apcv_weighted_mean(dMinus, model.levels(i).activeMask));
        allResponse(i, j) = 0.5 * (mean(dPlus(:), 'omitnan') + ...
            mean(dMinus(:), 'omitnan'));
        amplitudeResponse(i, j) = 0.5 * ( ...
            apcv_weighted_mean(dPlus, model.levels(i).amplitudeMask) + ...
            apcv_weighted_mean(dMinus, model.levels(i).amplitudeMask));
    end
end

for i = 1:numLevels
    model.levels(i).scaleSelf = responseToScale(activeResponse(i, :));
    model.levels(i).scaleAll = responseToScale(allResponse(i, :));
    model.levels(i).scaleAmplitudeMask = responseToScale(amplitudeResponse(i, :));
    model.levels(i).calibrationResponse = activeResponse(i, :);
    model.levels(i).calibrationResponseAll = allResponse(i, :);
    model.levels(i).calibrationResponseAmplitude = amplitudeResponse(i, :);
end

model.calibrationSampleIndices = sampleIndices;
model.calibrationCache = cache;
end

function scale = responseToScale(response)
% 严格按式 (26) 对逐帧 2/(DeltaPhi+ + DeltaPhi-) 求平均。
valid = isfinite(response) & abs(response) > 1e-4;
scale = mean(1 ./ response(valid), 'omitnan');
end
