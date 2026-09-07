function cfg = apcv_default_config(projectRoot)
%APCV_DEFAULT_CONFIG 论文复现的统一配置。
% 所有长度单位为 mm，像素位移正方向为图像向下，时间单位为 s。

if nargin < 1 || isempty(projectRoot)
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
end

cfg.projectRoot = projectRoot;
cfg.randomSeed = 20260828;
cfg.frameRate = 29.97;
cfg.imageSize = [128, 160];
cfg.direction = 'vertical';     % 位移方向：vertical（Y）或 horizontal（X）
cfg.canvasMargin = 48;
cfg.pyramidLevels = 1:4;
cfg.pyramidHeight = 4;
cfg.pyramidOrder = 3;          % 4 个方向子带
cfg.orientationBand = 3;      % 对竖向位移最敏感的方向子带（1-based）
cfg.maxCoarseLag = 34;
cfg.calibrationMaxFrames = 90;
cfg.figureDpi = 220;
cfg.saveVideos = true;
cfg.videoMaxFrames = 180;
cfg.verbose = true;

% 合成实验使用比论文原视频更小的 ROI，以便完整复现在普通电脑上运行。
cfg.lab.gammaMmPerPixel = 2.0;
cfg.lab.duration = 6.0;
cfg.lab.noiseSigma = 0.010;
cfg.lab.illuminationDrift = 0.025;
cfg.lab.textureSeed = cfg.randomSeed + 11;

cfg.bridge.gammaMmPerPixel = 0.50;
cfg.bridge.duration = 6.0;
cfg.bridge.noiseSigma = 0.014;
cfg.bridge.illuminationDrift = 0.035;
cfg.bridge.textureSeed = cfg.randomSeed + 29;

cfg.paths.src = fullfile(projectRoot, 'src');
cfg.paths.scripts = fullfile(projectRoot, 'scripts');
cfg.paths.configs = fullfile(projectRoot, 'configs');
cfg.paths.pyrTools = fullfile(projectRoot, 'third_party', 'matlabPyrTools');
cfg.paths.figures = fullfile(projectRoot, 'outputs', 'figures');
cfg.paths.process = fullfile(projectRoot, 'outputs', 'process');
cfg.paths.videos = fullfile(projectRoot, 'outputs', 'videos');
cfg.paths.data = fullfile(projectRoot, 'outputs', 'data');
end
