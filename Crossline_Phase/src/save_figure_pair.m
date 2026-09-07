function save_figure_pair(fig,basePath)
%SAVE_FIGURE_PAIR 保存 PNG；FIG 由调用方显式 savefig，且保持 Visible=on。
if ~isfolder(fileparts(basePath)), mkdir(fileparts(basePath)); end
set(fig,'Visible','on');
try, exportgraphics(fig,[basePath '.png'],'Resolution',180); catch, print(fig,[basePath '.png'],'-dpng','-r180'); end
end
