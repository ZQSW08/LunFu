function features = apcv_decompose_frame(image, cfg)
%APCV_DECOMPOSE_FRAME 提取论文使用的高通残差与方向相位子带。

[pyr, pind] = buildSCFpyr(double(image), cfg.pyramidHeight, ...
    cfg.pyramidOrder);
highResidual = pyrBand(pyr, pind, 1);
% 粗配准的一维剖面沿“垂直于运动方向”的图像维度求平均：
%   vertical  -> 对列求平均，保留行坐标（Y 位移）；
%   horizontal -> 对行求平均，保留列坐标（X 位移）。
if isfield(cfg, 'direction') && strcmpi(apcv_normalize_direction(cfg.direction), 'horizontal')
    features.highProfile = mean(abs(highResidual), 1).';
else
    features.highProfile = mean(abs(highResidual), 2);
end
features.bands = cell(numel(cfg.pyramidLevels), 1);
numOrientations = cfg.pyramidOrder + 1;

for i = 1:numel(cfg.pyramidLevels)
    level = cfg.pyramidLevels(i);
    bandIndex = 1 + (level - 1) * numOrientations + cfg.orientationBand;
    features.bands{i} = pyrBand(pyr, pind, bandIndex);
end
end
