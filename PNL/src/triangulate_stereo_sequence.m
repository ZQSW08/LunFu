function xyz = triangulate_stereo_sequence(cfg, uv)
%TRIANGULATE_STEREO_SEQUENCE 使用线性 DLT 三角测量恢复 3D 轨迹。
%   这是 MATLAB triangulate 的无工具箱等价实现，便于复现环境迁移。

N = size(uv, 2);
xyz = zeros(3, N);
for k = 1:N
    u1 = uv(1, k, 1); v1 = uv(2, k, 1);
    u2 = uv(1, k, 2); v2 = uv(2, k, 2);
    P1 = cfg.P{1}; P2 = cfg.P{2};
    A = [u1 * P1(3, :) - P1(1, :);
         v1 * P1(3, :) - P1(2, :);
         u2 * P2(3, :) - P2(1, :);
         v2 * P2(3, :) - P2(2, :)];
    [~, ~, V] = svd(A, 0);
    X = V(:, end);
    xyz(:, k) = X(1:3) / X(4);
end
end
