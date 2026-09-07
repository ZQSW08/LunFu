function [roi,cancelled]=select_video_roi(inputPath,presetRoi,windowTitle)
%SELECT_VIDEO_ROI Select [x y width height] on the first video frame.
%   Preset ROI skips the GUI. 双击 ROI 或按 Enter 确认，按 Esc/关闭窗口
%   取消；取消时返回 cancelled=true，不清理旧结果。

cancelled=false;
if nargin<2, presetRoi=[]; end
if nargin<3 || isempty(windowTitle), windowTitle='LoG-Gabor ROI'; end
if ~isempty(presetRoi)
    roi=validate_roi(presetRoi);
    return;
end
if ~usejava('desktop')
    error('select_video_roi:NoDesktop','Interactive ROI needs MATLAB desktop; set config.roi=[x y width height].');
end

reader=VideoReader(inputPath); firstFrame=rgb_to_luminance(readFrame(reader));
fig=figure('Name',windowTitle,'NumberTitle','off','Color','w',...
    'MenuBar','none','ToolBar','figure','CloseRequestFcn',@cancel_callback,...
    'WindowKeyPressFcn',@key_callback);
ax=axes(fig); imagesc(ax,firstFrame); axis(ax,'image'); colormap(ax,gray(256));
title(ax,'拖动矩形框；双击或按 Enter 确认，按 Esc 取消');
handle=drawrectangle(ax,'Color','r','LineWidth',1.2,'Deletable',false);
setappdata(fig,'cancelled',false);
setappdata(fig,'confirmed',false);
listener=addlistener(handle,'ROIClicked',@roi_clicked); %#ok<NASGU>
uiwait(fig);
if ~isgraphics(fig) || getappdata(fig,'cancelled')
    roi=[]; cancelled=true;
    if isgraphics(fig), delete(fig); end
    return;
end
if ~isgraphics(handle)
    roi=[]; cancelled=true; delete(fig); return;
end
position=handle.Position; roi=validate_roi(position);
delete(fig);

    function confirm_callback(varargin)
        if isgraphics(fig), uiresume(fig); end
    end
    function roi_clicked(~,event)
        selectionType='';
        if isstruct(event) && isfield(event,'SelectionType'), selectionType=event.SelectionType;
        elseif isprop(event,'SelectionType'), selectionType=event.SelectionType; end
        if strcmpi(selectionType,'double')
            setappdata(fig,'confirmed',true); confirm_callback();
        end
    end
    function key_callback(~,event)
        switch lower(event.Key)
            case {'return','enter'}
                setappdata(fig,'confirmed',true); confirm_callback();
            case 'escape'
                cancel_callback();
        end
    end
    function cancel_callback(varargin)
        if isgraphics(fig)
            setappdata(fig,'cancelled',true); uiresume(fig);
        end
    end
end

function roi=validate_roi(roi)
roi=round(reshape(roi,1,4));
if any(~isfinite(roi)) || roi(3)<2 || roi(4)<2
    error('select_video_roi:InvalidRoi','ROI must be [x y width height] with width and height >= 2.');
end
end
