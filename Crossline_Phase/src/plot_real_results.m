function [waveFig,spectrumFig,spectrum] = plot_real_results(time,center,valid,fps,outDir,meta)
%PLOT_REAL_RESULTS 真实视频的图像平面轨迹和频谱。
% 无真值时只展示轨迹/频率，不计算 RMSE、PCC 等监督指标。
if nargin<5, outDir=pwd; end
if nargin<6 || isempty(meta), meta=struct(); end
n=numel(time); xy=double(center); good=valid(:)&all(isfinite(xy),2);
filled=xy;
for d=1:2
    if nnz(good)>1, filled(~good,d)=interp1(time(good),xy(good,d),time(~good),'linear','extrap'); end
end
videoName='real video';
if isfield(meta,'videoName') && ~isempty(meta.videoName)
    [~,baseName,ext]=fileparts(char(meta.videoName)); videoName=[baseName ext];
end
waveFig=figure('Name','Crossline real-video waveform','NumberTitle','off','Color','w','Visible','on'); set(waveFig,'Position',[80 80 1050 700]);
tiledlayout(waveFig,2,1,'Padding','compact','TileSpacing','compact');
nexttile; plot(time,filled(:,1),'k-','LineWidth',.9,'DisplayName','Interpolated trajectory'); hold on; plot(time(good),xy(good,1),'r.','MarkerSize',5,'DisplayName','Valid detection');
if any(~good), plot(time(~good),filled(~good,1),'bx','DisplayName','Invalid frame'); end
grid on; xlabel('Time (s)'); ylabel('x (pixel)'); title('Image-plane center trajectory: x'); legend('Location','best');
nexttile; plot(time,filled(:,2),'k-','LineWidth',.9,'DisplayName','Interpolated trajectory'); hold on; plot(time(good),xy(good,2),'r.','MarkerSize',5,'DisplayName','Valid detection');
if any(~good), plot(time(~good),filled(~good,2),'bx','DisplayName','Invalid frame'); end
grid on; xlabel('Time (s)'); ylabel('y (pixel)'); title('Image-plane center trajectory: y'); legend('Location','best');
sgtitle(waveFig,sprintf('Crossline phase result | %s | %d frames | %.2f%% valid | Fs=%.2f Hz',videoName,n,100*mean(good),fps), ...
    'Interpreter','none','FontSize',14);
set(findall(waveFig,'-property','FontName'),'FontName','Times New Roman'); set(waveFig,'Visible','on');
save_figure_pair(waveFig,fullfile(outDir,'crossline_waveform')); savefig(waveFig,fullfile(outDir,'crossline_waveform.fig'));

Fs=fps; N=n; f=(0:floor(N/2))'*Fs/N; rawAmp=zeros(numel(f),2); amp=zeros(numel(f),2);
w=0.5-0.5*cos(2*pi*(0:max(N-1,0))'/max(N-1,1));
for d=1:2
    s=filled(:,d)-mean(filled(:,d),'omitnan'); rawAmp(:,d)=one_sided_amplitude(s,ones(N,1)); amp(:,d)=one_sided_amplitude(s.*w,w);
end
spectrum=struct('frequencyHz',f,'amplitudeX',amp(:,1),'amplitudeY',amp(:,2), ...
    'rawAmplitudeX',rawAmp(:,1),'rawAmplitudeY',rawAmp(:,2), ...
    'samplingRateHz',Fs,'validRate',mean(good),'window','Hann', ...
    'expectedFrequenciesHz',get_expected(meta), ...
    'note','amplitudeX/Y use detrended Hann-windowed FFT; rawAmplitudeX/Y preserve the unwindowed FFT.');
spectrumFig=figure('Name','Crossline real-video spectrum','NumberTitle','off','Color','w','Visible','on'); set(spectrumFig,'Position',[80 80 1050 700]);
tiledlayout(spectrumFig,2,1,'Padding','compact','TileSpacing','compact');
nexttile; plot(f,rawAmp(:,1),'Color',[.65 .65 .65],'LineWidth',.7,'DisplayName','Raw FFT'); hold on; plot(f,amp(:,1),'k-','LineWidth',1.0,'DisplayName','Hann-windowed FFT'); grid on; xlim([0 Fs/2]); xlabel('Frequency (Hz)'); ylabel('|X(f)| (pixel)'); title('x-axis spectrum'); legend('Location','best');
nexttile; plot(f,rawAmp(:,2),'Color',[.65 .65 .65],'LineWidth',.7,'DisplayName','Raw FFT'); hold on; plot(f,amp(:,2),'k-','LineWidth',1.0,'DisplayName','Hann-windowed FFT'); grid on; xlim([0 Fs/2]); xlabel('Frequency (Hz)'); ylabel('|Y(f)| (pixel)'); title('y-axis spectrum'); legend('Location','best');
sgtitle(spectrumFig,sprintf('One-sided FFT | %s | Fs = %.2f Hz | %d frames | valid %.2f%%',videoName,Fs,n,100*mean(good)), ...
    'Interpreter','none','FontSize',14);
set(findall(spectrumFig,'-property','FontName'),'FontName','Times New Roman'); set(spectrumFig,'Visible','on');
save_figure_pair(spectrumFig,fullfile(outDir,'crossline_spectrum')); savefig(spectrumFig,fullfile(outDir,'crossline_spectrum.fig'));
expected=get_expected(meta);
if ~isempty(expected)
    zfig=figure('Name','Crossline expected-frequency spectrum','NumberTitle','off','Color','w','Visible','on'); set(zfig,'Position',[100 100 1050 650]);
    tiledlayout(zfig,2,1,'Padding','compact','TileSpacing','compact');
    lo=max(0,min(expected)-3); hi=min(Fs/2,max(expected)+3);
    nexttile; plot(f,rawAmp(:,1),'Color',[.65 .65 .65],'LineWidth',.7,'DisplayName','Raw FFT'); hold on; plot(f,amp(:,1),'k-','LineWidth',1.1,'DisplayName','Hann-windowed FFT');
    for q=1:numel(expected), xline(expected(q),'r--','LineWidth',1.0,'DisplayName',sprintf('Target %.2f Hz',expected(q))); end
    grid on; xlim([lo hi]); xlabel('Frequency (Hz)'); ylabel('|X(f)| (pixel)'); title('x-axis expected-frequency zoom'); legend('Location','best');
    nexttile; plot(f,rawAmp(:,2),'Color',[.65 .65 .65],'LineWidth',.7,'DisplayName','Raw FFT'); hold on; plot(f,amp(:,2),'k-','LineWidth',1.1,'DisplayName','Hann-windowed FFT');
    for q=1:numel(expected), xline(expected(q),'r--','LineWidth',1.0,'DisplayName',sprintf('Target %.2f Hz',expected(q))); end
    grid on; xlim([lo hi]); xlabel('Frequency (Hz)'); ylabel('|Y(f)| (pixel)'); title('y-axis expected-frequency zoom'); legend('Location','best');
    sgtitle(zfig,sprintf('Expected-frequency zoom | %s | valid %.2f%%',videoName,100*mean(good)),'Interpreter','none','FontSize',14);
    set(findall(zfig,'-property','FontName'),'FontName','Times New Roman'); set(zfig,'Visible','on');
    save_figure_pair(zfig,fullfile(outDir,'crossline_spectrum_zoom')); savefig(zfig,fullfile(outDir,'crossline_spectrum_zoom.fig')); close(zfig);
end
end

function a=one_sided_amplitude(signal,window)
%ONE_SIDED_AMPLITUDE 计算含幅值校正的一侧单边幅值谱。
n=numel(signal); scale=max(sum(window),eps); z=fft(signal); a=abs(z(1:floor(n/2)+1))/scale;
if numel(a)>2, a(2:end-1)=2*a(2:end-1); end
end

function f=get_expected(meta)
if isfield(meta,'expectedFrequenciesHz'), f=double(meta.expectedFrequenciesHz(:)'); else, f=[]; end
end
