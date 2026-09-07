function report = evaluate_motion_test_results(resultDirs, outputRoot)
%EVALUATE_MOTION_TEST_RESULTS 将算法轨迹与模拟真值对齐并报告效果。
% resultDirs 可以是 run_real_video 生成的结果目录字符串或 cell 数组。
% 评估保留无效帧，不把无效帧当成正确结果；23 Hz 峰值在去除已知大运动后计算。

if nargin<1 || isempty(resultDirs)
    error('Crossline:Input','请提供 run_real_video 的结果目录。');
end
if ischar(resultDirs) || isstring(resultDirs), resultDirs=cellstr(resultDirs); end
if nargin<2 || isempty(outputRoot)
    outputRoot=fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
        'outputs','motion_test_evaluation');
end
if ~isfolder(outputRoot), mkdir(outputRoot); end

report=repmat(struct('resultDir','','scenario','','numFrames',0,'validRate',0, ...
    'rmseX_px',NaN,'rmseY_px',NaN,'rmse2D_px',NaN,'median2D_px',NaN, ...
    'p95_2D_px',NaN,'max2D_px',NaN,'biasX_px',NaN,'biasY_px',NaN, ...
    'estimatedMicroPeakHz',NaN,'estimatedMicroPeakAmpPx',NaN, ...
    'spectrumAtMicroHz',NaN,'spectrumMicroBinHz',NaN,'truthMicroFrequencyHz',NaN), ...
    1,numel(resultDirs));

for k=1:numel(resultDirs)
    resultDir=resultDirs{k};
    S=load(fullfile(resultDir,'crossline_results.mat'),'cfg','globalCenter','valid','trajectoryTable');
    videoBase=erase(string(get_video_path(S.cfg)),['.avi','.mp4','.mov','.m4v']); %#ok<NASGU>
    [videoFolder,videoName]=fileparts(get_video_path(S.cfg)); %#ok<ASGLU>
    truthPath=fullfile(videoFolder,[videoName '_truth.mat']);
    T=load(truthPath,'time','centers','largeCenters','microCenters','cfg');
    n=min([size(S.globalCenter,1),size(T.centers,1)]);
    est=S.globalCenter(1:n,:); truth=T.centers(1:n,:); large=T.largeCenters(1:n,:);
    ok=S.valid(1:n) & all(isfinite(est),2);
    err=est-truth; validRate=mean(ok);
    report(k).resultDir=resultDir; report(k).scenario=videoName; report(k).numFrames=n;
    report(k).validRate=validRate;
    if any(ok)
        report(k).rmseX_px=sqrt(mean(err(ok,1).^2)); report(k).rmseY_px=sqrt(mean(err(ok,2).^2));
        err2D=sqrt(sum(err(ok,:).^2,2));
        report(k).rmse2D_px=sqrt(mean(err2D.^2)); report(k).median2D_px=median(err2D);
        sortedErr=sort(err2D); report(k).p95_2D_px=sortedErr(max(1,ceil(0.95*numel(sortedErr))));
        report(k).max2D_px=max(err2D);
        report(k).biasX_px=mean(err(ok,1)); report(k).biasY_px=mean(err(ok,2));
        residual=est(ok,1)-large(ok,1); t=T.time(1:n); t=t(ok);
        [peakHz,peakAmp]=micro_peak(residual,t,T.cfg.microFrequencyHz);
        report(k).estimatedMicroPeakHz=peakHz; report(k).estimatedMicroPeakAmpPx=peakAmp;
        report(k).truthMicroFrequencyHz=T.cfg.microFrequencyHz;
    end
    spectrumPath=fullfile(resultDir,'crossline_spectrum.mat');
    if isfile(spectrumPath)
        Q=load(spectrumPath,'spectrum'); [~,ib]=min(abs(Q.spectrum.frequencyHz-T.cfg.microFrequencyHz));
        report(k).spectrumAtMicroHz=Q.spectrum.amplitudeX(ib);
        report(k).spectrumMicroBinHz=Q.spectrum.frequencyHz(ib);
    end
    save_evaluation_figure(resultDir,outputRoot,T.time(1:n),truth,est,large,ok,videoName,T.cfg.microFrequencyHz);
end

R=struct2table(report); writetable(R,fullfile(outputRoot,'motion_test_report.csv'));
save(fullfile(outputRoot,'motion_test_report.mat'),'report','R');
fprintf('运动测试评估已保存：%s\n',outputRoot);
for k=1:numel(report)
    fprintf('%s: valid=%.2f%%, RMSE2D=%.4f px, spectrum@%.1fHz=%.4f px\n', ...
        report(k).scenario,100*report(k).validRate,report(k).rmse2D_px, ...
        report(k).truthMicroFrequencyHz,report(k).spectrumAtMicroHz);
end
end

function path=get_video_path(cfg)
path=cfg.real.videoPath;
end

function [peakHz,peakAmp]=micro_peak(signal,time,targetHz)
signal=signal(:); time=time(:); n=numel(signal);
if n<8, peakHz=NaN; peakAmp=NaN; return; end
signal=detrend(signal,1); dt=median(diff(time)); fs=1/dt;
freq=(0:floor(n/2))'*fs/n; spec=abs(fft(signal))/n; spec=2*spec(1:numel(freq));
band=abs(freq-targetHz)<=1.0;
if ~any(band), peakHz=NaN; peakAmp=NaN; return; end
[peakAmp,idx]=max(spec(band)); fband=freq(band); peakHz=fband(idx);
end

function save_evaluation_figure(resultDir,outputRoot,time,truth,est,large,ok,name,targetHz)
fig=figure('Visible','on','Color','w','Name',['Motion evaluation - ' name]);
tl=tiledlayout(fig,3,1,'TileSpacing','compact','Padding','compact');
ax1=nexttile(tl); hold(ax1,'on');
plot(ax1,time,truth(:,1)-truth(1,1),'k-','LineWidth',1.0,'DisplayName','Ground truth');
plot(ax1,time,est(:,1)-est(1,1),'Color',[0.85 0.20 0.10],'LineWidth',0.8,'DisplayName','Algorithm');
plot(ax1,time(~ok),est(~ok,1)-est(1,1),'rx','DisplayName','Invalid frame');
xlabel(ax1,'Time (s)'); ylabel(ax1,'Horizontal displacement (px)'); title(ax1,name,'Interpreter','none');
legend(ax1,'Location','best'); grid(ax1,'on');
ax2=nexttile(tl); residual=est(:,1)-large(:,1); residual(~ok)=NaN;
plot(ax2,time,residual,'Color',[0.10 0.35 0.75],'LineWidth',0.8);
xlabel(ax2,'Time (s)'); ylabel(ax2,'Estimate - large motion (px)');
title(ax2,sprintf('Residual after removing known large motion; target %.1f Hz, valid %.2f%%',targetHz,100*mean(ok)), ...
    'Interpreter','none');
grid(ax2,'on');
ax3=nexttile(tl); signal=est(:,1); signal(~ok)=0; signal=signal-mean(signal(ok));
n=numel(signal); fs=1/median(diff(time)); freq=(0:floor(n/2))'*fs/n;
amp=2*abs(fft(signal))/n; amp=amp(1:numel(freq));
band=freq>=20 & freq<=26; plot(ax3,freq(band),amp(band),'k-','LineWidth',1.1); hold(ax3,'on');
xline(ax3,targetHz,'r--','LineWidth',1.0,'DisplayName',sprintf('Target %.1f Hz',targetHz));
xlabel(ax3,'Frequency (Hz)'); ylabel(ax3,'|X(f)| (px)'); title(ax3,'Zoomed micro-vibration spectrum');
legend(ax3,'Location','best'); grid(ax3,'on');
set(findall(fig,'-property','FontName'),'FontName','Times New Roman');
set(fig,'Visible','on');
base=fullfile(outputRoot,[name '_evaluation']); savefig(fig,[base '.fig']);
try, exportgraphics(fig,[base '.png'],'Resolution',180); catch, print(fig,[base '.png'],'-dpng','-r180'); end
close(fig);
end
