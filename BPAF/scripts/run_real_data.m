%RUN_REAL_DATA 使用 BPAF 处理真实“大运动+微振动”视频。
% 这是 BPAF 独立的真实数据入口，不复用 MPME 的运动模型/参考帧字段。
% 只需修改本节中的视频路径、输出目录和 BPAF 先验设置。
% ROI 为空时首帧手动框选，双击或按 Enter 确认，Esc/关闭窗口会安全停止。
% 文件采用 UTF-8 中文注释，请勿另存为 ANSI/GBK。

close all; clearvars; clc; warning off;
scriptPath=mfilename('fullpath');
projectRoot=fileparts(fileparts(scriptPath));
addpath(fullfile(projectRoot,'src'));
cfg=bpaf.default_config();
bpaf.setup_project(cfg);

%% 1. 工程路径与用户配置（只改这里）
config.videoPath = 'C:\0819\sun-3050-30mvpp.mp4';
config.outputDirectory = 'D:\LunFu\BPAF\outputs\0819\sun-3050-30mvpp';
config.outputName = 'sun-3050-30mvpp';
config.roi = [];                       % 留空手动框选；也可填 [x y width height]
config.maxFrames = 1800;               % Inf 表示读取全部
config.fpsOverride = 300;              % [] 表示使用视频原始帧率
config.primaryAxis = 'x';              % 'x'、'y' 或 'angle'
config.frequencyRangeHz = [0.05 60];   % 输出频谱显示/搜索范围
config.writeTrackingVideo = true;      % 输出固定 ROI 标注视频
config.output.clearPreviousResults = true;

% VP-DROI 前置跟踪层：只估计/跟随宏观运动，BPAF 仍负责最终微振动测量。
% tracker='fdsst' 时优先调用师兄第四章 fDSST；依赖不可用会回退到模板平移跟随。
config.dynamicROI.enabled = false;
config.dynamicROI.mode = 'trend';       % 'trend' 宏观趋势跟随；'fixed' 固定 ROI
config.dynamicROI.tracker = 'fdsst';    % 'fdsst' 或 'template_translation'
config.dynamicROI.macroTrendWindowSeconds = 0.15;
config.dynamicROI.searchRadiusPx = 180;
config.dynamicROI.minMatchScore = 0.35;
config.dynamicROI.maxStepPixels = 120;

% BPAF 专属语义：场景是大运动与微振动叠加，采用时域加速度带通先验。
config.bpaf.motionScenario = 'large-motion-plus-micro-vibration';
config.bpaf.temporalReference = 'band-passed-acceleration';
% BPAF 先验频带：按目标微振动频率修改；必须满足 FL < FH <= fps/2。
config.bpaf.frequencyBandHz = [5 100];
config.bpaf.useGeneticAlgorithm = true;
config.bpaf.savePhaseCube = true;

if isempty(config.videoPath)
    fprintf('请先填写 config.videoPath；当前运行未执行。\n');
    return;
end
if ~isfile(config.videoPath)
    fprintf('找不到视频：%s\n请修改 run_real_data.m 顶部的 config.videoPath。当前运行未执行。\n',config.videoPath);
    return;
end

%% 2. 输出目录与安全 ROI 交互
[roi,firstFrame,firstCrop,cancelled]=select_video_roi(config.videoPath,config.roi, ...
    'BPAF 真实视频 ROI');
if cancelled, return; end
% 只有 ROI 成功确认后才清理本次输出目录；误关闭窗口不会删除上一轮结果。
outputDirectory=prepare_real_output_directory(config.outputDirectory,projectRoot, ...
    config.output.clearPreviousResults);
save_roi_image(firstFrame,roi,fullfile(outputDirectory,'01_bpaf_roi_selection.png'),'BPAF ROI selection');
save_plain_image(firstCrop,fullfile(outputDirectory,'02_bpaf_roi_input.png'),'BPAF ROI input');

%% 3. 跟踪宏观运动并生成振动保持型动态 ROI
reader=VideoReader(config.videoPath);
videoFps=reader.FrameRate;
if isempty(config.fpsOverride), fps=videoFps; else, fps=config.fpsOverride; end
if isinf(config.maxFrames)
    requestedFrames=max(1,floor(reader.Duration*videoFps));
else
    requestedFrames=max(1,round(config.maxFrames));
end
frames=zeros(size(firstCrop,1),size(firstCrop,2),requestedFrames,'single');
if config.dynamicROI.enabled && ~strcmpi(config.dynamicROI.mode,'fixed')
    tracking=bpaf.track_video_roi(config.videoPath,roi,requestedFrames, ...
        'tracker',config.dynamicROI.tracker, ...
        'macroTrendWindowSeconds',config.dynamicROI.macroTrendWindowSeconds, ...
        'searchRadiusPx',config.dynamicROI.searchRadiusPx, ...
        'minMatchScore',config.dynamicROI.minMatchScore, ...
        'maxStepPixels',config.dynamicROI.maxStepPixels);
else
    tracking=fixed_roi_tracking(roi,requestedFrames,fps,reader.Width,reader.Height);
end
roiHistory=tracking.crop_bbox_xywh;
roiScores=tracking.confidence;
roiValid=tracking.valid;
requestedFrames=min(requestedFrames,size(roiHistory,1));
frames=frames(:,:,1:requestedFrames);
reader.CurrentTime=0;
frameCount=0; trackingVideo=[];
if config.writeTrackingVideo
    try
        trackingVideo=VideoWriter(fullfile(outputDirectory,'03_bpaf_roi_tracking.mp4'),'MPEG-4');
        trackingVideo.FrameRate=min(fps,30); trackingVideo.Quality=90; open(trackingVideo);
    catch trackingError
        trackingVideo=[];
        fprintf('BPAF 标注视频写入器不可用（%s），继续保存图像、CSV 和 MAT 结果。\n',trackingError.message);
    end
end
cleanupVideo=onCleanup(@() close_tracking_writer(trackingVideo));
while hasFrame(reader) && frameCount<requestedFrames
    rgb=readFrame(reader); frameCount=frameCount+1;
    gray=rgb; if size(gray,3)==3, gray=rgb2gray(gray); end
    currentRoi=roiHistory(frameCount,:);
    frames(:,:,frameCount)=single(crop_by_roi_local(gray,currentRoi));
    if ~isempty(trackingVideo)
        annotated=rgb;
        annotated=insertShape(annotated,'Rectangle',currentRoi,'Color',[230 85 13],'LineWidth',3);
        annotated=insertText(annotated,[8 8],sprintf('BPAF ROI | %d/%d',frameCount,requestedFrames), ...
            'TextColor','white','BoxColor','black','BoxOpacity',0.65,'FontSize',14);
        writeVideo(trackingVideo,annotated);
    end
end
if ~isempty(trackingVideo), close(trackingVideo); end
clear cleanupVideo;
frames=frames(:,:,1:frameCount);
roiHistory=roiHistory(1:frameCount,:); roiScores=roiScores(1:frameCount); roiValid=roiValid(1:frameCount);
roiTable=table((1:frameCount)',tracking.bbox_xywh(1:frameCount,1),tracking.bbox_xywh(1:frameCount,2), ...
    tracking.bbox_xywh(1:frameCount,3),tracking.bbox_xywh(1:frameCount,4), ...
    tracking.macro_center_xy(1:frameCount,1),tracking.macro_center_xy(1:frameCount,2), ...
    roiHistory(:,1),roiHistory(:,2),roiHistory(:,3),roiHistory(:,4),roiScores,roiValid, ...
    tracking.boundary(1:frameCount),repmat(tracking.fallback,frameCount,1), ...
    'VariableNames',{'frame','track_x','track_y','track_width','track_height', ...
    'macro_center_x','macro_center_y','crop_x','crop_y','crop_width','crop_height', ...
    'confidence','valid','boundary_flag','fallback_backend'});
writetable(roiTable,fullfile(outputDirectory,'03_bpaf_roi_trajectory.csv'));
if config.dynamicROI.enabled && ~strcmpi(config.dynamicROI.mode,'fixed') && mean(roiValid)<0.90
    fprintf('警告：ROI 跟随有效比例仅 %.1f%%，请检查轨迹 CSV、扩大搜索半径或重新框选更有纹理的区域。\n', ...
        100*mean(roiValid));
end
if frameCount<8
    fprintf('可处理帧数不足（%d），当前运行安全停止。\n',frameCount);
    return;
end

%% 4. BPAF 局部相位、滤波与输出
spec=struct('id',upper(config.outputName),'fs',fps,'duration',frameCount/fps, ...
    'targetFrequency',NaN,'description','真实视频 VP-DROI + BPAF','height',size(frames,1), ...
    'width',size(frames,2),'analyzeStart',0,'analyzeDuration',frameCount/fps, ...
    'proxy',false,'targetType','real-video');
truth=struct('time',(0:frameCount-1)'/fps,'largeMotionPx',nan(frameCount,1), ...
    'vibrationPx',zeros(frameCount,1),'totalMotionPx',nan(frameCount,1),'fs',fps, ...
    'targetFrequency',NaN,'proxy',false,'description','真实视频无外部真值');
data=struct('frames',frames,'truth',truth,'spec',spec);
runCfg=cfg;
runCfg.orientationBand=orientation_for_axis(config.primaryAxis,cfg.orientationBand);
runCfg.stopbandAlpha=cfg.stopbandAlpha;
cachePath=fullfile(outputDirectory,'04_bpaf_phase_features.mat');
features=bpaf.extract_phase_features(data,runCfg,cachePath);
band=sort(double(config.bpaf.frequencyBandHz(:).'));
band(1)=max(band(1),eps); band(2)=min(band(2),fps/2-1e-6);
if band(2)<=band(1)
    fprintf('BPAF 先验频带无效：[%.4g %.4g] Hz，当前运行安全停止。\n',band(1),band(2));
    return;
end
result=bpaf.run_method(features,'BPAF',band,runCfg,'cube',config.bpaf.useGeneticAlgorithm);
result.metrics.RMSE=NaN; result.metrics.truthAvailable=false;
time=(0:numel(result.signal)-1)'/fps;
signalTable=table(time,result.signal,features.rawSignal, ...
    'VariableNames',{'time_s','bpaf_phase','raw_weighted_phase'});
writetable(signalTable,fullfile(outputDirectory,'05_bpaf_vibration_signal.csv'));
runConfig=config; runConfig.roi=roi; runConfig.roiFinal=roiHistory(end,:); runConfig.frameCount=frameCount; runConfig.videoFps=videoFps; runConfig.processingFps=fps;
runConfig.roiTrackingBackend=tracking.backend;
runConfig.roiTrackingValidFraction=mean(roiValid);
runConfig.roiTrackingMedianScore=median(roiScores(roiValid));
save(fullfile(outputDirectory,'06_bpaf_run_result.mat'),'result','features','runConfig', ...
    'tracking','roiHistory','roiScores','roiValid','-v7.3');
save_real_plots(result,features.rawSignal,time,config.frequencyRangeHz,band,fps, ...
    outputDirectory,config.outputName);
fprintf('BPAF 真实视频处理完成：%s\n',outputDirectory);
fprintf('ROI=[%d %d %d %d], frames=%d, fps=%.6g, BPAF band=[%.4g %.4g] Hz, PF=%.6g Hz\n', ...
    roi,frameCount,fps,band,result.metrics.PF);

function outputDirectory=prepare_real_output_directory(outputDirectory,projectRoot,clearPrevious)
outputDirectory=char(outputDirectory);
if isempty(outputDirectory), outputDirectory=fullfile(projectRoot,'outputs','real_data'); end
resolved=char(java.io.File(outputDirectory).getCanonicalPath());
root=char(java.io.File(fullfile(projectRoot,'outputs')).getCanonicalPath());
if strcmpi(resolved,root) || ~startsWith(lower(resolved),[lower(root) filesep])
    if clearPrevious && isfolder(resolved)
        fprintf('输出目录不在 BPAF/outputs 的具体子目录内，跳过清理以保护已有数据：%s\n',resolved);
    end
else
    if clearPrevious && isfolder(resolved)
        [ok,msg]=rmdir(resolved,'s'); if ~ok, error('无法清理本次输出目录：%s',msg); end
    end
end
if ~isfolder(resolved), mkdir(resolved); end
outputDirectory=resolved;
end

function crop=crop_by_roi_local(frame,roi)
x=roi(1); y=roi(2); w=roi(3); h=roi(4);
x2=min(size(frame,2),x+w-1); y2=min(size(frame,1),y+h-1);
crop=frame(y:y2,x:x2,:);
end

function tracking=fixed_roi_tracking(roi,n,fs,imageWidth,imageHeight)
%FIXED_ROI_TRACKING 保留原论文 baseline：不引入动态跟踪，仅重复固定 ROI。
roi=round(roi);
tracking=struct();
tracking.backend='fixed_roi';
tracking.fps=fs;
tracking.time_s=(0:n-1)'/fs;
tracking.bbox_xywh=repmat(roi,n,1);
tracking.center_xy=repmat([roi(1)+roi(3)/2,roi(2)+roi(4)/2],n,1);
tracking.scale=ones(n,1);
tracking.confidence=ones(n,1);
tracking.valid=true(n,1);
tracking.macro_center_xy=tracking.center_xy;
tracking.crop_bbox_xywh=repmat(roi,n,1);
tracking.boundary=tracking.crop_bbox_xywh(:,1)<=1 | tracking.crop_bbox_xywh(:,2)<=1 | ...
    tracking.crop_bbox_xywh(:,1)+roi(3)-1>=imageWidth | ...
    tracking.crop_bbox_xywh(:,2)+roi(4)-1>=imageHeight;
tracking.macro_displacement_xy=zeros(n,2);
tracking.fallback=false;
tracking.trendWindowSeconds=0;
end

function axisBand=orientation_for_axis(axisName,defaultBand)
switch lower(axisName)
    case 'x', axisBand=4;
    case 'y', axisBand=1;
    otherwise, axisBand=defaultBand;
end
end

function save_roi_image(frame,roi,path,titleText)
fig=figure('Visible','off','Color','w','Position',[100 100 900 560]);
imshow(frame); hold on;
rectangle('Position',roi,'EdgeColor',[0.85 0.10 0.10],'LineWidth',2.0);
title(titleText,'FontName','Times New Roman','FontSize',13,'FontWeight','normal');
exportgraphics(fig,path,'Resolution',200); close(fig);
end

function save_plain_image(frame,path,titleText)
fig=figure('Visible','off','Color','w','Position',[100 100 900 560]);
imshow(frame);
title(titleText,'FontName','Times New Roman','FontSize',13,'FontWeight','normal');
exportgraphics(fig,path,'Resolution',200); close(fig);
end

function save_real_plots(result,rawSignal,time,frequencyRange,band,fs,folder,name)
% 绘图实现集中在可复用函数中，保证真实视频入口与批量重导出脚本完全一致。
bpaf.export_real_figures(result,rawSignal,time,frequencyRange,band,fs,folder,name);
end

function close_tracking_writer(writer)
if ~isempty(writer)
    try
        close(writer);
    catch
    end
end
end
