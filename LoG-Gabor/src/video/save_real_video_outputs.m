function save_real_video_outputs(reference,active,taskInfo,selected,fieldResult,representative,odsInstant,odsFrequency,targetFrequency,outDir)
%SAVE_REAL_VIDEO_OUTPUTS Save compact process, PME and ODS figures.
%   图中仅保留真实入口需要诊断的关键阶段，数值中间量写入 MAT。

f=figure('Visible','off','Color','w','Position',[40 40 1250 780]);
ax=subplot(2,3,1); imagesc(reference); axis image off; colormap(ax,gray(256)); title('(a) Real first frame');
subplot(2,3,2); imagesc(active.amplitude); axis image off; colorbar; title('(b) Local amplitude');
ax=subplot(2,3,3); imagesc(active.activeMask); axis image off; colormap(ax,gray(256)); title('(c) Active pixels');
subplot(2,3,4); imagesc(taskInfo.taskMap); axis image off; colorbar; hold on; plot(selected(:,2),selected(:,1),'r.','MarkerSize',8); title('(d) Task mapping');
frame=fieldResult.displacement(:,:,max(1,round(size(fieldResult.displacement,3)/2)));
subplot(2,3,5); imagesc(frame); axis image off; colorbar; title('(e) Real-video displacement');
subplot(2,3,6); plot(representative.displacement,'k','LineWidth',.9); grid on; xlabel('Frame'); ylabel('Pixel'); title('(f) Representative PME');
sgtitle('Real-video LoG-Gabor processing','FontName','Times New Roman','FontSize',12,'FontWeight','bold');
save_figure(f,fullfile(outDir,'real_video_process.png')); close(f);

series={representative.rawPhase,representative.wrappedDifference,representative.unwrappedDifference,...
    representative.increment,representative.displacement,representative.amplitude};
names={'Raw phase','Wrapped phase difference','Unwrapped phase difference',...
    'Incremental displacement','Cumulative displacement','Local amplitude'};
f=figure('Visible','off','Color','w','Position',[40 40 1250 780]);
for i=1:6, subplot(2,3,i); plot(series{i},'k','LineWidth',.8); grid on; title(names{i}); xlabel('Frame'); end
sgtitle('Real-video PME intermediate quantities','FontName','Times New Roman','FontSize',12,'FontWeight','bold');
save_figure(f,fullfile(outDir,'real_video_pme_intermediates.png')); close(f);

f=figure('Visible','off','Color','w','Position',[40 40 1250 430]);
subplot(1,3,1); imagesc(odsInstant.field); axis image off; colorbar; title('Instantaneous ODS');
subplot(1,3,2); imagesc(odsFrequency.amplitude); axis image off; colorbar; title(sprintf('Frequency ODS %.3g Hz',targetFrequency));
subplot(1,3,3); imagesc(odsFrequency.phase); axis image off; colorbar; title('Relative phase ODS');
sgtitle('Real-video operational deflection shapes','FontName','Times New Roman','FontSize',12,'FontWeight','bold'); colormap(jet(256));
save_figure(f,fullfile(outDir,'real_video_ods.png')); close(f);
end

function save_figure(fig,filePath)
try
    exportgraphics(fig,filePath,'Resolution',150);
catch
    saveas(fig,filePath);
end
end
