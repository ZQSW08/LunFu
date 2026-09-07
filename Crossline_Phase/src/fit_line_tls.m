function line = fit_line_tls(points)
%FIT_LINE_TLS 用总最小二乘拟合等值线点，返回归一化直线系数。
points = double(points);
points = points(all(isfinite(points),2),:);
if size(points,1) < 2
    line = struct('a',NaN,'b',NaN,'c',NaN,'points',points,'support',size(points,1),'residual',Inf);
    return;
end
mu = mean(points,1);
[~,~,V] = svd(points-mu,0);
direction = V(:,1);
normal = [-direction(2),direction(1)];
normal = normal/norm(normal);
line = struct('a',normal(1),'b',normal(2),'c',-normal*mu(:), ...
    'points',points,'support',size(points,1),'residual',0);
line.residual = mean(abs(points*[line.a;line.b]+line.c));
end
