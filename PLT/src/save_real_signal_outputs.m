function save_real_signal_outputs(outputDir,primary,fps,cfg)
% SAVE_REAL_SIGNAL_OUTPUTS 保存真实视频波形、频谱 PNG 和 MATLAB FIG。
% 依据用户要求，两个 FIG 的 Visible 均固定为 'on' 后再保存。

n=size(primary.center,1); t=(0:n-1)'/fps;
validMask=logical(primary.valid) & all(isfinite(primary.center),2);
spectrumX=compute_single_sided_spectrum(primary.center(:,1),fps,validMask);
spectrumY=compute_single_sided_spectrum(primary.center(:,2),fps,validMask);
axisName='x';
if isfield(cfg.method,'observedAxis'), axisName=lower(char(cfg.method.observedAxis)); end
if strcmp(axisName,'y'), axisIndex=2; else, axisName='x'; axisIndex=1; end
observedSignal=primary.center(:,axisIndex)-primary.center(1,axisIndex);
observedSignal(~validMask)=NaN;
spectrumObserved=compute_single_sided_spectrum(observedSignal,fps,validMask);

waveFig=figure('Visible','on','Color','w','Units','pixels','Position',[100 100 900 620]);
set(waveFig,'DefaultAxesFontName',cfg.plot.fontName,'DefaultAxesFontSize',cfg.plot.fontSize);
subplot(2,1,1); plot(t,observedSignal,'Color',cfg.plot.blue,'LineWidth',1); ylabel([upper(axisName) ' displacement (px)']); style_axes_local(cfg);
subplot(2,1,2); plot(t,primary.quality,'Color',cfg.plot.red,'LineWidth',1); ylabel('Tracking quality'); xlabel('Time (s)'); ylim([0 1]); style_axes_local(cfg);
sgtitle(['Real-video phase tracking waveform (' upper(axisName) ')'],'FontName',cfg.plot.fontName);
set(waveFig,'Visible','on'); save_figure_png_local(waveFig,fullfile(outputDir,'11_real_video_waveform.png'));
savefig(waveFig,fullfile(outputDir,'11_real_video_waveform.fig'));

specFig=figure('Visible','on','Color','w','Units','pixels','Position',[100 100 900 620]);
set(specFig,'DefaultAxesFontName',cfg.plot.fontName,'DefaultAxesFontSize',cfg.plot.fontSize);
plot(spectrumObserved.frequencyHz,spectrumObserved.amplitude,'Color',cfg.plot.blue,'LineWidth',1); ylabel([upper(axisName) ' amplitude (px)']); xlabel('Frequency (Hz)'); style_axes_local(cfg);
if isempty(spectrumObserved.frequencyHz), title('No valid tracking samples for spectrum','Color',cfg.plot.red); end
sgtitle(['Real-video phase tracking spectrum (' upper(axisName) ')'],'FontName',cfg.plot.fontName);
set(specFig,'Visible','on'); save_figure_png_local(specFig,fullfile(outputDir,'12_real_video_spectrum.png'));
savefig(specFig,fullfile(outputDir,'12_real_video_spectrum.fig'));

real_signal=table((1:n)',t,primary.center(:,1),primary.center(:,2),observedSignal,primary.quality,primary.valid,...
    'VariableNames',{'frame','time_s','x_px','y_px','observed_displacement_px','quality','valid'});
writetable(real_signal,fullfile(outputDir,'real_video_signal.csv'));
save(fullfile(outputDir,'real_video_signal.mat'),'real_signal','spectrumX','spectrumY','spectrumObserved','observedSignal','axisName','-v7.3');
end

function style_axes_local(cfg)
ax=gca; set(ax,'Box','on','LineWidth',0.8,'FontName',cfg.plot.fontName,'FontSize',cfg.plot.fontSize,'TickDir','out'); grid(ax,'off');
end

function save_figure_png_local(fig,path)
if exist('exportgraphics','file')==2, exportgraphics(fig,path,'Resolution',180); else, saveas(fig,path); end
end
