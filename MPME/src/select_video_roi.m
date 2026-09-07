function [roi, firstFrame, croppedFrame] = select_video_roi(videoPath, presetRoi, windowTitle)
%SELECT_VIDEO_ROI 在视频首帧上交互框选 ROI，并返回裁剪结果。
% presetRoi 为空时弹出 drawrectangle；非空时直接复用 [x y width height]。

if nargin < 2, presetRoi = []; end
if nargin < 3 || isempty(windowTitle), windowTitle = '请选择处理区域 ROI'; end

reader = VideoReader(videoPath);
firstFrame = readFrame(reader);
if size(firstFrame, 3) == 3
    displayFrame = firstFrame;
else
    displayFrame = repmat(firstFrame, 1, 1, 3);
end

if isempty(presetRoi)
    selectionFigure = figure('Name', windowTitle, 'Color', 'w');
    imshow(displayFrame);
    title({windowTitle; '请框住目标主体及其纹理，勿只框选背景亮线；拖动后双击确认'}, ...
        'Interpreter', 'none');
    rectangleHandle = drawrectangle('Color', [0.85 0.33 0.10], 'LineWidth', 1.5);
    % MATLAB R2022b 中 wait(ROI) 不返回位置，需等待结束后读取 Position。
    wait(rectangleHandle);
    if ~isvalid(rectangleHandle)
        close(selectionFigure);
        error('未完成 ROI 框选，处理已取消。');
    end
    roi = round(rectangleHandle.Position);
    close(selectionFigure);
else
    roi = round(presetRoi);
end

% 将 ROI 限制在图像边界内，避免 imcrop 因越界补零。
imageHeight = size(firstFrame, 1);
imageWidth = size(firstFrame, 2);
roi(1) = min(max(1, roi(1)), imageWidth);
roi(2) = min(max(1, roi(2)), imageHeight);
roi(3) = min(max(1, roi(3)), imageWidth - roi(1));
roi(4) = min(max(1, roi(4)), imageHeight - roi(2));
minimumRoiSide = 32;
if roi(3) < minimumRoiSide || roi(4) < minimumRoiSide
    error(['ROI 太小：当前为 %d×%d px，至少需要 %d×%d px。' ...
        '请框选完整目标及其纹理，不要只框选一条边缘或单个亮点。'], ...
        roi(3),roi(4),minimumRoiSide,minimumRoiSide);
end

croppedFrame = imcrop(firstFrame, roi);
fprintf('已选择 ROI: [x=%d, y=%d, width=%d, height=%d]\n', roi);
end
