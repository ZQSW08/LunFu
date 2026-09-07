function [roi, firstFrame, firstCrop, cancelled] = select_video_roi(videoPath, presetRoi, windowTitle)
% SELECT_VIDEO_ROI 在首帧上交互选择矩形 ROI。
% [] ROI 不显示初始框，直接用鼠标拖动；双击 ROI 或按 Enter 确认，Esc/关闭窗口取消。
% 不依赖 wait(rectangleHandle) 的返回值，避免不同 MATLAB 版本的交互差异。

roi = [];
firstFrame = [];
firstCrop = [];
cancelled = true;
hFig = [];
hRect = [];

if nargin < 2, presetRoi = []; end
if nargin < 3 || isempty(windowTitle)
    windowTitle = 'PLT ROI：拖动矩形，双击或 Enter 确认，Esc 取消';
end

try
    vr = VideoReader(videoPath);
    if ~hasFrame(vr), return; end
    firstFrame = readFrame(vr);
    imageSize = [size(firstFrame, 2), size(firstFrame, 1)];

    hFig = figure('Name', windowTitle, 'NumberTitle', 'off', ...
        'MenuBar', 'none', 'ToolBar', 'figure', 'Color', 'w', ...
        'WindowKeyPressFcn', @onKeyPress, 'CloseRequestFcn', @onClose);
    hAx = axes('Parent', hFig);
    imshow(firstFrame, 'InitialMagnification', 'fit', 'Parent', hAx);
    axis(hAx, 'image');

    if isempty(presetRoi)
        % 不传 Position，使用 MATLAB 原生鼠标拖动创建 ROI。
        hRect = drawrectangle(hAx, 'Color', [0.90 0.10 0.10], ...
            'LineWidth', 1.5, 'InteractionsAllowed', 'all');
    else
        hRect = drawrectangle(hAx, 'Position', clamp_roi(presetRoi, imageSize), ...
            'Color', [0.90 0.10 0.10], 'LineWidth', 1.5, ...
            'InteractionsAllowed', 'all');
    end
    addlistener(hRect, 'ROIClicked', @onRoiClicked);
    uiwait(hFig);

    if isgraphics(hFig) && ~cancelled && isgraphics(hRect)
        selected = clamp_roi(hRect.Position, imageSize);
        if selected(3) >= 8 && selected(4) >= 8
            roi = selected;
            firstCrop = crop_frame(firstFrame, roi);
        else
            cancelled = true;
        end
    end
    if isgraphics(hFig), delete(hFig); end
catch err
    cancelled = true;
    if isgraphics(hFig), delete(hFig); end
    warning('MP-G2LPT:ROISelectionFailed', 'ROI 窗口发生异常，已取消：%s', err.message);
end

    function onRoiClicked(~, eventData)
        selectionType = '';
        try, selectionType = eventData.SelectionType; catch, end
        if strcmpi(selectionType, 'double')
            cancelled = false;
            if isgraphics(hFig), uiresume(hFig); end
        end
    end

    function onKeyPress(~, eventData)
        if any(strcmpi(eventData.Key, {'return', 'enter'}))
            if isgraphics(hRect)
                selected = clamp_roi(hRect.Position, imageSize);
                if selected(3) >= 8 && selected(4) >= 8
                    cancelled = false;
                    uiresume(hFig);
                end
            end
        elseif strcmpi(eventData.Key, 'escape')
            cancelled = true;
            if isgraphics(hFig), uiresume(hFig); end
        end
    end

    function onClose(~, ~)
        cancelled = true;
        if isgraphics(hFig), uiresume(hFig); end
    end
end

function roi = clamp_roi(roi, imageSize)
% 将 ROI 限制在 [x y width height] 的图像边界内。
roi = double(roi(:).');
roi(1:2) = max(1, roi(1:2));
roi(3:4) = max(1, roi(3:4));
roi(3) = min(roi(3), imageSize(1) - roi(1) + 1);
roi(4) = min(roi(4), imageSize(2) - roi(2) + 1);
roi = floor(roi);
end

function crop = crop_frame(frame, roi)
x = roi(1); y = roi(2); w = roi(3); h = roi(4);
crop = frame(y:y+h-1, x:x+w-1, :);
end
