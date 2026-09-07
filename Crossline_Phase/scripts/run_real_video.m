function run_real_video(inputCfg)
%RUN_REAL_VIDEO 使用 Crossline Phase 方法处理一个真实视频。
% 用户只需修改本文件顶部的 videoPath、ROI、帧率和帧数配置。
% 双击或 Enter 确认 ROI；Esc 取消并退出。结果为整帧 image-plane 位移。
close all; clc;

scriptPath=fileparts(mfilename('fullpath'));
projectRoot=fileparts(scriptPath);
addpath(fullfile(projectRoot,'config'));
addpath(genpath(fullfile(projectRoot,'src')));
addpath(genpath(fullfile(projectRoot,'simulation')));
addpath(genpath(fullfile(projectRoot,'third_party','matlabPyrTools')));

% ========================== 用户配置区 ===============================
if nargin<1 || isempty(inputCfg)
    cfg=config_default(projectRoot);
    cfg.real.videoPath= 'D:\07-26_single\man-qiao.avi';                     % 修改为真实视频绝对路径
    cfg.real.outputName= 'D:\LunFu\Crossline_Phase\outputs\07-26_single\man-qiao';
    cfg.real.roi= [];                           % [] 首帧交互；或 [x y width height]
    cfg.real.maxFrames= Inf;                    % Inf 处理全部可读帧
    cfg.real.fpsOverride= 100;                   % [] 使用视频元数据帧率
    cfg.real.writeTrackingVideo= false;         % 论文未要求，默认不写过程视频
else
    cfg=inputCfg;
end
% 加速模式只将相位零交叉搜索的过采样从 4 改为 2；核心 Gabor/phase/求交公式不变。
% 在本工程测试样本上，两种设置的中心差异小于 0.009 pixel。
if ~isfield(cfg.real,'fastMode'), cfg.real.fastMode=true; end
if cfg.real.fastMode, cfg.method.phaseOversampling=2; end
% ================================================================

if isempty(cfg.real.videoPath) || ~isfile(cfg.real.videoPath)
    error('Crossline:Input','请先在 run_real_video.m 顶部填写有效的 cfg.real.videoPath。');
end
vr=VideoReader(cfg.real.videoPath); videoFps=vr.FrameRate; if isempty(cfg.real.fpsOverride), fps=videoFps; else, fps=cfg.real.fpsOverride; end
[roi,firstFrame,firstCrop,cancelled]=select_video_roi(cfg.real.videoPath,cfg.real.roi,'Crossline Phase - ROI 选择');
if cancelled, fprintf('ROI 已取消，未清理或写入本次输出目录。\n'); return; end

% ROI 确认后才创建本次输出目录，保护上一次结果和原始视频。
stamp=char(datetime('now','Format','yyyyMMdd_HHmmss'));
if ~isempty(fileparts(cfg.real.outputName))
    outputBase=cfg.real.outputName;
else
    outputBase=fullfile(cfg.real.outputDirectory,cfg.real.outputName);
end
outDir=[outputBase '_' stamp]; if ~isfolder(outDir), mkdir(outDir); end
cfg.real.actualRoi=roi; cfg.real.videoFps=videoFps; cfg.real.processingFps=fps; cfg.real.outputDirectory=outDir;
if ~isfield(cfg.real,'rejectLargeJumps'), cfg.real.rejectLargeJumps=true; end
if ~isfield(cfg.real,'useVelocityPrediction'), cfg.real.useVelocityPrediction=false; end
if ~isfield(cfg.real,'maxFrameJumpPx') || isempty(cfg.real.maxFrameJumpPx), maxFrameJumpPx=roi(3)/4; else, maxFrameJumpPx=cfg.real.maxFrameJumpPx; end
imwrite(firstCrop,fullfile(outDir,'01_initial_roi.png')); save(fullfile(outDir,'run_config.mat'),'cfg');

% 预分配少量空间并动态扩展，保存 local/global 坐标及每帧几何参数。
capacity=1000; frame=zeros(capacity,1); time=zeros(capacity,1); roiTrajectory=NaN(capacity,4); localCenter=NaN(capacity,2); globalCenter=NaN(capacity,2); roughCenter=NaN(capacity,2); angles=NaN(capacity,2); widths=NaN(capacity,2); lengths=NaN(capacity,2); valid=false(capacity,1); jumpPx=NaN(capacity,1); runtime=zeros(capacity,1);
lastGlobal=[roi(1)-1+roi(3)/2,roi(2)-1+roi(4)/2]; velocity=[0 0]; currentRoi=roi; k=0; vr=VideoReader(cfg.real.videoPath); readFrame(vr); % 首帧已由 ROI 选择函数读取，这里同步推进读取器
while k < cfg.real.maxFrames
    tic;
    if k==0, fullFrame=firstFrame; else, if ~hasFrame(vr), break; end; fullFrame=readFrame(vr); end
    if k>0
        % 用上一帧速度预测搜索窗口，降低大运动时 ROI 因偶发误检而逐步漂移的概率。
        % 这只影响下一帧搜索位置，不对输出轨迹做平滑或插值。
        cropCenter=lastGlobal;
        if cfg.real.rejectLargeJumps && cfg.real.useVelocityPrediction, cropCenter=lastGlobal+velocity; end
        [crop,currentRoi]=crop_square_from_frame(fullFrame,cropCenter,roi(3));
    else, crop=firstCrop; end
    r=crossline_process_frame(crop,cfg); k=k+1;
    if k>capacity
        grow=capacity; frame(end+1:end+grow)=0; time(end+1:end+grow)=0; roiTrajectory(end+1:end+grow,:)=NaN; localCenter(end+1:end+grow,:)=NaN; globalCenter(end+1:end+grow,:)=NaN; roughCenter(end+1:end+grow,:)=NaN; angles(end+1:end+grow,:)=NaN; widths(end+1:end+grow,:)=NaN; lengths(end+1:end+grow,:)=NaN; valid(end+1:end+grow)=false; jumpPx(end+1:end+grow)=NaN; runtime(end+1:end+grow)=0; capacity=capacity+grow;
    end
    frame(k)=k; time(k)=(k-1)/fps; roiTrajectory(k,:)=currentRoi; runtime(k)=toc;
    if r.geometry.valid
        roughCenter(k,:)=r.geometry.roughCenter; angles(k,:)=r.geometry.lineAnglesDeg; widths(k,:)=r.geometry.lineWidthsPx; lengths(k,:)=r.geometry.lineLengthsPx;
    end
    if r.valid
        candidateGlobal=local_to_global(r.center,currentRoi); referenceGlobal=lastGlobal;
        if k>1 && cfg.real.rejectLargeJumps && cfg.real.useVelocityPrediction, referenceGlobal=lastGlobal+velocity; end
        jumpPx(k)=norm(candidateGlobal-referenceGlobal);
        if k>1 && cfg.real.rejectLargeJumps && jumpPx(k)>maxFrameJumpPx
            r.valid=false; r.message=sprintf('帧间跳变 %.2f px 超过 %.2f px，保留上一帧 ROI 中心。',jumpPx(k),maxFrameJumpPx);
        else
            localCenter(k,:)=r.center; globalCenter(k,:)=candidateGlobal;
            if k>1, velocity=candidateGlobal-lastGlobal; end
            lastGlobal=globalCenter(k,:);
        end
    end
    valid(k)=r.valid;
    if cfg.real.saveProcessImages && k==1 && r.valid
        pf=plot_process_result(crop,r,'Crossline first-frame processing'); save_figure_pair(pf,fullfile(outDir,'02_first_frame_process')); savefig(pf,fullfile(outDir,'02_first_frame_process.fig')); close(pf);
    end
end
frame=frame(1:k); time=time(1:k); roiTrajectory=roiTrajectory(1:k,:); localCenter=localCenter(1:k,:); globalCenter=globalCenter(1:k,:); roughCenter=roughCenter(1:k,:); angles=angles(1:k,:); widths=widths(1:k,:); lengths=lengths(1:k,:); valid=valid(1:k); jumpPx=jumpPx(1:k); runtime=runtime(1:k);
if k<2, error('Crossline:Frames','视频中可处理帧数不足。'); end
if ~any(valid)
    error('Crossline:Detection','所有帧均未定位到 crossline 中心。该方法要求 ROI 内存在清晰、高对比度的白色十字标记；请检查 ROI、照明和标记，或改用自然纹理跟踪方法。');
end

trajectoryTable=table(frame,time,roiTrajectory(:,1),roiTrajectory(:,2),roiTrajectory(:,3),roiTrajectory(:,4),jumpPx, ...
    localCenter(:,1),localCenter(:,2),globalCenter(:,1),globalCenter(:,2),roughCenter(:,1),roughCenter(:,2), ...
    angles(:,1),angles(:,2),widths(:,1),widths(:,2),lengths(:,1),lengths(:,2),valid,runtime, ...
    'VariableNames',{'frame','time_s','roi_x','roi_y','roi_width','roi_height','jump_from_previous_px','local_x','local_y','global_x','global_y','rough_x','rough_y','line_angle1_deg','line_angle2_deg','line_width1_px','line_width2_px','line_length1_px','line_length2_px','valid','runtime_s'});
writetable(trajectoryTable,fullfile(outDir,'crossline_trajectory.csv'));
runtimeSummary=struct('mean_s_per_frame',mean(runtime,'omitnan'),'median_s_per_frame',median(runtime,'omitnan'), ...
    'p95_s_per_frame',prctile(runtime,95),'throughput_fps',1/mean(runtime,'omitnan'), ...
    'fastMode',cfg.real.fastMode,'phaseOversampling',cfg.method.phaseOversampling, ...
    'rejectLargeJumps',cfg.real.rejectLargeJumps,'maxFrameJumpPx',maxFrameJumpPx); %#ok<NASGU>
save(fullfile(outDir,'crossline_results.mat'),'cfg','trajectoryTable','valid','globalCenter','localCenter','roiTrajectory','runtimeSummary','-v7.3');
write_real_output_readme(outDir,cfg.real.videoPath,roi,fps,k,mean(valid),runtimeSummary);
meta=struct('videoName',get_video_name(cfg.real.videoPath),'roi',roi,'videoFps',videoFps, ...
    'processingFps',fps,'expectedFrequenciesHz',get_expected_frequencies(cfg));
[waveFig,spectrumFig,spectrum]=plot_real_results(time,globalCenter,valid,fps,outDir,meta); %#ok<ASGLU>
save(fullfile(outDir,'crossline_spectrum.mat'),'spectrum');
fprintf('真实视频处理完成：%d 帧，valid rate %.2f%%\n结果目录：%s\n',k,100*mean(valid),outDir);
fprintf('平均单帧 %.4f s，吞吐 %.2f fps（fastMode=%d）\n',runtimeSummary.mean_s_per_frame,runtimeSummary.throughput_fps,cfg.real.fastMode);
end

function name=get_video_name(videoPath)
[~,name,ext]=fileparts(videoPath); name=[name ext];
end
function f=get_expected_frequencies(cfg)
if isfield(cfg.real,'expectedFrequenciesHz'), f=cfg.real.expectedFrequenciesHz; else, f=[]; end
end
