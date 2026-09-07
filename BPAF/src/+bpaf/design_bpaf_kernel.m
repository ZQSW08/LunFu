function [kernel, info] = design_bpaf_kernel(fs, fl, fh, fhs, alpha, cfg, useGA)
%DESIGN_BPAF_KERNEL 按论文式(12)-(22)设计 DoG 带通加速度核。
% 频率先除以采样率转换为 cycles/sample；sigma 的单位为采样点。

arguments
    fs (1,1) double {mustBePositive}
    fl (1,1) double {mustBePositive}
    fh (1,1) double {mustBePositive}
    fhs (1,1) double {mustBePositive}
    alpha (1,1) double {mustBePositive}
    cfg struct
    useGA (1,1) logical = true
end
assert(fl < fh && fh <= fs/2, 'BPAF 频带必须满足 0 < FL < FH <= FPS/2。');

fln = fl/fs;
fhn = fh/fs;
fhsn = min(fhs, fs/2)/fs;
lb = [0.05, 1.01];
ub = [50, 15];

objective = @(x) objective_value(x, fln, fhn, fhsn, alpha);
nonlinear = @(x) constraints(x, fln, fhn, fhsn, alpha);

bestX = [];
bestValue = inf;
optimizerName = 'deterministic-grid';
if useGA && license('test', 'GADS_Toolbox')
    optimizerName = 'genetic-algorithm';
    for retry = 1:cfg.gaRetries
        rng(cfg.randomSeed + retry + round(10*fl) + round(100*fh), 'twister');
        opts = optimoptions('ga', 'Display', 'off', ...
            'PopulationSize', cfg.gaPopulation, ...
            'MaxGenerations', cfg.gaGenerations, ...
            'FunctionTolerance', 1e-9, 'ConstraintTolerance', 1e-7);
        [candidate, value] = ga(objective, 2, [], [], [], [], lb, ub, nonlinear, opts);
        [c, ~] = nonlinear(candidate);
        if all(c <= 1e-5) && value < bestValue
            bestX = candidate;
            bestValue = value;
        end
    end
end

if isempty(bestX)
    [bestX, bestValue] = deterministic_search(fln, fhn, fhsn, alpha);
end

sigma = bestX(1);
k = bestX(2);
halfWidth = min(250, max(6, ceil(4*k*sigma)));
t = -halfWidth:halfWidth;
g1 = exp(-(t.^2)/(2*sigma^2)) / (sqrt(2*pi)*sigma);
g2 = exp(-(t.^2)/(2*(k*sigma)^2)) / (sqrt(2*pi)*k*sigma);
kernel = g1 - g2;
kernel = kernel - mean(kernel);

% 归一化为单位峰值频率响应，不改变滤波器形状和通带。
nfft = max(8192, 2^nextpow2(numel(kernel)*16));
response = abs(fft(kernel, nfft));
kernel = kernel / max(response(1:floor(nfft/2)+1));

fm = peak_frequency(sigma, k) * fs;
info = struct('sigmaSamples', sigma, 'k', k, 'peakFrequencyHz', fm, ...
    'flHz', fl, 'fhHz', fh, 'fhsHz', min(fhs, fs/2), 'alpha', alpha, ...
    'objective', bestValue, 'optimizer', optimizerName, ...
    'timeIndex', t, 'kernelLength', numel(kernel));
end

function value = objective_value(x, fl, fh, fhs, alpha)
sigma = x(1);
k = x(2);
fm = peak_frequency(sigma, k);
rPeak = dog_response(fm, sigma, k);
rLow = dog_response(fl, sigma, k);
rHigh = dog_response(fh, sigma, k);
value = log((rPeak^2 + eps) / (rLow*rHigh + eps));
[c, ~] = constraints(x, fl, fh, fhs, alpha);
value = value + 1e4*sum(max(c, 0).^2);
end

function [c, ceq] = constraints(x, fl, fh, fhs, alpha)
sigma = x(1);
k = x(2);
fm = peak_frequency(sigma, k);
c = [fl-fm; fm-fh];
if fhs > fh + eps
    c(end+1, 1) = dog_response(fhs, sigma, k) ...
        - alpha*dog_response(fh, sigma, k);
end
ceq = [];
end

function [bestX, bestValue] = deterministic_search(fl, fh, fhs, alpha)
% 扫描峰值位置与尺度比；该分支用于大量先验频带扫描，目标函数与约束不变。
kValues = linspace(1.05, 12, 180);
fmValues = linspace(fl*1.002, fh*0.998, 140);
[fmGrid, kGrid] = ndgrid(fmValues, kValues);
sigmaGrid = sqrt(log(kGrid)./(kGrid.^2-1)) ./ (pi*fmGrid);
rPeak = dog_response(fmGrid, sigmaGrid, kGrid);
rLow = dog_response(fl, sigmaGrid, kGrid);
rHigh = dog_response(fh, sigmaGrid, kGrid);
valueGrid = log((rPeak.^2+eps)./(rLow.*rHigh+eps));
feasible = true(size(valueGrid));
if fhs > fh + eps
    rStop = dog_response(fhs, sigmaGrid, kGrid);
    feasible = rStop <= alpha*rHigh;
end
valueGrid(~feasible) = inf;
[bestValue, linearIdx] = min(valueGrid, [], 'all', 'linear');
bestX = [sigmaGrid(linearIdx), kGrid(linearIdx)];
if ~isfinite(bestValue)
    % 极端临近 Nyquist 的频带无法满足额外阻带约束时，保留峰值在通带内。
    k = 2;
    fm = (fl+fh)/2;
    bestX = [sqrt(log(k)/(k^2-1))/(pi*fm), k];
    bestValue = objective_value(bestX, fl, fh, fh, alpha);
end
end

function value = peak_frequency(sigma, k)
value = sqrt(log(k)./(k.^2-1)) ./ (pi*sigma);
end

function value = dog_response(frequency, sigma, k)
value = exp(-2*pi^2*sigma.^2.*frequency.^2) ...
    - exp(-2*pi^2*k.^2.*sigma.^2.*frequency.^2);
value = max(value, realmin);
end
