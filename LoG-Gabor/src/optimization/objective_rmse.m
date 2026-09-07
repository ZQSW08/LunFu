function value = objective_rmse(params, video, truth, pixel, cfg, theta0)
%OBJECTIVE_RMSE 论文单任务优化目标：估计位移与预定义真值的 RMSE。
if nargin < 6 || isempty(theta0), theta0 = cfg.loggabor.theta0; end
measured = pme_measure(video, params, cfg, pixel, theta0).displacement;
truth = truth(:);
measured = measured(:);
if numel(measured) ~= numel(truth)
    error('truth 与 PME 输出长度不一致。');
end
value = sqrt(mean((measured - truth).^2));
if ~isfinite(value), value = realmax; end
end
