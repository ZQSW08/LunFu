function [wT, wD] = confidence_weights(nccT, nccD)
%CONFIDENCE_WEIGHTS 根据论文 Eq.(10) 计算 tracking/detection 权重。
denom = max(0, nccT) + max(0, nccD);
if denom < 1e-12
    wT = 0.5;
    wD = 0.5;
else
    wT = max(0, nccT) / denom;
    wD = max(0, nccD) / denom;
end
end
