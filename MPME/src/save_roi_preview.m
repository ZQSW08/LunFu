function save_roi_preview(firstFrame, roi, croppedFrame, outputPath, figureTitle)
%SAVE_ROI_PREVIEW 保存原始首帧、ROI 框和裁剪区域对照图。

previewFigure = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1100 460]);
layout = tiledlayout(previewFigure, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, figureTitle, 'Interpreter', 'none');
nexttile; imshow(firstFrame, []); hold on;
rectangle('Position', roi, 'EdgeColor', [0.85 0.33 0.10], 'LineWidth', 1.8);
title('视频首帧与所选 ROI');
nexttile; imshow(croppedFrame, []); title(sprintf('ROI: [%d %d %d %d]', roi));
exportgraphics(previewFigure, outputPath, 'Resolution', 180);
close(previewFigure);
end
