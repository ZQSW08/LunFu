function cfg = px_default_config()
% 返回论文复现的默认参数。
% 所有未在论文中完全公开的数值都在此处集中管理，便于真实数据上复核。

cfg.pyramid.height = 2;
cfg.pyramid.order = 3;
cfg.pyramid.twidth = 1;
cfg.pyramid.scale = 0;
cfg.pyramid.sigmaReference = 2.0;
cfg.pyramid.referenceSize = [1080, 1440];

% 方向分析配置：x为水平方向，y为垂直方向，auto按方向平均幅值自动选择。
% 下面的子带编号映射是针对当前order=3实现的工程约定；论文没有给出
% MATLAB子带编号与图像坐标方向的直接映射，因此在结果中会保存该选择。
cfg.direction.analysis = 'y';
cfg.direction.orientationMap.x = [1, 3];
cfg.direction.orientationMap.y = [2, 4];

cfg.foreground.thresholdStd = 1.0;
% CSP频域边界会产生数值边缘响应；仅在前景候选阶段屏蔽边缘，不改动相位数据。
cfg.foreground.borderMargin = 5;
cfg.spatial.neighborhood = 7;
cfg.spatial.confidenceThreshold = 0.9;
cfg.spatial.fallbackFraction = 0.10;

% 论文只给出稳健Z分数和自适应阈值的形式，未给出唯一窗口长度与百分位。
cfg.temporal.windowFrames = 20;
cfg.temporal.percentile = 90.0;

cfg.sparse.fmin = 0.1;
cfg.sparse.fmax = 50.0;
cfg.sparse.df = 0.01;
cfg.sparse.lambda = 0.01;
cfg.sparse.maxIter = 350;
cfg.sparse.tolerance = 1e-6;

cfg.synthetic.frames = 300;
cfg.synthetic.fs = 100.0;
cfg.synthetic.height = 128;
cfg.synthetic.width = 192;
cfg.synthetic.frequency = 10.0;
cfg.synthetic.amplitudePixels = 0.8;
cfg.synthetic.seed = 7;

cfg.io.maxFrames = Inf;
cfg.io.roi = [];
cfg.io.fpsOverride = [];
cfg.io.saveVideo = true;
cfg.io.writeRoiAvi = true;
cfg.io.outputName = 'pixel_selection';
cfg.io.saveIntermediate = true;
cfg.io.visibleFigures = false;
end
