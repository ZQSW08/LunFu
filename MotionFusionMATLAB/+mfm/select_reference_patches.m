function [rois,info]=select_reference_patches(im,target,searchROI,cfg)
% Select dispersed, two-dimensionally observable patches outside the target.
im=double(im);assert(ismatrix(im),'Automatic reference selection needs a grayscale image');
[h,w]=size(im);p=cfg.automaticPatchSize;if isscalar(p),p=[p p];end;p=round(p([1 2]));
assert(all(p>=12),'automaticPatchSize must be at least 12 pixels');
if isempty(searchROI),searchROI=[1 1 w h];source='full_frame_outside_target';else,searchROI=round(searchROI(:)');source='explicit_searchROI';end
assert(numel(searchROI)==4&&all(isfinite(searchROI)),'searchROI must be [x y w h]');
assert(searchROI(1)>=1&&searchROI(2)>=1&&searchROI(3)>=p(1)&&searchROI(4)>=p(2)&&...
    searchROI(1)+searchROI(3)-1<=w&&searchROI(2)+searchROI(4)-1<=h,'searchROI outside first frame or smaller than patch');
gx=conv2(im,[1 0 -1]/2,'same');gy=conv2(im,[1;0;-1]/2,'same');
stride=max(4,round(min(p)/2));xs=searchROI(1):stride:searchROI(1)+searchROI(3)-p(1);
ys=searchROI(2):stride:searchROI(2)+searchROI(4)-p(2);cand=zeros(0,4);score=zeros(0,1);
pad=max(2,round(.15*min(p)));for y=ys
for x=xs
    r=[x y p];if overlap(r,target+[-pad -pad 2*pad 2*pad]),continue;end
    rows=y:y+p(2)-1;cols=x:x+p(1)-1;b=im(rows,cols);a=mean(gx(rows,cols).^2,'all');c=mean(gy(rows,cols).^2,'all');q=mean(gx(rows,cols).*gy(rows,cols),'all');
    lambda=.5*(a+c-hypot(a-c,2*q));
    if std(b(:),1)>=cfg.automaticMinTextureStd&&lambda>=cfg.automaticMinGradientEigenvalue
        cand(end+1,:)=r;score(end+1,1)=lambda; %#ok<AGROW>
    end
end
end
n=min(cfg.automaticReferenceCount,size(cand,1));chosen=zeros(0,1);centers=cand(:,1:2)+(cand(:,3:4)-1)/2;
if n>0
    [~,first]=max(score);chosen=first;
    while numel(chosen)<n
        d=inf(size(score));for j=1:numel(chosen),d=min(d,hypot(centers(:,1)-centers(chosen(j),1),centers(:,2)-centers(chosen(j),2)));end
        texture=min(score,3*median(score))/max(eps,min(max(score),3*median(score)));
        utility=.45*texture+.55*min(1,d/max(eps,hypot(searchROI(3),searchROI(4))));
        utility(d<.9*min(p))=-Inf;utility(chosen)=-Inf;
        [best,next]=max(utility);if ~isfinite(best),break;end;chosen(end+1,1)=next; %#ok<AGROW>
    end
end
rois=cand(chosen,:);selectedScores=score(chosen);status='ok';if size(rois,1)<cfg.automaticMinReferences,status='insufficient_observable_references';end
info=struct('status',status,'source',source,'searchROI',searchROI,'candidateCount',size(cand,1),...
    'selectedCount',size(rois,1),'selectedScores',selectedScores,'patchSize',p,'targetExcluded',true);
end
function yes=overlap(a,b)
yes=a(1)<=b(1)+b(3)-1&&b(1)<=a(1)+a(3)-1&&a(2)<=b(2)+b(4)-1&&b(2)<=a(2)+a(4)-1;
end
