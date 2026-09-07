function apcv_plot_reproduction(lab, bridge, cfg)
%APCV_PLOT_REPRODUCTION 生成与论文图 6-18 信息结构相对应的合成复现图。
% 所有图均显示 Synthetic equivalent，避免与作者真实实验数据混淆。

colors.truth = [0.80 0.12 0.12];
colors.proposed = [0.10 0.10 0.10];
colors.amplitude = [0.90 0.45 0.05];
colors.blue = [0.00 0.45 0.70];
colors.green = [0.00 0.60 0.50];
colors.gray = [0.45 0.45 0.45];

plotSetup(lab, 6, 'Single-story building model', cfg, colors);
plotCalibration(lab, 7, 8, cfg, colors);
plotLabResults(lab, cfg, colors);
plotSetup(bridge, 15, 'Footbridge field test', cfg, colors);
plotBridgeCalibration(bridge, cfg, colors);
plotBridgeResults(bridge, cfg, colors);
end

function plotSetup(site, figureNumber, titleText, cfg, colors)
fig = figure('Visible','off','Position',[100 100 1120 380]);
tiledlayout(fig,1,3,'TileSpacing','compact','Padding','compact');
nexttile; axis equal off; hold on;
rectangle('Position',[0.08 0.22 0.32 0.38],'FaceColor',[0.75 0.78 0.82]);
rectangle('Position',[0.14 0.60 0.20 0.12],'FaceColor',colors.blue);
plot([0.34 0.78],[0.66 0.66],'-','Color',colors.proposed,'LineWidth',2);
quiver(0.26,0.78,0,0.14,0,'Color',colors.truth,'LineWidth',2,'MaxHeadSize',1);
text(0.10,0.12,'Moving structure / camera','FontSize',10);
text(0.55,0.70,'Tracking target','FontSize',10);
title('(a) Synthetic setup schematic');
nexttile; axis([0 1 0 1]); axis off; hold on;
plot([0.15 0.85],[0.50 0.50],'-k','LineWidth',5);
plot([0.25 0.25],[0.50 0.78],'-','Color',colors.blue,'LineWidth',3);
plot([0.75 0.75],[0.50 0.82],'-','Color',colors.gray,'LineWidth',6);
quiver(0.25,0.68,0.42,0,0,'Color',colors.amplitude,'LineWidth',2);
text(0.16,0.84,'Camera'); text(0.68,0.88,'Background target');
text(0.37,0.73,'Approx. standoff');
title('(b) Measurement geometry');
nexttile; imagesc(site.referenceImage); axis image off; colormap gray;
rectangle('Position',[25 30 95 65],'EdgeColor',colors.amplitude,'LineWidth',2);
title('(c) Synthetic FOV and ROI');
sgtitle(sprintf('Fig. %d equivalent - %s (Synthetic equivalent reproduction)', ...
    figureNumber, titleText),'FontWeight','bold');
apcv_export_figure(fig, fullfile(cfg.paths.figures, ...
    sprintf('figure_%02d_synthetic_setup', figureNumber)), cfg.figureDpi);
close(fig);
end

function plotCalibration(site, corrFigure, parameterFigure, cfg, colors)
idx = site.model.selectedIndex;
level = site.model.levels(idx);
fig = figure('Visible','off','Position',[100 100 1120 650]);
tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');
nexttile; imagesc(site.referenceImage); axis image off; colormap gray; title('(a) Synthetic FOV');
nexttile; imagesc(site.referenceImage); axis image off; title('(b) Selected ROI');
nexttile; imagesc(level.correlationMap,[-1 1]); axis image off; colorbar;
title(sprintf('(c) Phase correlation, level %d',site.model.selectedLevel));
nexttile; imagesc(level.activeMask); axis image off; colormap(gca,gray);
title(sprintf('(d) Active mask, threshold %.3f',level.correlationThreshold));
sgtitle(sprintf('Fig. %d equivalent - Active pixel selection (Synthetic equivalent)',corrFigure));
apcv_export_figure(fig,fullfile(cfg.paths.process,sprintf('figure_%02d_active_pixels',corrFigure)),cfg.figureDpi);
close(fig);

fig = figure('Visible','off','Position',[100 100 1180 330]);
tiledlayout(fig,1,4,'TileSpacing','compact','Padding','compact');
opt = site.model.optimization;
for pair = 1:3
    nexttile; x=opt.sequence{pair}; y=opt.sequence{pair+1};
    scatter(x,y,10,colors.blue,'filled'); hold on;
    xx=linspace(min(x),max(x),100)';
    yy=opt.fitSlope(pair)*xx+opt.fitIntercept(pair);
    plot(xx,yy,'--','Color',colors.amplitude,'LineWidth',1.2);
    xlabel(sprintf('Phase L%d (rad)',pair)); ylabel(sprintf('Phase L%d (rad)',pair+1));
    title(sprintf('L%d vs L%d, R^2=%.3f',pair,pair+1,opt.pairR2(pair)));
    grid on;
end
nexttile; response=level.calibrationResponse;
plot(response,'o','Color',colors.green,'MarkerSize',3); hold on;
yline(mean(response,'omitnan'),'--','Color',colors.proposed,'LineWidth',1.2);
xlabel('Calibration frame'); ylabel('Phase / pixel (rad)');
title(sprintf('Scale = %.3f px/rad',level.scaleSelf)); grid on;
sgtitle(sprintf('Fig. %d equivalent - Level optimization and self-calibration (Synthetic equivalent)',parameterFigure));
apcv_export_figure(fig,fullfile(cfg.paths.process,sprintf('figure_%02d_parameter_calibration',parameterFigure)),cfg.figureDpi);
close(fig);
end

function plotLabResults(site,cfg,colors)
results=site.results;
fig=figure('Visible','off','Position',[100 100 1180 780]);
tiledlayout(fig,5,1,'TileSpacing','compact','Padding','compact');
for i=1:5
    nexttile; r=results(i); hold on;
    plot(r.time,r.truthMm,':','Color',colors.truth,'LineWidth',1.0);
    plot(r.time,r.estimate.amplitudeOnlyMm,'-.','Color',colors.amplitude,'LineWidth',1.0);
    plot(r.time,r.estimate.proposedMm,'-','Color',colors.proposed,'LineWidth',1.0);
    ylabel('mm'); grid on; title(sprintf('(%c) %s | Fusion RMSE %.3f mm',96+i,r.name,r.metrics.proposed.rmse));
    if i==1; legend('Ground truth','Amplitude only','Fusion','Location','best','NumColumns',3); end
end
xlabel('Time (s)'); sgtitle('Fig. 9 equivalent - Laboratory displacement (Synthetic equivalent reproduction)');
apcv_export_figure(fig,fullfile(cfg.paths.figures,'figure_09_lab_displacement'),cfg.figureDpi); close(fig);

fig=figure('Visible','off','Position',[100 100 1050 330]);
r=results(1); idx=site.model.selectedIndex;
plot(r.time,r.estimate.unalignedPhase(:,idx),'Color',colors.proposed,'LineWidth',0.8); grid on;
xlabel('Time (s)'); ylabel('Unaligned phase (rad)');
title('Fig. 10 equivalent - Phase without amplitude alignment (Synthetic equivalent)');
apcv_export_figure(fig,fullfile(cfg.paths.process,'figure_10_unaligned_phase'),cfg.figureDpi); close(fig);

fig=figure('Visible','off','Position',[100 100 1180 760]);
tiledlayout(fig,5,1,'TileSpacing','compact','Padding','compact');
for i=1:5
    nexttile; r=results(i); truthResidual=r.truthMm/site.gammaMmPerPixel-r.estimate.coarsePx;
    plot(r.time,truthResidual,':','Color',colors.truth); hold on;
    plot(r.time,r.estimate.translationExistingPx,'--','Color',colors.gray);
    plot(r.time,r.estimate.translationProposedPx,'-','Color',colors.proposed);
    ylabel('pixel'); grid on; title(sprintf('(%c) %s',96+i,r.name));
    if i==1; legend('Ground truth residual','Uncalibrated phase','Self-calibrated','NumColumns',3); end
end
xlabel('Time (s)'); sgtitle('Fig. 11 equivalent - Residual translation after coarse alignment (Synthetic equivalent)');
apcv_export_figure(fig,fullfile(cfg.paths.figures,'figure_11_scale_comparison'),cfg.figureDpi); close(fig);

fig=figure('Visible','off','Position',[100 100 1120 340]); tiledlayout(fig,1,3,'TileSpacing','compact');
r=results(1); idx=site.model.selectedIndex; level=site.model.levels(idx);
nexttile; plot(r.time,r.estimate.phaseAll(:,idx),'--','Color',colors.gray); hold on;
plot(r.time,r.estimate.phaseActive(:,idx),'-','Color',colors.proposed); grid on; title('(a) Averaged phase'); legend('All pixels','Active pixels');
nexttile; plot(level.calibrationResponseAll,'.','Color',colors.gray); hold on; plot(level.calibrationResponse,'.','Color',colors.green); grid on; title('(b) +/-1 pixel response');
nexttile;
allRmse=arrayfun(@(x)x.metrics.allPixels.rmse,results); activeRmse=arrayfun(@(x)x.metrics.proposed.rmse,results);
bar([allRmse(:),activeRmse(:)]); ylabel('RMSE (mm)'); xlabel('Case'); title('(c) Displacement error'); legend('All pixels','Active pixels'); grid on;
sgtitle('Fig. 12 equivalent - Necessity of active pixels (Synthetic equivalent)');
apcv_export_figure(fig,fullfile(cfg.paths.figures,'figure_12_active_vs_all'),cfg.figureDpi); close(fig);

fig=figure('Visible','off','Position',[100 100 900 340]); tiledlayout(fig,1,2,'TileSpacing','compact');
nexttile; plot(r.time,r.estimate.phaseAmplitude(:,idx),'--','Color',colors.amplitude); hold on; plot(r.time,r.estimate.phaseActive(:,idx),'-','Color',colors.proposed); grid on; title('(a) Phase signals'); legend('Amplitude mask','Correlation mask');
nexttile; ampRmse=arrayfun(@(x)x.metrics.amplitudeMask.rmse,results); bar([ampRmse(:),activeRmse(:)]); grid on; ylabel('RMSE (mm)'); xlabel('Case'); title('(b) Active-pixel algorithm'); legend('Amplitude threshold','Proposed correlation');
sgtitle('Fig. 13 equivalent - Active pixel selection comparison (Synthetic equivalent)');
apcv_export_figure(fig,fullfile(cfg.paths.figures,'figure_13_active_method_comparison'),cfg.figureDpi); close(fig);

fig=figure('Visible','off','Position',[100 100 900 360]); rmse=zeros(5,numel(cfg.pyramidLevels));
for i=1:5; for j=1:numel(cfg.pyramidLevels); rmse(i,j)=results(i).metrics.byLevel(j).rmse; end; end
bar(rmse); grid on; ylabel('RMSE (mm)'); xlabel('Laboratory case'); legend(compose('Level %d',cfg.pyramidLevels),'Location','best');
title(sprintf('Fig. 14 equivalent - Pyramid levels; selected level %d (Synthetic equivalent)',site.model.selectedLevel));
apcv_export_figure(fig,fullfile(cfg.paths.figures,'figure_14_pyramid_levels'),cfg.figureDpi); close(fig);
end

function plotBridgeCalibration(site,cfg,colors)
idx=site.model.selectedIndex; level=site.model.levels(idx); opt=site.model.optimization;
fig=figure('Visible','off','Position',[100 100 1120 340]); tiledlayout(fig,1,3,'TileSpacing','compact');
nexttile; imagesc(level.correlationMap,[-1 1]); axis image off; colorbar; hold on; contour(level.activeMask,[0.5 0.5],'k','LineWidth',0.7); title('(a) Correlation map / mask');
nexttile; yyaxis left; plot(1:3,opt.pairR2,'-o','Color',colors.amplitude,'LineWidth',1.4); ylabel('R^2'); yyaxis right; plot(1:3,abs(opt.fitSlope),'-s','Color',colors.blue,'LineWidth',1.4); ylabel('|slope|'); xticks(1:3); xticklabels({'L1-L2','L2-L3','L3-L4'}); grid on; title('(b) Adjacent-level linearity');
nexttile; plot(level.calibrationResponse,'.','Color',colors.green); hold on; yline(mean(level.calibrationResponse,'omitnan'),'--k'); grid on; xlabel('Calibration frame'); ylabel('rad/pixel'); title(sprintf('(c) Scale %.3f px/rad',level.scaleSelf));
sgtitle('Fig. 16 equivalent - Footbridge calibration (Synthetic equivalent reproduction)');
apcv_export_figure(fig,fullfile(cfg.paths.process,'figure_16_bridge_calibration'),cfg.figureDpi); close(fig);
end

function plotBridgeResults(site,cfg,colors)
results=site.results;
fig=figure('Visible','off','Position',[100 100 1180 700]); tiledlayout(fig,4,2,'TileSpacing','compact','Padding','compact');
for i=1:8
    nexttile; r=results(i); plot(r.time,r.truthMm,':','Color',colors.truth,'LineWidth',0.9); hold on; plot(r.time,r.estimate.proposedMm,'-','Color',colors.proposed,'LineWidth',0.9); grid on; ylabel('mm'); title(sprintf('(%c) Scenario %d, RMSE %.3f mm',96+i,i,r.metrics.proposed.rmse)); if i==1; legend('Ground truth','Proposed'); end
end
xlabel('Time (s)'); sgtitle('Fig. 17 equivalent - Footbridge displacement (Synthetic equivalent reproduction)');
apcv_export_figure(fig,fullfile(cfg.paths.figures,'figure_17_bridge_displacement'),cfg.figureDpi); close(fig);

fig=figure('Visible','off','Position',[100 100 1050 360]); tiledlayout(fig,1,2,'TileSpacing','compact');
rmse=zeros(8,numel(cfg.pyramidLevels)); for i=1:8; for j=1:numel(cfg.pyramidLevels); rmse(i,j)=results(i).metrics.byLevel(j).rmse; end; end
nexttile; bar(rmse); grid on; ylabel('RMSE (mm)'); xlabel('Scenario'); legend(compose('Level %d',cfg.pyramidLevels),'Location','best'); title('(a) Pyramid levels');
existing=arrayfun(@(x)x.metrics.existingScale.rmse,results); proposed=arrayfun(@(x)x.metrics.proposed.rmse,results);
nexttile; bar([existing(:),proposed(:)]); grid on; ylabel('RMSE (mm)'); xlabel('Scenario'); legend('Uncalibrated phase','Self-calibrated'); title('(b) Scale calibration');
sgtitle('Fig. 18 equivalent - Footbridge parameter comparison (Synthetic equivalent)');
apcv_export_figure(fig,fullfile(cfg.paths.figures,'figure_18_bridge_parameter_comparison'),cfg.figureDpi); close(fig);
end
