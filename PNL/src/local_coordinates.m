function localXYZ = local_coordinates(X, cfg)
%LOCAL_COORDINATES 按论文 Eq. (4) 将全局坐标变换到结构局部坐标。
%   仿真默认使用单位旋转和论文仿真标记中心；真实视频入口可以在
%   cfg.RLG 中提供全局到局部的旋转矩阵，并在 cfg.marker.center 中
%   提供局部坐标原点。这样不会把仿真坐标约定硬编码到真实数据流程。

if isfield(cfg, 'RLG') && isequal(size(cfg.RLG), [3, 3])
    RLG = cfg.RLG;
else
    RLG = eye(3);
end
if isfield(cfg, 'marker') && isfield(cfg.marker, 'center')
    origin = cfg.marker.center;
else
    origin = zeros(3, 1);
end
localXYZ = RLG * (X - origin);
end
