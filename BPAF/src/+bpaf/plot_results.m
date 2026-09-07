function plot_results(results, datasets, cfg)
%PLOT_RESULTS 生成与论文图5、8-20信息结构对应的正式复现图。

set(groot, 'defaultAxesFontName', 'Times New Roman', ...
    'defaultAxesFontSize', 9, 'defaultLineLineWidth', 1.0);
paperColors = lines(4);

% Fig. 5：时域核与幅频响应。
fig = new_figure(cfg, [900 620]);
tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
nexttile; hold on;
for idx=1:numel(results.filterDemo)
    d=results.filterDemo(idx);
    plot(d.info.timeIndex,d.kernel,'Color',paperColors(idx,:));
end
xlabel('Index'); ylabel('Amplitude'); legend(band_labels(results.filterDemo),'Location','best'); grid on;
nexttile; hold on;
for idx=1:numel(results.filterDemo)
    [h,f]=freqz(results.filterDemo(idx).kernel,1,4096,120);
    plot(f,abs(h),'Color',paperColors(idx,:));
end
xlim([0 60]); ylim([0 1.05]); xlabel('Frequency (Hz)'); ylabel('Amplitude'); grid on;
save_figure(fig,cfg.figureDir,'fig05_bpaf_kernels.png');

% Fig. 8：两类模拟场景与位移真值。
fig = new_figure(cfg,[1100 680]); tiledlayout(2,4,'TileSpacing','compact','Padding','compact');
for caseIdx=1:2
    d=datasets{caseIdx}; ids=round(linspace(1,size(d.frames,3),3));
    for j=1:3
        nexttile((caseIdx-1)*4+j);
        imagesc(d.frames(:,:,ids(j)));
        axis image off;
        colormap gray;
        title(sprintf('%s frame %d',d.spec.id,ids(j)));
    end
    nexttile(caseIdx*4); plot(d.truth.time,d.truth.largeMotionPx,'k'); hold on;
    plot(d.truth.time,50*d.truth.vibrationPx,'r'); grid on;
    xlabel('Time (s)'); ylabel('Displacement (px)'); title([d.spec.id ' truth (vibration x50)']);
end
save_figure(fig,cfg.figureDir,'fig08_simulation_setup.png');

% Fig. 9：原始相位与 BPAF 输出。
fig = new_figure(cfg,[1050 520]); tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for caseIdx=1:2
    nexttile((caseIdx-1)*2+1); plot(results.sim(caseIdx).time,results.sim(caseIdx).rawSignal,'k');
    xlabel('Time (s)'); ylabel('Phase (rad)'); title([results.sim(caseIdx).id ' raw phase']); grid on;
    nexttile((caseIdx-1)*2+2); plot(results.sim(caseIdx).time,results.sim(caseIdx).methods(4).signal,'b');
    xlabel('Time (s)'); ylabel('Filtered phase (rad)'); title([results.sim(caseIdx).id ' BPAF']); grid on;
end
save_figure(fig,cfg.figureDir,'fig09_raw_and_bpaf_phase.png');

% Fig. 10：四种方法、两种大运动下的波形与频谱。
fig = new_figure(cfg,[1350 900]); tiledlayout(4,4,'TileSpacing','compact','Padding','compact');
for caseIdx=1:2
    for methodIdx=1:4
        r=results.sim(caseIdx).methods(methodIdx);
        tile=(caseIdx-1)*8+methodIdx;
        nexttile(tile); plot(results.sim(caseIdx).time,r.signal,'k'); grid on; xlim([0 4]);
        title(r.method); ylabel([results.sim(caseIdx).id ' phase']);
        nexttile(tile+4); plot(r.metrics.frequency,r.metrics.spectrum,'k'); grid on; xlim([0 100]); ylim([0 1.05]);
        xlabel('Frequency (Hz)'); ylabel('Amp');
    end
end
save_figure(fig,cfg.figureDir,'fig10_simulation_comparison.png');

% Fig. 11：归一化波形叠加。
fig = new_figure(cfg,[1300 530]); tiledlayout(2,4,'TileSpacing','compact','Padding','compact');
for caseIdx=1:2
    for methodIdx=1:4
        r=results.sim(caseIdx).methods(methodIdx); nexttile((caseIdx-1)*4+methodIdx);
        plot(results.sim(caseIdx).time,r.metrics.normalizedTruth,'b'); hold on;
        plot(results.sim(caseIdx).time,r.metrics.normalizedSignal,'r'); grid on; xlim([0 4]); ylim([0 1]);
        title([results.sim(caseIdx).id ' ' r.method]); xlabel('Time (s)');
    end
end
legend({'Ground truth','Estimated'},'Location','best');
save_figure(fig,cfg.figureDir,'fig11_waveform_overlay.png');

% Fig. 12：PVE / BP / BP+NS 消融。
fig = new_figure(cfg,[1100 900]); tiledlayout(4,3,'TileSpacing','compact','Padding','compact');
for caseIdx=1:2
    models={results.sim(caseIdx).pve,results.sim(caseIdx).bp,results.sim(caseIdx).methods(4)};
    names={'PVE','BP','BP+NS'};
    for modelIdx=1:3
        r=models{modelIdx}; tile=(caseIdx-1)*6+modelIdx;
        nexttile(tile); plot(results.sim(caseIdx).time,r.signal,'k'); grid on; title(names{modelIdx}); ylabel(results.sim(caseIdx).id);
        nexttile(tile+3); plot(r.metrics.frequency,r.metrics.spectrum,'k'); grid on; xlim([0 100]); ylim([0 1.05]); xlabel('Frequency (Hz)');
    end
end
save_figure(fig,cfg.figureDir,'fig12_ablation.png');

% Fig. 13：BPAF 在不同先验上限下的 PF/PER。
fig = new_figure(cfg,[950 650]); tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
for caseIdx=1:2
    p=results.simPerformance(caseIdx); nexttile; yyaxis left;
    plot(p.fhValues,p.bpafPER,'k.-'); ylabel('PER'); ylim([0 1]);
    yyaxis right; plot(p.fhValues,p.bpafPF,'r+--'); ylabel('PF (Hz)'); yline(20,'r:');
    xlabel('FH (Hz)'); title(p.id); grid on;
end
save_figure(fig,cfg.figureDir,'fig13_bpaf_prior_performance.png');

% Fig. 14：对比方法的估计频率扫描。
fig = new_figure(cfg,[1250 700]); tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
for caseIdx=1:2
    p=results.simPerformance(caseIdx);
    for methodIdx=1:3
        nexttile((caseIdx-1)*3+methodIdx); yyaxis left;
        plot(p.feValues,squeeze(p.accPER(methodIdx,:)),'k.-'); ylabel('PER'); ylim([0 1]);
        yyaxis right; plot(p.feValues,squeeze(p.accPF(methodIdx,:)),'r+--'); ylabel('PF (Hz)'); yline(20,'r:');
        accYears = [2017 2018 2022];
        title([p.id ' Acc' num2str(accYears(methodIdx))]); xlabel('FE (Hz)'); grid on;
    end
end
save_figure(fig,cfg.figureDir,'fig14_acc_prior_performance.png');

% Fig. 15：移动激振器等价模拟场景。
fig = proxy_setup_figure(datasets{3},cfg,'Exciter proxy');
save_figure(fig,cfg.figureDir,'fig15_exciter_proxy_setup.png');

% Fig. 16：激振器三种先验等级频谱。
fig = new_figure(cfg,[1300 780]); tiledlayout(3,4,'TileSpacing','compact','Padding','compact');
for lev=1:3
    for methodIdx=1:4
        r=results.exciter.methods(lev,methodIdx); nexttile((lev-1)*4+methodIdx);
        plot(r.metrics.frequency,r.metrics.spectrum,'k'); xline(30.7,'r--'); xlim([0 100]); ylim([0 1.05]); grid on;
        title(['L' num2str(lev) ' ' r.method]); xlabel('Frequency (Hz)');
    end
end
save_figure(fig,cfg.figureDir,'fig16_exciter_proxy_spectra.png');

% Fig. 17：悬臂梁等价模拟场景。
fig = proxy_setup_figure(datasets{4},cfg,'Cantilever beam proxy');
save_figure(fig,cfg.figureDir,'fig17_beam_proxy_setup.png');

% Fig. 18/19：悬臂梁频谱与波形。
figS = new_figure(cfg,[1300 780]); tiledlayout(3,4,'TileSpacing','compact','Padding','compact');
figW = new_figure(cfg,[1300 780]); tiledlayout(figW,3,4,'TileSpacing','compact','Padding','compact');
for lev=1:3
    for methodIdx=1:4
        r=results.beam.methods(lev,methodIdx); tile=(lev-1)*4+methodIdx;
        figure(figS); nexttile(tile); plot(r.metrics.frequency,r.metrics.spectrum,'k'); hold on;
        plot(results.beam.ground.metrics.frequency,results.beam.ground.metrics.spectrum,'r--'); xlim([0 50]); ylim([0 1.05]); grid on;
        title(['L' num2str(lev) ' ' r.method]); xlabel('Frequency (Hz)');
        figure(figW); nexttile(tile); plot(results.beam.time,r.metrics.normalizedSignal,'k'); hold on;
        plot(results.beam.time,r.metrics.normalizedTruth,'r--'); xlim([0 6]); ylim([0 1]); grid on;
        title(['L' num2str(lev) ' ' r.method]); xlabel('Time (s)');
    end
end
save_figure(figS,cfg.figureDir,'fig18_beam_proxy_spectra.png');
save_figure(figW,cfg.figureDir,'fig19_beam_proxy_waveforms.png');

% Fig. 20：极少先验频带。
fig = new_figure(cfg,[950 700]); tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for idx=1:4
    r=results.beam.limits(idx); nexttile;
    plot(r.metrics.frequency,r.metrics.spectrum,'k'); hold on;
    plot(results.beam.ground.metrics.frequency,results.beam.ground.metrics.spectrum,'r--');
    xlim([0 50]); ylim([0 1.05]); grid on; xlabel('Frequency (Hz)');
    title(['Band ' mat2str(results.beam.limitBands(idx,:)) ' Hz']);
end
save_figure(fig,cfg.figureDir,'fig20_beam_proxy_limited_prior.png');
close all;
end

function labels = band_labels(demo)
labels=cell(1,numel(demo));
for idx=1:numel(demo), labels{idx}=sprintf('%g-%g Hz',demo(idx).band); end
end

function fig = proxy_setup_figure(data,cfg,heading)
fig=new_figure(cfg,[1050 600]); tiledlayout(2,3,'TileSpacing','compact','Padding','compact');
ids=round(linspace(1,size(data.frames,3),3));
for idx=1:3
    nexttile(idx); imagesc(data.frames(:,:,ids(idx))); axis image off; colormap gray; title(['Frame ' num2str(ids(idx))]);
end
nexttile([1 3]); plot(data.truth.time,data.truth.largeMotionPx,'k'); hold on;
plot(data.truth.time,20*data.truth.vibrationPx,'r'); grid on; xlabel('Time (s)'); ylabel('Displacement (px)');
title([heading ' motion truth (vibration x20)']); legend({'Large motion','Vibration x20'});
end

function fig = new_figure(cfg,wh)
fig=figure('Visible',cfg.figureVisible,'Color','w','Position',[100 100 wh]);
end

function save_figure(fig,folder,name)
exportgraphics(fig,fullfile(folder,name),'Resolution',200);
end
