function g = complex_gabor_kernel(f, sigmaA, sigmaR, alpha)
%COMPLEX_GABOR_KERNEL 实现论文 Eq. (5) 的复数二维 Gabor 滤波器。
%   f 使用 cycles/pixel；alpha 为载波方向（弧度）。

radius = ceil(3 * max(sigmaA, sigmaR));
[X, Y] = meshgrid(-radius:radius, -radius:radius);
Xr = X * cos(alpha) + Y * sin(alpha);
Yr = -X * sin(alpha) + Y * cos(alpha);
envelope = exp(-(Xr .^ 2) / (2 * sigmaR ^ 2) - (Yr .^ 2) / (2 * sigmaA ^ 2));
carrier = exp(1i * 2 * pi * f * Xr);
g = envelope .* carrier;
% 去除微小 DC 分量并归一化，减少边界和亮度偏置对相位的影响。
g = g - mean(g(:));
g = g / sqrt(sum(abs(g(:)) .^ 2) + eps);
end
