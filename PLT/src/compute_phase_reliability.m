function reliability = compute_phase_reliability(amplitude, minFraction)
% COMPUTE_PHASE_RELIABILITY 用首帧/当前帧的局部幅值筛除不稳定相位。
% 相位负责匹配，幅值只负责判断相位是否可信；这不是退回强度域匹配。

amplitude = double(amplitude);
finiteAmplitude = amplitude(isfinite(amplitude));
if isempty(finiteAmplitude)
    reliability = false(size(amplitude));
    return;
end
sortedAmplitude = sort(finiteAmplitude(:));
index = max(1, min(numel(sortedAmplitude), round(0.20*numel(sortedAmplitude))));
referenceAmplitude = sortedAmplitude(index);
threshold = max(eps, minFraction * max(referenceAmplitude, eps));
reliability = isfinite(amplitude) & amplitude >= threshold;
end
