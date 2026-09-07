function ok = test_ncc()
%TEST_NCC 验证 NCC(A,A)=1、ZNSSD(A,A)=0。
A = reshape(sin(1:37^2), 37, 37);
assert(abs(ncc_patch(A,A)-1) < 1e-12);
assert(znssd(A,A) < 1e-12);
ok = true;
end
