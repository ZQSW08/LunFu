function cfg = default_config()
%DEFAULT_CONFIG 返回 BPAF 论文复现的统一配置。
% 所有路径均从当前 BPAF 项目根目录推导，避免污染同级论文工程。

thisFile = mfilename('fullpath');
cfg.projectRoot = fileparts(fileparts(fileparts(thisFile)));
cfg.dataDir = fullfile(cfg.projectRoot, 'data', 'generated');
cfg.outputDir = fullfile(cfg.projectRoot, 'outputs');
cfg.figureDir = fullfile(cfg.outputDir, 'figures');
cfg.processDir = fullfile(cfg.outputDir, 'process');
cfg.videoDir = fullfile(cfg.outputDir, 'videos');
cfg.tableDir = fullfile(cfg.outputDir, 'tables');
cfg.resultDir = fullfile(cfg.outputDir, 'data');

% 论文使用最高空间频带；order=3 对应四个方向。matlabPyrTools 的 band=4
% 对本项目水平方向载波位移最敏感（已用已知平移真值核对相位方向）。
cfg.pyramidHeight = 1;
cfg.pyramidOrder = 3;
cfg.orientationBand = 4;
cfg.localStdWindow = 5;

% 复现实验采用固定随机种子，使遗传算法和合成噪声可重复。
cfg.randomSeed = 20250829;
cfg.gaPopulation = 48;
cfg.gaGenerations = 60;
cfg.gaRetries = 2;
cfg.stopbandAlpha = 0.7;

% 等价模拟分辨率低于论文原视频，以便在 CPU 环境完成全流程。
% 采样率、持续时间、运动频率和幅值比仍按论文设置。
cfg.frameSize = [90, 160];
cfg.videoQuality = 95;
cfg.forceRegenerate = false;
cfg.forceReextract = false;
cfg.figureVisible = 'off';
cfg.savePhaseCubes = true;
end
