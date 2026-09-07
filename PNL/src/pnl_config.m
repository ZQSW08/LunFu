function cfg = pnl_config(mode)
%PNL_CONFIG 论文 PNL 复现的集中配置。
%   该配置把论文明确给出的仿真参数与实现推断参数分开保存。
%   mode='demo' 使用裁剪视场，便于在普通 MATLAB 环境快速复现；
%   mode='paper' 将图像尺寸改为论文报告的 1600 x 1100 像素。

if nargin == 0
    mode = 'demo';
end

cfg.root = fileparts(fileparts(mfilename('fullpath')));
cfg.fps = 200;
cfg.dt = 1 / cfg.fps;
cfg.seed = 20260829;
cfg.mode = char(mode);

% 论文仿真中报告的相机与目标几何（单位：mm、像素）。
cfg.imageSize = [1100, 1600];       % [行, 列]
cfg.K{1} = [3000, 0, 800; 0, 3000, 550; 0, 0, 1];
cfg.K{2} = cfg.K{1};
cfg.baseline = 278;
cfg.cameraCenter{1} = [0; 0; 0];
cfg.cameraCenter{2} = [cfg.baseline; 0; 0];
cfg.R{1} = eye(3);
% 论文只给出相对 yaw/pitch/roll；以下采用 Z-Y-X 组合，是实现推断。
cfg.R{2} = rotz_deg(1.2) * roty_deg(-0.4) * rotx_deg(-21.6);
cfg.P{1} = cfg.K{1} * [cfg.R{1}, -cfg.R{1} * cfg.cameraCenter{1}];
cfg.P{2} = cfg.K{2} * [cfg.R{2}, -cfg.R{2} * cfg.cameraCenter{2}];

cfg.marker.size = 16;
cfg.marker.lineLength = 14;
cfg.marker.lineWidth = 1;
cfg.marker.center = [171.5; -100.8; 1693.7];
cfg.marker.textureSamples = 192;

% 论文 Fig. 5 的运动轨迹：X 为高频面内运动，Z 在 1 s 后开启。
cfg.motion.type = 'coupled';
cfg.motion.duration = 2.0;
cfg.motion.xAmplitude = -0.36;
cfg.motion.xFrequency = 18;
cfg.motion.zAmplitude = 0.75;
cfg.motion.zFrequency = 2;
cfg.motion.zStart = 1.0;

% 论文 Fig. 6/8 的仿真 baseline：T=2.8，sigmaA=sigmaR=T。
% Fig. 3 另展示了 f=1/8、sigmaA=sigmaR=3 的滤波器，单独保留如下。
cfg.filter.generic.T = 2.8;
cfg.filter.generic.f = 1 / cfg.filter.generic.T;
cfg.filter.generic.sigmaA = cfg.filter.generic.T;
cfg.filter.generic.sigmaR = cfg.filter.generic.T;
cfg.filter.figure3.f = 1 / 8;
cfg.filter.figure3.sigmaA = 3;
cfg.filter.figure3.sigmaR = 3;
cfg.filter.geometry.T = 5.4;
cfg.filter.geometry.f = 1 / cfg.filter.geometry.T;
cfg.filter.geometry.sigmaA = 2 * cfg.filter.geometry.T;
cfg.filter.geometry.sigmaR = 2 * cfg.filter.geometry.T;
cfg.filter.orientations = [0, pi / 2];

% 默认只处理包围标记的裁剪区域；这不改变像素坐标，只减少演示运行量。
if strcmpi(cfg.mode, 'paper')
    cfg.roiSize = [256, 256];
    cfg.nFrames = round(cfg.motion.duration * cfg.fps);
else
    cfg.roiSize = [128, 128];
    cfg.nFrames = round(cfg.motion.duration * cfg.fps);
end
cfg.roiMargin = 8;
cfg.render.blurSigma = 0.7;
cfg.render.supersample = 2;
cfg.noiseLevels = [0, 4, 8, 12, 16, 20];
cfg.amplitudeLevels = [0.002, 0.0058, 0.02, 0.062, 0.2];
cfg.amplitudeDuration = 1.0;
cfg.keepFlowFields = false;          % 正式结果不保存每个像素每帧的巨大数组
cfg.writeVideos = true;
cfg.amplitudeVideoDuration = 18;

% 根据初始投影自动选择每个相机的裁剪中心，避免把相机姿态写死到 ROI 中。
uv0 = zeros(2, 2);
for cam = 1:2
    uv0(:, cam) = project_points(cfg.P{cam}, cfg.marker.center);
end
cfg.roiCenter = uv0;

cfg.output.figures = fullfile(cfg.root, 'outputs', 'figures');
cfg.output.process = fullfile(cfg.root, 'outputs', 'process');
cfg.output.videos = fullfile(cfg.root, 'outputs', 'videos');
cfg.output.results = fullfile(cfg.root, 'outputs', 'pnl_reproduction_results.mat');
end

function R = rotx_deg(a)
c = cosd(a); s = sind(a);
R = [1 0 0; 0 c -s; 0 s c];
end

function R = roty_deg(a)
c = cosd(a); s = sind(a);
R = [c 0 s; 0 1 0; -s 0 c];
end

function R = rotz_deg(a)
c = cosd(a); s = sind(a);
R = [c -s 0; s c 0; 0 0 1];
end

function uv = project_points(P, X)
% 使用齐次投影返回 [u;v]，X 可以是 3x1 或 3xN。
q = P * [X; ones(1, size(X, 2))];
uv = q(1:2, :) ./ q(3, :);
end
