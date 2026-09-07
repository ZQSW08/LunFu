function out = spof_weighted_gmm2(values, confidence, cfg)
% SPOF_WEIGHTED_GMM2 对一维光流场执行置信度加权二成分 GMM-EM。
% 论文对应式(16)-(20)。E 步中的置信度因子在分子/分母中会抵消，
% 但在 M 步中保留置信度作为样本权重，以降低不可靠像素的影响。

x = double(values(:));
w = double(confidence(:));
valid = isfinite(x) & isfinite(w) & w > 0;
xv = x(valid);
wv = w(valid);
if numel(xv) < 10 || std(xv) < sqrt(cfg.gmm.minVariance)
    out = struct('posteriorAbnormal', zeros(size(values)), 'model', [], ...
        'valid', valid, 'componentAbnormal', 2);
    return;
end

med = median(xv);
madValue = median(abs(xv - med)) + eps;
mu = [med - madValue, med + madValue];
sigma2 = [max((1.4826*madValue)^2, cfg.gmm.minVariance), ...
    max((2.5*1.4826*madValue)^2, cfg.gmm.minVariance)];
piK = [0.8, 0.2];
gamma = zeros(numel(xv), 2);

for iter = 1:cfg.gmm.maxIter
    old = [piK, mu, sigma2];
    logProb = zeros(numel(xv), 2);
    for k = 1:2
        logProb(:, k) = log(max(piK(k), cfg.gmm.minWeight)) ...
            - 0.5*log(2*pi*max(sigma2(k), cfg.gmm.minVariance)) ...
            - (xv - mu(k)).^2/(2*max(sigma2(k), cfg.gmm.minVariance));
    end
    logProb = logProb - max(logProb, [], 2);
    prob = exp(logProb);
    gamma = prob ./ max(sum(prob, 2), eps);
    for k = 1:2
        weightedPosterior = wv .* gamma(:, k);
        mass = sum(weightedPosterior);
        if mass <= eps
            continue;
        end
        piK(k) = mass / max(sum(wv), eps);
        mu(k) = sum(weightedPosterior .* xv) / mass;
        sigma2(k) = sum(weightedPosterior .* (xv - mu(k)).^2) / mass;
        sigma2(k) = max(sigma2(k), cfg.gmm.minVariance);
    end
    current = [piK, mu, sigma2];
    if max(abs(current - old)) < cfg.gmm.tol
        break;
    end
end

% 论文将高方差分量解释为异常分量；当方差接近时选取权重较小者。
[~, abnormalComponent] = max(sigma2 + 1e-9*(1-piK));
posterior = zeros(size(x));
posterior(valid) = gamma(:, abnormalComponent);
out = struct('posteriorAbnormal', reshape(posterior, size(values)), ...
    'model', struct('pi', piK, 'mu', mu, 'sigma2', sigma2, 'iterations', iter), ...
    'valid', reshape(valid, size(values)), 'componentAbnormal', abnormalComponent);
end
