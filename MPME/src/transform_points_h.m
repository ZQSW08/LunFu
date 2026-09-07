function transformed = transform_points_h(H, points)
%TRANSFORM_POINTS_H Transform Nx2 zero-based points by homogeneous matrix H.

homogeneous = H * [points.'; ones(1, size(points, 1))];
transformed = (homogeneous(1:2, :) ./ homogeneous(3, :)).';
end
