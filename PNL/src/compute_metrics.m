function m = compute_metrics(estimate, truth)
%COMPUTE_METRICS 计算论文使用的相关系数、MAE、RMSE 和 SNR。

estimate = estimate(:);
truth = truth(:);
valid = isfinite(estimate) & isfinite(truth);
estimate = estimate(valid);
truth = truth(valid);
if isempty(estimate)
    m = struct('corr', NaN, 'mae', NaN, 'rmse', NaN, 'snr', NaN);
    return
end
estimate = estimate - mean(estimate);
truth = truth - mean(truth);
if std(estimate) == 0 || std(truth) == 0
    rho = NaN;
else
    rho = sum(estimate .* truth) / sqrt(sum(estimate .^ 2) * sum(truth .^ 2));
end
err = estimate - truth;
m.corr = rho;
m.mae = mean(abs(err));
m.rmse = sqrt(mean(err .^ 2));
m.snr = 20 * log10((sqrt(mean(truth .^ 2)) + eps) / (m.rmse + eps));
end
