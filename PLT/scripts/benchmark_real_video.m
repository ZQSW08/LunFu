function benchmark_real_video()
% BENCHMARK_REAL_VIDEO 测量 V3 真实视频前端的主要耗时。
% 该脚本不弹 ROI 框，使用配置区的 ROI；ROI=[] 时自动取首帧中央区域。
% 目的仅是回答“时间花在哪里”，不把运行时间结果当作精度结论。

close all; clc;
scriptPath=mfilename('fullpath'); projectRoot=fileparts(fileparts(scriptPath));
srcDir=fullfile(projectRoot,'src'); addpath(srcDir,'-begin');
cfg=default_config(projectRoot); setup_project(cfg);

%% 用户配置区
cfg.video.path='D:\07-26_single\man-qiao.avi';
cfg.video.maxFrames=25;                 % 仅用于速度标定
cfg.video.processingScale=0.5;
cfg.video.roi=[];                       % [] 自动取中央 ROI；正式处理仍由 run_real_video 交互选择
cfg.method.observedAxis='x';
outputDir=fullfile(projectRoot,'outputs','runtime_benchmark');
if isfolder(outputDir), rmdir(outputDir,'s'); end
mkdir(outputDir);

if ~isfile(cfg.video.path), error('找不到视频：%s',cfg.video.path); end
vr=VideoReader(cfg.video.path); firstFrame=readFrame(vr);
scale=cfg.video.processingScale; firstProc=resize_for_benchmark(firstFrame,scale);
if isempty(cfg.video.roi)
    h=size(firstFrame,1); w=size(firstFrame,2); roi=[floor((w-240)/2)+1,floor((h-180)/2)+1,240,180];
else
    roi=cfg.video.roi;
end
roi=scale_roi(roi,scale,size(firstProc));
procCfg=cfg; procCfg.method.wavelengthsPx=cfg.method.wavelengthsPx*scale;
procCfg.method.localSearchRadiusPx=max(2,cfg.method.localSearchRadiusPx*scale);
procCfg.method.subpixelMaxPx=cfg.method.subpixelMaxPx*scale;
procCfg.method.maxPocJumpPx=cfg.method.maxPocJumpPx*scale;
state=initialize_phase_tracker(firstProc,roi,procCfg);
n=max(1,round(cfg.video.maxFrames));
tPyramid=zeros(n-1,1); tTrack=zeros(n-1,1); tTotal=tic; count=1;
while hasFrame(vr) && count<n
    count=count+1; frame=resize_for_benchmark(readFrame(vr),scale);
    ticP=tic; pyramid=build_complex_gabor_pyramid(frame,procCfg); tPyramid(count-1)=toc(ticP);
    ticT=tic; [state,~]=track_one_frame(state,frame,procCfg,'v3_predictive',pyramid); tTrack(count-1)=toc(ticT);
end
tTotalValue=toc(tTotal); tPyramid=tPyramid(1:count-1); tTrack=tTrack(1:count-1);
if count>1
    summary=table(count,tTotalValue,mean(tPyramid),median(tPyramid),mean(tTrack),median(tTrack),...
        count/tTotalValue,1/mean(tPyramid+tTrack),scale,string(cfg.method.observedAxis),...
        'VariableNames',{'frames','total_s','mean_pyramid_s','median_pyramid_s','mean_track_s','median_track_s','frames_per_total_s','frames_per_core_s','processing_scale','observed_axis'});
else
    summary=table(count,tTotalValue,NaN,NaN,NaN,NaN,NaN,NaN,scale,string(cfg.method.observedAxis),...
        'VariableNames',{'frames','total_s','mean_pyramid_s','median_pyramid_s','mean_track_s','median_track_s','frames_per_total_s','frames_per_core_s','processing_scale','observed_axis'});
end
writetable(summary,fullfile(outputDir,'runtime_benchmark.csv'));
save(fullfile(outputDir,'runtime_benchmark.mat'),'summary','tPyramid','tTrack','cfg');
fprintf('V3 benchmark: %d frames, total %.3f s, pyramid mean %.3f s, tracking mean %.3f s\n',...
    count,tTotalValue,mean(tPyramid),mean(tTrack));
fprintf('Core throughput: %.3f frames/s\n',summary.frames_per_core_s);
fprintf('Outputs: %s\n',outputDir);
end

function frame=resize_for_benchmark(frame,scale)
if abs(scale-1)>eps, frame=imresize(frame,scale,'bilinear'); end
end
function roi=scale_roi(roi,scale,imageSize)
roi=[round((roi(1)-1)*scale)+1,round((roi(2)-1)*scale)+1,max(8,round(roi(3)*scale)),max(8,round(roi(4)*scale))];
roi(1)=min(max(1,roi(1)),imageSize(2)-roi(3)+1); roi(2)=min(max(1,roi(2)),imageSize(1)-roi(4)+1);
end
