function bank = spof_make_gabor_bank(cfg)
% SPOF_MAKE_GABOR_BANK 构造论文式二维复 Gabor 正交滤波器。
% x 向右、y 向下；theta=0 对 x 方向相位梯度敏感，theta=pi/2 对 y 方向敏感。

r = cfg.gabor.kernelRadius;
[x, y] = meshgrid(-r:r, -r:r);
bank = cell(numel(cfg.gabor.orientations), 1);
for k = 1:numel(cfg.gabor.orientations)
    theta = cfg.gabor.orientations(k);
    xp = x*cos(theta) + y*sin(theta);
    yp = -x*sin(theta) + y*cos(theta);
    envelope = exp(-(xp.^2 + cfg.gabor.gamma^2*yp.^2) / (2*cfg.gabor.sigma^2));
    carrier = exp(1i*(2*pi*xp/cfg.gabor.lambda + cfg.gabor.psi));
    g = envelope .* carrier;
    g = g - mean(g(:));
    scale = sum(abs(g(:)));
    if scale > 0
        g = g / scale;
    end
    bank{k} = g;
end
end
