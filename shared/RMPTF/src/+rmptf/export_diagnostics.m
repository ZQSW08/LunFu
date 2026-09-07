function export_diagnostics(outputDirectory, tracking, cfg, videoPath)
%EXPORT_DIAGNOSTICS 输出文档规定的逐帧日志、事件、配置和关键诊断图。
if ~isfolder(outputDirectory), mkdir(outputDirectory); end
n=size(tracking.center,1); fps=tracking.processingFps; time=(0:n-1)'/fps;
localInitialImages(outputDirectory,tracking,videoPath);
state=string(tracking.state);
T=table((1:n)',time,tracking.outerCenter(:,1),tracking.outerCenter(:,2), ...
    tracking.center(:,1),tracking.center(:,2),tracking.bbox(:,1),tracking.bbox(:,2), ...
    tracking.bbox(:,3),tracking.bbox(:,4),tracking.geometryScale,tracking.geometryRotationDeg, ...
    tracking.responsePeak,tracking.apce,tracking.psr,tracking.anchorNcc,tracking.recentNcc, ...
    tracking.gradientNcc,tracking.edgeCorrelation,tracking.kltPointCount,tracking.kltInlierRatio, ...
    tracking.kltFbError,tracking.kltReprojectionError,tracking.motionJumpScore, ...
    tracking.scaleJumpScore,tracking.rotationScore,tracking.accelerationScore,tracking.boundaryScore,tracking.quality,state,tracking.modelUpdated, ...
    tracking.redetectionUsed,tracking.valid,tracking.analysisRoiTrajectory(:,1), ...
    tracking.analysisRoiTrajectory(:,2),tracking.coarseDisplacement(:,1),tracking.coarseDisplacement(:,2), ...
    tracking.macroScale,tracking.macroRotationDeg, ...
    'VariableNames',{'frame','time_s','outer_x','outer_y','refined_x','refined_y', ...
    'bbox_x','bbox_y','bbox_w','bbox_h','scale','rotation_deg','response_peak','apce','psr', ...
    'anchor_ncc','recent_ncc','gradient_ncc','edge_correlation','klt_count','klt_inlier_ratio', ...
    'klt_fb_error','klt_reprojection_error','motion_score','scale_jump_score','rotation_score', ...
    'acceleration_score','boundary_score', ...
    'quality','state','model_updated','redetect','valid','crop_x','crop_y','macro_x','macro_y', ...
    'macro_scale','macro_rotation_deg'});
writetable(T,fullfile(outputDirectory,'tracking_trajectory.csv'));
events=T(~T.valid | T.redetect | T.model_updated | T.state~="TRACKING_OK",:);
writetable(events,fullfile(outputDirectory,'tracking_events.csv'));
save(fullfile(outputDirectory,'tracking_result.mat'),'tracking','cfg','videoPath','-v7.3');
fid=fopen(fullfile(outputDirectory,'tracking_config.json'),'w');
if fid>=0, cleaner=onCleanup(@()fclose(fid)); fwrite(fid,jsonencode(cfg,'PrettyPrint',true),'char'); clear cleaner; end

localPlot(outputDirectory,'04_raw_vs_refined_center.png',time, ...
    {tracking.outerCenter(:,1),tracking.center(:,1),tracking.largeMotionContinuous(:,1)}, ...
    {'outer x','refined x','macro x'},'Center / displacement (px)');
localPlot(outputDirectory,'05_tracking_quality.png',time, ...
    {tracking.quality,tracking.anchorNcc,tracking.kltInlierRatio}, ...
    {'quality','anchor NCC','KLT inlier'},'Quality');
localStatePlot(outputDirectory,time,tracking);
localPlot(outputDirectory,'07_scale_rotation.png',time, ...
    {tracking.geometryScale,tracking.geometryRotationDeg},{'scale','rotation (deg)'},'Geometry');
localPlot(outputDirectory,'08_anchor_similarity.png',time, ...
    {tracking.anchorNcc,tracking.gradientNcc,tracking.edgeCorrelation}, ...
    {'intensity NCC','gradient NCC','edge corr'},'Similarity');
localEventPlot(outputDirectory,time,tracking);
end

function localInitialImages(folder,tracking,videoPath)
try
    reader=VideoReader(videoPath); frame=readFrame(reader);
    both=insertShape(frame,'Rectangle',tracking.measurementRoiInitial,'Color','green','LineWidth',3);
    both=insertShape(both,'Rectangle',tracking.trackingRoiInitial,'Color','yellow','LineWidth',2);
    both=insertText(both,[8 8],'green: measurement | yellow: search context (not bbox)', ...
        'BoxColor','black','TextColor','white');
    imwrite(both,fullfile(folder,'01_initial_tracking_roi.png'));
    analysis=insertShape(frame,'Rectangle',tracking.analysisRoiInitial,'Color','cyan','LineWidth',3);
    analysis=insertText(analysis,[8 8],'analysis ROI','BoxColor','black','TextColor','white');
    imwrite(analysis,fullfile(folder,'02_initial_analysis_roi.png'));
catch
    % 图像注释工具箱不可用时，数值 ROI 仍完整保存在 CSV/MAT 中。
end
end

function localPlot(folder,name,time,signals,labels,yLabel)
fig=figure('Visible','off','Color','w'); hold on;
for k=1:numel(signals), plot(time,signals{k},'LineWidth',1); end
grid on; xlabel('Time (s)'); ylabel(yLabel); legend(labels,'Location','best');
exportgraphics(fig,fullfile(folder,name),'Resolution',150); close(fig);
end

function localEventPlot(folder,time,tracking)
fig=figure('Visible','off','Color','w');
[~,~,stateCode]=unique(string(tracking.state),'stable');
stairs(time,stateCode,'k'); hold on;
redetect=logical(tracking.redetectionUsed); invalid=~logical(tracking.valid);
stem(time(redetect),ones(nnz(redetect),1),'r','filled');
stem(time(invalid),0.5*ones(nnz(invalid),1),'Color',[0.85 0.33 0.10]);
grid on; xlabel('Time (s)'); ylabel('State/event'); legend('state','redetect','invalid','Location','best');
exportgraphics(fig,fullfile(folder,'09_redetection_events.png'),'Resolution',150); close(fig);
end


function localStatePlot(folder,time,tracking)
fig=figure('Visible','off','Color','w');
[labels,~,stateCode]=unique(string(tracking.state),'stable');
stairs(time,stateCode,'LineWidth',1.1); grid on; xlabel('Time (s)'); ylabel('State');
yticks(1:numel(labels)); yticklabels(labels);
exportgraphics(fig,fullfile(folder,'06_tracking_state.png'),'Resolution',150); close(fig);
end
