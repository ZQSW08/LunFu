function save_decomposition_outputs(outputDir,coordinate,dVib,fps,cfg)
% SAVE_DECOMPOSITION_OUTPUTS 保存 V2 宏观坐标、细相位残差和重建结果。
% 真实视频没有真值时只保存观测量，不计算伪造的 MSR/VPR。
dTotal=coordinate.dTotal; dMacro=coordinate.dMacro; dCrop=coordinate.dCrop; dVib=double(dVib); reconstructed=dCrop+dVib;
n=size(dTotal,1); t=(0:n-1)'/fps;
wave=figure('Visible','on','Color','w','Units','pixels','Position',[100 100 980 700]);
set(wave,'DefaultAxesFontName',cfg.plot.fontName,'DefaultAxesFontSize',cfg.plot.fontSize);
subplot(3,1,1); plot(t,dTotal(:,1),'Color',cfg.plot.blue); hold on; plot(t,dMacro(:,1),'Color',cfg.plot.red); ylabel('X (px)'); legend('total','macro','Location','best'); style_axes_local(cfg);
subplot(3,1,2); plot(t,dTotal(:,2),'Color',cfg.plot.blue); hold on; plot(t,dMacro(:,2),'Color',cfg.plot.red); ylabel('Y (px)'); legend('total','macro','Location','best'); style_axes_local(cfg);
subplot(3,1,3); plot(t,dVib(:,1),'Color',cfg.plot.blue); hold on; plot(t,dVib(:,2),'Color',cfg.plot.red); ylabel('Residual (px)'); xlabel('Time (s)'); legend('X residual','Y residual','Location','best'); style_axes_local(cfg);
sgtitle('MP-G2LPT macro/micro decomposition','FontName',cfg.plot.fontName); set(wave,'Visible','on');
save_png_local(wave,fullfile(outputDir,'13_decomposition_waveform.png')); savefig(wave,fullfile(outputDir,'13_decomposition_waveform.fig'));

sx=compute_single_sided_spectrum(dTotal(:,1),fps); sy=compute_single_sided_spectrum(dTotal(:,2),fps); svx=compute_single_sided_spectrum(dVib(:,1),fps); svy=compute_single_sided_spectrum(dVib(:,2),fps);
spec=figure('Visible','on','Color','w','Units','pixels','Position',[100 100 980 700]);
set(spec,'DefaultAxesFontName',cfg.plot.fontName,'DefaultAxesFontSize',cfg.plot.fontSize);
subplot(2,2,1); plot(sx.frequencyHz,sx.amplitude,'Color',cfg.plot.blue); title('Total X'); style_axes_local(cfg);
subplot(2,2,2); plot(sy.frequencyHz,sy.amplitude,'Color',cfg.plot.blue); title('Total Y'); style_axes_local(cfg);
subplot(2,2,3); plot(svx.frequencyHz,svx.amplitude,'Color',cfg.plot.red); title('Residual X'); xlabel('Frequency (Hz)'); style_axes_local(cfg);
subplot(2,2,4); plot(svy.frequencyHz,svy.amplitude,'Color',cfg.plot.red); title('Residual Y'); xlabel('Frequency (Hz)'); style_axes_local(cfg);
sgtitle('MP-G2LPT displacement spectra','FontName',cfg.plot.fontName); set(spec,'Visible','on');
save_png_local(spec,fullfile(outputDir,'14_decomposition_spectrum.png')); savefig(spec,fullfile(outputDir,'14_decomposition_spectrum.fig'));

tbl=table((1:n)',t,dTotal(:,1),dTotal(:,2),dMacro(:,1),dMacro(:,2),dCrop(:,1),dCrop(:,2),dVib(:,1),dVib(:,2),reconstructed(:,1),reconstructed(:,2),...
    'VariableNames',{'frame','time_s','total_x_px','total_y_px','macro_x_px','macro_y_px','crop_x_px','crop_y_px','vib_x_px','vib_y_px','reconstructed_x_px','reconstructed_y_px'});
writetable(tbl,fullfile(outputDir,'decomposition.csv')); save(fullfile(outputDir,'decomposition.mat'),'coordinate','dVib','reconstructed','sx','sy','svx','svy','-v7.3');
end

function style_axes_local(cfg)
ax=gca; set(ax,'Box','on','LineWidth',0.8,'FontName',cfg.plot.fontName,'FontSize',cfg.plot.fontSize,'TickDir','out'); grid(ax,'off');
end
function save_png_local(fig,path)
if exist('exportgraphics','file')==2, exportgraphics(fig,path,'Resolution',180); else, saveas(fig,path); end
end
