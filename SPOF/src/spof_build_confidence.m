function confidence = spof_build_confidence(flow, amplitudes, cfg)
% SPOF_BUILD_CONFIDENCE 构造边缘集中与局部平滑联合置信度。
% 论文对应式(12)-(15)：E=A^T，S=exp(-sigma_local)，C=alpha*E+(1-alpha)*S。

vx = double(flow.vx);
vy = double(flow.vy);
amp = mean(cat(3, amplitudes{1}, amplitudes{2}), 3);
amp = normalize01(amp);
edge = amp .^ cfg.edgeExponent;

smoothX = local_std_3d(vx, cfg.smoothWindow);
smoothY = local_std_3d(vy, cfg.smoothWindow);
smoothness = normalize01(exp(-(smoothX + smoothY) / 2));
confidence = cfg.alpha*edge + (1-cfg.alpha)*smoothness;
confidence = min(max(confidence, 0), 1);
confidence = single(confidence);
end

function sigma = local_std_3d(x, windowSize)
[h, w, n] = size(x);
kernel = ones(windowSize, windowSize) / (windowSize^2);
sigma = zeros(h, w, n);
for t = 1:n
    frame = x(:, :, t);
    finiteMask = isfinite(frame);
    frame(~finiteMask) = 0;
    count = conv2(double(finiteMask), kernel, 'same');
    meanValue = conv2(frame, kernel, 'same') ./ max(count, eps);
    meanSquare = conv2(frame.^2, kernel, 'same') ./ max(count, eps);
    sigma(:, :, t) = sqrt(max(meanSquare - meanValue.^2, 0));
end
end

function y = normalize01(x)
finite = isfinite(x);
if ~any(finite(:))
    y = zeros(size(x));
    return;
end
lo = min(x(finite));
hi = max(x(finite));
if hi <= lo + eps
    y = ones(size(x));
else
    y = (x - lo) / (hi - lo);
end
y(~finite) = 0;
y = min(max(y, 0), 1);
end
