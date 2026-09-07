function [q, info] = adic2d_affine_icgn(reference, current, refCenter, q0, cfg)
%ADIC2D_AFFINE_ICGN 用 ADIC2D 的 SubCorr/SFExpressions 复用一阶 IC-GN。
% ADIC2D 的 GPL-3.0 源码保存在 third_party/ADIC2D，并保留其 LICENSE。
% 其 12 参数顺序映射为 [u ux uy 0 0 0 v vx vy 0 0 0]。
if exist('SFExpressions', 'file') ~= 2 || exist('SubCorr', 'file') ~= 2
    error('ADIC2D third-party path is not on MATLAB path.');
end
if mod(cfg.paper.templateSize, 2) == 0
    error('templateSize must be odd.');
end
cx = round(refCenter(1));
cy = round(refCenter(2));
r = floor(cfg.paper.templateSize / 2);
if cx-r < 1 || cy-r < 1 || cx+r > size(reference,2) || cy+r > size(reference,1)
    error('Reference subset is outside image bounds.');
end
reference = double(reference);
current = double(current);
[dfdx, dfdy] = imgradientxy(reference, 'prewitt');
f = reference(cy-r:cy+r, cx-r:cx+r);
dfdx = dfdx(cy-r:cy+r, cx-r:cx+r);
dfdy = dfdy(cy-r:cy+r, cx-r:cx+r);
[dX, dY] = meshgrid(-r:r, -r:r);
dX = dX(:); dY = dY(:);
f = f(:); dfdx = dfdx(:); dfdy = dfdy(:);

% GriddedInterpolant 使用 (row,column)，而 TDDM 坐标使用 (x,y)。
interpCoef = griddedInterpolant({1:size(current,1), 1:size(current,2)}, ...
    current, 'spline', 'none');
P0 = [q0(1); q0(3); q0(4); 0; 0; 0; q0(2); q0(5); q0(6); 0; 0; 0];
[P, C, iter, stopVal] = SubCorr(interpCoef, f, dfdx, dfdy, ...
    cfg.paper.templateSize, 1, [cx; cy], dX, dY, P0, ...
    cfg.impl.icgnTolerance);
q = [P(1); P(7); P(2); P(3); P(8); P(9)];
info = struct('converged', stopVal <= cfg.impl.icgnTolerance, ...
    'iterations', iter, 'ZNSSD', max(0, 2*(1-C)), 'engine', 'ADIC2D');
end
