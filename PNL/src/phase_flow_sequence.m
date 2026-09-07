function est = phase_flow_sequence(images, cfg, filterCfg, useConfidence)
%PHASE_FLOW_SEQUENCE 用多个复数 Gabor 响应求解二维 POF。
%   对每个滤波器建立 grad(phi)·v + phi_t = 0 的最小二乘方程，
%   与论文 Eq. (8)-(10) 对应。PNL 使用论文 Eq. (11) 计算。

if nargin < 4
    useConfidence = false;
end
[H, W, N] = size(images);
Q = numel(cfg.filter.orientations);
if N < 2
    error('图像序列至少需要两帧。');
end

gx = zeros(H, W, N - 1, Q, 'single');
gy = zeros(H, W, N - 1, Q, 'single');
dphi = zeros(H, W, N - 1, Q, 'single');
amp = zeros(H, W, N - 1, Q, 'single');

for q = 1:Q
    g = complex_gabor_kernel(filterCfg.f, filterCfg.sigmaA, filterCfg.sigmaR, cfg.filter.orientations(q));
    response = apply_circular_filter(images, g);
    % 采用相邻复响应的相角差计算空间梯度，避免逐帧二维 unwrap。
    gradX = zeros(H, W, N - 1, 'single');
    gradY = zeros(H, W, N - 1, 'single');
    gradX(:, 2:end-1, :) = single(angle(conj(response(:, 1:end-2, 1:end-1)) .* ...
        response(:, 3:end, 1:end-1)) / 2);
    gradY(2:end-1, :, :) = single(angle(conj(response(1:end-2, :, 1:end-1)) .* ...
        response(3:end, :, 1:end-1)) / 2);
    gradX(:, 1, :) = gradX(:, 2, :);
    gradX(:, end, :) = gradX(:, end-1, :);
    gradY(1, :, :) = gradY(2, :, :);
    gradY(end, :, :) = gradY(end-1, :, :);
    temporal = angle(conj(response(:, :, 1:end-1)) .* response(:, :, 2:end));
    gx(:, :, :, q) = gradX;
    gy(:, :, :, q) = gradY;
    dphi(:, :, :, q) = single(temporal);
    amp(:, :, :, q) = single(abs(response(:, :, 1:end-1)));
end

weight = ones(size(amp), 'like', amp);
if useConfidence
    % POF-CM 风格置信度：响应幅值与梯度强度共同决定方程权重。
    for q = 1:Q
        a = amp(:, :, :, q);
        gmag = hypot(gx(:, :, :, q), gy(:, :, :, q));
        scaleA = median(a(:)) + eps;
        scaleG = median(gmag(:)) + eps;
        weight(:, :, :, q) = min((a / scaleA) .* (gmag / scaleG), 10);
    end
end

A11 = sum(weight .* gx .* gx, 4);
A12 = sum(weight .* gx .* gy, 4);
A22 = sum(weight .* gy .* gy, 4);
b1 = sum(weight .* gx .* dphi, 4);
b2 = sum(weight .* gy .* dphi, 4);
detA = A11 .* A22 - A12 .* A12;
valid = isfinite(detA) & detA > 1e-8;
u = zeros(H, W, N - 1, 'single');
v = zeros(H, W, N - 1, 'single');
u(valid) = (-b1(valid) .* A22(valid) + b2(valid) .* A12(valid)) ./ detA(valid);
v(valid) = (A12(valid) .* b1(valid) - A11(valid) .* b2(valid)) ./ detA(valid);

% 论文 Eq. (11)：每个像素的逐帧归一化相位梯度波动。
pnlByFilter = zeros(H, W, Q, 'single');
for q = 1:Q
    gradMag = hypot(gx(:, :, :, q), gy(:, :, :, q));
    ratio = dphi(:, :, :, q) ./ max(gradMag, 1e-5);
    meanGrad = mean(gradMag, 3);
    residual = ratio - dphi(:, :, :, q) ./ max(meanGrad, 1e-5);
    pnlByFilter(:, :, q) = mean(abs(residual), 3, 'omitnan');
end
pnlMap = mean(pnlByFilter, 3, 'omitnan');

% 保留论文 Fig. 6-7 所需的时间统计，而不保存整个像素级梯度张量。
meanGradientTime = zeros(2, N - 1, Q);
frameMask = amp > median(amp(:));
for q = 1:Q
    for k = 1:N - 1
        mk = frameMask(:, :, k, q) & isfinite(gx(:, :, k, q));
        gxk = gx(:, :, k, q);
        gyk = gy(:, :, k, q);
        meanGradientTime(1, k, q) = mean(gxk(mk), 'omitnan');
        meanGradientTime(2, k, q) = mean(gyk(mk), 'omitnan');
    end
end

% 用固定范围保存前后阶段的分布计数，便于复刻论文 Fig. 7(c)-(d)。
split = min(max(round(cfg.motion.zStart * cfg.fps), 1), N - 1);
gradientBaseline = zeros(2, Q);
for q = 1:Q
    gradientBaseline(:, q) = mean(meanGradientTime(:, 1:split, q), 2, 'omitnan');
    meanGradientTime(:, :, q) = meanGradientTime(:, :, q) - gradientBaseline(:, q);
end
histEdges = linspace(-pi / 2, pi / 2, 401);
histPre = zeros(2, numel(histEdges) - 1, Q);
histPost = zeros(2, numel(histEdges) - 1, Q);
for q = 1:Q
    gxq = gx(:, :, :, q) - gradientBaseline(1, q);
    gyq = gy(:, :, :, q) - gradientBaseline(2, q);
    maskq = frameMask(:, :, :, q);
    preMask = maskq(:, :, 1:split);
    postMask = maskq(:, :, split+1:end);
    preX = gxq(:, :, 1:split); preY = gyq(:, :, 1:split);
    postX = gxq(:, :, split+1:end); postY = gyq(:, :, split+1:end);
    histPre(1, :, q) = histcounts(preX(preMask), histEdges);
    histPre(2, :, q) = histcounts(preY(preMask), histEdges);
    histPost(1, :, q) = histcounts(postX(postMask), histEdges);
    histPost(2, :, q) = histcounts(postY(postMask), histEdges);
end

validMask = valid & mean(amp, [3, 4]) > median(amp(:));
margin = min(cfg.roiMargin, floor(min(H, W) / 4));
validMask(1:margin, :) = false;
validMask(end-margin+1:end, :) = false;
validMask(:, 1:margin) = false;
validMask(:, end-margin+1:end) = false;

% 在标记纹理高置信区域汇总一个相机的图像平面运动。
du = zeros(1, N - 1);
dv = zeros(1, N - 1);
for k = 1:N - 1
    uk = u(:, :, k); vk = v(:, :, k);
    mk = validMask(:, :, k);
    du(k) = median(uk(mk), 'omitnan');
    dv(k) = median(vk(mk), 'omitnan');
end

if isfield(cfg, 'keepFlowFields') && cfg.keepFlowFields
    est.flowU = u;
    est.flowV = v;
end
est.deltaUV = [du; dv];
est.cumulativeUV = [zeros(2, 1), cumsum(est.deltaUV, 2)];
est.pnlMap = pnlMap;
est.pnlScalar = median(pnlMap(validMask(:, :, 1)), 'omitnan');
est.meanGradientTime = meanGradientTime;
est.gradientBaseline = gradientBaseline;
est.gradientDistribution.edges = histEdges;
est.gradientDistribution.pre = histPre;
est.gradientDistribution.post = histPost;
est.validMask = validMask(:, :, 1);
est.meanAmplitude = mean(amp, [3, 4]);
est.meanGradient = mean(hypot(gx, gy), [3, 4]);
end

function response = apply_circular_filter(images, kernel)
% 在二维空间频域逐帧卷积；圆周边界只影响裁剪边缘。
[H, W, ~] = size(images);
K = zeros(H, W, 'like', kernel);
kh = size(kernel, 1);
kw = size(kernel, 2);
K(1:kh, 1:kw) = kernel;
K = circshift(K, -floor([kh, kw] / 2));
G = fft2(K);
F = fft2(images);
response = ifft2(F .* reshape(G, H, W, 1));
end
