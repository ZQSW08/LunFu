function displacement = apcv_estimate_coarse(currentProfile, referenceProfile, maxLag)
%APCV_ESTIMATE_COARSE 按论文式 (14)-(15) 由幅度互相关求整数位移。

referenceProfile = double(referenceProfile(:));
currentProfile = double(currentProfile(:));

% 傅里叶高通残差在 ROI 上下边界会产生与真实运动无关的固定响应。
% 仅剔除滤波支撑范围内的边界样本，避免该固定峰压过结构纹理峰。
trim = max(4, round(0.04*numel(referenceProfile)));
if 2*trim + 2*maxLag + 8 < numel(referenceProfile)
    referenceProfile = referenceProfile(1+trim:end-trim);
    currentProfile = currentProfile(1+trim:end-trim);
end
referenceProfile = referenceProfile - mean(referenceProfile);
currentProfile = currentProfile - mean(currentProfile);
[correlation, lags] = xcorr(currentProfile, referenceProfile, maxLag, 'coeff');
[~, index] = max(correlation);
displacement = lags(index);
end
