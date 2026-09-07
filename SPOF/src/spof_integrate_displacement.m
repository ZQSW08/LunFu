function signal = spof_integrate_displacement(vx, vy, fs, roi, cfg)
% SPOF_INTEGRATE_DISPLACEMENT 对 ROI 内非零有效光流做平均、积分和线性去趋势。
% 论文对应式(23)-(25)，输出单位为像素；x 向右、y 向下为正。

roi = logical(roi);
n = size(vx, 3);
meanVx = zeros(n, 1);
meanVy = zeros(n, 1);
for t = 1:n
    x = double(vx(:, :, t));
    y = double(vy(:, :, t));
    validX = roi & isfinite(x) & abs(x) > 0;
    validY = roi & isfinite(y) & abs(y) > 0;
    if isfield(cfg, 'integrationConfidence') && ...
            isfield(cfg, 'integrationConfidenceThreshold')
        confidence = double(cfg.integrationConfidence(:, :, t));
        validX = validX & confidence >= cfg.integrationConfidenceThreshold;
        validY = validY & confidence >= cfg.integrationConfidenceThreshold;
    end
    if any(validX(:)), meanVx(t) = mean(x(validX)); end
    if any(validY(:)), meanVy(t) = mean(y(validY)); end
end

dt = 1 / fs;
dispX = cumsum(meanVx) * dt;
dispY = cumsum(meanVy) * dt;
if cfg.detrend
    time = (0:n-1)';
    dispX = dispX - polyval(polyfit(time, dispX, 1), time);
    dispY = dispY - polyval(polyfit(time, dispY, 1), time);
end
signal = struct('vx', meanVx, 'vy', meanVy, 'x', dispX, 'y', dispY, ...
    'time', (0:n-1)'/fs, 'scaleMmPerPixel', cfg.scaleMmPerPixel);
% 未完成标定时必须保留物理量为空，不能把“1”误当作 1 mm/Px。
% 真实入口用 [] 表示未标定；合成实验仍可使用数值比例尺。
if isfield(cfg, 'scaleMmPerPixel') && ~isempty(cfg.scaleMmPerPixel)
    signal.xMm = dispX * cfg.scaleMmPerPixel;
    signal.yMm = dispY * cfg.scaleMmPerPixel;
else
    signal.xMm = [];
    signal.yMm = [];
end
end
