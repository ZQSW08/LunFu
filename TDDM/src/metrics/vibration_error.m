function e = vibration_error(reference, estimate)
%VIBRATION_ERROR 对应论文 Eq.(20) 的平均绝对误差。
reference = double(reference(:));
estimate = double(estimate(:));
n = min(numel(reference), numel(estimate));
if n == 0
    e = NaN;
else
    e = mean(abs(reference(1:n) - estimate(1:n)));
end
end
