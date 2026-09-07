function [frames, videoInfo, roiTrajectory, tracking] = apcv_read_dynamic_roi_video_fdsst( ...
    videoPath, initialRoi, maxFrames, fpsOverride, options, timeWindow)
%APCV_READ_DYNAMIC_ROI_VIDEO_FDSST fDSST 粗跟踪 + 振动保持型动态裁剪。
%
% fDSST 输出带符号的 [x y width height] 目标框（含当前尺度）。黄色框只用于
% 原始画面可视化；测量窗口默认只跟随其低频中心趋势，并保持首帧尺寸，避免
% fDSST 把微振动一起跟踪掉，也避免逐帧缩放引入相位偏差。

if nargin < 3 || isempty(maxFrames), maxFrames = Inf; end
if nargin < 4, fpsOverride = []; end
if nargin < 5 || isempty(options), options = struct(); end
if nargin < 6 || isempty(timeWindow), timeWindow = struct(); end
reader = VideoReader(videoPath);
videoFps = reader.FrameRate;
captureFps = getWindowValue(timeWindow,'captureFps',videoFps);
captureFpsProvided = isfield(timeWindow,'captureFps') && ~isempty(timeWindow.captureFps);
if captureFpsProvided
    stride=1; processingFps=captureFps;
else
    [stride, processingFps] = localSampling(videoFps, fpsOverride);
end
firstRgb = readFrame(reader);
firstGray = localGray(firstRgb);
[imageHeight,imageWidth] = size(firstGray);
initialRoi = localClampRoi(double(initialRoi),imageWidth,imageHeight);
startSeconds = getWindowValue(timeWindow,'startSeconds',0);
durationSeconds = getWindowValue(timeWindow,'durationSeconds',Inf);
if ~isscalar(startSeconds)||~isfinite(startSeconds)||startSeconds<0
    error('timeWindow.startSeconds 必须是非负有限标量。');
end
if ~(isscalar(durationSeconds)&&((isfinite(durationSeconds)&&durationSeconds>0)||isinf(durationSeconds)))
    error('timeWindow.durationSeconds 必须为正数或 Inf。');
end
if ~isscalar(captureFps)||~isfinite(captureFps)||captureFps<=0
    error('timeWindow.captureFps 必须是正的有限采集帧率。');
end
startCaptureFrame = floor(startSeconds*captureFps)+1;
if captureFpsProvided
    startSourceIndex=startCaptureFrame;
else
    startSourceIndex=round((startCaptureFrame-1)*videoFps/captureFps)+1;
end
maxReadable = floor(reader.Duration*videoFps)+2;
if isfinite(durationSeconds)
    endCaptureFrame = floor((startSeconds+durationSeconds)*captureFps)+1;
    if captureFpsProvided
        endSourceIndex=min(maxReadable,endCaptureFrame);
    else
        endSourceIndex=min(maxReadable,round((endCaptureFrame-1)*videoFps/captureFps)+1);
    end
else
    endSourceIndex = maxReadable;
end
if startSourceIndex>endSourceIndex, error('timeWindow 起始时间超出视频时长。'); end
maxSourceFrames = endSourceIndex;

fdsstRoot = char(options.fdsstRoot);
if ~exist(fdsstRoot,'dir') || exist(fullfile(fdsstRoot,'DSST_Function.m'),'file')~=2
    error('找不到 fDSST 代码目录：%s。请检查 dynamicROI.fdsstRoot。',fdsstRoot);
end
addpath(fdsstRoot);
if exist('mexResize','file')~=3 && exist('mexResize','file')~=2
    error(['fDSST 依赖 mexResize。当前 MATLAB/平台未加载可用 MEX，' ...
        '请编译 fDSST MEX 或将 trackerType 改为 klt_smooth。']);
end

% fDSST 使用 VideoReader 的逐帧索引接口；maxSourceFrames 防止无界读取。
trackReader = VideoReader(videoPath);
rawRoi = DSST_Function(initialRoi,trackReader,maxSourceFrames);
rawRoi = double(rawRoi);
if isempty(rawRoi) || size(rawRoi,2)~=4
    error('fDSST 没有返回 N×4 目标框。');
end
sourceCount = min(size(rawRoi,1),maxSourceFrames);
rawRoi = rawRoi(1:sourceCount,:);
rawRoi(1,:) = initialRoi;
for k = 1:sourceCount
    rawRoi(k,:) = localClampRoi(rawRoi(k,:),imageWidth,imageHeight);
end

rawCenter = rawRoi(:,1:2)+0.5*rawRoi(:,3:4);
rawDisplacement = rawCenter-rawCenter(1,:);
largeMotion = localLowpass(rawDisplacement,videoFps,options.largeMotionCutoffHz);
largeMotion = largeMotion-largeMotion(1,:);
axisToken = lower(char(options.trackingAxis));
if ~any(strcmp(axisToken,{'x','y','xy','both'}))
    error('dynamicROI.trackingAxis 必须为 x、y 或 xy。');
end
if strcmp(axisToken,'x'), largeMotion(:,2)=0;
elseif strcmp(axisToken,'y'), largeMotion(:,1)=0; end
microCandidate = rawDisplacement-largeMotion;

selectedIndices = (startSourceIndex:stride:sourceCount).';
if isfinite(maxFrames), selectedIndices=selectedIndices(1:min(numel(selectedIndices),floor(maxFrames))); end
if numel(selectedIndices)<3, error('动态 ROI 抽帧后可处理帧数不足 3 帧。'); end
frameCount = numel(selectedIndices);

% 低频趋势中心是最终分析窗口；黄色 fDSST 框只作为可视化和尺度诊断。
analysisTrajectory = repmat(initialRoi,frameCount,1);
hitBoundary = false(frameCount,1);
for k = 1:frameCount
    center = initialRoi(1:2)+0.5*initialRoi(3:4)+largeMotion(selectedIndices(k),:);
    [analysisTrajectory(k,:),hitBoundary(k)] = localCenteredRoi( ...
        center,initialRoi(3:4),imageWidth,imageHeight);
end

frames=zeros(initialRoi(4),initialRoi(3),frameCount,'single');
secondReader=VideoReader(videoPath); sourceIndex=0; cursor=1;
while hasFrame(secondReader) && cursor<=frameCount
    sourceIndex=sourceIndex+1;
    rgb=readFrame(secondReader);
    if sourceIndex~=selectedIndices(cursor), continue; end
    gray=localGray(rgb);
    frames(:,:,cursor)=single(localFixedCrop(gray,analysisTrajectory(cursor,:)));
    cursor=cursor+1;
end
if cursor<=frameCount, error('第二遍动态裁剪提前结束，只读取到 %d/%d 帧。',cursor-1,frameCount); end

tracking=struct();
tracking.trackerType='fdsst';
tracking.analysisCropMode='low_frequency_center_fixed_size';
tracking.validPointCount=nan(frameCount,1);
tracking.quality=ones(frameCount,1); % 原版 fDSST 接口未导出 response confidence。
tracking.stepDisplacement=[zeros(1,2);diff(rawCenter(selectedIndices,:),1,1)];
tracking.fallbackUsed=false(frameCount,1);
tracking.hitBoundary=hitBoundary;
tracking.rawCoarseDisplacement=rawDisplacement(selectedIndices,:);
tracking.largeMotionContinuous=largeMotion(selectedIndices,:);
tracking.kltMicroCandidate=microCandidate(selectedIndices,:);
tracking.coarseDisplacement=analysisTrajectory(:,1:2)-analysisTrajectory(1,1:2);
tracking.analysisRoiTrajectory=analysisTrajectory;
tracking.rawRoiTrajectory=rawRoi(selectedIndices,:);
tracking.scaleTrajectory=rawRoi(selectedIndices,3:4);
tracking.selectedSourceIndices=selectedIndices;
tracking.fallbackFrameCount=0;
tracking.boundaryFrameCount=nnz(hitBoundary);
tracking.largeMotionCutoffHz=options.largeMotionCutoffHz;
tracking.trackingAxis=char(options.trackingAxis);
tracking.backendQualityAvailable=false;

roiTrajectory=analysisTrajectory;
videoInfo.path=videoPath;
videoInfo.videoFps=videoFps;
videoInfo.processingFps=processingFps;
videoInfo.frameCount=frameCount;
videoInfo.requestedMaxFrames=maxFrames;
videoInfo.frameIndices=selectedIndices;
videoInfo.time=(selectedIndices-1)/videoFps;
videoInfo.originalWidth=imageWidth;
videoInfo.originalHeight=imageHeight;
videoInfo.roi=initialRoi;
videoInfo.durationSeconds=videoInfo.time(end)-videoInfo.time(1);
videoInfo.windowStartSeconds=startSeconds;
videoInfo.windowDurationSeconds=durationSeconds;
videoInfo.captureFps=captureFps;
if captureFpsProvided
    videoInfo.captureFrameIndices=selectedIndices;
else
    videoInfo.captureFrameIndices=round((selectedIndices-1)*captureFps/videoFps)+1;
end
videoInfo.captureTime=(videoInfo.captureFrameIndices-1)/captureFps;
if captureFpsProvided, videoInfo.time=videoInfo.captureTime; end
end

function value=getWindowValue(timeWindow,name,defaultValue)
if isstruct(timeWindow)&&isfield(timeWindow,name)&&~isempty(timeWindow.(name))
    value=double(timeWindow.(name));
else
    value=defaultValue;
end
end

function [stride,processingFps]=localSampling(videoFps,fpsOverride)
if isempty(fpsOverride), stride=1; processingFps=videoFps; return; end
if ~isscalar(fpsOverride)||~isfinite(fpsOverride)||fpsOverride<=0||fpsOverride>videoFps
    error('fpsOverride 必须在 (0, %.6g] 内。',videoFps);
end
stride=max(1,round(videoFps/fpsOverride)); processingFps=videoFps/stride;
if abs(processingFps-fpsOverride)>max(0.01,0.01*fpsOverride)
    error('当前入口只接受整数抽帧比：原始 %.6g Hz，目标 %.6g Hz 不匹配。',videoFps,fpsOverride);
end
end

function trajectory=localLowpass(trajectory,fps,cutoffHz)
if cutoffHz<=0, return; end
window=max(5,2*floor(0.5*fps/cutoffHz)+1);
window=min(window,2*floor((size(trajectory,1)-1)/2)+1);
if window<3, return; end
for axis=1:size(trajectory,2)
    column=smoothdata(trajectory(:,axis),'movmedian',window);
    trajectory(:,axis)=smoothdata(column,'movmean',window);
end
end

function roi=localClampRoi(roi,imageWidth,imageHeight)
roi(3)=min(max(round(roi(3)),2),imageWidth-1);
roi(4)=min(max(round(roi(4)),2),imageHeight-1);
roi(1)=min(max(round(roi(1)),1),imageWidth-roi(3)+1);
roi(2)=min(max(round(roi(2)),1),imageHeight-roi(4)+1);
end

function [roi,hitBoundary]=localCenteredRoi(center,roiSize,imageWidth,imageHeight)
unclamped=[center-0.5*roiSize,roiSize]; roi=localClampRoi(unclamped,imageWidth,imageHeight);
hitBoundary=any(abs(roi(1:2)-unclamped(1:2))>0.25);
end

function crop=localFixedCrop(gray,roi)
x=round(roi(1)); y=round(roi(2)); w=round(roi(3)); h=round(roi(4)); crop=gray(y:y+h-1,x:x+w-1);
end

function gray=localGray(rgb)
if size(rgb,3)==3, gray=rgb2gray(rgb); else, gray=rgb; end
end
