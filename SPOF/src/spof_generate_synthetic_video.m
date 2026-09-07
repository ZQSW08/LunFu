function data = spof_generate_synthetic_video(kind, opts)
% SPOF_GENERATE_SYNTHETIC_VIDEO 生成带真值的等价合成振动视频。
% 运动模型保持论文实验的类型：正弦激振、悬臂梁衰减、钢索弱/强激励和桥梁复合激励。

if nargin < 2, opts = struct(); end
if ~isfield(opts, 'fs'), opts.fs = 100; end
if ~isfield(opts, 'duration'), opts.duration = 4; end
if ~isfield(opts, 'height'), opts.height = 144; end
if ~isfield(opts, 'width'), opts.width = 144; end
if ~isfield(opts, 'noiseStd'), opts.noiseStd = 0.005; end

fs = opts.fs; n = round(opts.duration*fs); t = (0:n-1)/fs;
[x, y] = meshgrid(1:opts.width, 1:opts.height);
base = 0.28 + 0.12*sin(2*pi*x/13) + 0.10*cos(2*pi*y/17) ...
    + 0.08*sin(2*pi*(x+y)/29);
target = x > 25 & x < opts.width-22 & y > 28 & y < opts.height-25;
base = base + target .* (0.15*sin(2*pi*x/7) + 0.12*cos(2*pi*y/9));
base = min(max(base, 0), 1);

switch lower(kind)
    case {'modal', 'exciter'}
        dx = 0.55*sin(2*pi*10*t) + 0.05*sin(2*pi*1.1*t);
        dy = 0.02*sin(2*pi*10*t);
    case {'cantilever', 'beam'}
        dx = 0.70*exp(-0.32*t).*sin(2*pi*3.0*t + 0.3);
        dy = 0.03*sin(2*pi*0.5*t);
    case {'cable_weak', 'weak'}
        dx = 0.34*exp(-0.10*t).*sin(2*pi*2.2*t) + 0.04*sin(2*pi*6.5*t);
        dy = 0.02*sin(2*pi*1.1*t);
    case {'cable_strong', 'strong'}
        dx = 0.62*exp(-0.08*t).*sin(2*pi*2.2*t) + 0.07*sin(2*pi*6.5*t);
        dy = 0.03*sin(2*pi*1.1*t);
    case {'bridge_5m', 'bridge5'}
        dx = 0.18*sin(2*pi*1.4*t) + 0.10*sin(2*pi*2.7*t) ...
            + 0.05*sin(2*pi*5.5*t) + 0.02*randn(size(t));
        dy = 0.03*sin(2*pi*0.8*t);
    case {'bridge_10m', 'bridge10'}
        dx = 0.08*sin(2*pi*1.4*t) + 0.04*sin(2*pi*2.7*t) ...
            + 0.015*sin(2*pi*5.5*t) + 0.015*randn(size(t));
        dy = 0.02*sin(2*pi*0.8*t);
    otherwise
        error('未知合成场景：%s', kind);
end

video = zeros(opts.height, opts.width, n);
for k = 1:n
    % 使用反向采样生成 I(x,y,t)=I0(x-dx,y-dy)，保留亚像素真值。
    frame = interp2(x, y, base, x-dx(k), y-dy(k), 'linear', 0.2);
    frame = frame + opts.noiseStd*randn(size(frame));
    video(:, :, k) = min(max(frame, 0), 1);
end
roi = target;
data = struct('video', video, 'fs', fs, 'time', t(:), 'dx', dx(:), 'dy', dy(:), ...
    'roi', roi, 'scene', kind, 'baseImage', base);
end
