function [I, center] = make_synthetic_image(cfg)
%MAKE_SYNTHETIC_IMAGE 生成带圆形标记和自然纹理的可控参考图像。
rng(cfg.impl.randomSeed, 'twister');
sz = cfg.impl.syntheticImageSize;
[X, Y] = meshgrid(1:sz(2), 1:sz(1));
texture = rand(sz);
texture = imgaussfilt(texture, 3);
texture = (texture - min(texture(:))) / max(eps, range(texture(:)));
I = 0.20 + 0.28 * texture;
% 标记略偏离画面中心，便于离面/旋转代理产生真实的平面位移。
center = [round(sz(2)/2), round(sz(1)*0.40)];
radius = cfg.impl.syntheticMarkerDiameter / 2;
disk = (X-center(1)).^2 + (Y-center(2)).^2 <= radius^2;
I(disk) = 0.92;
% 加入小的可重复内部纹理，便于 KLT 找到角点但不改变圆心真值。
inner = disk & ((X-center(1)).^2 + (Y-center(2)).^2 <= (0.55*radius)^2);
I(inner) = 0.78 + 0.08 * texture(inner);
I = min(max(I, 0), 1);
end
