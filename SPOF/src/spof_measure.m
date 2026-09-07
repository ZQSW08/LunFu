function result = spof_measure(video, fs, roi, cfg, flow)
% SPOF_MEASURE 执行完整相位光流测振链。
% cfg.method='SPOF' 是论文主方法；POF/AW-POF/MP-POF/PNOF 为统一对比入口。

if nargin < 5 || isempty(flow)
    % 同一视频的多方法对比应复用相位光流，避免重复执行昂贵的 Gabor 卷积。
    flow = spof_extract_phase_flow(video, fs, cfg);
end
method = upper(cfg.method);
confidence = ones(size(flow.vx), 'single');
posterior = zeros(size(flow.vx));
abnormalMask = false(size(flow.vx));
refinedX = flow.vx;
refinedY = flow.vy;
gmmX = [];
gmmY = [];

switch method
    case 'POF'
        finalX = flow.vx;
        finalY = flow.vy;
    case 'AW-POF'
        % 原始 AW-POF 实现未随本论文公开；用幅值置信度对原始流加权。
        confidence = spof_build_confidence(flow, flow.amplitudes, cfg);
        edge = confidence;
        finalX = flow.vx .* edge;
        finalY = flow.vy .* edge;
    case 'MP-POF'
        % 原始 MP-POF 实现未随本论文公开；用时间中值滤波作为兼容近似。
        finalX = temporal_median(flow.vx, 5);
        finalY = temporal_median(flow.vy, 5);
    case 'PNOF'
        % PNOF 的详细权重公式不在本论文中展开；构造二阶时间变化兼容权重。
        nonlinearity = temporal_nonlinearity(flow.vx, flow.vy);
        weight = 1 ./ (1 + nonlinearity);
        finalX = flow.vx .* weight;
        finalY = flow.vy .* weight;
    otherwise
        confidence = spof_build_confidence(flow, flow.amplitudes, cfg);
        gmmX = spof_weighted_gmm2(flow.vx, confidence, cfg);
        gmmY = spof_weighted_gmm2(flow.vy, confidence, cfg);
        posterior = max(gmmX.posteriorAbnormal, gmmY.posteriorAbnormal);
        [refinedX, maskX] = spof_refine_flow(flow.vx, confidence, gmmX.posteriorAbnormal, cfg);
        [refinedY, maskY] = spof_refine_flow(flow.vy, confidence, gmmY.posteriorAbnormal, cfg);
        abnormalMask = maskX | maskY;
        finalX = refinedX;
        finalY = refinedY;
end

% 真实视频可选择只对高置信度结构点积分；默认阈值为 0，保持论文式(23)
% 的“ROI 内非零有效点平均”行为。该增强项由真实入口显式配置。
if isfield(cfg, 'integrationConfidenceThreshold') && ...
        cfg.integrationConfidenceThreshold > 0
    cfg.integrationConfidence = confidence;
end
signal = spof_integrate_displacement(finalX, finalY, fs, roi, cfg);
result = struct('method', cfg.method, 'flow', flow, 'confidence', confidence, ...
    'posteriorAbnormal', posterior, 'abnormalMask', abnormalMask, ...
    'refinedFlow', struct('vx', refinedX, 'vy', refinedY), ...
    'finalFlow', struct('vx', finalX, 'vy', finalY), 'signal', signal, ...
    'gmmX', gmmX, 'gmmY', gmmY);
end

function out = temporal_median(x, width)
[~, ~, n] = size(x);
out = zeros(size(x), 'like', x);
half = floor(width/2);
for t = 1:n
    lo = max(1, t-half); hi = min(n, t+half);
    out(:, :, t) = median(x(:, :, lo:hi), 3, 'omitnan');
end
end

function out = temporal_nonlinearity(vx, vy)
[h, w, n] = size(vx);
out = zeros(h, w, n);
if n < 3, return; end
ax = zeros(size(vx)); ay = zeros(size(vy));
ax(:, :, 2:n-1) = abs(vx(:, :, 3:n) - 2*vx(:, :, 2:n-1) + vx(:, :, 1:n-2));
ay(:, :, 2:n-1) = abs(vy(:, :, 3:n) - 2*vy(:, :, 2:n-1) + vy(:, :, 1:n-2));
out = ax + ay;
end
