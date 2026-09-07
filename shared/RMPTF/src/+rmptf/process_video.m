function [frames,fps,roiTrajectory,tracking] = process_video(videoPath,maxFrames,initialRoi,userConfig,previewPath)
%PROCESS_VIDEO 两遍式 RMPTF：先跟踪，再按整数宏观轨迹裁剪固定尺寸帧。
if nargin<2 || isempty(maxFrames), maxFrames=Inf; end
if nargin<4, userConfig=struct(); end
if nargin<5, previewPath=''; end
cfg=rmptf.merge_config(rmptf.default_config(),userConfig);
reader=VideoReader(videoPath); metadataFps=reader.FrameRate;
imageSize0=[reader.Height reader.Width];
measurementRoi=localClamp(initialRoi,reader.Width,reader.Height);
if cfg.roi.dualEnabled
    trackingRoi=localExpand(measurementRoi,cfg.roi.trackingExpansion,imageSize0);
    analysisRoi=localExpand(measurementRoi,1+cfg.roi.analysisPadding,imageSize0);
else
    trackingRoi=measurementRoi; analysisRoi=measurementRoi;
end
if ~isempty(cfg.io.captureFps)
    sourceFps=cfg.io.captureFps; stride=1;
elseif ~isempty(cfg.io.fpsOverride)
    stride=max(1,round(metadataFps/cfg.io.fpsOverride)); sourceFps=metadataFps;
else
    stride=1; sourceFps=metadataFps;
end
fps=sourceFps/stride;
startSeconds=max(0,double(cfg.io.startSeconds));
durationSeconds=double(cfg.io.durationSeconds);
reader.CurrentTime=min(startSeconds,max(0,reader.Duration-1/max(metadataFps,eps)));
if isinf(maxFrames), maxSourceFrames=Inf; else, maxSourceFrames=max(1,round(maxFrames))*stride; end
if isfinite(durationSeconds), maxSourceFrames=min(maxSourceFrames,max(1,floor(durationSeconds*sourceFps))); end

outerBoxes=[]; trackerBackendUsed='hybrid'; trackerBackendError='';
if strcmpi(cfg.tracker.backend,'fdsst_improved')
    try
        % fDSST 接收真正的目标框；trackingRoi 只是搜索上下文，不能作为输出 bbox。
        outerBoxes=rmptf.fdsst_adapter(videoPath,measurementRoi,maxSourceFrames,cfg);
        trackerBackendUsed='fdsst_improved+rmptf_validation';
    catch caughtError
        trackerBackendError=caughtError.message;
        if ~cfg.tracker.allowBackendFallback, rethrow(caughtError); end
        warning('RMPTF:fDSSTFallback','fDSST 粗跟踪不可用，回退到 hybrid：%s',caughtError.message);
    end
end
[sourceTracking,sourceCount,imageSize] = localTrack(reader,measurementRoi,maxSourceFrames,sourceFps,cfg,outerBoxes);
if sourceCount<1, error('RMPTF 未读到可处理视频帧。'); end
selected=1:stride:sourceCount;
if ~isinf(maxFrames), selected=selected(1:min(numel(selected),round(maxFrames))); end
compensation=cfg.compensation;
if strcmpi(compensation.mode,'geometry_follow')
    compensation.geometryDisplacement=sourceTracking.geometryDisplacement;
end
[macroFull,macroDiagnostics]=rmptf.estimate_macro_motion( ...
    sourceTracking.rawDisplacement,sourceTracking.valid,sourceFps,compensation);
[cropFull,cropDisplacementFull,boundaryFull]=rmptf.phase_safe_crop( ...
    analysisRoi,macroFull,imageSize);

% 第二遍重新读取原图并按整数像素裁剪，绝不做 imwarp/imresize 稳像。
reader=VideoReader(videoPath);
reader.CurrentTime=min(startSeconds,max(0,reader.Duration-1/max(metadataFps,eps)));
roiTrajectory=cropFull(selected,:);
frames=zeros(analysisRoi(4),analysisRoi(3),numel(selected),'single');
preview=[];
if (~isempty(previewPath) || cfg.io.writePreview) && ~isempty(previewPath)
    try
        [folder,~,~]=fileparts(previewPath); if ~isempty(folder)&&~isfolder(folder), mkdir(folder); end
        preview=VideoWriter(previewPath,'MPEG-4'); preview.FrameRate=min(cfg.io.previewFps,fps); open(preview);
    catch
        preview=[];
    end
end
cleanup=onCleanup(@()localClose(preview)); %#ok<NASGU>
sourceIndex=0; selectedCursor=1;
while hasFrame(reader) && sourceIndex<sourceCount && selectedCursor<=numel(selected)
    rgb=readFrame(reader); sourceIndex=sourceIndex+1;
    if sourceIndex~=selected(selectedCursor), continue; end
    gray=localGray(rgb); roi=roiTrajectory(selectedCursor,:);
    if strcmpi(cfg.crop.mode,'canonical_warp')
        pose=struct('centerXY',localCenter(analysisRoi)+macroFull(sourceIndex,:), ...
            'scale',sourceTracking.geometryScale(sourceIndex), ...
            'rotationDeg',sourceTracking.geometryRotationDeg(sourceIndex));
        frames(:,:,selectedCursor)=rmptf.canonical_warp_crop(gray,pose,analysisRoi([4 3]),cfg.crop.interpolation);
    else
        frames(:,:,selectedCursor)=single(localCrop(gray,roi));
    end
    if ~isempty(preview)
        rawBox=sourceTracking.bbox(sourceIndex,:);
        annotated=insertShape(rgb,'Rectangle',rawBox,'Color','yellow','LineWidth',2);
        annotated=insertShape(annotated,'Rectangle',roi,'Color','cyan','LineWidth',2);
        label=sprintf('bbox yellow | analysis guard cyan | %s | Q %.2f', ...
            sourceTracking.state{sourceIndex},sourceTracking.quality(sourceIndex));
        annotated=insertText(annotated,[8 8],label,'BoxColor','black','TextColor','white');
        writeVideo(preview,annotated);
    end
    selectedCursor=selectedCursor+1;
end
tracking=localSelectTracking(sourceTracking,selected);
tracking.trackerType=['rmptf_' trackerBackendUsed]; tracking.frontTrackerType='rmptf';
tracking.outerTrackerBackend=trackerBackendUsed; tracking.outerTrackerError=trackerBackendError;
tracking.frontTrackerCallCount=1; tracking.frontTrackerOnly=true;
tracking.dynamicRoiMode=macroDiagnostics.mode;
tracking.rawCoarseDisplacement=tracking.rawDisplacement;
tracking.largeMotionContinuous=macroFull(selected,:);
tracking.kltMicroCandidate=tracking.rawDisplacement-tracking.largeMotionContinuous;
tracking.coarseDisplacement=cropDisplacementFull(selected,:);
tracking.analysisRoiTrajectory=roiTrajectory;
tracking.analysisCropMode=cfg.crop.mode;
tracking.rawRoiTrajectory=tracking.bbox;
tracking.bbox_xywh=tracking.bbox;
tracking.center_xy=tracking.center;
tracking.confidence=tracking.quality;
tracking.lost=~tracking.valid;
tracking.redetect=tracking.redetectionUsed;
tracking.hitBoundary=boundaryFull(selected);
tracking.boundary=tracking.hitBoundary;
tracking.crop_bbox_xywh=roiTrajectory;
tracking.crop=struct('origin_xy',roiTrajectory(:,1:2),'displacement_xy',tracking.coarseDisplacement);
tracking.macro=struct('xy',tracking.largeMotionContinuous,'diagnostics',macroDiagnostics);
tracking.macroTrendDiagnostics=macroDiagnostics;
tracking.expectedCoarseDisplacement=tracking.largeMotionContinuous;
tracking.scaleTrajectory=tracking.bbox(:,3:4);
tracking.scale=tracking.bbox(:,3:4)./double(measurementRoi(3:4));
tracking.measurementRoiInitial=measurementRoi;
tracking.trackingRoiInitial=trackingRoi;
tracking.analysisRoiInitial=analysisRoi;
tracking.measurementRoiOffset=measurementRoi(1:2)-analysisRoi(1:2);
tracking.measurementRoiLocal=[measurementRoi(1:2)-analysisRoi(1:2)+1 measurementRoi(3:4)];
tracking.macroScale=tracking.geometryScale;
tracking.macroRotationDeg=tracking.geometryRotationDeg;
tracking.validPointCount=tracking.kltPointCount;
tracking.fallbackUsed=~tracking.valid;
tracking.templateScore=tracking.anchorNcc;
tracking.templateCorrectionUsed=tracking.redetectionUsed;
tracking.fallbackFrameCount=nnz(tracking.fallbackUsed);
tracking.templateCorrectionFrameCount=nnz(tracking.templateCorrectionUsed);
tracking.previewWritingSeconds=0;
tracking.selectedSourceIndices=selected(:);
tracking.sourceFps=sourceFps; tracking.processingFps=fps;
tracking.validFraction=mean(tracking.valid); tracking.lostFrameCount=nnz(~tracking.valid);
tracking.redetectionFrameCount=nnz(tracking.redetectionUsed);
tracking.boundaryFrameCount=nnz(tracking.hitBoundary);
if cfg.phaseCrossline.enabled
    axisName='x'; if strcmpi(cfg.compensation.trackingAxis,'y'), axisName='y'; end
    tracking.crosslinePhaseMeasurement=rmptf.extract_crossline_vibration( ...
        tracking.crosslineCenter,tracking.coarseDisplacement,tracking.crosslineQuality>0, ...
        fps,axisName,cfg.compensation.targetBandHz);
end
if ~isempty(cfg.io.diagnosticsDirectory)
    rmptf.export_diagnostics(cfg.io.diagnosticsDirectory,tracking,cfg,videoPath);
end
end

function [tracking,count,imageSize]=localTrack(reader,initialRoi,maxFrames,fps,cfg,outerBoxes)
count=0; capacity=localCapacity(maxFrames,reader.Duration,fps);
fields={'bbox','center','outerCenter','rawDisplacement','quality','responsePeak','apce','psr', ...
    'anchorNcc','recentNcc','gradientNcc','edgeCorrelation','blurScore', ...
    'kltInlierRatio','kltPointCount','kltFbError','kltReprojectionError', ...
    'geometryCenter','geometryDisplacement','geometryScale','geometryRotationDeg', ...
    'motionJumpScore','scaleJumpScore','rotationScore','accelerationScore','boundaryScore','valid','modelUpdated', ...
    'redetectionUsed','crosslineCenter','crosslineQuality'};
tracking=struct();
for k=1:numel(fields), tracking.(fields{k})=[]; end
tracking.state=cell(capacity,1); state=[]; imageSize=[];
while hasFrame(reader) && count<maxFrames
    frame=readFrame(reader); gray=localGray(frame); count=count+1;
    if count==1
        imageSize=size(gray); state=localInitialize(gray,initialRoi,cfg);
        result=localInitialResult(state);
    else
        outer=[]; if count<=size(outerBoxes,1), outer=outerBoxes(count,:); end
        [state,result]=localStep(state,gray,cfg,outer);
    end
    tracking.bbox(count,:)=result.bbox; tracking.center(count,:)=result.center;
    tracking.rawDisplacement(count,:)=result.center-state.initialCenter;
    tracking.outerCenter(count,:)=result.outerCenter;
    tracking.quality(count,1)=result.quality; tracking.responsePeak(count,1)=result.responsePeak;
    tracking.apce(count,1)=result.apce;
    tracking.psr(count,1)=result.psr; tracking.anchorNcc(count,1)=result.anchorNcc;
    tracking.recentNcc(count,1)=result.recentNcc;
    tracking.gradientNcc(count,1)=result.gradientNcc;
    tracking.edgeCorrelation(count,1)=result.edgeCorrelation;
    tracking.blurScore(count,1)=result.blurScore;
    tracking.kltInlierRatio(count,1)=result.kltInlierRatio;
    tracking.kltPointCount(count,1)=result.kltPointCount;
    tracking.kltFbError(count,1)=result.kltFbError;
    tracking.kltReprojectionError(count,1)=result.kltReprojectionError;
    tracking.geometryCenter(count,:)=result.geometryCenter;
    tracking.geometryDisplacement(count,:)=result.geometryCenter-state.initialCenter;
    tracking.geometryScale(count,1)=result.geometryScale;
    tracking.geometryRotationDeg(count,1)=result.geometryRotationDeg;
    tracking.motionJumpScore(count,1)=result.motionJumpScore;
    tracking.scaleJumpScore(count,1)=result.scaleJumpScore;
    tracking.rotationScore(count,1)=result.rotationScore;
    tracking.accelerationScore(count,1)=result.accelerationScore;
    tracking.boundaryScore(count,1)=result.boundaryScore;
    tracking.valid(count,1)=result.valid; tracking.modelUpdated(count,1)=result.modelUpdated;
    tracking.redetectionUsed(count,1)=result.redetectionUsed;
    tracking.crosslineCenter(count,:)=result.crosslineCenter;
    tracking.crosslineQuality(count,1)=result.crosslineQuality;
    tracking.state{count,1}=result.state;
end
names=fieldnames(tracking);
for k=1:numel(names)
    value=tracking.(names{k});
    if iscell(value), tracking.(names{k})=value(1:count,:);
    elseif ~isempty(value), tracking.(names{k})=value(1:count,:); end
end
tracking.geometryScaleStep=tracking.geometryScale;
tracking.geometryRotationStepDeg=tracking.geometryRotationDeg;
scaleStep=tracking.geometryScaleStep; scaleStep(~isfinite(scaleStep)|scaleStep<=0)=1;
rotationStep=tracking.geometryRotationStepDeg; rotationStep(~isfinite(rotationStep))=0;
tracking.geometryScale=cumprod(scaleStep);
tracking.geometryRotationDeg=cumsum(rotationStep);
end

function capacity=localCapacity(maxFrames,duration,fps)
if isinf(maxFrames), capacity=max(1,ceil(duration*fps)); else, capacity=max(1,round(maxFrames)); end
end

function state=localInitialize(gray,roi,cfg)
roi=localClamp(roi,size(gray,2),size(gray,1));
state.initialBbox=roi; state.bbox=roi; state.initialCenter=localCenter(roi);
state.center=state.initialCenter; state.velocity=[0 0]; state.frameIndex=1; state.missCount=0;
state.kltBbox=state.bbox;
state.kltBbox=localClamp(state.kltBbox,size(gray,2),size(gray,1));
state.anchorTemplate=localCrop(gray,roi); state.recentTemplate=state.anchorTemplate;
state.bestTemplate=state.anchorTemplate; state.bestQuality=1; state.previousGray=gray;
state.anchorBlur=localSharpness(state.anchorTemplate); state.recoveryCount=0;
state.scaleTemplates={imresize(state.anchorTemplate,0.85),state.anchorTemplate,imresize(state.anchorTemplate,1.15)};
state.pointTracker=[]; state.points=[]; state=localResetKlt(state,gray,cfg);
end

function result=localInitialResult(state)
result=struct('bbox',state.bbox,'center',state.center,'quality',1,'apce',Inf,'psr',Inf, ...
    'outerCenter',state.center,'responsePeak',1,'anchorNcc',1,'recentNcc',1, ...
    'gradientNcc',1,'edgeCorrelation',1,'blurScore',1, ...
    'kltInlierRatio',1,'kltPointCount',size(state.points,1),'kltFbError',0, ...
    'kltReprojectionError',0,'geometryCenter',state.center,'geometryScale',1, ...
    'geometryRotationDeg',0,'motionJumpScore',1,'scaleJumpScore',1,'rotationScore',1, ...
    'accelerationScore',1,'boundaryScore',1, ...
    'valid',true,'modelUpdated',false,'redetectionUsed',false, ...
    'crosslineCenter',[NaN NaN],'crosslineQuality',0,'state','TRACKING_OK');
end

function [state,result]=localStep(state,gray,cfg,outerBox)
state.frameIndex=state.frameIndex+1; predictedCenter=state.center+state.velocity;
predicted=localBboxFromCenter(predictedCenter,state.bbox(3:4));
if ~isempty(outerBox) && numel(outerBox)==4 && all(isfinite(outerBox))
    predicted=localClamp(outerBox,size(gray,2),size(gray,1));
end
if cfg.tracker.useTemplateLocalization
    [recentCandidate,recentMetrics]=localTemplateCandidate(gray,state.recentTemplate,predicted, ...
        cfg.tracker.searchRadiusPx,cfg.tracker.scaleFactors);
    if cfg.tracker.useTemplateBank
        [anchorCandidate,anchorMetrics]=localTemplateCandidate(gray,state.anchorTemplate,predicted, ...
            cfg.tracker.searchRadiusPx,cfg.tracker.scaleFactors);
        [bestCandidate,bestMetrics]=localTemplateCandidate(gray,state.bestTemplate,predicted, ...
            cfg.tracker.searchRadiusPx,cfg.tracker.scaleFactors);
        [~,templateChoice]=max([anchorMetrics.ncc,recentMetrics.ncc,bestMetrics.ncc]);
    else
        % 单模板快速路径：避免每帧额外做 anchor/best 两次 NCC 搜索。
        % recent 模板仍按 conservativeUpdate 慢速更新，丢失时的全局重检测
        % 仍会使用 anchor/best 模板，因此不会改变恢复状态机的安全边界。
        anchorCandidate=recentCandidate; anchorMetrics=recentMetrics;
        bestCandidate=recentCandidate; bestMetrics=recentMetrics;
        templateChoice=2;
    end
    if templateChoice==2
        candidate=recentCandidate; metrics=recentMetrics;
    elseif templateChoice==3
        candidate=bestCandidate; metrics=bestMetrics;
    else
        candidate=anchorCandidate; metrics=anchorMetrics;
    end
else
    candidate=predicted;
    anchorMetrics=localEmptyMetrics(); recentMetrics=localEmptyMetrics();
    metrics=localEmptyMetrics();
end
outerCenter=localCenter(candidate);

[kltCandidate,kltGeometry]=localKltCandidate(state,gray,cfg);
kltRatio=kltGeometry.inlierRatio; kltCount=kltGeometry.pointCount;
kltOk=kltGeometry.valid && kltGeometry.reprojectionError<=cfg.klt.ransacMaxDistance && ...
    (~isfinite(kltGeometry.fbError) || kltGeometry.fbError<=cfg.klt.maximumBidirectionalError);
geometryCenter=kltGeometry.center; geometryScale=kltGeometry.scale;
geometryRotation=kltGeometry.rotationDeg;
templateCenter=localCenter(candidate); kltCenter=localCenter(kltCandidate);
geometryAgreement=norm(templateCenter-kltCenter)<=max(2,0.03*min(candidate(3:4)));
if kltOk && geometryAgreement
    blend=min(0.25,max(0.10,0.30*kltRatio));
    fusedCenter=(1-blend)*templateCenter+blend*kltCenter;
    candidate=localBboxFromCenter(fusedCenter,(1-blend)*candidate(3:4)+blend*kltCandidate(3:4));
end

phaseQuality=0; phaseCenter=[NaN NaN];
if cfg.phaseCrossline.enabled
    margin=cfg.phaseCrossline.searchMarginPx;
    search=[candidate(1)-margin,candidate(2)-margin,candidate(3)+2*margin,candidate(4)+2*margin];
    phaseResult=rmptf.detect_crossline_center(gray,search,cfg.phaseCrossline);
    phaseQuality=phaseResult.quality; phaseCenter=phaseResult.centerXY;
    if phaseResult.valid && phaseQuality>=cfg.phaseCrossline.minimumQuality && ...
            norm(phaseCenter-localCenter(candidate))<=cfg.phaseCrossline.maximumCorrectionPx
        candidate=localBboxFromCenter(phaseCenter,candidate(3:4));
    end
end

phaseCorrQuality=0;
if cfg.tracker.usePhaseCorrelation
    context=localContextBbox(state.bbox,cfg.tracker.searchRadiusPx,size(gray));
    previousPatch=localCrop(state.previousGray,context); currentPatch=localCrop(gray,context);
    [shift,phaseCorrQuality]=rmptf.phase_correlation_shift(previousPatch,currentPatch,cfg.tracker.maxStepPixels);
    phaseCenterCandidate=state.center+shift;
    if phaseCorrQuality>0.35 && norm(phaseCenterCandidate-localCenter(candidate))<cfg.tracker.maxStepPixels
        candidate=localBboxFromCenter(0.85*localCenter(candidate)+0.15*phaseCenterCandidate,candidate(3:4));
    end
end

step=norm(localCenter(candidate)-predictedCenter);
motionScore=exp(-step/max(cfg.tracker.maxStepPixels,eps));
acceleration=norm((localCenter(candidate)-state.center)-state.velocity);
accelerationScore=exp(-acceleration/max(0.5*cfg.tracker.maxStepPixels,eps));
scaleJumpScore=exp(-4*abs(log(max(sqrt(prod(candidate(3:4))/prod(state.bbox(3:4))),eps))));
rotationScore=exp(-abs(geometryRotation)/12);
anchorScore=localUnitNcc(anchorMetrics.ncc,cfg.tracker.anchorMinimumNcc);
recentScore=localUnitNcc(recentMetrics.ncc,cfg.tracker.minimumNcc);
responseScore=min(1,max(0,(metrics.psr-2)/10)); apceScore=min(1,max(0,metrics.apce/30));
kltScore=double(kltOk&&geometryAgreement)*min(1,kltRatio/0.7);
appearanceCrop=localResizeLike(localCrop(gray,candidate),state.anchorTemplate);
gradientNcc=localGradientNcc(state.anchorTemplate,appearanceCrop);
edgeCorrelation=localEdgeCorrelation(state.anchorTemplate,appearanceCrop);
blurScore=min(1,localSharpness(appearanceCrop)/max(state.anchorBlur,eps));
appearanceScore=max(0,0.55*localUnitNcc(gradientNcc,0)+0.45*localUnitNcc(edgeCorrelation,0));
quality=0.17*anchorScore+0.12*recentScore+0.11*responseScore+0.07*apceScore+ ...
    0.12*kltScore+0.09*motionScore+0.07*accelerationScore+0.07*appearanceScore+ ...
    0.04*scaleJumpScore+0.04*rotationScore+ ...
    cfg.tracker.phaseCorrelationWeight*phaseCorrQuality;
if cfg.phaseCrossline.enabled
    if phaseQuality>=cfg.phaseCrossline.minimumQuality
        quality=min(1,0.78*quality+0.22*phaseQuality);
    else
        % 标记路线中十字相位特征缺失通常意味着遮挡/出窗，必须触发冻结而非更新模板。
        quality=0.52*quality;
    end
end
proposedCandidate=candidate;
candidate=localClamp(candidate,size(gray,2),size(gray,1));
boundary=any(candidate(1:2)<=1) || candidate(1)+candidate(3)-1>=size(gray,2) || ...
    candidate(2)+candidate(4)-1>=size(gray,1);
clampPenalty=norm(double(candidate(1:2))-double(proposedCandidate(1:2)))/max(norm(candidate(3:4)),1);
edgeDistance=min([candidate(1)-1,candidate(2)-1,size(gray,2)-(candidate(1)+candidate(3)-1), ...
    size(gray,1)-(candidate(2)+candidate(4)-1)]);
boundaryScore=max(0,min(1,edgeDistance/max(0.25*min(candidate(3:4)),1)))*(1-min(1,clampPenalty));
if boundary, quality=0.8*quality; end

redetected=false; modelUpdated=false;
if quality>=cfg.tracker.goodQuality && anchorMetrics.ncc>=cfg.tracker.anchorMinimumNcc
    mode='TRACKING_OK'; accepted=candidate; valid=true; state.missCount=0;
elseif quality>=cfg.tracker.weakQuality
    mode='WEAK'; accepted=candidate; valid=true; state.missCount=state.missCount+1;
else
    state.missCount=state.missCount+1; valid=false; accepted=localBboxFromCenter(predictedCenter,state.bbox(3:4));
    if state.missCount<=cfg.tracker.predictFrames
        mode='PREDICT';
    else
        mode='REDETECT';
        if ~cfg.tracker.enableRedetection
            mode='LOST';
        else
        radius=cfg.tracker.redetectRadiusPx;
        if state.missCount>=cfg.tracker.globalRedetectAfter, radius=Inf; end
        [anchorBox,anchorRedetect]=localTemplateCandidate(gray,state.anchorTemplate,state.initialBbox,radius,cfg.tracker.scaleFactors);
        [bestBox,bestRedetect]=localTemplateCandidate(gray,state.bestTemplate,state.initialBbox,radius,cfg.tracker.scaleFactors);
        if bestRedetect.ncc>anchorRedetect.ncc, rebox=bestBox; remetrics=bestRedetect;
        else, rebox=anchorBox; remetrics=anchorRedetect; end
        if cfg.tracker.useTemplateBank
            for scaleIndex=1:numel(state.scaleTemplates)
                [scaleBox,scaleMetrics]=localTemplateCandidate(gray,state.scaleTemplates{scaleIndex}, ...
                    state.initialBbox,radius,1);
                if scaleMetrics.ncc>remetrics.ncc, rebox=scaleBox; remetrics=scaleMetrics; end
            end
        end
        if remetrics.ncc>=cfg.tracker.minimumNcc && remetrics.psr>=3
            accepted=rebox; valid=true; redetected=true; mode='RECOVERING';
            quality=max(quality,0.65*localUnitNcc(remetrics.ncc,cfg.tracker.minimumNcc)+0.35*min(1,remetrics.psr/12));
            anchorMetrics=remetrics; metrics=remetrics; state.missCount=0; state.recoveryCount=1;
        elseif state.missCount>=cfg.tracker.globalRedetectAfter
            mode='LOST';
        end
        end
    end
end
if valid && state.recoveryCount>0 && ~redetected
    state.recoveryCount=state.recoveryCount+1;
    if state.recoveryCount<cfg.tracker.recoveryConfirmFrames
        mode='RECOVERING';
    else
        state.recoveryCount=0;
    end
end
accepted=localClamp(accepted,size(gray,2),size(gray,1)); newCenter=localCenter(accepted);
measuredVelocity=newCenter-state.center;
if valid
    state.velocity=cfg.tracker.velocitySmoothing*state.velocity+(1-cfg.tracker.velocitySmoothing)*measuredVelocity;
else
    state.velocity=0.75*state.velocity;
end
state.center=newCenter; state.bbox=accepted;
state.kltBbox=localBboxFromCenter(newCenter,accepted(3:4));
state.kltBbox=localClamp(state.kltBbox,size(gray,2),size(gray,1));
updateGate=valid && ~boundary && blurScore>=cfg.tracker.maximumBlurDrop && ...
    kltRatio>=0.35 && anchorMetrics.ncc>=cfg.tracker.anchorMinimumNcc && state.recoveryCount==0;
if ~cfg.tracker.conservativeUpdate, updateGate=valid; end
if updateGate && mod(state.frameIndex,cfg.tracker.updateInterval)==0
    newTemplate=localResizeLike(localCrop(gray,accepted),state.recentTemplate);
    if quality>=cfg.tracker.updateQuality
        learningRate=1;
    elseif quality>=cfg.tracker.goodQuality
        learningRate=cfg.tracker.slowLearningRate;
    else
        learningRate=0;
    end
    if ~cfg.tracker.conservativeUpdate, learningRate=1; end
    if learningRate>0
        state.recentTemplate=(1-learningRate)*state.recentTemplate+learningRate*newTemplate;
        modelUpdated=true;
        if quality>state.bestQuality
            state.bestTemplate=state.recentTemplate; state.bestQuality=quality;
        end
    end
end
state.previousGray=gray; state=localResetKlt(state,gray,cfg);
result=struct('bbox',accepted,'center',newCenter,'quality',min(1,max(0,quality)), ...
    'outerCenter',outerCenter,'responsePeak',metrics.peak,'apce',metrics.apce,'psr',metrics.psr, ...
    'anchorNcc',anchorMetrics.ncc,'recentNcc',recentMetrics.ncc, ...
    'gradientNcc',gradientNcc,'edgeCorrelation',edgeCorrelation,'blurScore',blurScore, ...
    'kltInlierRatio',kltRatio,'kltPointCount',kltCount,'kltFbError',kltGeometry.fbError, ...
    'kltReprojectionError',kltGeometry.reprojectionError,'geometryCenter',geometryCenter, ...
    'geometryScale',geometryScale,'geometryRotationDeg',geometryRotation, ...
    'motionJumpScore',motionScore,'scaleJumpScore',scaleJumpScore,'rotationScore',rotationScore, ...
    'accelerationScore',accelerationScore,'boundaryScore',boundaryScore, ...
    'valid',valid,'modelUpdated',modelUpdated, ...
    'redetectionUsed',redetected,'crosslineCenter',phaseCenter, ...
    'crosslineQuality',phaseQuality,'state',mode);
end

function [candidate,metrics]=localTemplateCandidate(frame,template,predicted,radius,scaleFactors)
if isinf(radius), search=[1 1 size(frame,2) size(frame,1)];
else
    search=[predicted(1)-radius,predicted(2)-radius,predicted(3)+2*radius,predicted(4)+2*radius];
    search=localClamp(search,size(frame,2),size(frame,1));
end

searchImage=localCrop(frame,search); best=-Inf; candidate=predicted; bestSurface=[];
for scale=scaleFactors(:)'
    scaled=imresize(template,scale,'bilinear');
    if any(size(scaled)>size(searchImage)) || min(size(scaled))<4, continue; end
    if std(scaled(:))<1e-6 || std(searchImage(:))<1e-6, continue; end
    surface=normxcorr2(scaled,searchImage);
    [peak,index]=max(surface(:));
    if peak>best
        [py,px]=ind2sub(size(surface),index);
        topLeft=[search(1)+px-size(scaled,2),search(2)+py-size(scaled,1)];
        candidate=[topLeft size(scaled,2) size(scaled,1)]; best=peak; bestSurface=surface;
    end
end
if isempty(bestSurface)
    metrics=struct('ncc',-1,'peak',-1,'psr',0,'apce',0); return;
end
[peak,index]=max(bestSurface(:)); minimum=min(bestSurface(:));
apce=(peak-minimum)^2/max(mean((bestSurface(:)-minimum).^2),eps);
[py,px]=ind2sub(size(bestSurface),index); guard=bestSurface;
guard(max(1,py-2):min(end,py+2),max(1,px-2):min(end,px+2))=NaN;
side=guard(isfinite(guard)); psr=(peak-mean(side))/max(std(side),eps);
metrics=struct('ncc',best,'peak',peak,'psr',psr,'apce',apce);
end

function metrics=localEmptyMetrics()
metrics=struct('ncc',0,'peak',0,'psr',0,'apce',0);
end

function [candidate,geometry]=localKltCandidate(state,gray,cfg)
candidate=state.bbox;
geometry=struct('valid',false,'center',state.center,'scale',1,'rotationDeg',0, ...
    'inlierRatio',0,'pointCount',0,'fbError',NaN,'reprojectionError',NaN);
if isempty(state.pointTracker) || isempty(state.points), return; end
try
    [newPoints,validity]=state.pointTracker(gray); old=state.points(validity,:); new=newPoints(validity,:);
    geometry.pointCount=size(new,1);
    if geometry.pointCount<cfg.klt.minimumPoints, return; end
    try
        reverseTracker=vision.PointTracker('MaxBidirectionalError',1e6,'NumPyramidLevels',4);
        initialize(reverseTracker,new,gray); [backPoints,backValid]=reverseTracker(state.previousGray); release(reverseTracker);
        if any(backValid)
            fb=hypot(backPoints(backValid,1)-old(backValid,1),backPoints(backValid,2)-old(backValid,2));
            geometry.fbError=median(fb,'omitnan');
        end
    catch
        geometry.fbError=NaN;
    end
    [transform,inlierOld,inlierNew]=estimateGeometricTransform(old,new,'similarity', ...
        'MaxDistance',cfg.klt.ransacMaxDistance,'Confidence',99,'MaxNumTrials',300);
    geometry.inlierRatio=size(inlierNew,1)/geometry.pointCount;
    if size(inlierNew,1)<cfg.klt.minimumPoints, return; end
    corners=[state.bbox(1:2);state.bbox(1)+state.bbox(3),state.bbox(2); ...
        state.bbox(1)+state.bbox(3),state.bbox(2)+state.bbox(4);state.bbox(1),state.bbox(2)+state.bbox(4)];
    moved=transformPointsForward(transform,corners);
    candidate=[min(moved(:,1)),min(moved(:,2)),range(moved(:,1)),range(moved(:,2))];
    predicted=transformPointsForward(transform,inlierOld);
    geometry.reprojectionError=median(hypot(predicted(:,1)-inlierNew(:,1),predicted(:,2)-inlierNew(:,2)));
    matrix=transform.T;
    geometry.scale=sqrt(matrix(1,1)^2+matrix(1,2)^2);
    geometry.rotationDeg=atan2d(matrix(1,2),matrix(1,1));
    geometry.center=localCenter(candidate); geometry.valid=true;
catch
    geometry.valid=false;
end
end

function state=localResetKlt(state,gray,cfg)
if ~isempty(state.pointTracker)
    try
        release(state.pointTracker);
    catch
    end
end
state.pointTracker=[]; state.points=[];
if ~cfg.klt.enabled || exist('vision.PointTracker','class')~=8 || exist('detectMinEigenFeatures','file')~=2, return; end
try
    points=detectMinEigenFeatures(gray,'ROI',round(state.kltBbox),'MinQuality',cfg.klt.minimumQuality);
    points=points.selectStrongest(min(cfg.klt.maximumPoints,points.Count)); state.points=points.Location;
    if size(state.points,1)>=cfg.klt.minimumPoints
        state.pointTracker=vision.PointTracker('MaxBidirectionalError',cfg.klt.maximumBidirectionalError, ...
            'NumPyramidLevels',4); initialize(state.pointTracker,state.points,gray);
    else
        state.points=[];
    end
catch
    state.pointTracker=[]; state.points=[];
end
end

function selected=localSelectTracking(source,indices)
selected=struct(); names=fieldnames(source);
for k=1:numel(names), value=source.(names{k}); selected.(names{k})=value(indices,:); end
end

function value=localUnitNcc(value,minimum)
value=min(1,max(0,(value-minimum)/max(1-minimum,eps)));
end

function bbox=localContextBbox(bbox,margin,imageSize)
bbox=[bbox(1)-margin,bbox(2)-margin,bbox(3)+2*margin,bbox(4)+2*margin];
bbox=localClamp(bbox,imageSize(2),imageSize(1));
end

function bbox=localExpand(bbox,factor,imageSize)
factor=max(1,double(factor)); center=localCenter(bbox);
bbox=localBboxFromCenter(center,max([4 4],round(double(bbox(3:4))*factor)));
bbox=localClamp(bbox,imageSize(2),imageSize(1));
end

function resized=localResizeLike(image,reference)
if isequal(size(image),size(reference)), resized=image;
else, resized=imresize(image,size(reference),'bilinear'); end
resized=single(resized);
end

function value=localGradientNcc(a,b)
[ax,ay]=gradient(single(a)); [bx,by]=gradient(single(b));
value=localNcc(hypot(ax,ay),hypot(bx,by));
end

function value=localEdgeCorrelation(a,b)
[ax,ay]=gradient(single(a)); [bx,by]=gradient(single(b));
ea=hypot(ax,ay); eb=hypot(bx,by);
ea=ea>prctile(ea(:),70); eb=eb>prctile(eb(:),70);
value=localNcc(single(ea),single(eb));
end

function value=localNcc(a,b)
a=double(a(:)); b=double(b(:)); a=a-mean(a); b=b-mean(b);
value=sum(a.*b)/max(sqrt(sum(a.^2)*sum(b.^2)),eps);
if ~isfinite(value), value=0; end
end

function value=localSharpness(image)
lap=del2(single(image)); value=mean(lap(:).^2);
end

function center=localCenter(bbox), center=bbox(1:2)+0.5*bbox(3:4); end
function bbox=localBboxFromCenter(center,sizeXY), bbox=[center-0.5*sizeXY,sizeXY]; end
function bbox=localClamp(bbox,w,h)
bbox=round(double(bbox)); bbox(3)=min(max(4,bbox(3)),w); bbox(4)=min(max(4,bbox(4)),h);
bbox(1)=min(max(1,bbox(1)),max(1,w-bbox(3)+1)); bbox(2)=min(max(1,bbox(2)),max(1,h-bbox(4)+1));
end
function crop=localCrop(frame,bbox)
bbox=localClamp(bbox,size(frame,2),size(frame,1));
crop=frame(bbox(2):bbox(2)+bbox(4)-1,bbox(1):bbox(1)+bbox(3)-1);
end
function gray=localGray(frame)
if ndims(frame)==3, frame=rgb2gray(frame); end
gray=im2single(frame);
end
function localClose(writer)
if ~isempty(writer)
    try
        close(writer);
    catch
    end
end
end
