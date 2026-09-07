function H = params_to_H(q)
%PARAMS_TO_H 将 q=[u v ux uy vx vy]' 转为论文 Eq.(12) 的仿射矩阵。
q = q(:);
if numel(q) ~= 6
    error('q must contain six parameters.');
end
H = [1 + q(3), q(4), q(1); q(5), 1 + q(6), q(2); 0, 0, 1];
end
