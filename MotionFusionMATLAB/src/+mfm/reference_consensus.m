function [macro,valid,d]=reference_consensus(displacements,mask,cfg)
% Robust translation from reference rows only. The target is absent by API.
n=size(displacements,1);d=struct('inliers',false(1,n),'support',0,'validCandidates',0,'spread',NaN,'status','insufficient_valid_references');
macro=[NaN NaN];valid=false;good=mask(:)&all(isfinite(displacements),2);ids=find(good);d.validCandidates=numel(ids);
assert(size(displacements,2)==2&&numel(mask)==n,'Reference consensus needs N-by-2 displacement and N masks');
assert(cfg.automaticMinReferences>=1&&cfg.automaticMinInlierRatio>0&&cfg.automaticMinInlierRatio<=1&&...
    cfg.automaticConsensusTolerance>0&&cfg.automaticMaxSpread>=0&&cfg.automaticAmbiguityRatio>0,'Invalid automatic consensus configuration');
if numel(ids)<cfg.automaticMinReferences,return;end
x=displacements(ids,:);tol=cfg.automaticConsensusTolerance;D=hypot(x(:,1)-x(:,1)',x(:,2)-x(:,2)');counts=sum(D<=tol,2);
[bestCount,bestSeed]=max(counts);cluster=D(bestSeed,:)<=tol;center=median(x(cluster,:),1);
for iter=1:2,dist=hypot(x(:,1)-center(1),x(:,2)-center(2));cluster=dist<=tol;if any(cluster),center=median(x(cluster,:),1);end,end
dist=hypot(x(:,1)-center(1),x(:,2)-center(2));cluster=dist<=tol;bestCount=nnz(cluster);
remaining=find(~cluster);second=0;if ~isempty(remaining),second=max(sum(D(remaining,remaining)<=tol,2));end
d.support=bestCount;d.inliers(ids(cluster))=true;
if second>=cfg.automaticAmbiguityRatio*bestCount,d.status='ambiguous_motion_groups';return;end
if bestCount<cfg.automaticMinReferences,d.status='insufficient_inliers';return;end
if bestCount/numel(ids)<cfg.automaticMinInlierRatio,d.status='insufficient_inlier_ratio';return;end
macro=median(x(cluster,:),1);res=hypot(x(cluster,1)-macro(1),x(cluster,2)-macro(2));d.spread=sqrt(mean(res.^2));
if ~all(isfinite(macro)),d.status='nonfinite_reference_motion';macro=[NaN NaN];return;end
if d.spread>cfg.automaticMaxSpread,d.status='excessive_reference_spread';macro=[NaN NaN];return;end
valid=true;d.status='ok';
end
