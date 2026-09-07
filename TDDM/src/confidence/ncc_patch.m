function value = ncc_patch(A, B)
%NCC_PATCH 计算两个同尺寸图像子区的零均值归一化相关系数。
if ~isequal(size(A), size(B))
    error('Patch sizes must be identical.');
end
[An, ~, sa] = normalize_patch(A);
[Bn, ~, sb] = normalize_patch(B);
if sa < 1e-12 && sb < 1e-12
    value = double(max(abs(double(A(:)) - double(B(:)))) < 1e-12);
elseif sa < 1e-12 || sb < 1e-12
    value = 0;
else
    value = sum(An(:) .* Bn(:));
end
value = max(-1, min(1, value));
end
