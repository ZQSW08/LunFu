function run_real_video()
% RUN_REAL_VIDEO 使用 MP-G2LPT V1+V2 处理真实视频。
% 用户只需修改下方“用户配置区”；首帧 ROI 支持拖动后双击/Enter 确认，Esc 取消退出。
% 论文明确：首帧自然纹理 anchor、多尺度/多方向复 Gabor、POC 粗定位、局部 circular phase。
% 实现推断：Gabor 波长、搜索半径、可靠性阈值等集中在 default_config.m。

close all; clc;
scriptPath=mfilename('fullpath'); projectRoot=fileparts(fileparts(scriptPath));
srcDir=fullfile(projectRoot,'src');
if ~isfolder(srcDir), error('找不到 PLT 源代码目录：%s',srcDir); end
addpath(srcDir,'-begin');                % 强制优先使用 PLT 当前实现，避免串用其他工程旧函数
cfg=default_config(projectRoot); setup_project(cfg);

%% 用户配置区（只修改这里）
cfg.video.path= 'C:\0819\4-25mvpp-motion.avi';     % 例如：D:\data\natural_texture.mp4
cfg.output.directory= 'D:\LunFu\PLT\outputs\0819\4-25mvpp-motion';
cfg.video.roi= [];                          % [] 不预置框，首帧直接拖动；也可填 [x y width height]
cfg.video.maxFrames= 1000;                   % Inf 处理全部可读帧
cfg.video.fpsOverride= 100;                  % [] 使用视频元数据帧率
cfg.video.progressEveryFrames= 25;           % 每隔多少帧打印一次进度
cfg.video.processingScale= 0.5;               % 处理缩放：0.5 提速；1 为原始分辨率
cfg.output.writeTrackingVideo= true;
cfg.output.clearPreviousResults= true;      % ROI 确认后清空该目录，再写入本次结果
cfg.method.observedAxis='x';               % 观测方向：'x' 水平；'y' 垂直
cfg.method.trackingScaleIndices=1:2;       % Tracking: coarse + medium
cfg.method.measurementScaleIndices=2:3;    % Measurement: medium + fine
cfg.decomposition.mode='band_protected';   % temporal / band_protected / spatial
cfg.decomposition.temporalCutoffHz=2.0;
cfg.decomposition.vibrationBandHz=[2 30];
outputDir=char(cfg.output.directory);

if isempty(cfg.video.path) || ~isfile(cfg.video.path)
    error('请先在 run_real_video.m 顶部配置 cfg.video.path。');
end
vr=VideoReader(cfg.video.path); videoFps=vr.FrameRate;
if isempty(cfg.video.fpsOverride), processingFps=videoFps; else, processingFps=cfg.video.fpsOverride; end
if ~isfinite(processingFps) || processingFps<=0, error('processingFps 必须为正数。'); end

% ROI 确认之前不清理任何历史结果；首次运行也可以正常进入处理流程。
[roi,firstFrame,~,cancelled]=select_video_roi(cfg.video.path,cfg.video.roi,...
    'MP-G2LPT ROI：拖动矩形，双击或 Enter 确认，Esc 取消');
if cancelled
    fprintf('ROI 选择已取消，未清理既有结果。\n'); return;
end
if isempty(firstFrame) || isempty(roi), error('首帧或 ROI 无效。'); end
outputDir=prepare_real_output_directory(cfg.output.directory,projectRoot,cfg.output.clearPreviousResults);
processingScale=cfg.video.processingScale;
if isempty(processingScale), processingScale=1; end
if ~isscalar(processingScale) || ~isfinite(processingScale) || processingScale<=0 || processingScale>1
    error('cfg.video.processingScale 必须位于 (0,1]。');
end
procCfg=cfg;
procCfg.method.wavelengthsPx=cfg.method.wavelengthsPx*processingScale;
procCfg.method.localSearchRadiusPx=max(2,cfg.method.localSearchRadiusPx*processingScale);
procCfg.method.subpixelMaxPx=cfg.method.subpixelMaxPx*processingScale;
procCfg.method.maxPocJumpPx=cfg.method.maxPocJumpPx*processingScale;
procCfg.method.maxPredictionResidualPx=cfg.method.maxPredictionResidualPx*processingScale;
processingFirstFrame=resize_for_processing(firstFrame,processingScale);
processingRoi=scale_roi_for_processing(roi,processingScale,size(processingFirstFrame));

% 重新打开视频，从首帧开始逐帧处理，避免依赖 ROI 选择阶段的 reader 状态。
vr=VideoReader(cfg.video.path); state=initialize_phase_tracker(processingFirstFrame,processingRoi,procCfg);
% 时域对照只需独立的 previousCenter，首帧 anchor 与相位域完全相同，直接复用以节省初始化开销。
intensityState=state;
frameLimit=cfg.video.maxFrames; if isempty(frameLimit), frameLimit=Inf; end
if isfinite(frameLimit)
    maxN=max(1,round(frameLimit));
else
    % Duration 只用于预分配；实际结束条件仍以 hasFrame 为准。
    maxN=max(1,ceil(vr.Duration*videoFps)+1);
end
primary=empty_real_result(maxN); primary=put_real_initial(primary,state.anchor.center);
intensityCenters=nan(maxN,2); intensityCenters(1,:)=intensityState.anchor.center; frameCount=1;
progressEvery=max(1,round(cfg.video.progressEveryFrames)); progressTimer=tic;
if hasFrame(vr), readFrame(vr); end % 首帧已用于 anchor，避免结果序列重复一帧。
while hasFrame(vr) && frameCount<maxN
    frameCount=frameCount+1; frame=readFrame(vr);
    frameForProcessing=resize_for_processing(frame,processingScale);
    pyramid=build_complex_gabor_pyramid(frameForProcessing,procCfg);
    [state,out]=track_one_frame(state,frameForProcessing,procCfg,'v3_predictive',pyramid);
    [intensityState,intensityOut]=track_one_frame(intensityState,frameForProcessing,procCfg,'intensity_ncc',pyramid);
    primary=put_real_result(primary,frameCount,out);
    intensityCenters(frameCount,:)=intensityOut.center;
    if mod(frameCount-1,progressEvery)==0 || frameCount==maxN
        fprintf('V1 progress: %d/%d frames (%.1f%%), elapsed %.1f min\n', ...
            frameCount,maxN,100*frameCount/maxN,toc(progressTimer)/60);
    end
end
primary=trim_real_result(primary,frameCount);
intensityCenters=intensityCenters(1:frameCount,:);
primaryOutput=scale_real_result_to_original(primary,processingScale);
intensityCentersOutput=scale_points_to_original(intensityCenters,processingScale);
displayAnchor=state.anchor; displayAnchor.roi=roi;
displayAnchor.center=scale_points_to_original(state.anchor.center,processingScale);

% 保存 V1 标准图/CSV/MAT；真实视频没有真值，因此不输出 RMSE/PCC 等伪指标。
save_v1_outputs(outputDir,firstFrame,displayAnchor,[primaryOutput],cfg,processingFps,[],[]);
if cfg.output.writeTrackingVideo
    try
        phaseVideo=write_tracking_overlay_video_from_file(cfg.video.path,primaryOutput.center,roi,processingFps,...
            fullfile(outputDir,'04_phase_tracking_overlay.mp4'),cfg.plot.red,'phase-domain');
        fprintf('Phase-domain tracking video: %s\n',phaseVideo);
    catch videoError
        warning('MP-G2LPT:VideoWriter','相位域过程视频写入失败：%s',videoError.message);
    end
    try
        intensityVideo=write_tracking_overlay_video_from_file(cfg.video.path,intensityCentersOutput,roi,processingFps,...
            fullfile(outputDir,'05_intensity_tracking_overlay.mp4'),[0.0000 0.6000 0.3000],'intensity/time-domain');
        fprintf('Intensity/time-domain tracking video: %s\n',intensityVideo);
    catch videoError
        warning('MP-G2LPT:VideoWriter','时域/强度域过程视频写入失败：%s',videoError.message);
    end
end
intensityTable=table((1:frameCount)',(0:frameCount-1)'/processingFps,intensityCentersOutput(:,1),intensityCentersOutput(:,2),...
    'VariableNames',{'frame','time_s','x_px','y_px'});
writetable(intensityTable,fullfile(outputDir,'intensity_tracking.csv'));
save_real_signal_outputs(outputDir,primaryOutput,processingFps,cfg);
validRate=mean(primary.valid);
fprintf('V3 valid tracking rate: %.1f%%\n',100*validRate);
if isfield(cfg.method,'minValidRateForDecomposition') && validRate<cfg.method.minValidRateForDecomposition
    warning('MP-G2LPT:TrackingLost','有效跟踪帧比例仅 %.1f%%，未生成 V2 分解；请重新选择纹理丰富的 ROI。',100*validRate);
    fprintf('请重新选择 ROI：避免单根边缘/亮线，选择包含二维自然纹理的区域。\n');
    return;
end
% V2：宏观轨迹只用于整数测量坐标，细相位残差单独读取 measurement channels。
dTotal=primary.center-primary.center(1,:);
switch lower(cfg.decomposition.mode)
    case 'temporal'
        dMacro=estimate_macro_temporal(dTotal,processingFps,cfg.decomposition.temporalCutoffHz);
    case 'band_protected'
        dMacro=estimate_macro_bandprotected(dTotal,processingFps,cfg.decomposition.vibrationBandHz);
    case 'spatial'
        [dMacro,~,~]=estimate_macro_spatial(reshape(dTotal,size(dTotal,1),size(dTotal,2),1));
    otherwise
        error('未知 decomposition.mode：%s',cfg.decomposition.mode);
end
coordinateProc=build_measurement_coordinate(dTotal,dMacro);
dVibProc=compute_real_residuals(cfg.video.path,state.anchor,coordinateProc.dMacro,procCfg,processingFps,processingScale);
coordinate=scale_coordinate_to_original(coordinateProc,processingScale);
dVib=dVibProc/processingScale;
save_decomposition_outputs(outputDir,coordinate,dVib,processingFps,cfg);
fprintf('处理完成：%d frames, videoFps=%.6g, processingFps=%.6g\n',frameCount,videoFps,processingFps);
fprintf('Outputs: %s\n',outputDir);
end

function r=empty_real_result(n)
templateSource=repmat({''},n,1);
r=struct('name','V3 predictive phase tracking','center',nan(n,2),'integerCenter',nan(n,2),'subpixel',nan(n,2),...
    'quality',nan(n,1),'phaseScore',nan(n,1),'peakRatio',nan(n,1),...
    'crossScaleAgreement',nan(n,1),'subpixelResidualRms',nan(n,1),'valid',false(n,1),...
    'predictedCenter',nan(n,2),'usedPrediction',false(n,1),'usedPocRecovery',false(n,1),...
    'templateSource',{templateSource},'templateUpdated',false(n,1));
end
function r=put_real_initial(r,c)
r.center(1,:)=c; r.integerCenter(1,:)=c; r.subpixel(1,:)=[0 0]; r.quality(1)=1; r.phaseScore(1)=1; r.peakRatio(1)=1; r.crossScaleAgreement(1)=1; r.subpixelResidualRms(1)=0; r.valid(1)=true;
end
function r=put_real_result(r,k,out)
r.center(k,:)=out.center; r.integerCenter(k,:)=out.integerCenter; r.subpixel(k,:)=out.subpixel; r.quality(k)=out.quality; r.phaseScore(k)=out.phaseScore; r.peakRatio(k)=out.peakRatio; r.crossScaleAgreement(k)=out.crossScaleAgreement; r.subpixelResidualRms(k)=out.subpixelResidualRms; r.valid(k)=out.valid;
if isfield(out,'predictedCenter'), r.predictedCenter(k,:)=out.predictedCenter; end
if isfield(out,'usedPrediction'), r.usedPrediction(k)=out.usedPrediction; end
if isfield(out,'usedPocRecovery'), r.usedPocRecovery(k)=out.usedPocRecovery; end
if isfield(out,'templateSource'), r.templateSource{k}=out.templateSource; end
if isfield(out,'templateUpdated'), r.templateUpdated(k)=out.templateUpdated; end
end
function r=trim_real_result(r,n)
fields=fieldnames(r); for k=1:numel(fields), value=r.(fields{k}); if isnumeric(value)||islogical(value), r.(fields{k})=value(1:n,:); elseif iscell(value), r.(fields{k})=value(1:n,:); end, end
end

function outputDir=prepare_real_output_directory(outputDir,projectRoot,clearPrevious)
% 首次运行自动创建目录；仅在 ROI 确认后调用，因此取消 ROI 不会清理结果。
outputDir=char(outputDir);
if isempty(outputDir), outputDir=fullfile(projectRoot,'outputs','real_data'); end
resolved=char(java.io.File(outputDir).getCanonicalPath());
root=char(java.io.File(fullfile(projectRoot,'outputs')).getCanonicalPath());
if strcmpi(resolved,root) || ~startsWith(lower(resolved),[lower(root) filesep])
    error('输出目录必须是当前 PLT 工程 outputs 下的专用子目录：%s',resolved);
end
if clearPrevious && isfolder(resolved)
    [ok,msg]=rmdir(resolved,'s');
    if ~ok, error('无法清理本次输出目录：%s',msg); end
end
if ~isfolder(resolved)
    [ok,msg]=mkdir(resolved);
    if ~ok, error('无法创建输出目录：%s（%s）',resolved,msg); end
end
outputDir=resolved;
end

function dVib=compute_real_residuals(videoPath,anchor,dMacro,cfg,~,processingScale)
% 第二次读取视频，确保 fine phase 使用完整宏观轨迹而非未来帧在线估计。
if nargin<6 || isempty(processingScale), processingScale=1; end
n=size(dMacro,1); dVib=zeros(n,2); if n<=1, return; end
vr=VideoReader(videoPath); if hasFrame(vr), readFrame(vr); end
progressEvery=max(1,round(n/20)); progressTimer=tic;
for k=2:n
    if ~hasFrame(vr), break; end
    frame=resize_for_processing(readFrame(vr),processingScale); pyramid=build_complex_gabor_pyramid(frame,cfg);
    residual=measure_residual_phase(anchor,pyramid,dMacro(k,:),cfg); dVib(k,:)=residual.dVib;
    if mod(k-1,progressEvery)==0 || k==n
        fprintf('V2 residual progress: %d/%d frames (%.1f%%), elapsed %.1f min\n', ...
            k,n,100*k/n,toc(progressTimer)/60);
    end
end
end

function frame=resize_for_processing(frame,processingScale)
if abs(processingScale-1)<eps, return; end
frame=imresize(frame,processingScale,'bilinear');
end

function scaledRoi=scale_roi_for_processing(roi,processingScale,imageSize)
scaledRoi=[round((roi(1)-1)*processingScale)+1,round((roi(2)-1)*processingScale)+1,...
    max(8,round(roi(3)*processingScale)),max(8,round(roi(4)*processingScale))];
scaledRoi=clamp_roi_local(scaledRoi,imageSize);
end

function points=scale_points_to_original(points,processingScale)
points=(double(points)-0.5)/processingScale+0.5;
end

function result=scale_real_result_to_original(result,processingScale)
if abs(processingScale-1)<eps, return; end
result.center=scale_points_to_original(result.center,processingScale);
result.integerCenter=scale_points_to_original(result.integerCenter,processingScale);
result.subpixel=result.subpixel/processingScale;
end

function coordinate=scale_coordinate_to_original(coordinate,processingScale)
if abs(processingScale-1)<eps, return; end
fields={'dTotal','dMacro','dCrop','residual','reconstructed'};
for k=1:numel(fields)
    coordinate.(fields{k})=coordinate.(fields{k})/processingScale;
end
end

function roi=clamp_roi_local(roi,imageSize)
roi=double(roi(:).'); roi(1:2)=max(1,roi(1:2)); roi(3:4)=max(1,roi(3:4));
roi(3)=min(roi(3),imageSize(1)-roi(1)+1); roi(4)=min(roi(4),imageSize(2)-roi(2)+1); roi=floor(roi);
end
