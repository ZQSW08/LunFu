function metrics = spof_metrics(reference, estimate)
% SPOF_METRICS 计算论文式(26)-(28)中的 MAE、RMSE 和 PCC。
reference = double(reference(:));
estimate = double(estimate(:));
valid = isfinite(reference) & isfinite(estimate);
reference = reference(valid);
estimate = estimate(valid);
if isempty(reference)
    metrics = struct('mae', NaN, 'rmse', NaN, 'pcc', NaN);
    return;
end
delta = reference - estimate;
metrics = struct();
metrics.mae = mean(abs(delta));
metrics.rmse = sqrt(mean(delta.^2));
centeredReference = reference - mean(reference);
centeredEstimate = estimate - mean(estimate);
denominator = sqrt(sum(centeredReference.^2) * sum(centeredEstimate.^2));
if denominator < eps
    metrics.pcc = NaN;
else
    metrics.pcc = sum(centeredReference .* centeredEstimate) / denominator;
end
end
