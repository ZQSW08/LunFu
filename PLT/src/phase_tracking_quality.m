function qualityInfo=phase_tracking_quality(local,sub,poc,methodName,cfg)
% PHASE_TRACKING_QUALITY 汇总峰值、相位分数、跨尺度一致性和 WLS 状态。
scoreQuality=max(0,min(1,(local.score+1)/2));
peakQuality=1-exp(-max(0,min(20,local.peakRatio))); agreement=max(0,min(1,local.crossScaleAgreement));
if any(strcmpi(methodName,{'poc_local_multi','v3_predictive'})) && isfinite(poc.peakScore)
    coarseQuality=max(0,min(1,(poc.peakScore+1)/2));
else
    coarseQuality=1;
end
if strcmpi(methodName,'intensity_ncc')
    subQuality=1; % 强度基线没有相位 WLS 样本，不用该项惩罚。
else
    subQuality=double(sub.valid || (sub.sampleCount>0 && sub.sampleCount<3));
end
value=scoreQuality*(0.35+0.65*peakQuality)*(0.50+0.50*agreement)*(0.50+0.50*coarseQuality)*(0.50+0.50*subQuality);
qualityInfo=struct('value',value,'scoreQuality',scoreQuality,'peakQuality',peakQuality,'crossScaleAgreement',agreement,...
    'coarseQuality',coarseQuality,'subpixelQuality',subQuality,'status','PHASE_TRACK_OK');
if ~isfinite(value) || value<cfg.method.minTrackingQuality, qualityInfo.status='PHASE_TRACK_WEAK'; end
end
