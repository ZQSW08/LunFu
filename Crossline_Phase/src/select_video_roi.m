function [roi, firstFrame, firstCrop, cancelled] = select_video_roi(videoPath, presetRoi, windowTitle)
%SELECT_VIDEO_ROI 首帧方形 ROI 交互选择。
% 双击或 Enter 确认；Esc 或关闭窗口取消。程序不设置确认按钮。
if nargin < 2, presetRoi = []; end
if nargin < 3 || isempty(windowTitle), windowTitle = 'Crossline ROI'; end
cancelled = false; roi = []; firstCrop = [];
try
    vr = VideoReader(videoPath); firstFrame = readFrame(vr);
catch ME
    firstFrame = []; cancelled = true; warning('Crossline:VideoRead','视频读取失败：%s',ME.message); return;
end
[h,w,~] = size(firstFrame);
if ~isempty(presetRoi)
    roi=clamp_square_roi(presetRoi,w,h); firstCrop=crop_frame(firstFrame,roi); return;
end
fig = figure('Name',windowTitle,'NumberTitle','off','Color','w','Visible','on', ...
    'Units','pixels','Position',[80 80 min(1200,w+160) min(850,h+180)], ...
    'WindowKeyPressFcn',@onKey,'CloseRequestFcn',@onClose);
ax = axes('Parent',fig); imshow(firstFrame,'Parent',ax); hold(ax,'on');
title(ax,{'请在首帧上拖动绘制方形 ROI；双击或按 Enter 确认','Esc 取消并退出'},'FontSize',12);
setappdata(fig,'roiState',struct('confirmed',false,'cancelled',false,'position',[]));
try
    % 不传入 Position，启动时不预先放置 ROI，由用户在首帧上自行绘制。
    rect = drawrectangle(ax,'Color',[1 0.2 0.1],'LineWidth',1.5);
    addlistener(rect,'ROIClicked',@onRoiClicked);
catch
    rect = imrect(ax); setColor(rect,'r');
end
uiwait(fig);
if isvalid(fig)
    state = getappdata(fig,'roiState');
    if state.cancelled || ~state.confirmed
        cancelled = true; delete(fig); return;
    end
    pos = state.position;
    if isempty(pos)
        try, pos = getPosition(rect); catch, cancelled = true; delete(fig); return; end
    end
    delete(fig); drawnow;
else
    cancelled = true; return;
end
roi = clamp_square_roi(pos,w,h);
if roi(3) < 16 || roi(4) < 16, cancelled = true; roi = []; return; end
firstCrop = crop_frame(firstFrame,roi);
    function onRoiClicked(~,evt)
        try
            if strcmpi(evt.SelectionType,'double'), confirm(); end
        catch
            % 某些 MATLAB 版本的 ROIClicked 事件不提供 SelectionType，Enter 仍可确认。
        end
    end
    function onKey(~,evt)
        switch evt.Key
            case {'return','enter'}, confirm();
            case 'escape', cancel();
        end
    end
    function confirm()
        if ~isvalid(fig), return; end
        try, posNow=getPosition(rect); catch, return; end
        if isempty(posNow) || posNow(3)<1 || posNow(4)<1, return; end
        s=getappdata(fig,'roiState'); s.confirmed=true; s.position=posNow; setappdata(fig,'roiState',s); drawnow; uiresume(fig);
    end
    function cancel()
        if isvalid(fig), s=getappdata(fig,'roiState'); s.cancelled=true; setappdata(fig,'roiState',s); uiresume(fig); end
    end
    function onClose(~,~), cancel(); end
end

function out = clamp_square_roi(pos,w,h)
% 将用户框选结果转换成论文要求的方形、整数、图像内 ROI。
side = max(16,round(min(pos(3),pos(4)))); cx = pos(1)+pos(3)/2; cy = pos(2)+pos(4)/2;
x = round(cx-side/2); y = round(cy-side/2);
x = min(max(1,x),max(1,w-side+1)); y = min(max(1,y),max(1,h-side+1));
side = min([side,w,h]); out = [x y side side];
end

function crop = crop_frame(frame,roi)
x = roi(1); y = roi(2); side = roi(3);
crop = frame(y:y+side-1,x:x+side-1,:);
end
