%% 07-26_single 视频与三角光相对波形对比
% 本脚本只做测量完成后的独立评价，不参与ROI、跟踪、参数或频带选择。
% 三角光CSV没有时间列，因此按实验约定使用100 Hz，并在结果中记录这一假设。
close all; clearvars; clc;
scriptRoot=fileparts(mfilename('fullpath'));
projectRoot=fileparts(scriptRoot);
addpath(fullfile(projectRoot,'src'));

%% 1. 输入、输出与采样率
videoOutputRoot=fullfile(projectRoot,'outputs','batch_0726_single');
sensorRoot='E:\sanjiao\0726';
sensorFPS=100;                         % 三角光采样率：CSV无时间列，按实验约定100 Hz
videoAxis='x';                         % 与批处理脚本的测量方向保持一致
comparisonFolderName='comparison_0726';
showFigures=false;                     % 不弹出窗口；保存的FIG仍写成Visible=on

%% 2. 对齐与相对波形设置
% 三角光先采集、视频后录制；下面使用全局归一化互相关估计传感器领先样本数。
minOverlapFraction=0.60;               % 对齐至少保留这么多共同样本
removeLinearTrend=true;                % 对比前分别去除线性趋势，不做物理标定
allowPolarityFlip=true;                % 仅用于显示和相关性评价，不改变原始数据

%% 3. 扫描同名视频结果与三角光CSV
folders=dir(videoOutputRoot); folders=folders([folders.isdir]);
folders=folders(~ismember({folders.name},{'.','..','_history'}));
rows=struct([]);
for k=1:numel(folders)
    name=folders(k).name;
    resultDir=fullfile(videoOutputRoot,name);
    resultPath=fullfile(resultDir,'result.mat');
    sensorPath=fullfile(sensorRoot,[name '.csv']);
    if ~isfile(resultPath), fprintf('跳过 %s：没有result.mat。\n',name); continue; end
    if ~isfile(sensorPath), fprintf('跳过 %s：没有同名三角光CSV。\n',name); continue; end
    fprintf('\n=== 对比 [%d/%d] %s ===\n',k,numel(folders),name);
    try
        r=load(resultPath);
        [row,aligned]=compare_one(r,sensorPath,sensorFPS,videoAxis,minOverlapFraction,removeLinearTrend,allowPolarityFlip);
        outDir=fullfile(resultDir,comparisonFolderName); if ~isfolder(outDir),mkdir(outDir);end
        write_comparison_outputs(aligned,outDir,name,showFigures);
        row.videoName=string(name); row.sensorFile=string(sensorPath);
        rows=append_row(rows,row);
        fprintf('通道=%d；对齐偏移=%+.4f s；有符号PCC=%+.4f；|PCC|=%.4f；共同样本=%d。\n', ...
            row.sensorChannel,row.sensorLeadSeconds,row.pccSigned,row.pccAbsolute,row.commonSamples);
    catch ex
        warning('对比 %s 失败：%s',name,ex.message);
    end
end
if ~isempty(rows)
    summary=struct2table(rows);
    writetable(summary,fullfile(videoOutputRoot,'comparison_0726_metrics.csv'));
    disp(summary);
else
    warning('没有找到可以同时匹配的07-26视频结果和三角光文件。');
end
fprintf('\n07-26_single相对波形对比完成。三角光采样率按100 Hz记录；未进行物理标定。\n');

function [row,a]=compare_one(r,sensorPath,sensorFPS,videoAxis,minOverlap,removeTrend,allowFlip)
assert(isfield(r,'relative')&&isfield(r,'fps')&&isfield(r,'time'),'result.mat缺少relative、fps或time字段');
axisId=1; if strcmpi(videoAxis,'y'),axisId=2; end
video=double(r.relative(:,axisId)); videoFPS=double(r.fps); assert(videoFPS>0,'视频采样率无效');
M=readmatrix(sensorPath); assert(size(M,2)>=4,'三角光CSV少于4列，无法读取两个通道');
[tri,channel,quality]=choose_sensor_channel(M(:,3:4));
% 去除CSV首尾非数值记录；内部少量缺失只在评价信号中线性补齐。
valid=isfinite(tri); assert(nnz(valid)>=20,'三角光有效样本太少'); first=find(valid,1,'first'); last=find(valid,1,'last'); tri=tri(first:last); tri=fillmissing(tri,'linear','EndValues','nearest');
validVideo=isfinite(video); assert(nnz(validVideo)>=20,'视频有效样本太少'); video=fillmissing(video,'linear','EndValues','nearest');
videoTime=(0:numel(video)-1)'/videoFPS;
commonTime=(0:1/sensorFPS:videoTime(end))'; video100=interp1(videoTime,video,commonTime,'linear','extrap');
if removeTrend, videoForAlign=detrend(video100); sensorForAlign=detrend(tri); else, videoForAlign=video100-mean(video100); sensorForAlign=tri-mean(tri); end
videoForAlign=videoForAlign/std(videoForAlign); sensorForAlign=sensorForAlign/std(sensorForAlign);
[~,lags]=xcorr(sensorForAlign,videoForAlign,'none'); cc=nan(size(lags)); overlap=zeros(size(lags));
for j=1:numel(lags)
    lag=lags(j); s0=max(1,1+lag); s1=min(numel(tri),numel(videoForAlign)+lag); v0=s0-lag; v1=s1-lag;
    if s1>=s0
        xs=sensorForAlign(s0:s1); xv=videoForAlign(v0:v1); xs=xs-mean(xs); xv=xv-mean(xv);
        overlap(j)=numel(xs); denom=sqrt(sum(xs.^2)*sum(xv.^2)); if denom>eps, cc(j)=sum(xs.*xv)/denom; end
    end
end
eligible=overlap>=minOverlap*numel(videoForAlign); scores=abs(cc); scores(~eligible|~isfinite(scores))=-Inf; [best,ix]=max(scores); assert(isfinite(best),'无法找到足够重叠的对齐区间'); lag=lags(ix);
sensorStart=max(1,1+lag); videoStart=max(1,1-lag); n=min(numel(tri)-sensorStart+1,numel(videoForAlign)-videoStart+1); assert(n>=20,'对齐后的共同区间太短');
sensorSegment=tri(sensorStart:sensorStart+n-1); videoSegment=video100(videoStart:videoStart+n-1); if removeTrend, sensorSegment=detrend(sensorSegment); videoSegment=detrend(videoSegment); end
sensorNorm=normalize_relative(sensorSegment); videoNorm=normalize_relative(videoSegment); pcc=corr(videoNorm,sensorNorm,'Rows','complete'); polarity=1; if allowFlip&&pcc<0,polarity=-1;end
sensorPlot=polarity*sensorNorm; pccAbs=abs(pcc); rmse=sqrt(mean((videoNorm-sensorPlot).^2));
[av,fv]=one_sided_spectrum(videoNorm,sensorFPS); [as,fs]=one_sided_spectrum(sensorPlot,sensorFPS);
row=struct('sensorChannel',channel,'sensorQualityChannel1',quality(1),'sensorQualityChannel2',quality(2),'sensorFPS',sensorFPS,'videoFPS',videoFPS,'sensorLeadSamples',lag,'sensorLeadSeconds',lag/sensorFPS,'commonSamples',n,'commonDurationSeconds',(n-1)/sensorFPS,'pccSigned',pcc,'pccAbsolute',pccAbs,'rmseNormalized',rmse,'polarityForDisplay',polarity,'status','evaluated');
a=struct('time',(0:n-1)'/sensorFPS,'video',videoNorm,'sensor',sensorPlot,'videoSpectrum',av,'videoFrequency',fv,'sensorSpectrum',as,'sensorFrequency',fs,'rawVideo',videoSegment,'rawSensor',sensorSegment,'channel',channel,'channelQuality',quality,'lagSamples',lag,'sensorFPS',sensorFPS,'videoFPS',videoFPS);
end

function [x,channel,quality]=choose_sensor_channel(channels)
quality=-Inf(1,2); channel=NaN;
for c=1:2
    z=double(channels(:,c)); valid=isfinite(z); if nnz(valid)<20,continue;end
    z=z(valid); scale=1.4826*median(abs(z-median(z))); if ~isfinite(scale)||scale<=eps,scale=std(z);end
    rough=median(abs(diff(z))); quality(c)=mean(valid)*scale/max(rough,eps);
end
[~,channel]=max(quality); assert(isfinite(quality(channel)),'两个三角光通道都没有足够有效数据'); x=double(channels(:,channel));
end
function z=normalize_relative(x)
z=double(x(:)); s=std(z); if ~isfinite(s)||s<=eps, z=zeros(size(z)); else, z=(z-mean(z))/s;end
end
function [a,f]=one_sided_spectrum(x,fs)
z=x(:); z=z-mean(z); n=numel(z); nfft=2^nextpow2(max(n,2)); w=hann(n); y=fft(z.*w,nfft); a=abs(y(1:nfft/2+1))/max(sum(w),eps)*2; a(1)=a(1)/2; f=(0:nfft/2)'*fs/nfft; a=a/max(max(a),eps);
end
function write_comparison_outputs(a,outDir,name,showFigures)
t=table(a.time,a.video,a.sensor,'VariableNames',{'time_s','video_normalized','triangulation_normalized'}); writetable(t,fullfile(outDir,'aligned_relative_waveforms.csv'));
fig=figure('Visible','off','Color','w'); plot(a.time,a.video,'LineWidth',1); hold on; plot(a.time,a.sensor,'--','LineWidth',1); grid on; xlabel('Aligned time (s)'); ylabel('Relative normalized amplitude'); title([name ' video vs triangulation'],'Interpreter','none'); legend('Video','Triangulation','Location','best'); save_visible(fig,fullfile(outDir,'aligned_relative_waveforms.fig'),fullfile(outDir,'aligned_relative_waveforms.png'),showFigures);
fig=figure('Visible','off','Color','w'); plot(a.videoFrequency,a.videoSpectrum,'LineWidth',1); hold on; plot(a.sensorFrequency,a.sensorSpectrum,'--','LineWidth',1); grid on; xlabel('Frequency (Hz)'); ylabel('Normalized amplitude'); title([name ' relative spectra'],'Interpreter','none'); legend('Video','Triangulation','Location','best'); save_visible(fig,fullfile(outDir,'aligned_relative_spectra.fig'),fullfile(outDir,'aligned_relative_spectra.png'),showFigures);
save(fullfile(outDir,'alignment.mat'),'-struct','a','-v7');
end
function save_visible(fig,figPath,pngPath,showFigures)
set(fig,'Visible','on'); savefig(fig,figPath); exportgraphics(fig,pngPath); if ~showFigures,close(fig);end
end
function rows=append_row(rows,row)
if isempty(rows),rows=row;else,rows(end+1)=row;end
end
