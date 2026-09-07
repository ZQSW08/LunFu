function [frames,videoInfo,roiTrajectory,tracking] = apcv_read_dynamic_roi_video_rmptf( ...
    videoPath,initialRoi,maxFrames,fpsOverride,options,timeWindow)
%APCV_READ_DYNAMIC_ROI_VIDEO_RMPTF 可靠长程整数裁剪前端；AP-CV 核心保持不变。
reader=VideoReader(videoPath); videoFps=reader.FrameRate;
managerRoot=fileparts(fileparts(fileparts(mfilename('fullpath'))));
sharedRoot=fullfile(managerRoot,'shared','RMPTF','src');
if ~isfolder(sharedRoot), error('找不到 RMPTF 公共模块：%s',sharedRoot); end
addpath(sharedRoot);

cfg=rmptf.default_config();
cfg.compensation.mode=localField(options,'mode','integer_macro');
cfg.compensation.cutoffHz=localField(options,'largeMotionCutoffHz',1);
cfg.compensation.windowSeconds=localField(options,'macroTrendWindowSeconds',0.5);
cfg.compensation.trackingAxis=localField(options,'trackingAxis','xy');
cfg.compensation.targetBandHz=localField(options,'targetBandHz',[]);
cfg.tracker.maxStepPixels=localField(options,'maximumStepPixels',120);
cfg.tracker.searchRadiusPx=max(24,round(0.75*cfg.tracker.maxStepPixels));
cfg.tracker.redetectRadiusPx=max(100,2*cfg.tracker.searchRadiusPx);
cfg.klt.maximumPoints=localField(options,'maximumPoints',160);
cfg.klt.minimumPoints=localField(options,'minimumPoints',6);
cfg.klt.minimumQuality=localField(options,'minimumQuality',0.005);
cfg.klt.maximumBidirectionalError=localField(options,'maximumBidirectionalError',2);
cfg.io.diagnosticsDirectory=localField(options,'diagnosticsDirectory','');
if contains(lower(char(options.trackerType)),'fdsst')
    cfg.tracker.backend='fdsst_improved';
    cfg.tracker.fdsstRoot=localField(options,'fdsstImprovedRoot',localField(options,'fdsstRoot',''));
end
cfg.phaseCrossline.enabled=logical(localField(options,'phaseCrosslineEnabled',false)) || ...
    contains(lower(char(options.trackerType)),'crossline');

startSeconds=localField(timeWindow,'startSeconds',0);
durationSeconds=localField(timeWindow,'durationSeconds',Inf);
captureFps=localField(timeWindow,'captureFps',[]);
if ~isempty(captureFps)
    % AP-CV 将 captureFps 解释为真实帧序列时基；文件 metadata 仅决定 VideoReader seek。
    cfg.io.captureFps=captureFps;
    cfg.io.startSeconds=startSeconds*captureFps/videoFps;
else
    cfg.io.fpsOverride=fpsOverride;
    cfg.io.startSeconds=startSeconds;
end
cfg.io.durationSeconds=durationSeconds;
[frames,processingFps,roiTrajectory,tracking]=rmptf.process_video( ...
    videoPath,maxFrames,initialRoi,cfg,'');

n=size(frames,3);
if ~isempty(captureFps)
    startIndex=floor(startSeconds*captureFps)+1;
    frameIndices=startIndex-1+tracking.selectedSourceIndices;
    captureFrameIndices=frameIndices;
    time=(captureFrameIndices-1)/captureFps;
else
    startIndex=floor(startSeconds*videoFps)+1;
    frameIndices=startIndex-1+tracking.selectedSourceIndices;
    captureFps=videoFps;
    captureFrameIndices=frameIndices;
    time=(frameIndices-1)/videoFps;
end
videoInfo=struct('path',videoPath,'videoFps',videoFps,'processingFps',processingFps, ...
    'frameCount',n,'requestedMaxFrames',maxFrames,'frameIndices',frameIndices(:), ...
    'time',time(:),'originalWidth',reader.Width,'originalHeight',reader.Height, ...
    'roi',initialRoi,'durationSeconds',time(end)-time(1), ...
    'windowStartSeconds',startSeconds,'windowDurationSeconds',durationSeconds, ...
    'captureFps',captureFps,'captureFrameIndices',captureFrameIndices(:), ...
    'captureTime',(captureFrameIndices(:)-1)/captureFps);
tracking.analysisCropMode='integer_long_range_fixed_size';
end

function value=localField(source,name,defaultValue)
if isstruct(source)&&isfield(source,name)&&~isempty(source.(name)), value=source.(name); else, value=defaultValue; end
end
