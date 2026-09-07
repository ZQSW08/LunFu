function [frames,fps,roiTrajectory,tracking] = load_video_dynamic_roi( ...
    videoPath,maxFrames,initialRoi,options,previewPath)
%LOAD_VIDEO_DYNAMIC_ROI VP-DROI 的唯一前端入口。
%
% 运行时只调用一个粗跟踪后端：
%   klt            -> load_video_gray_smooth_follow_roi
%   fdsst/fDSST/ECO -> load_video_tracker_follow_roi
%   rmptf          -> D:\LunFu\shared\RMPTF 公共可靠前端
%
% 后续 estimate_macro_motion、动态裁剪和 M-PME 属于同一条流水线，不是第二个
% ROI 跟踪器。这样既保留四种后端选择，也避免 KLT 与 fDSST/ECO 串联运行。

if nargin < 4 || isempty(options), options = struct(); end
if nargin < 5, previewPath = ''; end
trackerType = 'klt';
if isfield(options,'trackerType') && ~isempty(options.trackerType)
    trackerType = lower(strtrim(char(string(options.trackerType))));
end

if startsWith(trackerType,'rmptf')
    managerRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    sharedRoot = fullfile(managerRoot,'shared','RMPTF','src');
    if ~isfolder(sharedRoot)
        error('找不到 RMPTF 公共模块：%s',sharedRoot);
    end
    addpath(sharedRoot);
    cfg = rmptf.default_config();
    cfg.compensation.mode = localField(options,'mode','trend');
    cfg.compensation.cutoffHz = localCutoff(options);
    cfg.compensation.windowSeconds = localField(options,'macroTrendWindowSeconds',0.5);
    cfg.compensation.trackingAxis = localField(options,'trackingAxis','xy');
    cfg.compensation.targetBandHz = localField(options,'targetBandHz',[]);
    cfg.tracker.maxStepPixels = localField(options,'maximumStepPixels',120);
    cfg.tracker.searchRadiusPx = max(24,round(0.75*cfg.tracker.maxStepPixels));
    cfg.tracker.redetectRadiusPx = max(80,2*cfg.tracker.searchRadiusPx);
    cfg.klt.maximumPoints = localField(options,'maximumPoints',160);
    cfg.klt.minimumPoints = localField(options,'minimumPoints',6);
    cfg.klt.minimumQuality = localField(options,'minimumQuality',0.005);
    cfg.klt.maximumBidirectionalError = localField(options,'maximumBidirectionalError',2);
    cfg.io.captureFps = localField(options,'captureFps',[]);
    cfg.io.writePreview = ~isempty(previewPath);
    cfg.io.diagnosticsDirectory = localField(options,'diagnosticsDirectory','');
    if contains(trackerType,'fdsst')
        cfg.tracker.backend='fdsst_improved';
        cfg.tracker.fdsstRoot=localField(options,'fdsstImprovedRoot','');
    end
    cfg.phaseCrossline.enabled = contains(trackerType,'crossline') || ...
        logical(localField(options,'phaseCrosslineEnabled',false));
    if isfield(options,'rmptf') && isstruct(options.rmptf)
        cfg = rmptf.merge_config(cfg,options.rmptf);
    end
    [frames,fps,roiTrajectory,tracking] = rmptf.process_video( ...
        videoPath,maxFrames,initialRoi,cfg,previewPath);
elseif strcmp(trackerType,'klt')
    [frames,fps,roiTrajectory,tracking] = ...
        load_video_gray_smooth_follow_roi(videoPath,maxFrames,initialRoi, ...
        options,previewPath);
else
    [frames,fps,roiTrajectory,tracking] = ...
        load_video_tracker_follow_roi(videoPath,maxFrames,initialRoi, ...
        options,previewPath);
end

% 统一记录“只调用一次前端跟踪器”的事实，便于结果审计。
tracking.frontTrackerType = trackerType;
tracking.frontTrackerCallCount = 1;
tracking.frontTrackerOnly = true;
end

function value = localField(source,name,defaultValue)
if isfield(source,name) && ~isempty(source.(name)), value=source.(name); else, value=defaultValue; end
end

function value = localCutoff(options)
value = localField(options,'macroTrendCutoffHz',[]);
if isempty(value), value=localField(options,'largeMotionCutoffHz',1); end
end
