function points = select_points_on_frame(frame, pointCount, promptText, presetPoints)
%SELECT_POINTS_ON_FRAME 在图像上依次点击轮毂或测点，坐标采用 0-based。

if nargin < 4, presetPoints = []; end
if ~isempty(presetPoints)
    points = double(presetPoints);
    return;
end
selectionFigure = figure('Name', promptText, 'Color', 'w');
imshow(frame, []); hold on;
title({promptText; sprintf('请依次点击 %d 个点，每个点双击确认', pointCount)}, ...
    'Interpreter', 'none');
points = zeros(pointCount, 2);
for pointIndex = 1:pointCount
    pointHandle = drawpoint('Color', [0 0.45 0.74]);
    % MATLAB R2022b 的 wait(ROI) 不返回坐标；等待结束后读取 Position。
    wait(pointHandle);
    if ~isvalid(pointHandle)
        close(selectionFigure);
        error('测点选择未完成，处理已取消。');
    end
    position = pointHandle.Position;
    points(pointIndex, :) = position - 1;
    text(position(1)+4, position(2), sprintf('P%d', pointIndex), ...
        'Color', 'y', 'FontWeight', 'bold');
end
close(selectionFigure);
end
