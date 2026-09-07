function value = px_percentile(x, percentage)
% 计算不依赖统计工具箱的线性插值百分位数。
x = sort(double(x(:)));
x = x(isfinite(x));
if isempty(x)
    value = NaN;
    return;
end
if numel(x) == 1
    value = x(1);
    return;
end
position = 1 + (numel(x) - 1) * percentage / 100;
lower = floor(position);
upper = ceil(position);
if lower == upper
    value = x(lower);
else
    value = x(lower) + (position - lower) * (x(upper) - x(lower));
end
end
