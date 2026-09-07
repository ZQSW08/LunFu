function save_motion_spectrum_figure(time, signals, names, fps, frequencyRange, ...
    outputPath, yLabel, titleText, saveEditableFigure)
%SAVE_MOTION_SPECTRUM_FIGURE 论文式时程/频谱双栏图；其余图均保持单面板。

if nargin < 9 || isempty(saveEditableFigure), saveEditableFigure = false; end

colors = [0.85 0.20 0.18; 0.00 0.32 0.62; 0.00 0.55 0.45; 0.55 0.35 0.70];
styles = {'-','--',':','-.'};
fig = figure('Visible','off','Color','w','Position',[50 50 980 360]);
layout = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');
nexttile;
for k = 1:size(signals,2)
    plot(time,signals(:,k),styles{1+mod(k-1,numel(styles))}, ...
        'Color',colors(1+mod(k-1,size(colors,1)),:),'LineWidth',1.15); hold on;
end
grid on; box on; xlabel('时间 (s)'); ylabel(yLabel);
legend(names,'Location','best','Box','off'); title('时程');

nexttile;
for k = 1:size(signals,2)
    [frequency, f, amplitude] = estimate_dominant_frequency(signals(:,k),fps,frequencyRange);
    amplitude = amplitude / max(max(amplitude),eps);
    plot(f,amplitude,styles{1+mod(k-1,numel(styles))}, ...
        'Color',colors(1+mod(k-1,size(colors,1)),:),'LineWidth',1.15); hold on;
    xline(frequency,':','Color',colors(1+mod(k-1,size(colors,1)),:),'LineWidth',0.9);
end
grid on; box on; xlim(frequencyRange); xlabel('频率 (Hz)'); ylabel('归一化幅值');
title('频谱');
title(layout,titleText,'FontWeight','normal','FontSize',11);
set(findall(fig,'-property','FontName'),'FontName','Microsoft YaHei');
set(findall(fig,'Type','axes'),'FontSize',9,'LineWidth',0.8,'TickDir','out');
exportgraphics(fig,outputPath,'Resolution',240);
if saveEditableFigure
    [figureDirectory,figureName] = fileparts(outputPath);
    % 后台绘图用于导出 PNG，但 FIG 必须保存为可见状态；否则双击打开后
    % MATLAB 会恢复 Visible=off，导致图窗存在但用户看不到。
    set(fig,'Visible','on');
    savefig(fig,fullfile(figureDirectory,[figureName '.fig']),'compact');
end
set(fig,'Visible','off');
close(fig);
end
