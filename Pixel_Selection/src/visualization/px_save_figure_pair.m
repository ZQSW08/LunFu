function px_save_figure_pair(fig, fileStem)
% 同时保存MATLAB可编辑FIG和PNG，FIG可在MATLAB中双击重新打开。
folder = fileparts(fileStem);
if ~exist(folder, 'dir')
    mkdir(folder);
end

% 先保存原生FIG，保留坐标轴、曲线和图例等可编辑对象。
savefig(fig, [fileStem, '.fig'], 'compact');
if exist('exportgraphics', 'file') == 2
    exportgraphics(fig, [fileStem, '.png'], 'Resolution', 300);
else
    print(fig, [fileStem, '.png'], '-dpng', '-r300');
end
close(fig);
end
