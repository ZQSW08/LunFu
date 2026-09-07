function result = active_pixel_selection(frame, cfg)
%ACTIVE_PIXEL_SELECTION 方向振幅 + 闭环填充 + 自适应阈值的可复现实现。
% 论文没有公开完整阈值程序，因此将百分位数和 minArea 作为显式推断参数。
[amplitude, ~] = local_amplitude_map(frame, cfg);
combined = amplitude.combined;
threshold = percentile_value(combined(:), cfg.active.initialPercentile);
edgeMask = combined >= threshold;
filledMask = morphology_fill(edgeMask);
% 将填充区域外沿与外部邻域的均值作为局部阈值，体现论文描述的两侧比较。
localThreshold = threshold * ones(size(combined));
boundary = filledMask & ~edgeMask;
for r = 2:size(combined,1)-1
    for c = 2:size(combined,2)-1
        if boundary(r,c)
            inner = combined(max(1,r-1):min(end,r+1), max(1,c-1):min(end,c+1));
            localThreshold(r,c) = 0.5*(mean(inner(:)) + threshold);
        end
    end
end
if cfg.active.keepFilledRegions
    active = filledMask & (combined >= min(localThreshold(:)));
else
    active = edgeMask;
end
try
    active = bwareaopen(active, cfg.active.minArea, 8);
catch
end
result.amplitude = combined;
result.horizontalAmplitude = amplitude.horizontal;
result.verticalAmplitude = amplitude.vertical;
result.threshold = threshold;
result.edgeMask = edgeMask;
result.filledMask = filledMask;
result.activeMask = logical(active);
result.localThreshold = localThreshold;
end

function value = percentile_value(x, p)
x = sort(x(isfinite(x)));
if isempty(x), value = 0; return; end
index = max(1, min(numel(x), 1 + round((p/100)*(numel(x)-1))));
value = x(index);
end
