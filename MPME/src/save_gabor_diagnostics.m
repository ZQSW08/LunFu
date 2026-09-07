function save_gabor_diagnostics(frame1, frame2, params, outputPath, figureTitle)
%SAVE_GABOR_DIAGNOSTICS 保存四方向 Gabor 响应和高置信点分布。

directions = params.directions;
directionCount = numel(directions);
diagnosticFigure = figure('Visible', 'off', 'Color', 'w', 'Position', [60 60 1450 660]);
colormap(diagnosticFigure, parula);
layout = tiledlayout(diagnosticFigure, 2, directionCount, ...
    'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, figureTitle, 'Interpreter', 'none');
for directionIndex = 1:directionCount
    theta = directions(directionIndex);
    q1 = gabor_response(frame1, params.lambda, theta, params.bandwidth, ...
        params.psi, params.supportSigma);
    q2 = gabor_response(frame2, params.lambda, theta, params.bandwidth, ...
        params.psi, params.supportSigma);
    amplitude1 = abs(q1).^2;
    amplitude2 = abs(q2).^2;
    confidence = (amplitude1 .* amplitude2) ./ ...
        max((amplitude1 + amplitude2).^(3/2), eps);
    positive = sort(confidence(confidence > 0));
    if isempty(positive)
        cutoff = Inf;
    elseif isfield(params, 'confidenceThreshold') && params.confidenceThreshold > 0
        cutoff = params.confidenceThreshold;
    else
        cutoff = positive(max(1, round(0.7*numel(positive))));
    end
    nexttile(directionIndex); imagesc(log1p(abs(q1))); axis image off;
    colorbar;
    title(sprintf('theta=%g deg：log(1+|q|)', theta));
    nexttile(directionCount + directionIndex); imshow(confidence >= cutoff);
    title(sprintf('高置信点：C >= %.2f', cutoff));
end
exportgraphics(diagnosticFigure, outputPath, 'Resolution', 180);
close(diagnosticFigure);
end
