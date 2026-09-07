function [out, mu, sigma] = normalize_patch(patch)
%NORMALIZE_PATCH 零均值、单位 L2 范数归一化，对应论文 ZNSSD/NCC 定义。
x = double(patch);
mu = mean(x(:));
centered = x - mu;
sigma = sqrt(sum(centered(:).^2));
if sigma < 1e-12
    out = zeros(size(x));
else
    out = centered ./ sigma;
end
end
