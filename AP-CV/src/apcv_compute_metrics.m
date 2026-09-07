function metrics = apcv_compute_metrics(estimate, truth)
%APCV_COMPUTE_METRICS 计算论文复现使用的误差指标。

errorValue = estimate(:) - truth(:);
metrics.rmse = sqrt(mean(errorValue.^2, 'omitnan'));
metrics.mae = mean(abs(errorValue), 'omitnan');
metrics.maxAbs = max(abs(errorValue), [], 'omitnan');
valid = isfinite(estimate(:)) & isfinite(truth(:));
if nnz(valid) >= 3
    c = corrcoef(estimate(valid), truth(valid));
    metrics.correlation = c(1, 2);
else
    metrics.correlation = NaN;
end
end
