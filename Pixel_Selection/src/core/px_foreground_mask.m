function foreground = px_foreground_mask(response, cfg)
% 按逐帧均值加标准差阈值累积候选区域，并保留最大连通域Cmax。
[height, width, frames] = size(response);
candidate = false(height, width, frames);
thresholds = zeros(frames, 1);
unionMask = false(height, width);
for frameIndex = 1:frames
    current = abs(double(response(:, :, frameIndex)));
    margin = min([cfg.foreground.borderMargin, floor((height - 1) / 2), floor((width - 1) / 2)]);
    if margin > 0
        current([1:margin, height-margin+1:height], :) = 0;
        current(:, [1:margin, width-margin+1:width]) = 0;
        statisticRegion = current(margin+1:height-margin, margin+1:width-margin);
    else
        statisticRegion = current;
    end
    thresholds(frameIndex) = mean(statisticRegion(:)) + cfg.foreground.thresholdStd * std(statisticRegion(:));
    candidate(:, :, frameIndex) = current > thresholds(frameIndex);
    unionMask = unionMask | candidate(:, :, frameIndex);
end

mask = px_largest_component(unionMask);
foreground.mask = mask;
foreground.candidate = candidate;
foreground.union = unionMask;
foreground.thresholds = thresholds;
foreground.pixelCount = nnz(mask);
end
