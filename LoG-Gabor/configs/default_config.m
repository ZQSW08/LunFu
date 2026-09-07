function cfg = default_config()
%DEFAULT_CONFIG 论文 Log-Gabor + MaTO 复现的统一配置。
% 论文明确给出的采样率、窗口和迭代条件优先保留；正文没有给出的
% 优化边界、中心频率和 EDA 参数在这里集中标记为实现推断，避免散落在代码中。

root = fileparts(fileparts(mfilename('fullpath')));
cfg.root = root;
cfg.randomSeed = 20260829;

% 论文 Eq. (1)-(5) 的滤波器约定。
cfg.loggabor.theta0 = 0;                 % 水平运动；垂直运动时由实验覆盖
cfg.loggabor.centerFrequency = 0.18;    % cycles/pixel，论文未固定公开，属于实现推断
cfg.loggabor.minFrequency = 0.015;
cfg.loggabor.maxFrequency = 0.48;
cfg.loggabor.habRange = [1, 50];         % 论文优化变量，边界未完整公开
cfg.loggabor.rsdRange = [0.15, 2.0];     % Table 1 中出现的量级
cfg.loggabor.asdRange = [0.15, 2.0];
cfg.loggabor.defaultParams = [20, 0.5, 0.5];

% 合成视频：保持小规模以便在普通 MATLAB 桌面环境复现完整链路。
cfg.synthetic.height = 64;
cfg.synthetic.width = 64;
cfg.synthetic.frames = 120;
cfg.synthetic.fs = 250;                 % 电缆实验视频帧率
cfg.synthetic.frequency = 5;
cfg.synthetic.amplitude = 0.10;          % pixel
cfg.synthetic.motionAngle = pi/2;        % 垂直振动
cfg.synthetic.noiseStd = 0.002;
cfg.synthetic.scaleMmPerPixel = 0.504;   % 论文电缆实验

% MaTO：论文给出“20 particles / 20 iterations”的代表性设置；其余为推断。
cfg.mato.populationSize = 15;
cfg.mato.generations = 20;
cfg.mato.similarCount = 3;
cfg.mato.kernelWidth = 0.35;
cfg.mato.clusterCount = 3;
cfg.mato.mutationProbability = 0.12;
cfg.mato.mutationScale = 0.08;
cfg.mato.crossoverProbability = 0.90;
cfg.mato.eliteFraction = 0.35;

% active-pixel：论文只明确了局部振幅、闭环填充和自适应阈值思想。
cfg.active.initialPercentile = 72;
cfg.active.keepFilledRegions = true;     % 电缆等简单结构；SSRM 模式设为 false
cfg.active.minArea = 6;

cfg.ods.bandwidth = 2;                   % 论文对 SSRM 使用 f +/- 2 Hz
cfg.outputs.figures = fullfile(root, 'outputs', 'figures');
cfg.outputs.process = fullfile(root, 'outputs', 'process');
cfg.outputs.videos = fullfile(root, 'outputs', 'videos');
cfg.outputs.tables = fullfile(root, 'outputs', 'tables');
end
