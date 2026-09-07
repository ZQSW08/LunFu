function [roi, firstFrame, croppedFrame, cancelled] = select_video_roi(videoPath, presetRoi, windowTitle)
%SELECT_VIDEO_ROI 安全地在首帧上手动框选 ROI。
% 不直接调用 wait(rectangleHandle)：窗口关闭、句柄失效或按 Esc 时返回
% cancelled=true，而不是把 MATLAB 的句柄异常抛给主流程。

if nargin < 2, presetRoi = []; end
if nargin < 3 || isempty(windowTitle), windowTitle = '请选择处理区域 ROI'; end
cancelled = false;
reader = VideoReader(videoPath);
firstFrame = readFrame(reader);
displayFrame = firstFrame;
if size(displayFrame,3)==1, displayFrame=repmat(displayFrame,1,1,3); end

if isempty(presetRoi)
    [roi, cancelled] = interactive_roi(displayFrame, windowTitle);
    if cancelled
        croppedFrame = [];
        fprintf('ROI 交互已取消，当前运行安全停止；没有生成不完整结果。\n');
        return;
    end
else
    roi = double(presetRoi(:).');
end

if numel(roi)~=4 || any(~isfinite(roi))
    cancelled = true;
    croppedFrame = [];
    fprintf('ROI 参数无效，当前运行安全停止。\n');
    return;
end
imageHeight=size(firstFrame,1); imageWidth=size(firstFrame,2);
roi=round(roi);
roi(1)=min(max(1,roi(1)),max(1,imageWidth-1));
roi(2)=min(max(1,roi(2)),max(1,imageHeight-1));
roi(3)=min(max(1,roi(3)),imageWidth-roi(1)+1);
roi(4)=min(max(1,roi(4)),imageHeight-roi(2)+1);
if roi(3)<16 || roi(4)<16
    cancelled = true;
    croppedFrame = [];
    fprintf('ROI 太小（当前 %d×%d px，至少需要 16×16 px），当前运行安全停止。\n',roi(3),roi(4));
    return;
end
croppedFrame = crop_by_roi(firstFrame,roi);
fprintf('已选择 ROI: [x=%d, y=%d, width=%d, height=%d]\n',roi);
end

function [roi, cancelled] = interactive_roi(displayFrame, windowTitle)
roi=[]; cancelled=true;
selectionFigure=[];
try
    selectionFigure=figure('Name',windowTitle,'Color','w', ...
        'NumberTitle','off','CloseRequestFcn',@close_selection_figure);
    imshow(displayFrame,'Parent',gca);
    title({windowTitle; '拖动矩形；双击、按 Enter 确认；Esc 或关闭窗口取消'}, ...
        'Interpreter','none');
    rectangleHandle=drawrectangle('Color',[0.85 0.33 0.10], ...
        'LineWidth',1.5,'InteractionsAllowed','all');
    setappdata(selectionFigure,'roiHandle',rectangleHandle);
    setappdata(selectionFigure,'roiDone',false);
    set(selectionFigure,'WindowKeyPressFcn',@key_press);
    addlistener(rectangleHandle,'ROIClicked', ...
        @(src,event) roi_clicked(src,event,selectionFigure));
    uiwait(selectionFigure);
    if ishghandle(selectionFigure) && isappdata(selectionFigure,'roiDone') && ...
            getappdata(selectionFigure,'roiDone') && isvalid(rectangleHandle)
        candidate=round(rectangleHandle.Position);
        if numel(candidate)==4 && all(isfinite(candidate))
            roi=candidate; cancelled=false;
        end
    end
catch caughtError
    fprintf('ROI 交互未完成（%s），当前运行安全停止。\n',caughtError.message);
    roi=[]; cancelled=true;
end
if ishghandle(selectionFigure)
    try
        delete(selectionFigure);
    catch
    end
end
end

function roi_clicked(src,event,selectionFigure)
if ~ishghandle(selectionFigure) || ~isvalid(src), return; end
if isprop(event,'SelectionType') && strcmpi(event.SelectionType,'double')
    setappdata(selectionFigure,'roiDone',true);
    uiresume(selectionFigure);
end
end

function key_press(selectionFigure, event)
if ~ishghandle(selectionFigure), return; end
if strcmpi(event.Key,'return') || strcmpi(event.Key,'enter')
    h=getappdata(selectionFigure,'roiHandle');
    if ~isempty(h) && isvalid(h)
        setappdata(selectionFigure,'roiDone',true);
        uiresume(selectionFigure);
    end
elseif strcmpi(event.Key,'escape')
    setappdata(selectionFigure,'roiDone',false);
    uiresume(selectionFigure);
end
end

function close_selection_figure(selectionFigure,~)
if ishghandle(selectionFigure)
    setappdata(selectionFigure,'roiDone',false);
    uiresume(selectionFigure);
end
end

function crop = crop_by_roi(frame,roi)
x=roi(1); y=roi(2); w=roi(3); h=roi(4);
x2=min(size(frame,2),x+w-1); y2=min(size(frame,1),y+h-1);
crop=frame(y:y2,x:x2,:);
end
