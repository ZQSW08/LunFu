function report = analyze_object_error(resultRoot, outputRoot)
%ANALYZE_OBJECT_ERROR 分解具象物体视频的误差来源并输出诊断图。
% 保留无效帧和被门控候选，不用插值后的轨迹计算误差。
if nargin < 1 || isempty(resultRoot)
    projectRoot=fileparts(fileparts(mfilename('fullpath')));
    resultRoot=fullfile(projectRoot,'outputs','object_motion_results_final128');
end
if nargin < 2 || isempty(outputRoot)
    projectRoot=fileparts(fileparts(mfilename('fullpath')));
    outputRoot=fullfile(projectRoot,'outputs','object_error_diagnostics');
end
if ~isfolder(outputRoot), mkdir(outputRoot); end
names={'object_linear_clean','object_linear_light_blur','object_nonlinear_fast_rotation','object_nonlinear_all_conditions'};
report=repmat(struct('scenario','','frames',0,'validRate',NaN,'gateRejectedRate',NaN,'detectionFailedRate',NaN, ...
    'rmse2D_px',NaN,'median2D_px',NaN,'p95_2D_px',NaN,'max2D_px',NaN,'medianJump_px',NaN,'p95Jump_px',NaN, ...
    'maxJump_px',NaN,'gateThreshold_px',NaN,'worstFrame',NaN),1,numel(names));
for i=1:numel(names)
    d=dir(fullfile(resultRoot,[names{i} '_*'])); d=d([d.isdir]); if isempty(d), error('Crossline:MissingResult','缺少：%s',names{i}); end
    [~,ix]=max([d.datenum]); resultDir=fullfile(d(ix).folder,d(ix).name);
    S=load(fullfile(resultDir,'crossline_results.mat'),'cfg','globalCenter','valid','trajectoryTable');
    [~,nm]=fileparts(S.cfg.real.videoPath); T=load(fullfile(fileparts(S.cfg.real.videoPath),[nm '_truth.mat']),'time','centers');
    n=min(size(S.globalCenter,1),size(T.centers,1)); ok=S.valid(1:n)&all(isfinite(S.globalCenter(1:n,:)),2);
    e=S.globalCenter(1:n,:)-T.centers(1:n,:); e2=sqrt(sum(e.^2,2)); jump=S.trajectoryTable.jump_from_previous_px(1:n);
    gateRejected=~S.valid(1:n)&isfinite(jump); detectFailed=~S.valid(1:n)&~isfinite(jump); threshold=S.cfg.real.maxFrameJumpPx;
    if isempty(threshold), threshold=S.cfg.real.actualRoi(3)/4; end
    report(i).scenario=nm; report(i).frames=n; report(i).validRate=mean(ok); report(i).gateRejectedRate=mean(gateRejected); report(i).detectionFailedRate=mean(detectFailed); report(i).gateThreshold_px=threshold;
    if any(ok), ev=e2(ok); report(i).rmse2D_px=sqrt(mean(ev.^2)); report(i).median2D_px=median(ev); report(i).p95_2D_px=prctile(ev,95); report(i).max2D_px=max(ev); temp=e2; temp(~ok)=-Inf; [~,wi]=max(temp); report(i).worstFrame=wi; end
    j=jump(isfinite(jump)); if ~isempty(j), report(i).medianJump_px=median(j); report(i).p95Jump_px=prctile(j,95); report(i).maxJump_px=max(j); end
    t=T.time(1:n); est=S.globalCenter(1:n,1); truth=T.centers(1:n,1);
    fig=figure('Visible','on','Color','w','Name',['Error diagnosis - ' nm]); set(fig,'Position',[80 80 1150 820]); tl=tiledlayout(fig,3,1,'TileSpacing','compact','Padding','compact');
    ax=nexttile(tl); hold(ax,'on'); plot(ax,t(ok),e2(ok),'k.','MarkerSize',5,'DisplayName','Valid 2D error'); yline(ax,report(i).p95_2D_px,'r--','DisplayName','95th percentile'); grid(ax,'on'); xlabel(ax,'Time (s)'); ylabel(ax,'Error (pixel)'); title(ax,sprintf('%s | RMSE %.3f px | median %.3f px | valid %.2f%%',nm,report(i).rmse2D_px,report(i).median2D_px,100*report(i).validRate),'Interpreter','none'); legend(ax,'Location','best');
    ax=nexttile(tl); hold(ax,'on'); cand=isfinite(jump); plot(ax,t(cand),jump(cand),'Color',[.35 .35 .35],'LineWidth',.7,'DisplayName','Candidate jump'); plot(ax,t(gateRejected),jump(gateRejected),'rx','DisplayName','Gate rejected'); yline(ax,threshold,'r--','DisplayName',sprintf('Threshold %.1f px',threshold)); grid(ax,'on'); xlabel(ax,'Time (s)'); ylabel(ax,'Frame-to-frame jump (pixel)'); title(ax,sprintf('Gate rejected %.2f%%; detection failed %.2f%%',100*mean(gateRejected),100*mean(detectFailed))); legend(ax,'Location','best');
    ax=nexttile(tl); hold(ax,'on'); plot(ax,t,truth,'k-','LineWidth',1.0,'DisplayName','Ground truth x'); plot(ax,t(ok),est(ok),'Color',[.85 .20 .10],'LineWidth',.8,'DisplayName','Algorithm x (valid only)'); plot(ax,t(~ok),truth(~ok),'bx','DisplayName','Invalid frame'); grid(ax,'on'); xlabel(ax,'Time (s)'); ylabel(ax,'x (pixel)'); title(ax,'Trajectory comparison; invalid estimates remain gaps'); legend(ax,'Location','best');
    set(findall(fig,'-property','FontName'),'FontName','Times New Roman'); set(fig,'Visible','on'); base=fullfile(outputRoot,[nm '_error_diagnosis']); savefig(fig,[base '.fig']); try, exportgraphics(fig,[base '.png'],'Resolution',180); catch, print(fig,[base '.png'],'-dpng','-r180'); end; close(fig);
end
R=struct2table(report); writetable(R,fullfile(outputRoot,'object_error_report.csv')); save(fullfile(outputRoot,'object_error_report.mat'),'report','R');
fprintf('误差诊断已保存：%s\n',outputRoot);
for i=1:numel(report), fprintf('%s: valid %.2f%%, gate rejected %.2f%%, detect failed %.2f%%, RMSE %.3f px\n',report(i).scenario,100*report(i).validRate,100*report(i).gateRejectedRate,100*report(i).detectionFailedRate,report(i).rmse2D_px); end
end
