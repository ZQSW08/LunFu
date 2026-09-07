function save_pyramid_preview(frame, levels, outputPath, figureTitle)
%SAVE_PYRAMID_PREVIEW 保存论文 Fig. 8/Fig. 16 类型的高斯金字塔图。

pyramid = build_gaussian_pyramid(frame, levels);
previewFigure = figure('Visible', 'off', 'Color', 'w', 'Position', [80 80 1300 360]);
layout = tiledlayout(previewFigure, 1, levels, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, figureTitle, 'Interpreter', 'none');
for level = 1:levels
    nexttile; imshow(pyramid{level}, []);
    title(sprintf('尺度 %d: %d x %d', level-1, size(pyramid{level},2), size(pyramid{level},1)));
end
exportgraphics(previewFigure, outputPath, 'Resolution', 180);
close(previewFigure);
end
