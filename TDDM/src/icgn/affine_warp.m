function [Xw, Yw] = affine_warp(X, Y, H)
%AFFINE_WARP 在局部子区坐标中应用齐次仿射变换。
P = [X(:)'; Y(:)'; ones(1, numel(X))];
Pw = H * P;
Xw = reshape(Pw(1,:), size(X));
Yw = reshape(Pw(2,:), size(Y));
end
