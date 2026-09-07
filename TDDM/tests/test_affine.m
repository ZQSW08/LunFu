function ok = test_affine()
%TEST_AFFINE 验证 q 与 H 的双向坐标映射。
q = [0.25; -0.4; 0.01; -0.02; 0.03; 0.005];
assert(norm(H_to_params(params_to_H(q))-q) < 1e-12);
assert(isequal(params_to_H(zeros(6,1)), eye(3)));
ok = true;
end
