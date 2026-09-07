function [roi, firstFrame, firstCrop, cancelled] = px_select_video_roi(videoPath, presetRoi, windowTitle)
% 读取首帧并选择固定ROI，返回[x,y,width,height]。
% 关闭窗口、按Esc或ROI无效均按cancelled处理，不触碰既有输出目录。
if nargin < 2
    presetRoi = [];
end
if nargin < 3 || isempty(windowTitle)
    windowTitle = 'Pixel Selection - ROI';
end
reader = VideoReader(videoPath);
firstFrame = readFrame(reader);
firstCrop = [];
cancelled = false;

if ~isempty(presetRoi)
    roi = px_clip_roi(round(presetRoi(:)'), size(firstFrame, 2), size(firstFrame, 1));
    if isempty(roi)
        roi = [];
        cancelled = true;
        return;
    end
    firstCrop = px_crop_frame(firstFrame, roi);
    return;
end

roi = [];
fig = figure('Name', windowTitle, 'NumberTitle', 'off', 'Color', 'w', ...
    'WindowKeyPressFcn', @px_roi_keypress, ...
    'CloseRequestFcn', @px_roi_close_request);
setappdata(fig, 'px_roi_action', 'waiting');
try
    imshow(firstFrame);
    title({'框选ROI后：双击矩形或按Enter确认；按Esc取消并退出'}, 'Interpreter', 'none');
    if exist('drawrectangle', 'file') == 2
        rectangleHandle = drawrectangle('Color', [0.85, 0.15, 0.15]);
        % 由ROI双击事件、Enter和Esc统一控制uiwait，不依赖按钮或wait返回值。
        clickListener = addlistener(rectangleHandle, 'ROIClicked', ...
            @(source, eventData) px_roi_clicked(source, eventData, fig));
        uiwait(fig);
        action = getappdata(fig, 'px_roi_action');
        if strcmp(action, 'confirm') && isgraphics(rectangleHandle)
            roiCandidate = round(rectangleHandle.Position);
        else
            roiCandidate = [];
        end
    else
        roiCandidate = round(getrect(fig));
    end
    if ~isgraphics(fig) || isempty(roiCandidate)
        cancelled = true;
    else
        roi = px_clip_roi(roiCandidate, size(firstFrame, 2), size(firstFrame, 1));
        cancelled = isempty(roi);
    end
catch
    cancelled = true;
end
if exist('clickListener', 'var') && isvalid(clickListener)
    delete(clickListener);
end
if isgraphics(fig)
    close(fig);
end
if ~cancelled
    firstCrop = px_crop_frame(firstFrame, roi);
end

function px_roi_keypress(fig, eventData)
% Enter确认当前矩形，Esc取消并结束本次处理。
if any(strcmpi(eventData.Key, {'return', 'enter'}))
    setappdata(fig, 'px_roi_action', 'confirm');
    uiresume(fig);
elseif strcmpi(eventData.Key, 'escape')
    setappdata(fig, 'px_roi_action', 'cancel');
    uiresume(fig);
end
end

function px_roi_close_request(fig, ~)
% 点击窗口关闭按钮等价于取消，并让主流程安全收尾。
setappdata(fig, 'px_roi_action', 'cancel');
uiresume(fig);
end

function px_roi_clicked(~, eventData, fig)
% 双击矩形时确认；不同MATLAB版本的事件名称做兼容判断。
try
    selectionType = lower(char(eventData.SelectionType));
catch
    selectionType = '';
end
if any(strcmp(selectionType, {'doubleclick', 'double'}))
    setappdata(fig, 'px_roi_action', 'confirm');
    uiresume(fig);
end
end
end

function roi = px_clip_roi(roi, frameWidth, frameHeight)
% 将ROI限制到图像边界，并强制保留至少2像素宽高。
if numel(roi) ~= 4 || any(~isfinite(roi))
    roi = [];
    return;
end
x1 = max(1, min(frameWidth - 1, roi(1)));
y1 = max(1, min(frameHeight - 1, roi(2)));
x2 = min(frameWidth, x1 + max(2, roi(3)) - 1);
y2 = min(frameHeight, y1 + max(2, roi(4)) - 1);
if x2 - x1 + 1 < 2 || y2 - y1 + 1 < 2
    roi = [];
else
    roi = [x1, y1, x2 - x1 + 1, y2 - y1 + 1];
end
end

function crop = px_crop_frame(frame, roi)
crop = frame(roi(2):(roi(2) + roi(4) - 1), roi(1):(roi(1) + roi(3) - 1), :);
end
