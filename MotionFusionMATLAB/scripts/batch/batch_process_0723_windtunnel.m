%% 0723风洞视频批处理：主方法配置与视频清单
% 说明：本脚本调用项目自己的 run_real_video，不修改核心算法输出。
% 逐行注释 videoFiles 中的路径即可控制本轮运行哪些视频。
close all; clearvars; clc;
scriptRoot=fileparts(mfilename('fullpath'));
projectRoot=fileparts(fileparts(scriptRoot));
addpath(fullfile(projectRoot,'src'));

%% 1. 输入视频与批处理输出
videoFiles={ ...
    'D:\实验室\风洞项目\0723单目\1-0-1.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-0-2.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-0-3.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-30-1-q.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-30-1-t.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-30-2-q.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-32-1-q.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-32-1-t.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-32-1-w.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-32-2-q.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-33-1-q.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-33-1-t.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-33-1-w.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-33-2-q.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-33-2-t.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-33-2-w.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-33-3-q.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-33-3-t.mp4', ...
    'D:\实验室\风洞项目\0723单目\1-33-3-w.mp4', ...
    'D:\实验室\风洞项目\0723单目\xinjiasuduji\2-0-1.mp4', ...
    'D:\实验室\风洞项目\0723单目\xinjiasuduji\2-0-2.mp4', ...
    'D:\实验室\风洞项目\0723单目\xinjiasuduji\2-0-3.mp4', ...
    'D:\实验室\风洞项目\0723单目\xinjiasuduji\2-0-4.mp4', ...
    'D:\实验室\风洞项目\0723单目\xinjiasuduji\2-33-1-q.mp4', ...
    'D:\实验室\风洞项目\0723单目\xinjiasuduji\2-33-1-t.mp4', ...
    'D:\实验室\风洞项目\0723单目\xinjiasuduji\2-33-1-w.mp4', ...
    'D:\实验室\风洞项目\0723单目\xinjiasuduji\2-33-2-q.mp4', ...
    'D:\实验室\风洞项目\0723单目\xinjiasuduji\2-33-2-t.mp4', ...
    'D:\实验室\风洞项目\0723单目\xinjiasuduji\2-33-2-w.mp4', ...
    'D:\实验室\风洞项目\0723单目\xinjiasuduji\2-33-3-q.mp4', ...
    'D:\实验室\风洞项目\0723单目\xinjiasuduji\2-33-3-t.mp4', ...
    'D:\实验室\风洞项目\0723单目\xinjiasuduji\2-33-3-w.mp4', ...
    'D:\实验室\风洞项目\0723单目\xinjiasuduji\jiujiasudujiweizhi.mp4', ...
    'D:\实验室\风洞项目\0723单目\xinjiasuduji\shoujidoudong.mp4' ...
};
outputRoot=fullfile(projectRoot,'outputs','batch_0723_windtunnel');

%% 2. 第一帧目标 ROI（与参考 ROI 配置相互独立）
% 每个视频运行时交互框选；也可以改成manual并填写targetROI。
roiMode='interactive';                 % interactive框选 / manual手填 / saved读取
targetROI=[];                           % manual时：[x y width height]
roiSource='';                           % saved时：ROI文件路径

%% 3. 宏观运动参考
referenceModel='translation';           % translation一个参考 / similarity至少两个参考 / none无参考
referenceSelection='interactive';      % interactive框选参考 / manual使用referenceROIs
referenceROIs=[];                       % manual时每行一个[x y width height]
% none只输出目标总位移；translation用于目标与一个刚性参考的相对位移。

%% 4. 图像配准（所有视频使用同一配置）
targetMode='direct';                    % direct一致目标配准 / profile旧方法 / consensus实验 / texture双向
referenceTracker='flow';                % flow双向光流参考 / anchor旧固定模板
axis='x';                               % 按物理方向选择x或y
captureFPS=[];                          % []使用视频元数据；明确填写时使用指定采样率
maxFrames=Inf;                          % Inf处理完整视频；可填整数做快速检查
maxSamples=6500;                        % 固定通用设置，不随视频名称变化
autoProfileRows=true;                   % 仅用第一帧确定目标测量支持

%% 5. 输出（主结果保持原始测量）
analysisBandHz=[];                     % []不带通；明确设置频带才生成额外诊断图
denoise=false;                          % 保持false；启用时必须先填写analysisBandHz
showFigures=true;                       % 保存的FIG保持visible=on
exportFigures=true;
exportTrackingVideo=false;              % 独立追踪视频，不计入算法耗时

%% 6. 批处理执行
for k=1:numel(videoFiles)
    videoPath=videoFiles{k};
    if ~isfile(videoPath), warning('跳过不存在的视频：%s',videoPath); continue; end
    [~,name]=fileparts(videoPath);
    fprintf('\n=== [%d/%d] %s ===\n',k,numel(videoFiles),name);
    u=mfm.real_defaults();
    u.videoPath=videoPath; u.outputRoot=outputRoot;
    u.captureFPS=captureFPS; u.maxFrames=maxFrames; u.axis=axis;
    u.roiMode=roiMode; u.targetROI=targetROI; u.roiSource=roiSource;
    u.referenceModel=referenceModel; u.referenceSelection=referenceSelection; u.referenceROIs=referenceROIs;
    u.targetMode=targetMode; u.referenceTracker=referenceTracker;
    u.autoProfileRows=autoProfileRows; u.maxSamples=maxSamples;
    u.analysisBandHz=analysisBandHz; u.denoise=denoise;
    u.showFigures=showFigures; u.exportFigures=exportFigures; u.exportTrackingVideo=exportTrackingVideo;
    result=run_real_video(u);
    write_acceleration_outputs(result,fullfile(outputRoot,name),name);
end
fprintf('\n0723批处理完成；加速度结果位于每个视频文件夹的 batch_acceleration 子文件夹。\n');

function write_acceleration_outputs(result,outDir,name)
% 加速度只在本批处理脚本中计算，不改变核心方法的输出文件。
if ~isfield(result,'relative') || isempty(result.relative), warning('没有位移结果：%s',name); return; end
axisId=1;
if isfield(result,'cfg') && isfield(result.cfg,'axis') && strcmp(result.cfg.axis,'y'), axisId=2; end
x=double(result.relative(:,axisId)); fs=result.fps; valid=isfinite(x);
if nnz(valid)<4, warning('有效样本不足，无法计算加速度：%s',name); return; end
t=(0:numel(x)-1)'/fs; x=fillmissing(x,'linear','EndValues','nearest');
velocity=gradient(x,1/fs); acceleration=gradient(velocity,1/fs); acceleration(~valid)=NaN;
folder=fullfile(outDir,'batch_acceleration'); if ~isfolder(folder), mkdir(folder); end
fig=figure('Visible','on','Color','w');
plot(t,acceleration,'LineWidth',1); grid on; xlabel('Time (s)'); ylabel('Acceleration (px/s^2)');
title([name ' acceleration'],'Interpreter','none');
savefig(fig,fullfile(folder,'acceleration_time.fig')); exportgraphics(fig,fullfile(folder,'acceleration_time.png')); close(fig);
[a,f]=one_sided_spectrum(acceleration,fs); ref=max(a); if ref>0, an=a/ref; else, an=zeros(size(a)); end
fig=figure('Visible','on','Color','w'); plot(f,an,'LineWidth',1); grid on;
xlabel('Frequency (Hz)'); ylabel('Normalized amplitude'); title([name ' normalized acceleration spectrum'],'Interpreter','none'); xlim([0 fs/2]);
savefig(fig,fullfile(folder,'acceleration_spectrum_normalized.fig')); exportgraphics(fig,fullfile(folder,'acceleration_spectrum_normalized.png')); close(fig);
save(fullfile(folder,'acceleration.mat'),'t','x','velocity','acceleration','f','a','an','fs','valid','-v7');
end
function [a,f]=one_sided_spectrum(x,fs)
z=x(:); z(~isfinite(z))=0; z=z-mean(z); n=numel(z); nfft=2^nextpow2(max(n,2)); w=hann(n);
y=fft(z.*w,nfft); a=abs(y(1:nfft/2+1))/max(sum(w),eps)*2; a(1)=a(1)/2; f=(0:nfft/2)'*fs/nfft;
end
