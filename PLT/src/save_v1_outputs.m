function save_v1_outputs(outputDir, firstFrame, template, allResults, cfg, fps, frames, trueCenters)
% SAVE_V1_OUTPUTS 保存报告第 53 节要求的 V1 复现证据和论文风格图。
% trueCenters 只供合成验证图参考；真实视频应传入 []，不伪造误差指标。

if nargin < 8, trueCenters = []; end
if ~isfolder(outputDir), mkdir(outputDir); end
primaryIndex = numel(allResults);
primary = allResults(primaryIndex);
n = size(primary.center,1); t = (0:n-1)'/fps;

save_roi_figure(outputDir, firstFrame, template.roi, cfg);
save_template_figure(outputDir, template, cfg);
save_reliability_figure(outputDir, template, cfg);
save_trajectory_figure(outputDir, t, allResults, trueCenters, cfg);
save_score_figure(outputDir, t, primary, cfg);
save_scalar_figure(outputDir, t, primary.peakRatio, 'Peak ratio', '07_peak_ratio.png', cfg);
save_scalar_figure(outputDir, t, primary.crossScaleAgreement, 'Cross-scale agreement', '08_cross_scale_agreement.png', cfg);
save_scalar_figure(outputDir, t, primary.subpixelResidualRms, 'Subpixel WLS residual (rad)', '09_subpixel_residual.png', cfg);
save_comparison_figure(outputDir, t, allResults, cfg);

if cfg.output.writeTrackingVideo && ~isempty(frames)
    try
        write_tracking_overlay_video(frames, primary.center, template.roi, fps, ...
            fullfile(outputDir, '04_tracking_overlay.mp4'));
    catch videoError
        warning('MP-G2LPT:VideoWriter', '过程视频写入失败：%s', videoError.message);
    end
end

tracking = table((1:n)', t, primary.center(:,1), primary.center(:,2), ...
    primary.integerCenter(:,1), primary.integerCenter(:,2), ...
    primary.subpixel(:,1), primary.subpixel(:,2), primary.valid, ...
    'VariableNames', {'frame','time_s','x_px','y_px','integer_x_px','integer_y_px','subpixel_x_px','subpixel_y_px','valid'});
quality = table((1:n)', t, primary.quality, primary.phaseScore, primary.peakRatio, ...
    primary.crossScaleAgreement, primary.subpixelResidualRms, primary.valid, ...
    'VariableNames', {'frame','time_s','quality','phase_score','peak_ratio','cross_scale_agreement','subpixel_residual_rad','valid'});
writetable(tracking, fullfile(outputDir, 'tracking.csv'));
writetable(quality, fullfile(outputDir, 'quality.csv'));

configForJson = cfg;
if isinf(configForJson.video.maxFrames), configForJson.video.maxFrames = 'Inf'; end
if isempty(configForJson.video.fpsOverride), configForJson.video.fpsOverride = 'video_fps'; end
fid = fopen(fullfile(outputDir, 'config.json'), 'w', 'n', 'UTF-8');
if fid > 0
    fwrite(fid, jsonencode(configForJson), 'char'); fclose(fid);
end
phase_tracking_result = struct('method', {allResults.name}, 'results', allResults, ...
    'fps', fps, 'roi', template.roi, 'trueCenters', trueCenters);
save(fullfile(outputDir, 'phase_tracking_result.mat'), 'phase_tracking_result', '-v7.3');
end

function save_roi_figure(outDir, frame, roi, cfg)
fig=make_figure(cfg,'off'); imshow(frame); hold on; rectangle('Position',roi,'EdgeColor',cfg.plot.red,'LineWidth',1.5);
title('Initial ROI','FontName',cfg.plot.fontName); save_png(fig,fullfile(outDir,'01_initial_roi.png')); close(fig);
end

function save_template_figure(outDir, template, cfg)
[ns,no]=size(template.channels); fig=make_figure(cfg,'off');
for s=1:ns
    for o=1:no
        subplot(ns,no,(s-1)*no+o); imagesc(template.channels(s,o).phase); axis image off; colormap(gca,hsv(256));
        title(sprintf('lambda=%g, %g deg',template.channels(s,o).wavelength,template.channels(s,o).orientationDeg),...
            'FontName',cfg.plot.fontName,'FontSize',8);
    end
end
save_png(fig,fullfile(outDir,'02_phase_template_scales.png')); close(fig);
end

function save_reliability_figure(outDir, template, cfg)
[ns,no]=size(template.channels); mask=false(size(template.channels(1,1).phase));
for s=1:ns, for o=1:no, mask=mask|template.channels(s,o).reliability; end, end
fig=make_figure(cfg,'off'); imagesc(mask); axis image off; colormap(gca,gray(2)); title('Phase reliability support','FontName',cfg.plot.fontName);
save_png(fig,fullfile(outDir,'03_phase_reliability_mask.png')); close(fig);
end

function save_trajectory_figure(outDir,t,allResults,trueCenters,cfg)
fig=make_figure(cfg,'off');
subplot(2,1,1); hold on; plot_methods(t,allResults,1,cfg); ylabel('X position (px)'); style_axes(cfg);
subplot(2,1,2); hold on; plot_methods(t,allResults,2,cfg); ylabel('Y position (px)'); xlabel('Time (s)'); style_axes(cfg);
if ~isempty(trueCenters), subplot(2,1,1); plot(t,trueCenters(:,1),'k--','LineWidth',0.8); subplot(2,1,2); plot(t,trueCenters(:,2),'k--','LineWidth',0.8); end
save_png(fig,fullfile(outDir,'05_tracking_trajectory.png')); close(fig);
end

function save_score_figure(outDir,t,result,cfg)
fig=make_figure(cfg,'off'); subplot(2,1,1); plot(t,result.quality,'Color',cfg.plot.blue,'LineWidth',1); ylabel('Tracking quality'); ylim([0 1]); style_axes(cfg);
subplot(2,1,2); plot(t,result.phaseScore,'Color',cfg.plot.blue,'LineWidth',1); ylabel('Phase score'); xlabel('Time (s)'); ylim([-1 1]); style_axes(cfg);
save_png(fig,fullfile(outDir,'06_tracking_score.png')); close(fig);
end

function save_scalar_figure(outDir,t,y,ylabelText,fileName,cfg)
fig=make_figure(cfg,'off'); plot(t,y,'Color',cfg.plot.blue,'LineWidth',1); xlabel('Time (s)'); ylabel(ylabelText); style_axes(cfg);
save_png(fig,fullfile(outDir,fileName)); close(fig);
end

function save_comparison_figure(outDir,t,allResults,cfg)
fig=make_figure(cfg,'off'); hold on; colors=lines(numel(allResults));
for k=1:numel(allResults), plot(t,allResults(k).center(:,1),'Color',colors(k,:),'LineWidth',1); end
legend({allResults.name},'Location','best'); xlabel('Time (s)'); ylabel('X position (px)'); style_axes(cfg);
save_png(fig,fullfile(outDir,'10_method_comparison.png')); close(fig);
end

function plot_methods(t,allResults,dimension,cfg)
colors=lines(numel(allResults));
for k=1:numel(allResults), plot(t,allResults(k).center(:,dimension),'Color',colors(k,:),'LineWidth',1); end
legend({allResults.name},'Location','best'); style_axes(cfg);
end

function fig=make_figure(cfg,visible)
fig=figure('Visible',visible,'Color','w','Units','pixels','Position',[100 100 900 620]);
set(fig,'DefaultAxesFontName',cfg.plot.fontName,'DefaultAxesFontSize',cfg.plot.fontSize,'DefaultLineLineWidth',1);
end

function style_axes(cfg)
ax=gca; set(ax,'Box','on','LineWidth',0.8,'FontName',cfg.plot.fontName,'FontSize',cfg.plot.fontSize,'TickDir','out'); grid(ax,'off');
end

function save_png(fig,path)
if exist('exportgraphics','file')==2, exportgraphics(fig,path,'Resolution',180); else, saveas(fig,path); end
end

function write_tracking_overlay_video(frames,centers,roi,fps,outPath)
try
    write_video_once(frames,centers,roi,fps,outPath,'MPEG-4');
catch
    if isfile(outPath), delete(outPath); end
    write_video_once(frames,centers,roi,fps,strrep(outPath,'.mp4','.avi'),'Motion JPEG AVI');
end
end

function write_video_once(frames,centers,roi,fps,outPath,profile)
writer=VideoWriter(outPath,profile); writer.FrameRate=fps; open(writer); fig=figure('Visible','off','Color','w');
try
    for k=1:numel(frames)
        imshow(frames{k}); hold on; rectangle('Position',[centers(k,1)-roi(3)/2+0.5,centers(k,2)-roi(4)/2+0.5,roi(3),roi(4)],'EdgeColor',[1 0 0],'LineWidth',1.5);
        plot(centers(k,1),centers(k,2),'r+','MarkerSize',8,'LineWidth',1.2); hold off; writeVideo(writer,getframe(fig));
    end
    close(writer); close(fig);
catch err
    close(writer); close(fig); rethrow(err);
end
end
