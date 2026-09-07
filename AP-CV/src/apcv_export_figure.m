function apcv_export_figure(fig, basePath, dpi)
%APCV_EXPORT_FIGURE 同时保存可编辑 PDF 和带明确分辨率的 PNG。
% 图形使用白色不透明背景；不使用自动 tight 裁剪改变物理尺寸。

set(fig, 'Color', 'w');
exportgraphics(fig, [basePath '.pdf'], 'ContentType', 'vector', ...
    'BackgroundColor', 'white');
exportgraphics(fig, [basePath '.png'], 'Resolution', dpi, ...
    'BackgroundColor', 'white');
end
