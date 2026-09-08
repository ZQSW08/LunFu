function plot_laser_v2(parent)
files=dir(fullfile(parent,'*','evaluation','comparison_*.csv'));
for j=1:numel(files)
    data=readtable(fullfile(files(j).folder,files(j).name));folder=fileparts(files(j).folder);[~,name]=fileparts(folder);
    f=figure('Visible','off','Color','w','Position',[100 100 1100 650]);tiledlayout(2,1,'TileSpacing','compact');
    nexttile;plot(data.time_s,data.broad_px,'Color',[.65 .65 .65]);hold on;plot(data.time_s,data.clean_px,'Color',[0 .447 .698]);y=data.training_fitted_laser_px;y(~logical(data.common_test))=NaN;plot(data.time_s,y,'--','Color',[.835 .369 0]);
    xlabel('Time (s)');ylabel('Displacement (px)');grid on;legend('Broad','Video modal','Laser, training-fit scale/lag');title([name ': all observations; evaluation after measurement'],'Interpreter','none');
    nexttile;plot(data.time_s,data.clean_px,'Color',[0 .447 .698]);hold on;plot(data.time_s,y,'--','Color',[.835 .369 0]);first=find(data.common_test,1);if ~isempty(first),xlim(data.time_s(first)+[0 1]);end
    xlabel('Time (s)');ylabel('Displacement (px)');grid on;title('Held-out excerpt; gaps are not reconstructed');
    exportgraphics(f,fullfile(folder,'04_laser_comparison.png'),'Resolution',160);set(f,'Visible','on','WindowState','normal');drawnow;savefig(f,fullfile(folder,'04_laser_comparison.fig'));close(f);
end
end
