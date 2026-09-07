function [refined, abnormalMask] = spof_refine_flow(raw, confidence, posteriorAbnormal, cfg)
% SPOF_REFINE_FLOW 检测并修复异常光流点。
% 论文对应式(21)-(22)：Mab=[gamma2>tau] AND [C<tauC]，
% 异常点使用局部均值与原值按置信度加权融合。

raw = double(raw);
confidence = double(confidence);
posteriorAbnormal = double(posteriorAbnormal);
[~, ~, n] = size(raw);
refined = raw;
abnormalMask = posteriorAbnormal > cfg.tau & confidence < cfg.tauC;
kernel = ones(cfg.localWindow, cfg.localWindow);

for t = 1:n
    frame = raw(:, :, t);
    valid = isfinite(frame);
    frame(~valid) = 0;
    count = conv2(double(valid), kernel, 'same');
    localMean = conv2(frame, kernel, 'same') ./ max(count, 1);
    c = confidence(:, :, t);
    replacement = c .* frame + (1-c) .* localMean;
    output = frame;
    output(~valid) = localMean(~valid);
    mask = abnormalMask(:, :, t) | ~valid;
    output(mask) = replacement(mask);
    refined(:, :, t) = output;
end
refined = single(refined);
end
