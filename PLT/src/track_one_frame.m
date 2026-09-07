function [state,result]=track_one_frame(state,grayFrame,cfg,methodName,pyramid)
% TRACK_ONE_FRAME 执行一帧的 global-to-local phase tracking。
% anchor 永不更新；previousCenter 仅用于下一帧搜索和失效回退。

if nargin<5 || isempty(pyramid), pyramid=build_complex_gabor_pyramid(grayFrame,cfg); end
grayFrame=to_gray_double_local(grayFrame); methodName=char(methodName); anchor=state.anchor;
isV3=strcmpi(methodName,'v3_predictive');
template=anchor; templateSource='anchor'; usedPrediction=false; usedPocRecovery=false;
if isV3
    % V3 健康状态只在预测位置附近做局部相位搜索，POC 仅用于失效恢复。
    if ~isfield(state,'templateBank'), state.templateBank=phase_template_bank(anchor,[],[]); end
    [template,templateSource]=phase_template_bank_select(state.templateBank,cfg);
    if ~isfield(state,'velocity'), state.velocity=[0 0]; end
    if ~isfield(state,'predictedCenter'), state.predictedCenter=state.previousCenter; end
    predictedCenter=state.predictedCenter;
    recoveryAfter=cfg.method.recoveryAfterLostFrames;
    needRecovery=isfield(state,'lostCount') && state.lostCount>=recoveryAfter;
    if needRecovery
        poc=global_poc_search(template.grayCrop,grayFrame,state.previousCenter);
        usedPocRecovery=true; coarseCenter=poc.center;
        if ~poc.valid || poc.peakScore<cfg.method.recoveryMinPocPeakScore || poc.peakRatio<cfg.method.recoveryMinPocPeakRatio
            % 恢复峰不可信时仍留在上一帧，不能把错误 POC 位置交给局部跟踪。
            coarseCenter=state.previousCenter; poc.valid=false;
        end
    else
        poc=struct('center',predictedCenter,'peakScore',NaN,'peakRatio',NaN,'valid',true);
        coarseCenter=predictedCenter; usedPrediction=true;
    end
elseif strcmpi(methodName,'poc_local_multi')
    poc=global_poc_search(anchor.grayCrop,grayFrame,state.previousCenter);
    if isfield(cfg.method,'maxPocJumpPx') && isfinite(cfg.method.maxPocJumpPx)
        if isfield(cfg.method,'observedAxis') && strcmpi(cfg.method.observedAxis,'x')
            jump=abs(poc.center(1)-state.previousCenter(1));
        elseif isfield(cfg.method,'observedAxis') && strcmpi(cfg.method.observedAxis,'y')
            jump=abs(poc.center(2)-state.previousCenter(2));
        else
            jump=norm(poc.center-state.previousCenter);
        end
        if jump>cfg.method.maxPocJumpPx
            % 放弃明显不可信的全局峰，退回上一帧位置交给局部相位搜索。
            poc.center=state.previousCenter; poc.peakScore=NaN; poc.peakRatio=NaN; poc.valid=false;
        end
    end
    coarseCenter=poc.center; coarsePeak=poc.peakScore;
else
    poc=struct('center',state.previousCenter,'peakScore',NaN,'peakRatio',NaN,'valid',true);
    coarseCenter=state.previousCenter; coarsePeak=NaN;
end
if isV3
    coarsePeak=poc.peakScore;
end
switch lower(methodName)
    case 'intensity_ncc'
        local=local_intensity_ncc(anchor.grayCrop,grayFrame,coarseCenter,cfg.method.localSearchRadiusPx,cfg);
    case 'scalar_phase_ncc'
        local=local_phase_refine(anchor,pyramid,coarseCenter,cfg,'scalar_phase');
    case 'circular_single'
        local=local_phase_refine(anchor,pyramid,coarseCenter,cfg,'circular_single');
    case {'circular_multi','poc_local_multi'}
        local=local_phase_refine(anchor,pyramid,coarseCenter,cfg,'circular_multi');
    case 'v3_predictive'
        local=local_phase_refine(template,pyramid,coarseCenter,cfg,'circular_multi');
    otherwise
        error('未知方法：%s',methodName);
end
if strcmpi(methodName,'intensity_ncc')
    % 时域/强度基线不使用相位亚像素修正，保持对照方法语义纯净。
    sub=struct('delta',[0 0],'valid',false,'residualRms',NaN,'sampleCount',0);
else
    sub=phase_subpixel_wls(anchor,pyramid,local.center,cfg);
end
qualityInfo=phase_tracking_quality(local,sub,poc,methodName,cfg); quality=qualityInfo.value;
center=local.center+sub.delta; previousCenter=state.previousCenter;
[state,center,status]=phase_state_machine(state,center,quality,cfg);
if isV3 && usedPrediction
    predictionResidual=axis_distance(center,predictedCenter,cfg.method.observedAxis);
    if predictionResidual>cfg.method.maxPredictionResidualPx
        % 局部峰明显偏离预测时，禁止把该峰当作稳定跟踪结果。
        center=previousCenter; state.lostCount=state.lostCount+1; status='PHASE_TRACK_WEAK';
        state.previousCenter=center; quality=0;
    end
else
    predictionResidual=NaN;
end
if strcmp(status,'PHASE_TRACK_WEAK'), sub.delta=[0 0]; sub.valid=false; end
templateUpdated=false; updatedTemplateSource='none';
if isV3
    % 将速度限制在观测方向，避免未观测方向的噪声反馈到预测器。
    velocity=center-previousCenter;
    if strcmpi(cfg.method.observedAxis,'x'), velocity(2)=0; end
    if strcmpi(cfg.method.observedAxis,'y'), velocity(1)=0; end
    if strcmp(status,'PHASE_TRACK_OK')
        state.velocity=velocity;
        if isfield(cfg.method,'predictionEnabled') && cfg.method.predictionEnabled
            state.predictedCenter=center+cfg.method.predictionHorizon*velocity;
        else
            state.predictedCenter=center;
        end
    else
        % 失效期间衰减速度，避免预测位置在错误方向持续发散。
        state.velocity=0.5*state.velocity; state.predictedCenter=center+state.velocity;
    end
    updateAllowed=strcmp(status,'PHASE_TRACK_OK') && ~usedPocRecovery && ...
        local.peakRatio>=cfg.method.templateUpdateMinPeakRatio && ...
        local.crossScaleAgreement>=cfg.method.templateUpdateMinAgreement && ...
        (~usedPrediction || predictionResidual<=cfg.method.maxPredictionResidualPx);
    if updateAllowed
        candidateRoi=roi_for_center(center,anchor.roi,size(grayFrame));
        candidateTemplate=build_phase_template(grayFrame,candidateRoi,pyramid,cfg);
        [state.templateBank,templateUpdated,updatedTemplateSource]=phase_template_bank_update(...
            state.templateBank,candidateTemplate,quality,state.frameIndex,cfg);
    end
    state.lastTemplateSource=templateSource; state.lastTemplateUpdated=templateUpdated;
end
state.lastPyramid=pyramid; state.frameIndex=state.frameIndex+1;
result=struct('center',center,'integerCenter',local.center,'subpixel',sub.delta,...
    'valid',strcmp(status,'PHASE_TRACK_OK'),'quality',quality,'phaseScore',local.score,...
    'coherence',local.score,'peakRatio',local.peakRatio,...
    'crossScaleAgreement',local.crossScaleAgreement,'subpixelResidualRms',sub.residualRms,...
    'subpixelValid',sub.valid,'coarseCenter',coarseCenter,'coarsePeak',coarsePeak,...
    'status',status,'poc',poc);
if isV3
    result.predictedCenter=predictedCenter; result.usedPrediction=usedPrediction;
    result.usedPocRecovery=usedPocRecovery; result.templateSource=templateSource;
    result.templateUpdated=templateUpdated; result.updatedTemplateSource=updatedTemplateSource;
    result.predictionResidual=predictionResidual;
end
end

function distance=axis_distance(a,b,axisName)
delta=double(a(:).'-b(:).');
if strcmpi(axisName,'x'), distance=abs(delta(1));
elseif strcmpi(axisName,'y'), distance=abs(delta(2));
else, distance=norm(delta);
end
end

function roi=roi_for_center(center,referenceRoi,imageSize)
% 让模板库的新模板保持固定尺寸，并裁剪到当前图像范围内。
w=round(referenceRoi(3)); h=round(referenceRoi(4));
x=round(center(1)-floor((w-1)/2)); y=round(center(2)-floor((h-1)/2));
x=min(max(x,1),imageSize(2)-w+1); y=min(max(y,1),imageSize(1)-h+1);
roi=[x y w h];
end

function local=local_intensity_ncc(template,image,coarseCenter,radius,cfg)
[h,w]=size(template); centerX=round(coarseCenter(1))+(-round(radius):round(radius));
centerY=round(coarseCenter(2))+(-round(radius):round(radius)); scores=-Inf(numel(centerY),numel(centerX));
if isfield(cfg.method,'observedAxis') && strcmpi(cfg.method.observedAxis,'x'), centerY=round(coarseCenter(2)); end
if isfield(cfg.method,'observedAxis') && strcmpi(cfg.method.observedAxis,'y'), centerX=round(coarseCenter(1)); end
for iy=1:numel(centerY)
    for ix=1:numel(centerX)
        x=centerX(ix)-floor((w-1)/2); y=centerY(iy)-floor((h-1)/2);
        if x<1 || y<1 || x+w-1>size(image,2) || y+h-1>size(image,1), continue; end
        candidate=image(y:y+h-1,x:x+w-1); a=template-mean(template(:)); b=candidate-mean(candidate(:));
        scores(iy,ix)=sum(a(:).*b(:))/max(sqrt(sum(a(:).^2)*sum(b(:).^2)),eps);
    end
end
[score,idx]=max(scores(:)); [iy,ix]=ind2sub(size(scores),idx); second=scores;
second(max(1,iy-1):min(size(scores,1),iy+1),max(1,ix-1):min(size(scores,2),ix+1))=-Inf;
secondScore=max(second(:)); if ~isfinite(secondScore), secondScore=-1; end
local=struct('center',[centerX(ix),centerY(iy)],'score',score,'secondScore',secondScore,...
    'peakRatio',(score-secondScore)/max(abs(secondScore),eps),'crossScaleAgreement',1,...
    'scoreMap',scores,'scaleCenters',[],'mode','intensity_ncc');
end

function img=to_gray_double_local(frame)
frame=double(frame);
if ndims(frame)==3, img=0.298936*frame(:,:,1)+0.587043*frame(:,:,2)+0.114021*frame(:,:,3); else, img=frame; end
if max(img(:))>1, img=img/255; end
img(~isfinite(img))=0;
end
