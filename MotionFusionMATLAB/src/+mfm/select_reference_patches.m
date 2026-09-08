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
nx=0;ny=0;gridId=zeros(size(cand,1),1);
if n>0
    % First assign candidates to a coarse grid derived only from the search
    % rectangle and requested count.  Selecting at most one strong patch from
    % each occupied cell prevents several high-texture corners of one object
    % from consuming the whole reference budget.
    aspect=searchROI(3)/max(eps,searchROI(4));
    nx=max(1,ceil(sqrt(n*aspect)));ny=max(1,ceil(n/nx));
    ux=(centers(:,1)-searchROI(1))/max(eps,searchROI(3));
    uy=(centers(:,2)-searchROI(2))/max(eps,searchROI(4));
    ix=min(nx,max(1,floor(ux*nx)+1));iy=min(ny,max(1,floor(uy*ny)+1));
    gridId=(iy-1)*nx+ix;
    cells=unique(gridId(:),'stable');
    cellBest=zeros(numel(cells),1);cellScore=-Inf(numel(cells),1);
    for j=1:numel(cells)
        ids=find(gridId==cells(j));[~,q]=max(score(ids));cellBest(j)=ids(q);cellScore(j)=score(ids(q));
    end
    % Strong texture remains the first criterion; spatial coverage decides
    % ties and fills any cells left after the requested count is reached.
    [~,order]=sort(cellScore,'descend');
    % A patch-sized exclusion is too weak for a textured object: adjacent
    % corners can be separated by one patch width while still observing the
    % same object.  Keep a modest margin so high-texture duplicates do not
    % crowd out other spatial cells, while retaining the public spacing
    % contract (>= .9*patchSize).
    minDistance=1.15*min(p);
    for j=1:numel(order)
        if numel(chosen)>=n,break;end
        candidate=cellBest(order(j));
        if isempty(chosen)||all(hypot(centers(candidate,1)-centers(chosen,1),centers(candidate,2)-centers(chosen,2))>=minDistance)
            chosen(end+1,1)=candidate; %#ok<AGROW>
        end
    end
    while numel(chosen)<n
        d=inf(size(score));
        for j=1:numel(chosen),d=min(d,hypot(centers(:,1)-centers(chosen(j),1),centers(:,2)-centers(chosen(j),2)));end
        base=max(eps,median(score));texture=min(score,3*base)/max(eps,3*base);
        utility=d/max(eps,hypot(searchROI(3),searchROI(4)))+.10*texture;
        utility(d<minDistance)=-Inf;utility(chosen)=-Inf;
        [best,next]=max(utility);if ~isfinite(best),break;end
        chosen(end+1,1)=next; %#ok<AGROW>
    end
end
rois=cand(chosen,:);selectedScores=score(chosen);status='ok';if size(rois,1)<cfg.automaticMinReferences,status='insufficient_observable_references';end
info=struct('status',status,'source',source,'searchROI',searchROI,'candidateCount',size(cand,1),...
    'selectedCount',size(rois,1),'selectedScores',selectedScores,'patchSize',p,'targetExcluded',true,...
    'gridSize',[nx ny],'selectedGridCells',unique(gridId(chosen)).');
end
function yes=overlap(a,b)
yes=a(1)<=b(1)+b(3)-1&&b(1)<=a(1)+a(3)-1&&a(2)<=b(2)+b(4)-1&&b(2)<=a(2)+a(4)-1;
end
