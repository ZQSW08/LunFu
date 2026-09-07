function out = run_tddm_real_video(config)
%RUN_TDDM_REAL_VIDEO 按论文 TDDM 流程处理真实视频。
% 论文明确：37x37 模板、NCC=0.60、偏心率<0.70、KLT+检测+affine IC-GN。
% 实现推断：真实视频的标记像素直径、ROI 和像素标定需由用户提供或框选。
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(genpath(fullfile(root,'src'))); addpath(genpath(fullfile(root,'config')));
if ~isstruct(config) || ~isfield(config,'videoPath') || ~isfile(config.videoPath)
    error('config.videoPath 不存在。');
end

cfg=paper_config();
cfg.paper.templateSize=37; cfg.paper.nccGate=0.60; cfg.paper.eccentricityMax=0.70;
cfg.impl.realMarkerDiameterPx=get_field(config,'markerDiameterPx',8);
cfg.impl.icgnModel='affine'; cfg.impl.icgnEngine='native';
cfg.impl.useZNNormalization=true; cfg.impl.useForwardBackward=true;
cfg.impl.enableTracking=true; cfg.impl.enableDetection=true; cfg.impl.enableICGN=true;
cfg.impl.detectorMode=get_field(config,'detectorMode','texture');
cfg.impl.textureSearchRadiusPx=get_field(config,'textureSearchRadiusPx',8);
cfg.video.progressEveryFrames=max(0,round(get_field(config,'progressEveryFrames',25)));
cfg.video.showProgress=logical(get_field(config,'showProgress',true));
if get_field(config,'useADIC2D',false), cfg.impl.icgnEngine='adic2d'; end
cfg.tddmRealVideo=struct('templateSize',37,'nccGate',0.60,'eccentricityMax',0.70, ...
    'referenceFrame','first','coordinateOrder','[x,y]=[column,row]');

video=VideoReader(config.videoPath); videoFps=video.FrameRate;
processingFps=get_field(config,'fpsOverride',[]); if isempty(processingFps), processingFps=videoFps; end
% 真实视频的时长和帧率元数据可能高估帧数，这里统计实际可读帧数。
maxFrames=get_field(config,'maxFrames',Inf);
actualFrameCount=video_frame_count(config.videoPath,maxFrames);
frameIndices=choose_frames(actualFrameCount,maxFrames);
% 主流程按顺序读取，避免 VideoReader 每帧随机 seek 造成明显变慢。
% 首帧预览会消耗一个顺序流，因此正式处理前重新建立流。
probeSource=video_to_sequential_stream(config.videoPath,frameIndices);
firstFrame=read_gray(probeSource.getFrame(1));

% 首帧 ROI 确认前不清理旧结果。
presetROI=get_field(config,'roi',[]);
if isempty(presetROI) && get_field(config,'selectROI',true)
    [roi,~,firstCrop,cancelled]=select_video_roi(config.videoPath,[], 'TDDM - select marker ROI');
    if cancelled, out=struct('cancelled',true,'videoPath',config.videoPath); return; end
else
    [roi,firstCrop,cancelled]=sanitize_roi(presetROI,firstFrame);
    if cancelled, out=struct('cancelled',true,'videoPath',config.videoPath); return; end
end

outputRoot=resolve_output_root(config,root);
if get_field(config,'clearPreviousResults',true), safe_clear_output(outputRoot,root); end
if ~isfolder(outputRoot), mkdir(outputRoot); end
cfg.impl.outputRoot=outputRoot;
save_roi_inputs(firstFrame,firstCrop,roi,fullfile(outputRoot,'01_roi_selection.png'), ...
    fullfile(outputRoot,'02_roi_first_frame.png'));
write_fixed_roi_csv(roi,numel(frameIndices),fullfile(outputRoot,'roi_trajectory.csv'));

centerHint=roi(1:2)+[roi(3)-1 roi(4)-1]/2;
if strcmpi(cfg.impl.detectorMode,'texture')
    center=centerHint;
else
    d=detect_marker(firstCrop,cfg.impl.realMarkerDiameterPx,cfg,[size(firstCrop,2)/2 size(firstCrop,1)/2]);
    if isempty(d), center=centerHint; else, center=roi(1:2)-1+d.center; end
end
initialROI=[center(1)-cfg.impl.realMarkerDiameterPx center(2)-cfg.impl.realMarkerDiameterPx ...
    2*cfg.impl.realMarkerDiameterPx 2*cfg.impl.realMarkerDiameterPx];

processFrames=get_field(config,'processFrames',[]);
if isempty(processFrames), processFrames=unique([2 round(numel(frameIndices)/2) numel(frameIndices)]); end
processFrames=unique(round(processFrames(:)'));
processFrames=processFrames(processFrames>=2 & processFrames<=numel(frameIndices));
cfg.impl.saveProcess=get_field(config,'saveProcess',true); cfg.impl.processFrames=processFrames;
cfg.impl.processOutputRoot=fullfile(outputRoot,'process');
source=video_to_sequential_stream(config.videoPath,frameIndices);
trace=run_tddm(source,center,initialROI,cfg);
if get_field(config,'followROI',true)
    followRects=roi_follow_trajectory(trace,roi,size(firstFrame));
else
    followRects=repmat(roi,numel(trace),1);
end
out=struct('cancelled',false,'source','real_video','videoPath',config.videoPath, ...
    'videoFps',videoFps,'processingFps',processingFps,'frameIndices',frameIndices, ...
    'frameCount',source.count,'roi',roi,'initialCenter',center,'initialROI',initialROI, ...
    'config',cfg,'userConfig',config,'tddm',trace,'roiTrajectory',followRects,'outputRoot',outputRoot);
write_local_roi_csv(trace,cfg.impl.realMarkerDiameterPx,firstFrame, ...
    fullfile(outputRoot,'tddm_local_roi_trajectory.csv'));
write_follow_roi_csv(followRects,trace,fullfile(outputRoot,'roi_follow_trajectory.csv'));
write_tddm_trace_csv(trace,fullfile(outputRoot,'tddm_trace.csv'));

if get_field(config,'writeROIVideo',true)
    out.roiVideoPath=fullfile(outputRoot,'03_roi_follow_cropped_video.avi');
    cropSource=video_to_sequential_stream(config.videoPath,frameIndices);
    [out.roiVideoWritten,out.roiVideoError]=write_roi_video(cropSource,followRects,processingFps,out.roiVideoPath);
end
if get_field(config,'writeTrackingVideo',true)
    out.trackingVideoPath=fullfile(outputRoot,'04_roi_follow_tracking_video.avi');
    trackSource=video_to_sequential_stream(config.videoPath,frameIndices);
    [out.trackingVideoWritten,out.trackingVideoError]=write_tracking_video(trackSource,trace,followRects,processingFps,out.trackingVideoPath);
end
if get_field(config,'runBaselines',false)
    kltSource=video_to_sequential_stream(config.videoPath,frameIndices);
    detSource=video_to_sequential_stream(config.videoPath,frameIndices);
    out.klt=run_klt_sequence(kltSource,center,initialROI,cfg);
    out.detection=run_detection_sequence(detSource,center,cfg.impl.realMarkerDiameterPx,cfg);
    write_baseline_csv(out,fullfile(outputRoot,'baseline_trace.csv'));
end

axesToAnalyze=normalize_axes(get_field(config,'analysisAxes','y'));
out.analysis=struct();
for k=1:numel(axesToAnalyze)
    label=axesToAnalyze{k}; axisIndex=double(label=='y')+1;
    wave=make_waveform_axis(out,center,axisIndex,get_field(config,'pxPerMM',NaN),label);
    rawWaveform=wave.value;
    specInput=fill_missing_for_spectrum(rawWaveform);
    spec=frequency_analysis(specInput,processingFps);
    spec.validFraction=mean(isfinite(rawWaveform));
    spec.interpolatedForSpectrum=any(~isfinite(rawWaveform));
    spec.plotMaxHz=min(get_field(config,'spectrumMaxHz',spec.nyquistHz),spec.nyquistHz);
    spec.plotLegend=get_field(config,'spectrumLegend','TDDM visual displacement');
    wave.rawValue=rawWaveform;
    wave.spectrumInput=specInput;
    out.analysis.(label)=struct('waveform',wave,'spectrum',spec);
    write_waveform_csv(wave,fullfile(outputRoot,sprintf('04_tddm_%s_waveform.csv',label)));
    write_spectrum_csv(spec,fullfile(outputRoot,sprintf('05_tddm_%s_spectrum.csv',label)));
    save_signal_figures(wave,spec,label,fullfile(outputRoot,sprintf('06_tddm_%s_waveform.png',label)), ...
        fullfile(outputRoot,sprintf('06_tddm_%s_waveform.fig',label)),fullfile(outputRoot,sprintf('07_tddm_%s_spectrum.png',label)), ...
        fullfile(outputRoot,sprintf('07_tddm_%s_spectrum.fig',label)));
end
% 兼容旧字段：waveform/spectrum 指向第一个所选方向。
out.waveform=out.analysis.(axesToAnalyze{1}).waveform;
out.spectrum=out.analysis.(axesToAnalyze{1}).spectrum;
plot_real_video(out,fullfile(outputRoot,'08_tddm_summary.png'));
save(fullfile(outputRoot,'tddm_results.mat'),'out');
end

function value=get_field(s,name,default)
if isfield(s,name) && ~isempty(s.(name)), value=s.(name); else, value=default; end
end
function idx=choose_frames(n,maxFrames)
if isempty(maxFrames) || isinf(maxFrames), idx=1:n; else, idx=1:min(n,max(1,round(maxFrames))); end
end
function I=read_gray(I)
if size(I,3)==3, I=rgb2gray(I); end
I=im2double(I);
end
function [roi,crop,cancelled]=sanitize_roi(roi,I)
cancelled=false; if isempty(roi) || numel(roi)~=4, error('config.roi 必须为 [x y width height]。'); end
roi=double(roi(:)'); x=max(1,round(roi(1))); y=max(1,round(roi(2)));
w=min(round(roi(3)),size(I,2)-x+1); h=min(round(roi(4)),size(I,1)-y+1);
if w<8 || h<8, error('ROI 太小或完全越界。'); end
roi=[x y w h]; crop=I(y:y+h-1,x:x+w-1,:);
end
function outRoot=resolve_output_root(config,root)
% outputDirectory 只要被显式填写，就把它视为“本次运行目录”。
% 这样 config.outputDirectory=...\1-1 时不会再次拼接 outputName=1-1。
parent=get_field(config,'outputDirectory','');
if ~isempty(parent)
    outRoot=char(parent);
    return;
end
base=get_field(config,'outputName',''); if isempty(base), [~,base]=fileparts(config.videoPath); end
base=regexprep(base,'[^A-Za-z0-9_-]','_');
outRoot=fullfile(root,'results','real_video',base);
end
function safe_clear_output(target,root)
resultsRoot=char(fullfile(root,'results')); target=char(target);
if ~startsWith(lower(target),[lower(resultsRoot) filesep]), error('输出目录必须位于当前 TDDM/results 下。'); end
if isfolder(target), rmdir(target,'s'); end
end
function save_roi_inputs(I,crop,roi,selectionPath,cropPath)
fig=figure('Visible','off','Color','w'); imshow(I,[]); hold on; rectangle('Position',roi,'EdgeColor','r','LineWidth',1.5); title('TDDM ROI selection');
exportgraphics(fig,selectionPath,'Resolution',180); close(fig);
fig=figure('Visible','off','Color','w'); imshow(crop,[]); title('TDDM cropped ROI / first frame'); exportgraphics(fig,cropPath,'Resolution',180); close(fig);
end
function write_fixed_roi_csv(roi,n,path)
T=table((1:n)',repmat(roi(1),n,1),repmat(roi(2),n,1),repmat(roi(3),n,1),repmat(roi(4),n,1), ...
    'VariableNames',{'frame','x','y','width','height'}); writetable(T,path);
end
function write_follow_roi_csv(rects,r,path)
p=vertcat(r.pFinal); n=size(rects,1);
T=table((1:n)',rects(:,1),rects(:,2),rects(:,3),rects(:,4),p(:,1),p(:,2), ...
    'VariableNames',{'frame','x','y','width','height','final_x','final_y'}); writetable(T,path);
end
function write_local_roi_csv(r,diameter,I,path)
pt=vertcat(r.pTracking); n=size(pt,1); side=max(37,round(3*diameter)); half=floor(side/2);
x=zeros(n,1); y=zeros(n,1); w=zeros(n,1); h=zeros(n,1);
for i=1:n
    x(i)=max(1,floor(pt(i,1)-half)); y(i)=max(1,floor(pt(i,2)-half));
    w(i)=min(side,size(I,2)-x(i)+1); h(i)=min(side,size(I,1)-y(i)+1);
end
T=table((1:n)',x,y,w,h,pt(:,1),pt(:,2),'VariableNames', ...
    {'frame','x','y','width','height','tracking_x','tracking_y'}); writetable(T,path);
end
function write_tddm_trace_csv(r,path)
% 保存 Tracking、Detection、Correction、IC-GN 的逐帧结果，便于审查中间过程。
pt=vertcat(r.pTracking); pd=vertcat(r.pDetection); pc=vertcat(r.pCorrected); pf=vertcat(r.pFinal);
T=table([r.frame]',pt(:,1),pt(:,2),pd(:,1),pd(:,2),pc(:,1),pc(:,2),pf(:,1),pf(:,2), ...
    [r.NCC_T]',[r.NCC_D]',[r.ZNSSD]',[r.ICGNIterations]',[r.ICGNConverged]', ...
    string({r.fusionMode})',string({r.failureReason})', ...
    'VariableNames',{'frame','tracking_x','tracking_y','detection_x','detection_y', ...
    'corrected_x','corrected_y','final_x','final_y','ncc_tracking','ncc_detection', ...
    'znssd','icgn_iterations','icgn_converged','fusion_mode','failure_reason'});
writetable(T,path);
end
function labels=normalize_axes(value)
if isstring(value), value=char(value); end
if ischar(value)
    value=lower(strtrim(value));
    if strcmp(value,'xy') || strcmp(value,'both'), labels={'x','y'}; else, labels={value}; end
else, labels=cellstr(value); end
if any(~ismember(labels,{'x','y'})), error('analysisAxes 只能为 x、y 或 xy。'); end
end
function values=fill_missing_for_spectrum(values)
values=double(values(:)); valid=isfinite(values);
if ~any(valid), values=zeros(size(values)); return; end
if any(~valid), t=(1:numel(values))'; values(~valid)=interp1(t(valid),values(valid),t(~valid),'linear','extrap'); end
end
function w=make_waveform_axis(out,center,axisIndex,pxPerMM,label)
r=out.tddm; p=vertcat(r.pFinal); value=p(:,axisIndex)-center(axisIndex); unit='pixel';
if isfinite(pxPerMM) && pxPerMM>0, value=value/pxPerMM; unit='mm'; end
w=struct('frame',(1:numel(value))','value',value,'unit',unit,'axis',label,'center',center(axisIndex));
end
function write_waveform_csv(w,path)
writetable(table(w.frame,w.value,'VariableNames',{'frame','displacement'}),path);
end
function write_spectrum_csv(s,path)
writetable(table(s.frequency,s.amplitude,s.normalizedAmplitude, ...
    'VariableNames',{'frequency_Hz','amplitude','normalized_amplitude'}),path);
end
function save_signal_figures(wave,spec,label,wavePNG,waveFIG,specPNG,specFIG)
fig=figure('Visible','off','Color','w','Position',[100 100 1000 420]); plot(wave.frame,wave.value,'k','LineWidth',0.8); grid on;
xlabel('Frame'); ylabel(['Displacement / ' wave.unit]); title(['TDDM ' upper(label) ' waveform']);
exportgraphics(fig,wavePNG,'Resolution',180); fig.Visible='on'; savefig(fig,waveFIG); close(fig);
fig=figure('Visible','off','Color','w','Position',[100 100 1000 420]);
plot(spec.frequency,spec.normalizedAmplitude,'k','LineWidth',0.9); grid on; box on;
xlim([0 spec.plotMaxHz]); ylim([0 1.02]); yticks(0:0.1:1);
xlabel('Frequency / Hz'); ylabel('Normalized amplitude');
title(['TDDM ' upper(label) '-direction displacement spectrum']);
legend(spec.plotLegend,'Location','northeast');
exportgraphics(fig,specPNG,'Resolution',180); fig.Visible='on'; savefig(fig,specFIG); close(fig);
end
function write_baseline_csv(out,path)
n=size(out.klt,1); writetable(table((1:n)',out.klt(:,1),out.klt(:,2),out.detection(:,1),out.detection(:,2), ...
    'VariableNames',{'frame','klt_x','klt_y','detection_x','detection_y'}),path);
end
function plot_real_video(out,path)
r=out.tddm; p=vertcat(r.pFinal); fig=figure('Visible','off','Color','w','Position',[80 80 1100 760]);
subplot(2,2,1); plot(p(:,1),'k'); grid on; xlabel('Frame'); ylabel('X / pixel'); title('TDDM X trajectory');
subplot(2,2,2); plot(p(:,2),'k'); grid on; xlabel('Frame'); ylabel('Y / pixel'); title('TDDM Y trajectory');
subplot(2,2,3); plot([r.NCC_T],'r'); hold on; plot([r.NCC_D],'b'); grid on; ylim([-1 1]); xlabel('Frame'); ylabel('NCC'); legend('Tracking','Detection'); title('NCC confidence');
subplot(2,2,4); plot([r.ZNSSD],'k'); grid on; xlabel('Frame'); ylabel('ZNSSD'); title('IC-GN matching error');
sgtitle('TDDM real-video result'); exportgraphics(fig,path,'Resolution',180); close(fig);
end
