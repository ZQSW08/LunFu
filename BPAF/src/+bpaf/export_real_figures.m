function export_real_figures(result, rawSignal, time, frequencyRange, band, fs, folder, name)
%EXPORT_REAL_FIGURES 导出 BPAF 真实视频的论文风格图片及可编辑 FIG 文件。
% 保留原四面板总图，同时将波形和频谱分别导出为 PNG/FIG。

if ~isfolder(folder), mkdir(folder); end
frequencyRange=double(frequencyRange(:).');
band=double(band(:).');
plotName=strrep(char(name),'_','\_');

% 总图：保留原有 BPAF 四面板结构。
fig=figure('Visible','off','Color','w','Position',[100 100 1100 760]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
sgtitle(sprintf('%s | BPAF real-video analysis',plotName), ...
    'FontName','Times New Roman','FontSize',14,'FontWeight','normal');
ax1=nexttile;
plot(time,rawSignal,'k','LineWidth',1.0); grid on;
xlabel('Time (s)'); ylabel('Phase (rad)'); title('Raw weighted phase');
ax2=nexttile;
plot(time,result.signal,'k','LineWidth',1.0); grid on;
xlabel('Time (s)'); ylabel('Phase (rad)'); title('BPAF filtered phase');
ax3=nexttile;
plot(result.metrics.frequency,result.metrics.spectrum,'k','LineWidth',1.0); grid on;
xlim([max(0,frequencyRange(1)),min(frequencyRange(2),fs/2)]);
xlabel('Frequency (Hz)'); ylabel('Normalized amplitude');
title(sprintf('BPAF spectrum (PF = %.6g Hz, PER = %.4f)',result.metrics.PF,result.metrics.PER));
hold on; xline(band(1),'--','Color',[0.85 0.10 0.10],'LineWidth',1.0);
xline(band(2),'--','Color',[0.85 0.10 0.10],'LineWidth',1.0); hold off;
ax4=nexttile;
plot_kernel_response(result.kernel,fs,frequencyRange);
xlabel('Frequency (Hz)'); ylabel('Normalized response'); title('BPAF temporal kernel');
set([ax1 ax2 ax3 ax4],'FontName','Times New Roman','FontSize',11,'LineWidth',0.8);
exportgraphics(fig,fullfile(folder,'07_bpaf_paper_style_result.png'),'Resolution',220);
% PNG 后台导出保持隐藏；FIG 必须保存为可见状态，确保双击加载后图窗可见。
set(fig,'Visible','on');
saveas(fig,fullfile(folder,'07_bpaf_paper_style_result.fig'),'fig');
close(fig);

% 独立波形图：上下排列原始加权相位和 BPAF 输出，便于单独查看时域结果。
fig=figure('Visible','off','Color','w','Position',[100 100 1000 700]);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
sgtitle(sprintf('%s | BPAF waveform',plotName), ...
    'FontName','Times New Roman','FontSize',14,'FontWeight','normal');
ax1=nexttile; plot(time,rawSignal,'k','LineWidth',1.0); grid on;
xlabel('Time (s)'); ylabel('Phase (rad)'); title('Raw weighted phase');
ax2=nexttile; plot(time,result.signal,'k','LineWidth',1.0); grid on;
xlabel('Time (s)'); ylabel('Phase (rad)'); title('BPAF filtered phase');
set([ax1 ax2],'FontName','Times New Roman','FontSize',11,'LineWidth',0.8);
exportgraphics(fig,fullfile(folder,'08_bpaf_waveform.png'),'Resolution',220);
% FIG 序列化会记录 Visible 属性，因此保存前显式改为 on。
set(fig,'Visible','on');
saveas(fig,fullfile(folder,'08_bpaf_waveform.fig'),'fig');
close(fig);

% 独立频谱图：保留论文风格的黑色主曲线和红色先验频带线。
fig=figure('Visible','off','Color','w','Position',[100 100 1000 560]);
ax=axes(fig);
plot(ax,result.metrics.frequency,result.metrics.spectrum,'k','LineWidth',1.0); grid(ax,'on'); hold(ax,'on');
xline(ax,band(1),'--','Color',[0.85 0.10 0.10],'LineWidth',1.0);
xline(ax,band(2),'--','Color',[0.85 0.10 0.10],'LineWidth',1.0); hold(ax,'off');
xlim(ax,[max(0,frequencyRange(1)),min(frequencyRange(2),fs/2)]);
xlabel(ax,'Frequency (Hz)'); ylabel(ax,'Normalized amplitude');
title(ax,sprintf('%s | BPAF spectrum (PF = %.6g Hz, PER = %.4f)', ...
    plotName,result.metrics.PF,result.metrics.PER), ...
    'FontName','Times New Roman','FontSize',13,'FontWeight','normal');
set(ax,'FontName','Times New Roman','FontSize',11,'LineWidth',0.8);
exportgraphics(fig,fullfile(folder,'09_bpaf_spectrum.png'),'Resolution',220);
% FIG 序列化会记录 Visible 属性，因此保存前显式改为 on。
set(fig,'Visible','on');
saveas(fig,fullfile(folder,'09_bpaf_spectrum.fig'),'fig');
close(fig);
end

function plot_kernel_response(kernel,fs,frequencyRange)
kernel=kernel(:);
if isempty(kernel)
    plot(0,0,'k'); grid on; xlim([0,min(frequencyRange(2),fs/2)]); return;
end
nfft=max(1024,2^nextpow2(8*numel(kernel)));
response=abs(fft(kernel,nfft)); response=response(1:floor(nfft/2)+1);
freq=(0:numel(response)-1)'*fs/nfft;
response=response/max(max(response),eps);
plot(freq,response,'k','LineWidth',1.0); grid on;
xlim([0,min(frequencyRange(2),fs/2)]);
end
