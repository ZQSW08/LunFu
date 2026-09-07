function cache = apcv_process_sequence(frames, referenceFeatures, cfg)
%APCV_PROCESS_SEQUENCE 执行幅度粗配准并缓存各层相位残差。
% 该函数对应论文图 2 中的步骤 (1)-(4)，但尚不应用尺度换算。

n = size(frames, 3);
numLevels = numel(cfg.pyramidLevels);
cache.coarsePx = zeros(n, 1);
cache.alignedFrames = zeros(size(frames), 'single');
cache.phaseDifference = cell(numLevels, 1);
cache.unalignedPhaseDifference = cell(numLevels, 1);

for levelIndex = 1:numLevels
    bandSize = size(referenceFeatures.bands{levelIndex});
    cache.phaseDifference{levelIndex} = zeros([bandSize, n], 'single');
    cache.unalignedPhaseDifference{levelIndex} = zeros([bandSize, n], 'single');
end

for k = 1:n
    current = double(frames(:, :, k));
    unaligned = apcv_decompose_frame(current, cfg);
    coarse = apcv_estimate_coarse(unaligned.highProfile, ...
        referenceFeatures.highProfile, cfg.maxCoarseLag);
    alignedImage = apcv_shift_image(current, -coarse, cfg.direction);
    aligned = apcv_decompose_frame(alignedImage, cfg);

    cache.coarsePx(k) = coarse;
    cache.alignedFrames(:, :, k) = single(alignedImage);
    for levelIndex = 1:numLevels
        referenceBand = referenceFeatures.bands{levelIndex};
        cache.phaseDifference{levelIndex}(:, :, k) = single(angle( ...
            aligned.bands{levelIndex} .* conj(referenceBand)));
        cache.unalignedPhaseDifference{levelIndex}(:, :, k) = single(angle( ...
            unaligned.bands{levelIndex} .* conj(referenceBand)));
    end
end
end
