function [result,diagnostics] = apcv_apply_tracking_reliability(result,model,tracking,enabled)
%APCV_APPLY_TRACKING_RELIABILITY 用外层不确定度选择更保守的金字塔层级。
% 这是 AP-CV-LongRange 研究扩展；固定 baseline 的 selectedLevel 仍保存在 fixedLevelPx。
if nargin<4, enabled=true; end
n=numel(result.proposedPx); quality=ones(n,1); valid=true(n,1);
if isfield(tracking,'quality'), quality=double(tracking.quality(:)); end
if isfield(tracking,'valid'), valid=logical(tracking.valid(:)); end
quality=quality(1:min(end,n)); valid=valid(1:min(end,n));
if numel(quality)<n, quality(end+1:n)=quality(end); end
if numel(valid)<n, valid(end+1:n)=false; end
quality(~isfinite(quality))=0; quality=min(1,max(0,quality));

baseIndex=model.selectedIndex; levels=[model.levels.level]; [~,coarseIndex]=max(levels);
indices=repmat(baseIndex,n,1);
if enabled && coarseIndex~=baseIndex
    for k=1:n
        fraction=min(1,max(0,(0.70-quality(k))/0.35));
        target=levels(baseIndex)+fraction*(levels(coarseIndex)-levels(baseIndex));
        [~,indices(k)]=min(abs(levels-target));
    end
end
linear=sub2ind(size(result.byLevelPx),(1:n)',indices);
result.fixedLevelPx=result.proposedPx;
result.proposedPx=result.byLevelPx(linear);
result.adaptiveLevelIndex=indices;
result.adaptiveLevel=levels(indices(:))'; result.adaptiveLevel=result.adaptiveLevel(:);
result.trackingValid=valid;
result.proposedPxValidOnly=result.proposedPx;
result.proposedPxValidOnly(~valid)=NaN;
diagnostics=struct('enabled',logical(enabled),'baseIndex',baseIndex,'coarseIndex',coarseIndex, ...
    'quality',quality,'valid',valid,'selectedIndex',indices);
end
