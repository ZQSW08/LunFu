function summary = run_reproduce()
%RUN_REPRODUCE 运行 LoG-Gabor 论文方法级与等价实验复现。
% 真实论文视频、LDV 和加速度计数据未随项目提供，因此本入口保存的
% steel/cable/SSRM 结果均明确标为“论文条件等价模拟”，并保留真值。
root=fileparts(fileparts(mfilename('fullpath'))); addpath(genpath(fullfile(root,'src'))); addpath(fullfile(root,'configs'));
cfg=default_config(); ensure_output_dirs(cfg); rng(cfg.randomSeed,'twister');

%% A-C: Fourier shift -> Log-Gabor -> single-point PME
time=(0:cfg.synthetic.frames-1)'/cfg.synthetic.fs;
[coreX,coreY]=meshgrid(1:cfg.synthetic.width,1:cfg.synthetic.height);
% Level-1 真值样例使用与滤波器中心频率对齐的正弦纹理，直接验证 Fourier
% shift 与 phase-to-displacement 的数值关系；它不是论文实验图像。
coreReference=0.5+0.4*cos(2*pi*cfg.loggabor.centerFrequency*coreY)+0.03*cos(2*pi*coreX/13);
truthXY=[zeros(size(time)), cfg.synthetic.amplitude*sin(2*pi*cfg.synthetic.frequency*time)];
[video,truthXY]=generate_synthetic_video(coreReference,truthXY,cfg);
truth=truthXY(:,2); pixel=[round(cfg.synthetic.height/2),round(cfg.synthetic.width/2)+5];
params=cfg.loggabor.defaultParams; theta0=cfg.synthetic.motionAngle;
pme=pme_measure(video,params,cfg,pixel,theta0);
coreRMSE=sqrt(mean((pme.displacement-truth).^2));
save(fullfile(cfg.outputs.process,'core_baseline.mat'),'coreReference','video','truthXY','pme','params','pixel','cfg');
save_core_figure(coreReference,video,truth,pme,params,cfg.outputs.process);
save_fig1_style(coreReference,cfg,cfg.outputs.process);
save_single_flow_figure(coreReference,video,pme,params,cfg,cfg.outputs.process);
write_video_preview(video,fullfile(cfg.outputs.videos,'synthetic_core.avi'),cfg.synthetic.fs);

%% D: Table 1 风格参数扫描
sweepParams=[1 2 2;5 2 2;20 2 2;20 .5 .5;20 .15 .15];
sweepRMSE=zeros(size(sweepParams,1),1);
for i=1:size(sweepParams,1)
    sweepRMSE(i)=objective_rmse(sweepParams(i,:),video,truth,pixel,cfg,theta0);
end
sweepTable=table((1:5)',sweepParams(:,1),sweepParams(:,2),sweepParams(:,3),sweepRMSE,...
    'VariableNames',{'Filter','HAB','RSD','ASD','RMSE_pixel'});
writetable(sweepTable,fullfile(cfg.outputs.tables,'parameter_sweep.csv'));

%% E: 单任务优化 baseline
single=single_task_optimize(video,truth,pixel,cfg,theta0);
save(fullfile(cfg.outputs.process,'single_task_result.mat'),'single','sweepTable');
save_convergence_figure(single.history,cfg.outputs.figures,'single_task_convergence');

%% F-M: cable 等价全场实验 + MaTO + ODS
reference=make_reference_scene(cfg.synthetic.height,cfg.synthetic.width,'cable');
timeField=(0:89)'/cfg.synthetic.fs;
[xx,yy]=meshgrid(1:cfg.synthetic.width,1:cfg.synthetic.height); %#ok<ASGLU>
modeCable=exp(-((xx-cfg.synthetic.width/2)/(cfg.synthetic.width*.12)).^2);
[cableVideo,cableTruth]=generate_mode_video(reference,timeField,modeCable,cfg);
activeCable=active_pixel_selection(cableVideo(:,:,1),cfg);
taskInfo=build_task_map(size(reference,1),size(reference,2),activeCable.activeMask);
selected=choose_task_centers(taskInfo.activeTaskPixels,24);
taskMap=nearest_task_map(size(reference),selected);
taskTruth=zeros(size(selected,1),numel(timeField));
for i=1:size(selected,1), taskTruth(i,:)=squeeze(cableTruth(selected(i,1),selected(i,2),:)); end
mato=mato_optimize(cableVideo,taskTruth,selected,cfg,cfg.synthetic.motionAngle);
cableSingleCfg=cfg; cableSingleCfg.mato.populationSize=5; cableSingleCfg.mato.generations=cfg.mato.generations;
cableSingle=single_task_optimize(cableVideo,taskTruth(1,:)',selected(1,:),cableSingleCfg,cfg.synthetic.motionAngle);
fieldResult=fullfield_pme(cableVideo,taskMap,selected,mato.bestX,cfg,cfg.synthetic.motionAngle);
fieldResult.rawDisplacement=fieldResult.displacement;
fieldResult.activeMask=activeCable.activeMask;
fieldResult.displacement=fieldResult.displacement.*repmat(activeCable.activeMask,1,1,size(fieldResult.displacement,3));
representative=pme_measure(cableVideo,mato.bestX(1,:),cfg,selected(1,:),cfg.synthetic.motionAngle);
mato.mmdMatrix=compute_mmd_matrix(mato,cfg.mato.kernelWidth);
odsInstant=instantaneous_ods(fieldResult.displacement,45);
odsFrequency=frequency_ods(fieldResult.displacement,cfg.synthetic.fs,cfg.synthetic.frequency,cfg.ods.bandwidth);
save(fullfile(cfg.outputs.process,'cable_equivalent_result.mat'),'cableVideo','cableTruth','activeCable','taskInfo','selected','mato','cableSingle','fieldResult','representative','odsInstant','odsFrequency','cfg');
save(fullfile(cfg.outputs.process,'cable_representative_intermediates.mat'),'representative');
save_mask_figure(cableVideo(:,:,1),activeCable,cfg.outputs.process,'cable_active_pixels');
save_task_mapping_figure(taskInfo,selected,cfg.outputs.process);
save_fullfield_process_figure(cableVideo(:,:,1),activeCable,taskInfo,fieldResult,cfg.outputs.process);
save_representative_intermediate_figure(representative,cfg.outputs.process);
save_mmd_figure(mato,cfg,cfg.outputs.figures);
save_mato_convergence_figure(mato,cableSingle,cfg.outputs.figures);
save_amp_figure(mato,cfg.outputs.process);
save_ods_figure(odsInstant,odsFrequency,cfg.outputs.figures,'cable_ods');
save_cable_comparison_figure(cableVideo,cableTruth,selected,mato,cableSingle,cfg,cfg.outputs.figures);
save_cable_roi_figure(fieldResult,cableTruth,selected,cfg,cfg.outputs.figures);
save_ods_frames_figure(reference,fieldResult,cfg.outputs.figures);
save_harmonic_ods_figure(fieldResult,cfg,cfg.outputs.figures);
write_video_preview(cableVideo,fullfile(cfg.outputs.videos,'cable_equivalent.avi'),cfg.synthetic.fs);

%% N1: steel plate 等价 proof-of-principle（32 位置中的代表性子集）
steelCfg=cfg; steelCfg.mato.populationSize=5; steelCfg.mato.generations=6; steelCfg.synthetic.frequency=7;
steelReference=make_reference_scene(cfg.synthetic.height,cfg.synthetic.width,'steel');
steelTime=(0:59)'/250; steelXY=[zeros(size(steelTime)),.04*sin(2*pi*7*steelTime)];
[steelVideo,steelXY]=generate_synthetic_video(steelReference,steelXY,steelCfg);
roi=[16 16;16 32;16 48;32 16;32 32;32 48;48 16;48 32;48 48];
steelRows=zeros(size(roi,1),5);
for i=1:size(roi,1)
    r=single_task_optimize(steelVideo,steelXY(:,2),roi(i,:),steelCfg,pi/2);
    steelRows(i,:)=[i,r.bestX,r.bestFitness];
end
steelTable=array2table(steelRows,'VariableNames',{'ROI','HAB','RSD','ASD','RMSE_pixel'});
writetable(steelTable,fullfile(cfg.outputs.tables,'steel_equivalent_rois.csv'));
save(fullfile(cfg.outputs.process,'steel_equivalent_result.mat'),'steelReference','steelVideo','steelXY','steelTable');
save_steel_figure(steelTable,cfg.outputs.figures);

%% N2: SSRM 等价模拟（25 fps，5.32/8.06 Hz 双频）
ssrmCfg=cfg; ssrmCfg.synthetic.fs=25; ssrmCfg.synthetic.noiseStd=.001; ssrmCfg.mato.populationSize=5; ssrmCfg.mato.generations=8;
ssrmCfg.ods.bandwidth=2; ssrmCfg.active.keepFilledRegions=false; ssrmReference=make_reference_scene(cfg.synthetic.height,cfg.synthetic.width,'ssrm');
ssrmTime=(0:99)'/ssrmCfg.synthetic.fs;
mode1=exp(-((xx-cfg.synthetic.width*.35)/(cfg.synthetic.width*.16)).^2);
mode2=exp(-((xx-cfg.synthetic.width*.68)/(cfg.synthetic.width*.13)).^2);
[ssrmVideo,ssrmTruth]=generate_multifrequency_mode_video(ssrmReference,ssrmTime,{mode1,mode2},[5.32,8.06],[.035,.022],ssrmCfg);
activeSsrm=active_pixel_selection(ssrmVideo(:,:,1),ssrmCfg); ssrmTasks=build_task_map(size(reference,1),size(reference,2),activeSsrm.activeMask);
ssrmSelected=choose_task_centers(ssrmTasks.activeTaskPixels,12); ssrmMap=nearest_task_map(size(reference),ssrmSelected);
ssrmTaskTruth=zeros(size(ssrmSelected,1),numel(ssrmTime));
for i=1:size(ssrmSelected,1), ssrmTaskTruth(i,:)=squeeze(ssrmTruth(ssrmSelected(i,1),ssrmSelected(i,2),:)); end
ssrmMato=mato_optimize(ssrmVideo,ssrmTaskTruth,ssrmSelected,ssrmCfg,pi/2);
ssrmField=fullfield_pme(ssrmVideo,ssrmMap,ssrmSelected,ssrmMato.bestX,ssrmCfg,pi/2);
ssrmField.rawDisplacement=ssrmField.displacement;
ssrmField.activeMask=activeSsrm.activeMask;
ssrmField.displacement=ssrmField.displacement.*repmat(activeSsrm.activeMask,1,1,size(ssrmField.displacement,3));
ssrmODS1=frequency_ods(ssrmField.displacement,25,5.32,2); ssrmODS2=frequency_ods(ssrmField.displacement,25,8.06,2);
save(fullfile(cfg.outputs.process,'ssrm_equivalent_result.mat'),'ssrmVideo','ssrmTruth','activeSsrm','ssrmTasks','ssrmSelected','ssrmMato','ssrmField','ssrmODS1','ssrmODS2');
save_mask_figure(ssrmVideo(:,:,1),activeSsrm,cfg.outputs.process,'ssrm_active_pixels');
save_frequency_figure(ssrmODS1,ssrmODS2,cfg.outputs.figures,'ssrm_frequency_ods');
save_ssrm_comparison_figure(ssrmField,ssrmTruth,ssrmVideo,ssrmMato,ssrmCfg,cfg.outputs.figures);
write_video_preview(ssrmVideo,fullfile(cfg.outputs.videos,'ssrm_equivalent.avi'),25);

summary=struct('coreRMSE_pixel',coreRMSE,'singleTaskRMSE_pixel',single.bestFitness,...
    'cableTaskCount',size(selected,1),'ssrmTaskCount',size(ssrmSelected,1),...
    'paperDataAvailable',false,'outputsRoot',root);
save(fullfile(cfg.outputs.tables,'reproduction_summary.mat'),'summary','sweepTable','steelTable');
write_experiment_log(summary,cfg,coreRMSE,single.bestFitness);
fprintf('LoG-Gabor reproduction complete. Core RMSE = %.6g pixel; single-task RMSE = %.6g pixel.\n',coreRMSE,single.bestFitness);
end

function ensure_output_dirs(cfg)
dirs={cfg.outputs.figures,cfg.outputs.process,cfg.outputs.videos,cfg.outputs.tables};
for i=1:numel(dirs), if ~exist(dirs{i},'dir'), mkdir(dirs{i}); end, end
end

function selected=choose_task_centers(centers,maxCount)
if isempty(centers), error('active-pixel 选择没有得到任何可用任务。'); end
if size(centers,1)<=maxCount, selected=centers; else, selected=centers(round(linspace(1,size(centers,1),maxCount)),:); end
end

function taskMap=nearest_task_map(imageSize,centers)
[x,y]=meshgrid(1:imageSize(2),1:imageSize(1)); taskMap=zeros(imageSize);
for r=1:imageSize(1)
    for c=1:imageSize(2)
        [~,taskMap(r,c)]=min((centers(:,1)-r).^2+(centers(:,2)-c).^2);
    end
end
end

function save_fig1_style(reference,cfg,outDir)
% 复刻论文 Fig.1 的信息结构：输入/频域信息 + 五组滤波器的频域、振幅、相位。
filters=[1 2 2;5 2 2;20 2 2;20 .5 .5;20 .15 .15];
f=figure('Visible','off','Color','w','Position',[50 50 1500 700]);
for row=1:3
    for col=1:6
        ax=subplot(3,6,(row-1)*6+col); set_paper_axes(ax);
        if col==1
            if row==1, imagesc(reference); title('Image information');
            elseif row==2, imagesc(abs(fftshift(fft2(reference)))); title('Frequency domain');
            else, imagesc(reference); title('Luminance / gray'); end
            axis image off; colormap(ax,gray(256));
        else
            [lg,meta]=build_loggabor_filter(size(reference,1),size(reference,2),filters(col-1,:),cfg,0);
            if row==1
                imagesc(log10(lg+1e-6)); title(sprintf('Filter %d',col-1));
            else
                [amp,phase]=loggabor_response(reference,filters(col-1,:),cfg,0);
                if row==2, imagesc(amp(:,:,1)); title('Local amplitude');
                else, imagesc(phase(:,:,1)); title('Local phase'); end
            end
            axis image off; colorbar('off');
            if row==1
                text(.03,.08,sprintf('HAB=%g, RSD=%g, ASD=%g',filters(col-1,:)),...
                    'Units','normalized','Color','w','FontSize',7,'FontWeight','bold');
            end
        end
    end
end
sgtitle('Log-Gabor filter responses and phase-based features','FontName','Times New Roman','FontSize',12,'FontWeight','bold');
save_figure(f,fullfile(outDir,'fig1_filter_responses.png')); close(f);
end

function save_task_mapping_figure(taskInfo,selected,outDir)
f=figure('Visible','off','Color','w','Position',[50 50 1100 500]);
subplot(1,2,1); imagesc(taskInfo.taskMap); axis image; hold on; grid on;
scatter(taskInfo.taskPixels(:,2),taskInfo.taskPixels(:,1),14,'k','filled');
title('(a) 3 x 3 task selection'); xlabel('x pixel'); ylabel('y pixel');
subplot(1,2,2); imagesc(taskInfo.taskMap); axis image; hold on;
scatter(selected(:,2),selected(:,1),36,'r','s','LineWidth',1.2); title('(b) Selected task centers'); xlabel('x pixel'); ylabel('y pixel');
colormap(parula(256)); set_paper_axes(gca); save_figure(f,fullfile(outDir,'fig4_task_mapping.png')); close(f);
end

function save_single_flow_figure(reference,video,pme,params,cfg,outDir)
% 复刻论文 Fig.2 的单点 PME 流程证据，补充实际输入和中间相位图。
[~,phase,response]=loggabor_response(video(:,:,1),params,cfg,pi/2);
f=figure('Visible','off','Color','w','Position',[40 40 1350 700]);
subplot(2,3,1); imagesc(reference); axis image off; colormap(gray(256)); title('(a) Video input / reference');
subplot(2,3,2); imagesc(video(:,:,ceil(size(video,3)/2))); axis image off; colormap(gray(256)); title('(b) Synthetic video frame');
subplot(2,3,3); imagesc(abs(response(:,:,1))); axis image off; colorbar; title('(c) Log-Gabor response amplitude');
subplot(2,3,4); imagesc(phase(:,:,1)); axis image off; colorbar; title('(d) Local phase map');
subplot(2,3,5); plot(pme.rawPhase,'k','LineWidth',.8); hold on; plot(unwrap(pme.rawPhase),'r--','LineWidth',.8); grid on; xlabel('Frame'); ylabel('Phase (rad)'); legend('Raw','Unwrapped'); title('(e) Phase sequence');
subplot(2,3,6); plot(pme.displacement,'b','LineWidth',1); grid on; xlabel('Frame'); ylabel('Displacement (pixel)'); title('(f) PME vibration output');
sgtitle('Single-target phase-based motion estimation','FontName','Times New Roman','FontSize',12,'FontWeight','bold');
save_figure(f,fullfile(outDir,'fig2_single_target_flow.png')); close(f);
end

function save_fullfield_process_figure(frame,active,taskInfo,fieldResult,outDir)
T=size(fieldResult.displacement,3); score=zeros(T,1);
for k=1:T, score(k)=max(abs(fieldResult.displacement(:,:,k)),[],'all'); end
[~,id]=max(score); f=figure('Visible','off','Color','w','Position',[40 40 1300 650]);
subplot(2,3,1); imagesc(frame); axis image off; colormap(gray(256)); title('(a) Input frame');
subplot(2,3,2); imagesc(active.amplitude); axis image off; colorbar; title('(b) Two-direction local amplitude');
subplot(2,3,3); imagesc(active.activeMask); axis image off; colormap(gray(256)); title('(c) Adaptive active-pixel mask');
subplot(2,3,4); imagesc(taskInfo.taskMap); axis image off; colorbar; title('(d) 3 x 3 task map');
subplot(2,3,5); imagesc(fieldResult.displacement(:,:,id)); axis image off; colorbar; title(sprintf('(e) Instantaneous field, frame %d',id));
subplot(2,3,6); plot(squeeze(fieldResult.displacement(round(end/2),round(end/2),:)),'b','LineWidth',1); grid on; xlabel('Frame'); ylabel('Pixel'); title('(f) Full-field PME trace');
sgtitle('Full-field processing stages','FontName','Times New Roman','FontSize',12,'FontWeight','bold');
save_figure(f,fullfile(outDir,'fig3_fullfield_process.png')); close(f);
end

function save_representative_intermediate_figure(pme,outDir)
f=figure('Visible','off','Color','w','Position',[40 40 1250 700]);
subplot(2,3,1); plot(pme.rawPhase,'k'); grid on; xlabel('Frame'); ylabel('rad'); title('(a) Raw phase');
subplot(2,3,2); plot(pme.wrappedDifference,'b'); grid on; xlabel('Frame'); ylabel('rad'); title('(b) Wrapped phase difference');
subplot(2,3,3); plot(pme.unwrappedDifference,'r'); grid on; xlabel('Frame'); ylabel('rad'); title('(c) Unwrapped phase difference');
subplot(2,3,4); plot(pme.increment,'m'); grid on; xlabel('Frame'); ylabel('pixel'); title('(d) Incremental displacement');
subplot(2,3,5); plot(pme.displacement,'g'); grid on; xlabel('Frame'); ylabel('pixel'); title('(e) Cumulative displacement');
subplot(2,3,6); plot(pme.amplitude,'k'); grid on; xlabel('Frame'); ylabel('amplitude'); title('(f) Local amplitude');
sgtitle('Representative PME intermediate variables','FontName','Times New Roman','FontSize',12,'FontWeight','bold');
save_figure(f,fullfile(outDir,'representative_pme_intermediates.png')); close(f);
end

function save_mmd_figure(mato,cfg,outDir)
M=compute_mmd_matrix(mato,cfg.mato.kernelWidth);
f=figure('Visible','off','Color','w','Position',[80 80 700 650]); imagesc(M); axis image; colorbar;
xlabel('Task number'); ylabel('Task number'); title('MMD values between tasks'); colormap(parula(256)); set_paper_axes(gca);
save_figure(f,fullfile(outDir,'fig14_mmd_values.png')); close(f);
end

function M=compute_mmd_matrix(mato,sigma)
K=numel(mato.populations); M=inf(K,K);
for i=1:K
    for j=i+1:K
        M(i,j)=mmd_unbiased(mato.populations{i},mato.populations{j},sigma); M(j,i)=M(i,j);
    end
end
M(~isfinite(M))=0;
end

function save_amp_figure(mato,outDir)
if ~isfield(mato,'ampHistory'), return; end
f=figure('Visible','off','Color','w','Position',[80 80 850 500]); plot(mato.ampHistory','LineWidth',.8); grid on;
xlabel('Generation'); ylabel('Adaptive mating probability'); ylim([0 1]); title('AMP history for MaTO tasks'); set_paper_axes(gca);
save_figure(f,fullfile(outDir,'fig6_mato_amp_history.png')); close(f);
end

function save_mato_convergence_figure(mato,baseline,outDir)
f=figure('Visible','off','Color','w','Position',[80 80 850 560]); hold on; grid on;
plot(mato.history(1,:),'r-o','LineWidth',1.2,'MarkerSize',3);
plot(mean(mato.history,1,'omitnan'),'b-','LineWidth',1.2);
plot(baseline.history,'k-*','LineWidth',1.0,'MarkerSize',3);
xlabel('Iteration number'); ylabel('RMSE (pixel)'); title('MaTO and single-task optimisation');
legend('MaTO target task','MaTO mean','Single-task GA','Location','best'); set_paper_axes(gca);
save_figure(f,fullfile(outDir,'fig15_mato_ipso_comparison.png')); close(f);
end

function save_cable_comparison_figure(video,truthField,selected,mato,baseline,cfg,outDir)
p=selected(1,:); truth=squeeze(truthField(p(1),p(2),:));
proposed=squeeze(fullfield_signal_at_pixel(mato.bestX(1,:),video,p,cfg));
matched=pme_measure(video,baseline.bestX,cfg,p,pi/2).displacement(:);
default=pme_measure(video,cfg.loggabor.defaultParams,cfg,p,pi/2).displacement(:);
t=(0:numel(truth)-1)'/cfg.synthetic.fs;
signals=[truth,proposed,matched,default]; names={'Truth','MaTO','Single-task','Original PME'};
f=figure('Visible','off','Color','w','Position',[40 40 1250 720]);
subplot(2,2,1); plot(t,signals,'LineWidth',1.0); grid on; xlabel('Time (s)'); ylabel('Displacement (pixel)'); title('(a) Full signal'); legend(names,'Location','best');
subplot(2,2,2); n=min(40,numel(t)); plot(t(1:n),signals(1:n,:),'LineWidth',1.0); grid on; xlabel('Time (s)'); ylabel('Displacement (pixel)'); title('(b) Zoom in');
subplot(2,2,3); [freq,mag]=one_sided_spectrum(signals,cfg.synthetic.fs); plot(freq,mag,'LineWidth',1.0); xlim([0 min(25,cfg.synthetic.fs/2)]); grid on; xlabel('Frequency (Hz)'); ylabel('Amplitude'); title('(c) FFT spectrum'); legend(names,'Location','best');
subplot(2,2,4); errors=sqrt(mean((signals-truth).^2,1)); bar(errors); set(gca,'XTick',1:4,'XTickLabel',names); ylabel('RMSE (pixel)'); title('(d) Quantitative comparison'); grid on;
save_figure(f,fullfile(outDir,'fig17_cable_comparison.png')); close(f);
end

function signal=fullfield_signal_at_pixel(params,video,pixel,cfg)
signal=pme_measure(video,params,cfg,pixel,pi/2).displacement;
end

function save_cable_roi_figure(fieldResult,truthField,selected,cfg,outDir)
n=min(5,size(selected,1)); f=figure('Visible','off','Color','w','Position',[20 20 1600 850]);
for i=1:n
    p=selected(i,:); truth=squeeze(truthField(p(1),p(2),:)); signal=squeeze(fieldResult.displacement(p(1),p(2),:));
    t=(0:numel(signal)-1)'/cfg.synthetic.fs;
    subplot(3,n,i); plot(t,signal,'b',t,truth,'k--','LineWidth',.8); grid on; title(sprintf('ROI %d',i)); if i==1, ylabel('Time'); end
    [tf,ff,tt]=time_frequency(signal,cfg.synthetic.fs); subplot(3,n,n+i); imagesc(tt,ff,tf); axis xy; ylim([0 min(25,cfg.synthetic.fs/2)]); colormap(parula(256)); if i==1, ylabel('STFT (Hz)'); end
    [freq,mag]=one_sided_spectrum(signal,cfg.synthetic.fs); subplot(3,n,2*n+i); plot(freq,mag,'k','LineWidth',.8); xlim([0 min(25,cfg.synthetic.fs/2)]); grid on; if i==1, ylabel('FFT'); end; xlabel('Hz');
end
save_figure(f,fullfile(outDir,'fig19_cable_rois_time_stft_fft.png')); close(f);
end

function save_ods_frames_figure(reference,fieldResult,outDir)
T=size(fieldResult.displacement,3); score=zeros(T,1);
for k=1:T, score(k)=max(abs(fieldResult.displacement(:,:,k)),[],'all'); end
candidate=2:T; [~,order]=sort(score(candidate),'descend'); ids=sort(candidate(order(1:min(4,numel(candidate)))));
if numel(ids)<4, ids=round(linspace(1,T,4)); end
plotFields=fieldResult.displacement(:,:,ids);
% 论文 Fig. 20 只显示通过 active-pixel 筛选的有效区域；使用 AlphaData
% 让无效像素透明，避免它们以零位移颜色覆盖结构。
if isfield(fieldResult,'activeMask')
    validMask=logical(fieldResult.activeMask);
else
    validMask=true(size(plotFields,1),size(plotFields,2));
end
finiteValues=abs(plotFields(repmat(validMask,1,1,size(plotFields,3)) & isfinite(plotFields)));
if isempty(finiteValues) || max(finiteValues)==0
    scale=1;
else
    sortedValues=sort(finiteValues(:));
    scale=sortedValues(max(1,ceil(.98*numel(sortedValues))));
    if scale==0, scale=max(finiteValues); end
end
f=figure('Visible','off','Color','w','Position',[30 30 1100 750]);
for i=1:4
    ax=subplot(2,2,i); frame=plotFields(:,:,i); frame(~isfinite(frame))=0;
    imageHandle=imagesc(frame,[-scale scale]); set(imageHandle,'AlphaData',double(validMask));
    axis image off; set(ax,'Color',[.88 .88 .88]); colorbar; title(sprintf('Frame %d: instantaneous ODS',ids(i)));
end
sgtitle('Instantaneous operational deflection shapes','FontName','Times New Roman','FontSize',12,'FontWeight','bold'); colormap(jet(256));
save_figure(f,fullfile(outDir,'fig20_instantaneous_ods.png')); close(f);
end

function save_harmonic_ods_figure(fieldResult,cfg,outDir)
targets=cfg.synthetic.frequency*(1:4); f=figure('Visible','off','Color','w','Position',[30 30 1400 500]);
for i=1:4
    ods=frequency_ods(fieldResult.displacement,cfg.synthetic.fs,targets(i),cfg.ods.bandwidth);
    subplot(1,4,i); imagesc(ods.amplitude); axis image off; colorbar; title(sprintf('%.2f Hz',targets(i)));
end
sgtitle('Frequency-specific ODS','FontName','Times New Roman','FontSize',12,'FontWeight','bold'); colormap(jet(256)); save_figure(f,fullfile(outDir,'fig21_harmonic_ods.png')); close(f);
end

function save_ssrm_comparison_figure(fieldResult,truthField,video,mato,cfg,outDir)
p=mato.taskPixels(1,:); truth=squeeze(truthField(p(1),p(2),:)); proposed=squeeze(fieldResult.displacement(p(1),p(2),:));
default=pme_measure(video,cfg.loggabor.defaultParams,cfg,p,pi/2).displacement(:); t=(0:numel(truth)-1)'/cfg.synthetic.fs;
[freq,mag]=one_sided_spectrum([truth,proposed,default],cfg.synthetic.fs); rmse=[sqrt(mean((truth-proposed).^2)),sqrt(mean((truth-default).^2))]; cc=[safe_corr(truth,proposed),safe_corr(truth,default)];
f=figure('Visible','off','Color','w','Position',[40 40 1250 720]);
subplot(2,2,1); plot(t,[truth,proposed,default],'LineWidth',.9); grid on; xlabel('Time (s)'); ylabel('Amplitude (pixel)'); title('(a) SSRM equivalent signal'); legend('Truth','This study','Original PME','Location','best');
subplot(2,2,2); n=min(35,numel(t)); plot(t(1:n),[truth(1:n),proposed(1:n),default(1:n)],'LineWidth',.9); grid on; xlabel('Time (s)'); title('(b) Zoom in');
subplot(2,2,3); plot(freq,mag,'LineWidth',.9); xlim([0 12]); grid on; xlabel('Frequency (Hz)'); ylabel('Amplitude'); title('(c) FFT spectra'); legend('Truth','This study','Original PME');
subplot(2,2,4); yyaxis left; bar(rmse); ylabel('RMSE (pixel)'); yyaxis right; plot(1:2,cc,'ko-','LineWidth',1.1); ylabel('CC'); set(gca,'XTick',1:2,'XTickLabel',{'This study','Original PME'}); grid on; title('(d) RMSE and CC');
save_figure(f,fullfile(outDir,'fig24_25_ssrm_comparison.png')); close(f);
end

function r=safe_corr(x,y)
c=corrcoef(x(:),y(:)); if numel(c)>1 && isfinite(c(1,2)), r=c(1,2); else, r=0; end
end

function [freq,mag]=one_sided_spectrum(signal,fs)
if isvector(signal), signal=signal(:); end; N=size(signal,1); Y=fft(signal,[],1); n=floor(N/2)+1; freq=(0:n-1)'*fs/N; mag=2*abs(Y(1:n,:))/N; end

function [tf,freq,time]=time_frequency(signal,fs)
signal=signal(:); N=numel(signal); win=max(16,min(64,floor(N/3))); hop=max(1,floor(win/4)); centers=1:hop:max(1,N-win+1); nfft=max(64,2^nextpow2(win)); tf=zeros(nfft/2+1,numel(centers));
for i=1:numel(centers), seg=signal(centers(i):min(N,centers(i)+win-1)); seg=seg-mean(seg); nseg=numel(seg); window=.5-.5*cos(2*pi*(0:nseg-1)'/max(1,nseg-1)); seg=seg(:).*window; Y=fft(seg,nfft); tf(:,i)=abs(Y(1:nfft/2+1)); end
freq=(0:nfft/2)'*fs/nfft; time=(centers-1)/fs; end

function set_paper_axes(ax)
set(ax,'FontName','Times New Roman','FontSize',8,'LineWidth',.8,'Box','on');
end

function save_core_figure(reference,video,truth,pme,params,outDir)
f=figure('Visible','off','Color','w');
subplot(2,2,1); imagesc(reference); axis image off; title('Reference frame');
subplot(2,2,2); imagesc(abs(fftshift(fft2(reference)))); axis image off; title('Reference spectrum');
subplot(2,2,3); plot(truth,'k','LineWidth',1.2); hold on; plot(pme.displacement,'r--'); grid on; legend('Truth','PME','Location','best'); xlabel('Frame'); ylabel('Displacement (pixel)');
subplot(2,2,4); plot(truth-pme.displacement); grid on; xlabel('Frame'); ylabel('Error (pixel)'); title(sprintf('PME [%g %g %g]',params));
save_figure(f,fullfile(outDir,'core_baseline.png')); close(f);
end

function save_convergence_figure(history,outDir,name)
f=figure('Visible','off','Color','w'); plot(history,'LineWidth',1.4); grid on; xlabel('Generation'); ylabel('RMSE (pixel)'); title('Single-task optimisation'); save_figure(f,fullfile(outDir,[name '.png'])); close(f);
end

function save_mask_figure(frame,active,outDir,name)
f=figure('Visible','off','Color','w','Position',[50 50 1200 650]);
ax=subplot(2,2,1); imagesc(frame); axis image off; colormap(ax,gray(256)); title('(a) Image frame');
ax=subplot(2,2,2); imagesc(active.amplitude); axis image off; colorbar; title('(b) Local amplitude');
ax=subplot(2,2,3); imagesc(active.filledMask); axis image off; colormap(ax,gray(256)); title('(c) Filled image');
ax=subplot(2,2,4); imagesc(active.activeMask); axis image off; colormap(ax,gray(256)); title('(d) Active pixels');
sgtitle('Adaptive processing for selecting active pixels','FontName','Times New Roman','FontSize',12,'FontWeight','bold');
save_figure(f,fullfile(outDir,[name '.png'])); close(f);
end

function save_ods_figure(instant,freq,outDir,name)
f=figure('Visible','off','Color','w');
subplot(1,3,1); imagesc(instant.field); axis image off; colorbar; title('Instantaneous ODS');
subplot(1,3,2); imagesc(freq.amplitude); axis image off; colorbar; title(sprintf('Frequency ODS %.2f Hz',freq.targetFrequency));
subplot(1,3,3); imagesc(freq.phase); axis image off; colorbar; title('Relative phase');
save_figure(f,fullfile(outDir,[name '.png'])); close(f);
end

function save_frequency_figure(freq1,freq2,outDir,name)
f=figure('Visible','off','Color','w');
subplot(1,3,1); imagesc(freq1.amplitude); axis image off; colorbar; title(sprintf('SSRM %.2f Hz',freq1.targetFrequency));
subplot(1,3,2); imagesc(freq2.amplitude); axis image off; colorbar; title(sprintf('SSRM %.2f Hz',freq2.targetFrequency));
subplot(1,3,3); imagesc(freq1.phase); axis image off; colorbar; title('Relative phase');
save_figure(f,fullfile(outDir,[name '.png'])); close(f);
end

function save_steel_figure(T,outDir)
f=figure('Visible','off','Color','w'); scatter(T.HAB,T.RSD,60,T.ROI,'filled'); grid on; xlabel('HAB'); ylabel('RSD'); colorbar; title('Steel equivalent task parameter distribution'); save_figure(f,fullfile(outDir,'steel_parameter_distribution.png')); close(f);
end

function save_figure(fig,filePath)
try, exportgraphics(fig,filePath,'Resolution',150); catch, saveas(fig,filePath); end
end

function write_experiment_log(summary,cfg,coreRMSE,singleRMSE)
filePath=fullfile(cfg.root,'experiments','EXPERIMENTS.md');
fid=fopen(filePath,'w','n','UTF-8');
fprintf(fid,'# LoG-Gabor 复现实验账本\n\n');
fprintf(fid,'### EXP-20260829-01: 方法级与等价全场模拟\n');
fprintf(fid,'- commit / branch: 当前目录无 Git 仓库\n- paper experiment: Eq. (11) 合成、PME、单任务优化、MaTO、full-field ODS、steel/cable/SSRM 等价模拟\n');
fprintf(fid,'- question: 是否能在无原始实验数据时跑通论文的完整算法链？\n');
fprintf(fid,'- data + key config: MATLAB R2022b；cable 250 Hz；SSRM 25 Hz；MaTO 15 particles/20 generations（SSRM 为轻量等价模拟配置）\n');
fprintf(fid,'- result: core RMSE = %.6g pixel；single-task RMSE = %.6g pixel；cable tasks = %d；SSRM tasks = %d\n',coreRMSE,singleRMSE,summary.cableTaskCount,summary.ssrmTaskCount);
fprintf(fid,'- paper / baseline comparison: 运行链路与论文方法一致；真实论文图表数值不能因缺失原始视频/传感器数据而声称 exact match\n- decision: keep\n');
fclose(fid);
end
