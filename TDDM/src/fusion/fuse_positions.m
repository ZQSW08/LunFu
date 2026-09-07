function [pCorrected, mode] = fuse_positions(pT, pD, nccT, nccD, gate)
%FUSE_POSITIONS 实现论文 Eq.(10)，同时避免两路都失败时传播 NaN。
hasT = ~isempty(pT) && all(isfinite(pT)) && isfinite(nccT) && nccT >= gate;
hasD = ~isempty(pD) && all(isfinite(pD)) && isfinite(nccD) && nccD >= gate;
if hasT && hasD
    [wT, wD] = confidence_weights(nccT, nccD);
    pCorrected = wT * pT + wD * pD;
    mode = 'tracking_detection_weighted';
elseif hasT
    pCorrected = pT;
    mode = 'tracking_only';
elseif hasD
    pCorrected = pD;
    mode = 'detection_only';
else
    pCorrected = pT;
    mode = 'unreliable_tracking_fallback';
end
end
