function [filter, meta] = build_loggabor_filter(height, width, params, cfg, theta0)
%BUILD_LOGGABOR_FILTER 构造论文 Eq. (1)-(4) 的二维 Log-Gabor 频域滤波器。
% params=[HAB,RSD,ASD]。论文同时把 HAB、RSD 作为优化变量，但没有公开
% 二者到 f0 的完整工程映射；这里显式采用可复现的实现推断：HAB 改变中心
% 频率的 octave 位置，RSD 控制 log-radial 宽度，ASD 控制角向宽度。
if nargin < 5 || isempty(theta0), theta0 = cfg.loggabor.theta0; end
% EDA 采样属于随机过程；在进入幂运算前统一做有限值和边界保护，
% 避免异常候选污染后续的代表性中间输出。
if ~isnumeric(params) || numel(params) ~= 3 || any(~isfinite(params(:)))
    params = cfg.loggabor.defaultParams;
end
params = double(reshape(params,1,3));
lower = [cfg.loggabor.habRange(1), cfg.loggabor.rsdRange(1), cfg.loggabor.asdRange(1)];
upper = [cfg.loggabor.habRange(2), cfg.loggabor.rsdRange(2), cfg.loggabor.asdRange(2)];
params = min(max(params,lower),upper);
hab = params(1); rsd = max(abs(params(2)), 1e-3); asd = max(abs(params(3)), 1e-3);
f0 = cfg.loggabor.centerFrequency * 2.^((hab-20)/20);
f0 = min(max(f0, cfg.loggabor.minFrequency), cfg.loggabor.maxFrequency);
[fx, fy] = centered_frequency_grid(height, width);
radius = hypot(fx, fy);
angle = atan2(fy, fx);
% Eq. (2)：f=0 时严格置零；RSD 使用论文 Table 1 的无量纲量级。
radial = zeros(size(radius));
nonzero = radius > 0;
logRatio = log(radius(nonzero) / f0);
logRsd = max(abs(log(rsd)), 0.05);
radial(nonzero) = exp(-(logRatio.^2) ./ (2*logRsd.^2));
% 圆周角距离，保证 -pi/pi 处连续。
angularDistance = angle_difference(angle, theta0);
angular = exp(-(angularDistance.^2) ./ (2*asd.^2));
filter = radial .* angular;
meta.f0 = f0;
meta.theta0 = theta0;
meta.omega = 2*pi*f0;
meta.params = params;
meta.frequencyGrid = radius;
end

function d = angle_difference(a, b)
d = atan2(sin(a-b), cos(a-b));
end

function [fx, fy] = centered_frequency_grid(height, width)
fxv = (-floor(width/2):ceil(width/2)-1) / width;
fyv = (-floor(height/2):ceil(height/2)-1) / height;
[fx, fy] = meshgrid(fxv, fyv);
end
