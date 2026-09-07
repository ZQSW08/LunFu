function [q, info] = affine_icgn_native(reference, current, refCenter, q0, cfg)
%AFFINE_ICGN_NATIVE TDDM 的原生六参数逆组合 IC-GN 实现。
if mod(cfg.paper.templateSize, 2) == 0
    error('templateSize must be odd.');
end
r = floor(cfg.paper.templateSize / 2);
[X, Y] = meshgrid(-r:r, -r:r);
cx = refCenter(1); cy = refCenter(2);
Xref = cx + X; Yref = cy + Y;
T = interp2(double(reference), Xref, Yref, cfg.impl.interpolation, NaN);
if any(isnan(T(:)))
    error('Reference subset outside image.');
end
[Gx, Gy] = gradient(T);
if cfg.impl.useZNNormalization
    [Tn, ~, st] = normalize_patch(T);
else
    Tn = T; st = 1;
end
if st < 1e-12, error('Reference subset has insufficient intensity variation.'); end
SD = [Gx(:), Gy(:), Gx(:).*X(:), Gx(:).*Y(:), Gy(:).*X(:), Gy(:).*Y(:)] / st;
Hessian = SD' * SD + eye(6) * cfg.impl.icgnDamping;
q = q0(:);
converged = false;
lastZNSSD = Inf;
for iter = 1:cfg.impl.icgnMaxIter
    [Xw, Yw] = affine_warp(X, Y, params_to_H(q));
    Iw = interp2(double(current), cx + Xw, cy + Yw, cfg.impl.interpolation, NaN);
    if any(isnan(Iw(:)))
        break;
    end
    if cfg.impl.useZNNormalization
        [In, ~, si] = normalize_patch(Iw);
    else
        In = Iw; si = 1;
    end
    if si < 1e-12
        break;
    end
    residual = Tn - In;
    % 论文 Eq.(14)-(16)：逆组合增量的符号和 H(q)*inv(H(delta)) 更新。
    delta = -Hessian \ (SD' * residual(:));
    Hnew = params_to_H(q) / params_to_H(delta);
    qNew = H_to_params(Hnew);
    lastZNSSD = sum(residual(:).^2);
    if norm(delta([1 2 3 4 5 6])) < cfg.impl.icgnTolerance
        q = qNew;
        converged = true;
        break;
    end
    q = qNew;
end
if ~exist('iter', 'var'), iter = 0; end
if ~isfinite(lastZNSSD)
    [Xw, Yw] = affine_warp(X, Y, params_to_H(q));
    Iw = interp2(double(current), cx + Xw, cy + Yw, cfg.impl.interpolation, NaN);
    if all(isfinite(Iw(:))), lastZNSSD = znssd(T, Iw); end
end
info = struct('converged', converged, 'iterations', iter, ...
    'ZNSSD', lastZNSSD, 'engine', 'native');
end
