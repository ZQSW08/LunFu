function [roi, firstFrame, firstCrop, cancelled] = apcv_select_video_roi(videoPath, presetRoi, windowTitle)
%APCV_SELECT_VIDEO_ROI 在首帧上安全选择固定区域。
% 支持预设区域、拖动矩形、双击、Enter 确认和 Esc/关闭取消。
% 界面不显示方法名称或“ROI”标签，避免把显示文字写入视频内容。

cancelled = false;
roi = [];
firstCrop = [];

try
    reader = VideoReader(videoPath);
    if ~hasFrame(reader)
        error('视频没有可读帧。');
    end
    firstFrame = readFrame(reader);
catch ME
    error('无法读取视频首帧：%s', ME.message);
end

if size(firstFrame, 3) == 3
    displayFrame = rgb2gray(firstFrame);
else
    displayFrame = firstFrame;
end
imageSize = [size(displayFrame, 1), size(displayFrame, 2)];

if ~isempty(presetRoi)
    [roi, ok, message] = apcv_validate_roi(presetRoi, imageSize);
    if ~ok
        error('预设 ROI 无效：%s', message);
    end
    firstCrop = cropFrame(displayFrame, roi);
    return;
end

% 无桌面环境不能弹出交互窗口，安全返回取消状态。
if ~usejava('desktop')
    cancelled = true;
    return;
end

if nargin < 3 || isempty(windowTitle)
    windowTitle = '';
end
fig = figure('Name', windowTitle, 'NumberTitle', 'off', 'Color', 'w', ...
    'MenuBar', 'none', 'ToolBar', 'figure', 'WindowKeyPressFcn', @keyPressed, ...
    'CloseRequestFcn', @cancelSelection);
ax = axes(fig);
imshow(displayFrame, 'Parent', ax); hold(ax, 'on');
% 不预先创建大矩形；drawrectangle 进入“鼠标按下后拖动创建”的直接框选模式。
roiHandle = drawrectangle(ax, 'Color', [0.1 0.8 0.2]);
title(ax, '拖动矩形后双击或按 Enter 确认；按 Esc 取消并退出');
addlistener(roiHandle, 'ROIClicked', @roiClicked);
uiwait(fig);

if cancelled
    if isvalid(fig)
        delete(fig);
    end
    return;
end
if isvalid(fig) && isvalid(roiHandle)
    candidate = roiHandle.Position;
else
    candidate = [];
end
if isvalid(fig)
    delete(fig);
end
if isempty(candidate)
    cancelled = true;
    return;
end
[roi, ok, message] = apcv_validate_roi(candidate, imageSize);
if ~ok
    error('交互 ROI 无效：%s', message);
end
firstCrop = cropFrame(displayFrame, roi);

    function roiClicked(~, event)
        if isprop(event, 'SelectionType') && strcmpi(event.SelectionType, 'double')
            confirmSelection();
        end
    end
    function keyPressed(~, event)
        if strcmpi(event.Key, 'return') || strcmpi(event.Key, 'enter')
            confirmSelection();
        elseif strcmpi(event.Key, 'escape')
            cancelSelection();
        end
    end
    function confirmSelection(~, ~)
        if isvalid(fig); uiresume(fig); end
    end
    function cancelSelection(~, ~)
        cancelled = true;
        if isvalid(fig); uiresume(fig); end
    end
end

function crop = cropFrame(frame, roi)
x = roi(1); y = roi(2); w = roi(3); h = roi(4);
crop = frame(y:y+h-1, x:x+w-1, :);
end
