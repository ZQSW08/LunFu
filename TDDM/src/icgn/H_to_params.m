function q = H_to_params(H)
%H_TO_PARAMS 从仿射矩阵恢复 TDDM 六参数。
if ~isequal(size(H), [3 3])
    error('H must be a 3-by-3 matrix.');
end
q = [H(1,3); H(2,3); H(1,1)-1; H(1,2); H(2,1); H(2,2)-1];
end
