function dMacro=estimate_macro_temporal(dTotal,fps,cutoffHz)
% ESTIMATE_MACRO_TEMPORAL 用低通/平滑提取慢变宏观运动。
% 优先使用零相位 Butterworth；无 Signal Processing Toolbox 时退化为对称移动平均。
dTotal=double(dTotal); wasVector=isvector(dTotal); if wasVector, dTotal=dTotal(:); end
n=size(dTotal,1); dMacro=zeros(size(dTotal));
if n<3 || cutoffHz<=0, dMacro=dTotal; if wasVector, dMacro=dMacro(:); end, return; end
if exist('butter','file')==2 && exist('filtfilt','file')==2 && cutoffHz<fps/2
    [b,a]=butter(2,min(0.99,cutoffHz/(fps/2)));
    for k=1:size(dTotal,2), dMacro(:,k)=filtfilt(b,a,dTotal(:,k)); end
else
    half=max(1,round(fps/(2*cutoffHz))); span=2*half+1;
    for k=1:size(dTotal,2), dMacro(:,k)=movmean(dTotal(:,k),span,'Endpoints','shrink'); end
end
if wasVector, dMacro=dMacro(:); end
end
