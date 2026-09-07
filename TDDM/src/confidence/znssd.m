function value = znssd(A, B)
%ZNSSD 计算论文 Eq.(17) 使用的零均值归一化平方差。
if ~isequal(size(A), size(B))
    error('Patch sizes must be identical.');
end
[An, ~, sa] = normalize_patch(A);
[Bn, ~, sb] = normalize_patch(B);
if sa < 1e-12 && sb < 1e-12
    value = double(max(abs(double(A(:)) - double(B(:)))) >= 1e-12);
else
    value = sum((An(:) - Bn(:)).^2);
end
end
