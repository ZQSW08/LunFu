function local = local_phase_refine(template,pyramid,coarseCenter,cfg,mode)
% LOCAL_PHASE_REFINE 在粗定位附近进行整数像素 circular phase 搜索。
% mode: scalar_phase / circular_single / circular_multi。

roi=template.roi; w=roi(3); h=roi(4); radius=round(cfg.method.localSearchRadiusPx);
center0=coarseCenter(:).'; candidateX=round(center0(1))+(-radius:radius); candidateY=round(center0(2))+(-radius:radius);
if isfield(cfg.method,'observedAxis') && strcmpi(cfg.method.observedAxis,'x'), candidateY=round(center0(2)); end
if isfield(cfg.method,'observedAxis') && strcmpi(cfg.method.observedAxis,'y'), candidateX=round(center0(1)); end
% 候选中心必须保证整块 ROI 能落在当前帧内，避免边界候选产生空/短相关区域。
imageSize=size(pyramid(1,1).phase); minX=1+floor((w-1)/2); maxX=imageSize(2)-ceil((w-1)/2);
minY=1+floor((h-1)/2); maxY=imageSize(1)-ceil((h-1)/2);
candidateX=clip_candidate_axis(candidateX,minX,maxX,center0(1)); candidateY=clip_candidate_axis(candidateY,minY,maxY,center0(2));
if strcmpi(mode,'scalar_phase')
    scaleIndex=cfg.method.singleScaleIndex; scoreMap=-Inf(numel(candidateY),numel(candidateX));
    for iy=1:numel(candidateY)
        for ix=1:numel(candidateX)
            topLeft=[candidateX(ix)-floor((w-1)/2),candidateY(iy)-floor((h-1)/2)];
            if ~is_valid_patch(topLeft,[w h],size(pyramid(1,1).phase)), continue; end
            currentPhase=crop_matrix(pyramid(scaleIndex,1).phase,topLeft,[w h]);
            scoreMap(iy,ix)=normalized_score(template.channels(scaleIndex,1).phase,currentPhase);
        end
    end
    scaleCenters=[candidateX(1),candidateY(1)];
else
    scaleIndices=scaleIndices_for_mode(mode,cfg);
    local=vectorized_circular_search(template,pyramid,coarseCenter,cfg,scaleIndices,1:numel(cfg.method.orientationsDeg),mode); return;
end
[bestScore,bestIndex]=max(scoreMap(:)); [bestY,bestX]=ind2sub(size(scoreMap),bestIndex); bestCenter=[candidateX(bestX),candidateY(bestY)];
secondMap=scoreMap; secondMap(max(1,bestY-1):min(size(scoreMap,1),bestY+1),max(1,bestX-1):min(size(scoreMap,2),bestX+1))=-Inf;
secondScore=max(secondMap(:)); if ~isfinite(secondScore), secondScore=-1; end
peakRatio=(bestScore-secondScore)/max(abs(secondScore),eps);
local=struct('center',bestCenter,'score',bestScore,'secondScore',secondScore,'peakRatio',peakRatio,'scoreMap',scoreMap,...
    'candidateX',candidateX,'candidateY',candidateY,'scaleCenters',scaleCenters,'crossScaleAgreement',1,'mode',mode);
end

function indices=scaleIndices_for_mode(mode,cfg)
if strcmpi(mode,'circular_single')
    indices=cfg.method.singleScaleIndex;
elseif isfield(cfg.method,'trackingScaleIndices')
    indices=cfg.method.trackingScaleIndices;
else
    indices=1:numel(cfg.method.wavelengthsPx);
end
end

function local=vectorized_circular_search(template,pyramid,coarseCenter,cfg,scaleIndices,orientationIndices,mode)
roi=template.roi; radius=round(cfg.method.localSearchRadiusPx); candidateX=round(coarseCenter(1))+(-radius:radius); candidateY=round(coarseCenter(2))+(-radius:radius);
imageSize=size(pyramid(1,1).phase); w=round(roi(3)); h=round(roi(4));
minX=1+floor((w-1)/2); maxX=imageSize(2)-ceil((w-1)/2);
minY=1+floor((h-1)/2); maxY=imageSize(1)-ceil((h-1)/2);
candidateX=clip_candidate_axis(candidateX,minX,maxX,coarseCenter(1)); candidateY=clip_candidate_axis(candidateY,minY,maxY,coarseCenter(2));
numScales=size(template.channels,1); scaleIndices=scaleIndices(scaleIndices>=1 & scaleIndices<=numScales);
if isempty(scaleIndices), scaleIndices=1:numScales; end
numOrientations=size(template.channels,2); orientationIndices=orientationIndices(orientationIndices>=1 & orientationIndices<=numOrientations);
if isempty(orientationIndices), orientationIndices=1:numOrientations; end
scoreMap=zeros(numel(candidateY),numel(candidateX)); scaleMaps=-Inf(numel(cfg.method.wavelengthsPx),numel(candidateY),numel(candidateX));
for s=scaleIndices
    orientationScores=zeros(numel(candidateY),numel(candidateX));
    for o=orientationIndices
        channel=template.channels(s,o); weight=double(channel.reliability).*channel.amplitude; weight=weight/max(mean(weight(:)),eps); weight(~isfinite(weight))=0; weightSum=sum(weight(:));
        currentZ=pyramid(s,o).unitPhasor.*double(pyramid(s,o).reliability);
        % 只在候选中心覆盖的局部区域做相关，避免每个通道对整幅 1440x1080 图像 FFT。
        cross=local_linear_correlation(currentZ,rot90(conj(channel.unitPhasor).*weight,2),candidateX,candidateY);
        phaseScore=abs(cross)/max(weightSum,eps); meanPhase=angle(cross); phaseScore=phaseScore.*exp(-0.5*(meanPhase/cfg.method.phaseMeanSigmaRad).^2);
        phaseScore(~isfinite(phaseScore))=0;
        orientationScores=orientationScores+phaseScore;
    end
    orientationScores=orientationScores/max(numel(orientationIndices),1); scaleMaps(s,:,:)=orientationScores; scoreMap=scoreMap+orientationScores;
end
scoreMap=scoreMap/max(numel(scaleIndices),1); [bestScore,bestIndex]=max(scoreMap(:)); [bestY,bestX]=ind2sub(size(scoreMap),bestIndex); bestCenter=[candidateX(bestX),candidateY(bestY)];
secondMap=scoreMap; secondMap(max(1,bestY-1):min(size(scoreMap,1),bestY+1),max(1,bestX-1):min(size(scoreMap,2),bestX+1))=-Inf; secondScore=max(secondMap(:)); if ~isfinite(secondScore), secondScore=-1; end
peakRatio=(bestScore-secondScore)/max(abs(secondScore),eps); scaleCenters=nan(numel(scaleIndices),2);
for k=1:numel(scaleIndices)
    % 不使用 squeeze，避免 observedAxis='x'/'y' 时单例维度被压掉导致索引交换。
    oneScale=reshape(scaleMaps(scaleIndices(k),:,:),numel(candidateY),numel(candidateX));
    [~,idx]=max(oneScale(:)); [iy,ix]=ind2sub([numel(candidateY),numel(candidateX)],idx);
    scaleCenters(k,:)=[candidateX(ix),candidateY(iy)];
end
if size(scaleCenters,1)>1, crossScaleStd=mean(std(scaleCenters,0,1)); else, crossScaleStd=0; end
local=struct('center',bestCenter,'score',bestScore,'secondScore',secondScore,'peakRatio',peakRatio,'scoreMap',scoreMap,...
    'candidateX',candidateX,'candidateY',candidateY,'scaleCenters',scaleCenters,'crossScaleAgreement',exp(-crossScaleStd/max(1,radius)),'mode',mode);
end

function values=clip_candidate_axis(values,minValue,maxValue,reference)
% 保留搜索步长；若预测点出界，则退回到最近的合法中心。
values=values(values>=minValue & values<=maxValue);
if isempty(values), values=min(max(round(reference),minValue),maxValue); end
end

function ok=is_valid_patch(topLeft,patchSize,imageSize)
ok=topLeft(1)>=1 && topLeft(2)>=1 && topLeft(1)+patchSize(1)-1<=imageSize(2) && topLeft(2)+patchSize(2)-1<=imageSize(1);
end
function patch=crop_matrix(matrix,topLeft,patchSize)
x=topLeft(1); y=topLeft(2); w=patchSize(1); h=patchSize(2); patch=matrix(y:y+h-1,x:x+w-1);
end
function score=normalized_score(reference,candidate)
reference=reference-mean(reference(:)); candidate=candidate-mean(candidate(:)); denominator=sqrt(sum(reference(:).^2)*sum(candidate(:).^2)); score=sum(reference(:).*candidate(:))/max(denominator,eps);
end

function same=linear_same_correlation(image,kernel)
% 频域计算与 conv2(...,'same') 相同的线性相关，避免大 Gabor 核的 O(N^2) 开销。
image=squeeze(image); kernel=squeeze(kernel);
if ndims(image)>2, image=image(:,:,1); end
if ndims(kernel)>2, kernel=kernel(:,:,1); end
[h,w]=size(image); [kh,kw]=size(kernel);
if h<1 || w<1 || kh<1 || kw<1, same=zeros(max(h,1),max(w,1)); return; end
fftH=h+kh-1; fftW=w+kw-1;
full=ifft2(fft2(image,fftH,fftW).*fft2(kernel,fftH,fftW));
% 保持原工程的 even-size kernel 中心约定，避免修复边界时改变位移坐标。
row0=floor(kh/2)+1; col0=floor(kw/2)+1;
row1=row0+h-1; col1=col0+w-1;
% 对极小 ROI/奇异输入保留安全回退，任何情况下都返回与 image 同尺寸的结果。
if row1>size(full,1) || col1>size(full,2)
    same=conv2(image,kernel,'same');
else
    same=full(row0:row1,col0:col1);
end
end

function values=local_linear_correlation(image,kernel,candidateX,candidateY)
% 返回指定候选中心处的 same-correlation，计算范围仅覆盖候选点及核半径。
[h,w]=size(image); [kh,kw]=size(kernel);
candidateX=round(candidateX(:).'); candidateY=round(candidateY(:).');
values=-Inf(numel(candidateY),numel(candidateX));
if h<1 || w<1 || kh<1 || kw<1, return; end
rowRadius=floor(kh/2); colRadius=floor(kw/2);
validX=candidateX>=1 & candidateX<=w; validY=candidateY>=1 & candidateY<=h;
if ~any(validX) || ~any(validY), return; end
validCandidateX=candidateX(validX); validCandidateY=candidateY(validY);
y0=max(1,min(validCandidateY)-rowRadius); y1=min(h,max(validCandidateY)+rowRadius);
x0=max(1,min(validCandidateX)-colRadius); x1=min(w,max(validCandidateX)+colRadius);
local=linear_same_correlation(image(y0:y1,x0:x1),kernel);
localY=validCandidateY-y0+1; localX=validCandidateX-x0+1;
values(validY,validX)=local(localY,localX);
end
