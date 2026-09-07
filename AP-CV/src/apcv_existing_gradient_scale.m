function scalePxPerRad = apcv_existing_gradient_scale(referenceBand, mask, level)
%APCV_EXISTING_GRADIENT_SCALE 复现论文式 (12) 的相位梯度尺度。
% 子带每升一级下采样 2 倍，因此梯度先换算回原图像像素。

phaseStepY = angle(referenceBand(2:end, :) .* conj(referenceBand(1:end-1, :)));
validMask = logical(mask(1:end-1, :)) & logical(mask(2:end, :));
gradientValue = mean(phaseStepY(validMask), 'omitnan');
downsample = 2^(level-1);
scalePxPerRad = -downsample / gradientValue;
if ~isfinite(scalePxPerRad) || abs(scalePxPerRad) > 1e4
    scalePxPerRad = NaN;
end
end
