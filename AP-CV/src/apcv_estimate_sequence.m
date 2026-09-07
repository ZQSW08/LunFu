function result = apcv_estimate_sequence(frames, model, cfg)
%APCV_ESTIMATE_SEQUENCE 执行论文式 (14)-(17) 的完整位移估计。

n = size(frames, 3);
numLevels = numel(model.levels);
coarse = zeros(n, 1);
phaseActive = zeros(n, numLevels);
phaseAll = zeros(n, numLevels);
phaseAmplitude = zeros(n, numLevels);
unalignedPhase = zeros(n, numLevels);

for k = 1:n
    current = double(frames(:, :, k));
    unaligned = apcv_decompose_frame(current, cfg);
    coarse(k) = apcv_estimate_coarse(unaligned.highProfile, ...
        model.referenceFeatures.highProfile, cfg.maxCoarseLag);
    alignedImage = apcv_shift_image(current, -coarse(k), cfg.direction);
    aligned = apcv_decompose_frame(alignedImage, cfg);

    for i = 1:numLevels
        refBand = model.referenceFeatures.bands{i};
        difference = angle(aligned.bands{i} .* conj(refBand));
        unalignedDifference = angle(unaligned.bands{i} .* conj(refBand));
        phaseActive(k, i) = apcv_weighted_mean(difference, model.levels(i).activeMask);
        phaseAll(k, i) = mean(difference(:), 'omitnan');
        phaseAmplitude(k, i) = apcv_weighted_mean(difference, model.levels(i).amplitudeMask);
        unalignedPhase(k, i) = apcv_weighted_mean(unalignedDifference, model.levels(i).activeMask);
    end
end

gamma = model.gammaMmPerPixel;
byLevelPx = zeros(n, numLevels);
for i = 1:numLevels
    byLevelPx(:, i) = coarse + model.levels(i).scaleSelf * phaseActive(:, i);
end
i = model.selectedIndex;
result.coarsePx = coarse;
result.phaseActive = phaseActive;
result.phaseAll = phaseAll;
result.phaseAmplitude = phaseAmplitude;
result.unalignedPhase = unalignedPhase;
result.byLevelPx = byLevelPx;
result.byLevelMm = gamma * byLevelPx;
result.proposedPx = coarse + model.levels(i).scaleSelf * phaseActive(:, i);
result.amplitudeOnlyPx = coarse;
result.existingScalePx = coarse + model.levels(i).existingScale * phaseActive(:, i);
result.allPixelsPx = coarse + model.levels(i).scaleAll * phaseAll(:, i);
result.amplitudeMaskPx = coarse + ...
    model.levels(i).scaleAmplitudeMask * phaseAmplitude(:, i);
result.amplitudeOnlyMm = gamma * coarse;
result.proposedMm = gamma * (coarse + model.levels(i).scaleSelf * phaseActive(:, i));
result.existingScaleMm = gamma * (coarse + model.levels(i).existingScale * phaseActive(:, i));
result.allPixelsMm = gamma * (coarse + model.levels(i).scaleAll * phaseAll(:, i));
result.amplitudeMaskMm = gamma * (coarse + ...
    model.levels(i).scaleAmplitudeMask * phaseAmplitude(:, i));
result.translationProposedPx = model.levels(i).scaleSelf * phaseActive(:, i);
result.translationExistingPx = model.levels(i).existingScale * phaseActive(:, i);
end
