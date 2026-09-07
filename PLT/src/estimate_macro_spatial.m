function [dMacro,residual,consensus] = estimate_macro_spatial(patchTracks)
% ESTIMATE_MACRO_SPATIAL 用多个 phase patch 的鲁棒中位数估计共同平移。
% patchTracks 维度为 N×D×P（D=1 或 2），输出每个 patch 相对共同运动的残差。
tracks=double(patchTracks); if ndims(tracks)==2, tracks=reshape(tracks,size(tracks,1),size(tracks,2),1); end
[n,d,p]=size(tracks); dMacro=nan(n,d); consensus=nan(n,1); residual=nan(n,d,p);
for k=1:n
    samples=squeeze(tracks(k,:,:)).'; good=all(isfinite(samples),2); samples=samples(good,:);
    if isempty(samples), continue; end
    center=median(samples,1); dMacro(k,:)=center; consensus(k)=sum(good);
    residual(k,:,:)=tracks(k,:,:)-reshape(center,1,d,1);
end
if p<1 || p==1, return; end
end
