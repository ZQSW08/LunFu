function [frames,fps,roiTrajectory,tracking] = load_video_tracker_follow_roi( ...
    videoPath,maxFrames,initialRoi,options,previewPath)
%LOAD_VIDEO_TRACKER_FOLLOW_ROI 使用外部目标跟踪器生成动态 ROI。
%
% 本函数只替换粗跟踪层。fDSST/ECO 输出带尺度的目标框；随后仍采用
% MPME 原有的低频大运动轨迹和固定尺寸分析裁剪，避免尺度变化破坏后端
% 的三维帧数组。显示/保存的 roiTrajectory 保留跟踪器估计的尺度变化。

if nargin < 2 || isempty(maxFrames), maxFrames = Inf; end
if nargin < 4 || isempty(options), options = struct(); end
if nargin < 5, previewPath = ''; end
options = localDefaults(options);

reader = VideoReader(videoPath);
fps = reader.FrameRate;
firstRgb = readFrame(reader);
firstGray = localGray(firstRgb);
[imageHeight,imageWidth] = size(firstGray);
initialRoi = localClampRoi(double(initialRoi),imageWidth,imageHeight);

[rawRoiTrajectory,backendQuality,backendName] = localRunBackend( ...
    videoPath,initialRoi,maxFrames,options);
if isempty(rawRoiTrajectory)
    error('跟踪器 %s 没有返回任何 ROI。',backendName);
end
frameCount = min(size(rawRoiTrajectory,1),localMaxFrameCount(maxFrames));
rawRoiTrajectory = rawRoiTrajectory(1:frameCount,:);
rawRoiTrajectory(1,:) = initialRoi;
rawRoiTrajectory = localNormalizeBoxes(rawRoiTrajectory,imageWidth,imageHeight,initialRoi);

rawCenter = rawRoiTrajectory(:,1:2)+0.5*rawRoiTrajectory(:,3:4);
initialCenter = initialRoi(1:2)+0.5*initialRoi(3:4);
rawCenterDisplacement = rawCenter-initialCenter;

% 低频趋势只用于分析裁剪；原始有符号中心轨迹保留用于诊断和质量判断。
[largeMotionContinuous,kltMicroCandidate,macroDiagnostics] = ...
    estimate_macro_motion(rawCenterDisplacement,fps,options);
smoothedSize = localLowpassTrajectory(rawRoiTrajectory(:,3:4), ...
    fps,options.scaleSmoothingCutoffHz);
smoothedSize = max(smoothedSize,options.minimumTrackedSize);
displayCenter = initialCenter+largeMotionContinuous;
roiTrajectory = [displayCenter-0.5*smoothedSize,smoothedSize];
roiTrajectory = localNormalizeBoxes(roiTrajectory,imageWidth,imageHeight,initialRoi);

% 后端帧数组必须是固定尺寸。以低频中心裁剪，再保持初始尺寸，尺度变化
% 由外层跟踪框记录，避免直接 resize 使 M-PME 的位移单位发生变化。
analysisTrajectory = repmat(initialRoi,frameCount,1);
hitBoundary = false(frameCount,1);
for index = 1:frameCount
    proposedCenter = initialCenter+largeMotionContinuous(index,:);
    [analysisTrajectory(index,:),hitBoundary(index)] = localCenteredRoi( ...
        proposedCenter,initialRoi(3:4),imageWidth,imageHeight);
end

frames = zeros(initialRoi(4),initialRoi(3),frameCount,'single');
writePreview = ~isempty(previewPath);
previewWritingSeconds = 0;
if writePreview
    writer = VideoWriter(previewPath,'MPEG-4');
    writer.FrameRate = min(fps,options.previewFps);
    writer.Quality = 90;
    open(writer);
end
secondReader = VideoReader(videoPath);
try
    for index = 1:frameCount
        if ~hasFrame(secondReader), break; end
        rgb = readFrame(secondReader);
        gray = localGray(rgb);
        frames(:,:,index) = single(localFixedCrop(gray,analysisTrajectory(index,:)));
        if writePreview
            previewTimer = tic;
            annotated = localAnnotate(rgb,roiTrajectory(index,:),index,frameCount, ...
                backendName,backendQuality(index),hitBoundary(index));
            writeVideo(writer,annotated);
            previewWritingSeconds = previewWritingSeconds+toc(previewTimer);
        end
    end
    if writePreview, close(writer); end
catch caughtError
    if writePreview
        try
            close(writer);
        catch
            % 保留视频读取/写出根因。
        end
    end
    rethrow(caughtError);
end

tracking = struct();
tracking.trackerType = backendName;
tracking.dynamicRoiMode = macroDiagnostics.mode;
tracking.validPointCount = nan(frameCount,1);
tracking.quality = backendQuality(:);
tracking.stepDisplacement = [zeros(1,2); diff(rawCenter)];
tracking.fallbackUsed = false(frameCount,1);
% 外部跟踪器不使用 KLT 首帧模板，但入口输出表需要统一字段。
tracking.templateScore = nan(frameCount,1);
tracking.templateCorrectionUsed = false(frameCount,1);
tracking.redetectionUsed = false(frameCount,1);
tracking.rawRoiTrajectory = rawRoiTrajectory;
tracking.bbox_xywh = rawRoiTrajectory;
tracking.center_xy = rawCenter;
tracking.scale = rawRoiTrajectory(:,3:4)./initialRoi(3:4);
tracking.confidence = backendQuality;
tracking.valid = true(frameCount,1);
tracking.lost = false(frameCount,1);
tracking.redetect = false(frameCount,1);
tracking.hitBoundary = hitBoundary;
tracking.rawCoarseDisplacement = rawCenterDisplacement;
tracking.largeMotionContinuous = largeMotionContinuous;
tracking.kltMicroCandidate = kltMicroCandidate;
tracking.coarseDisplacement = analysisTrajectory(:,1:2)-analysisTrajectory(1,1:2);
tracking.expectedCoarseDisplacement = largeMotionContinuous;
tracking.macroTrendDiagnostics = macroDiagnostics;
tracking.macro = struct('xy',largeMotionContinuous, ...
    'microCandidate',kltMicroCandidate);
tracking.crop = struct('origin_xy',analysisTrajectory(:,1:2), ...
    'bbox_xywh',analysisTrajectory,'valid',~hitBoundary, ...
    'expected_xy',initialRoi(1:2)+largeMotionContinuous);
tracking.analysisRoiTrajectory = analysisTrajectory;
tracking.scaleTrajectory = roiTrajectory(:,3:4);
tracking.fallbackFrameCount = 0;
tracking.templateCorrectionFrameCount = 0;
tracking.boundaryFrameCount = nnz(hitBoundary);
tracking.previewWritingSeconds = previewWritingSeconds;
tracking.largeMotionCutoffHz = macroDiagnostics.cutoffHz;
tracking.trackingAxis = options.trackingAxis;
tracking.backendQuality = backendQuality;
end

function options = localDefaults(options)
defaults = struct('trackerType','fdsst_improved', ...
    'fdsstOriginalRoot','C:\Users\SPRING\Desktop\师兄\第四章实验\程序\DSST', ...
    'fdsstImprovedRoot','D:\方法库备份\fDSST备份\Tracking', ...
    'ecoRoot','D:\方法库备份\ECO备份\ECO-master', ...
    'ecoWrapperRoot','C:\Users\SPRING\Desktop\师兄\第四章实验\程序\Tracking', ...
    'fdsstOptions',struct(),'ecoOptions',struct(), ...
    'largeMotionCutoffHz',1,'macroTrendCutoffHz',[],'macroTrendWindowSeconds',0.5, ...
    'mode','trend','scaleSmoothingCutoffHz',1, ...
    'minimumTrackedSize',[8 8],'maximumStepPixels',Inf, ...
    'trackingAxis','xy','previewFps',30);
names = fieldnames(defaults);
for index = 1:numel(names)
    if ~isfield(options,names{index}) || isempty(options.(names{index}) )
        options.(names{index}) = defaults.(names{index});
    end
end
end

function [boxes,quality,name] = localRunBackend(videoPath,initialRoi,maxFrames,options)
name = lower(strtrim(char(string(options.trackerType))));
quality = [];
switch name
    case {'fdsst','fdsst_original','original_fdsst'}
        originalRoot = options.fdsstOriginalRoot;
        shimRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
            'third_party','fdsst_original');
        localRequireDirectory(originalRoot,'原版 fDSST');
        localRequireDirectory(shimRoot,'原版 fDSST 适配副本');
        addpath(originalRoot);
        addpath(shimRoot);
        reader = VideoReader(videoPath);
        result = DSST_Function(initialRoi,reader);
        boxes = result;
        name = 'fdsst';
    case {'fdsst_improved','improved_fdsst'}
        localRequireDirectory(options.fdsstImprovedRoot,'改进 fDSST');
        addpath(options.fdsstImprovedRoot);
        reader = VideoReader(videoPath);
        trackerOptions = options.fdsstOptions;
        result = DSST_Improved_Function(initialRoi,reader,trackerOptions);
        boxes = result.res;
        name = 'fdsst_improved';
        if isfield(result,'metrics') && isfield(result.metrics,'max_response')
            quality = result.metrics.max_response(:);
        end
    case {'eco','eco_improved','improved_eco'}
        localRequireDirectory(options.ecoRoot,'ECO');
        localRequireDirectory(options.ecoWrapperRoot,'ECO 适配脚本');
        addpath(options.ecoWrapperRoot);
        trackerOptions = options.ecoOptions;
        trackerOptions.eco_root = options.ecoRoot;
        if ~isfield(trackerOptions,'cache_dir') || isempty(trackerOptions.cache_dir)
            trackerOptions.cache_dir = fullfile(tempdir,'mpme_eco_tracking_cache');
        end
        result = run_ECO_improved_mpme(videoPath,initialRoi,trackerOptions);
        boxes = result.res;
        name = 'eco_improved';
    otherwise
        error('不支持的 trackerType: %s。可选：klt、fdsst、fdsst_improved、eco_improved。',name);
end

if isempty(boxes) || size(boxes,2)~=4
    error('%s 返回的 ROI 不是 N×4 数组。',name);
end
if isempty(quality)
    quality = ones(size(boxes,1),1);
else
    quality = quality(1:min(numel(quality),size(boxes,1)));
    lastQuality = quality(end);
    quality(end+1:size(boxes,1),1) = lastQuality;
    quality(~isfinite(quality)) = 0;
    quality = rescale(quality,0,1);
end
if isfinite(maxFrames)
    boxes = boxes(1:min(size(boxes,1),maxFrames),:);
    quality = quality(1:size(boxes,1));
end
end

function localRequireDirectory(pathValue,label)
if ~exist(pathValue,'dir')
    error('%s目录不存在：%s',label,pathValue);
end
end

function count = localMaxFrameCount(maxFrames)
if isfinite(maxFrames), count = max(1,floor(maxFrames)); else, count = Inf; end
end

function boxes = localNormalizeBoxes(boxes,imageWidth,imageHeight,initialRoi)
boxes = double(boxes);
for index = 1:size(boxes,1)
    if any(~isfinite(boxes(index,:))) || boxes(index,3)<2 || boxes(index,4)<2
        if index==1, boxes(index,:) = initialRoi; else, boxes(index,:) = boxes(index-1,:); end
    end
    boxes(index,:) = localClampRoi(boxes(index,:),imageWidth,imageHeight);
end
end

function trajectory = localLowpassTrajectory(trajectory,fps,cutoffHz)
if size(trajectory,1)<19 || cutoffHz<=0 || cutoffHz>=0.45*fps
    if size(trajectory,1)>=5
        trajectory = smoothdata(trajectory,1,'sgolay',min(size(trajectory,1),9));
    end
    return;
end
[filterB,filterA] = butter(3,min(cutoffHz,0.45*fps)/(fps/2),'low');
for column = 1:size(trajectory,2)
    trajectory(:,column) = filtfilt(filterB,filterA,trajectory(:,column));
end
end

function [roi,hitBoundary] = localCenteredRoi(center,roiSize,imageWidth,imageHeight)
roi = [center-0.5*roiSize,roiSize];
unclamped = roi;
roi = localClampRoi(roi,imageWidth,imageHeight);
hitBoundary = any(abs(roi(1:2)-unclamped(1:2))>0.25);
end

function crop = localFixedCrop(gray,roi)
x = round(roi(1)); y = round(roi(2));
w = round(roi(3)); h = round(roi(4));
crop = gray(y:y+h-1,x:x+w-1);
end

function roi = localClampRoi(roi,imageWidth,imageHeight)
roi(3) = min(max(round(roi(3)),2),imageWidth-1);
roi(4) = min(max(round(roi(4)),2),imageHeight-1);
roi(1) = min(max(round(roi(1)),1),imageWidth-roi(3));
roi(2) = min(max(round(roi(2)),1),imageHeight-roi(4));
end

function gray = localGray(rgb)
if size(rgb,3)==3, gray = rgb2gray(rgb); else, gray = rgb; end
end

function rgb = localAnnotate(frame,roi,frameIndex,frameCount,trackerName,quality,hitBoundary)
if size(frame,3)==1, rgb = repmat(frame,1,1,3); else, rgb = frame; end
rgb = insertShape(rgb,'Rectangle',round(roi),'Color',[0 210 255],'LineWidth',3);
status = '尺度跟踪';
if hitBoundary, status = '尺度跟踪/分析裁剪触边'; end
label = sprintf('Tracker=%s | %d/%d | Q=%.3f | %s | ROI=[%.0f %.0f %.0f %.0f]', ...
    trackerName,frameIndex,frameCount,quality,status,roi);
rgb = insertText(rgb,[8 8],label,'FontSize',13,'TextColor','white', ...
    'BoxColor','black','BoxOpacity',0.65);
end
