function px_save_figure(fig, filePath)
% 以固定分辨率导出图像，并在无exportgraphics时使用兼容写法。
folder = fileparts(filePath);
if ~exist(folder, 'dir')
    mkdir(folder);
end
if exist('exportgraphics', 'file') == 2
    exportgraphics(fig, filePath, 'Resolution', 300);
else
    print(fig, filePath, '-dpng', '-r300');
end
close(fig);
end
