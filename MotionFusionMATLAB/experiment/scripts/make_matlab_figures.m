function make_matlab_figures(tag)
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
root=projectRoot;files=dir(fullfile(root,'outputs',tag,'*','profile_ic_laser.csv'));
for i=1:numel(files)
    d=readtable(fullfile(files(i).folder,files(i).name));[~,name]=fileparts(files(i).folder);
    fig=figure('Visible','off','Color','w','Position',[100 100 1100 700]);tiledlayout(2,1,'TileSpacing','compact');
    nexttile;plot(d.time_s,d.raw_relative_px,'Color',[0 .447 .698]);xlabel('Time (s)');ylabel('Raw relative x (px)');title([name ' — unfiltered spatial measurement'],'Interpreter','none');grid on;
    nexttile;plot(d.time_s,d.band_px,'Color',[0 .447 .698]);hold on;
    z=d.fitted_laser_px;z(~logical(d.heldout))=NaN;plot(d.time_s,z,'--','Color',[.835 .369 0]);xlabel('Time (s)');ylabel('Displacement (px)');legend('Video, 5–45 Hz','Laser, fitted on calibration half');grid on;
    title('Missing data stay missing; fitted laser scale is not optical calibration');
    exportgraphics(fig,fullfile(files(i).folder,'measurement.png'),'Resolution',150);set(fig,'Visible','on','WindowState','normal');savefig(fig,fullfile(files(i).folder,'measurement.fig'));close(fig);
end
end



