function [video,meta] = read_video_frames(inputPath,options)
%READ_VIDEO_FRAMES Read a real video as H-by-W-by-T luminance data.
%   [VIDEO,META] = READ_VIDEO_FRAMES(INPUTPATH,OPTIONS) uses VideoReader.
%   Coordinates in OPTIONS.Roi are [x y width height] and are applied after
%   luminance conversion. The function intentionally does
%   not silently fall back to synthetic data when the input is unavailable.

if nargin<2 || isempty(options), options=struct; end
if ~(ischar(inputPath) || isstring(inputPath))
    error('read_video_frames:InvalidPath','inputPath must be a video file path.');
end
inputPath=char(inputPath);
if ~isfile(inputPath)
    error('read_video_frames:MissingFile','Video file not found: %s',inputPath);
end

reader=VideoReader(inputPath);
startFrame=max(1,round(get_option(options,'StartFrame',1)));
endFrame=get_option(options,'EndFrame',inf);
maxFrames=get_option(options,'MaxFrames',inf);
if ~isfinite(endFrame), endFrame=inf; else, endFrame=max(startFrame,round(endFrame)); end
if ~isfinite(maxFrames), maxFrames=inf; else, maxFrames=max(1,round(maxFrames)); end
roi=get_option(options,'Roi',[]);
useSingle=get_option(options,'UseSingle',true);

frames={}; frameNumber=0; selectedCount=0; firstSize=[];
while hasFrame(reader)
    rgb=readFrame(reader); frameNumber=frameNumber+1;
    if frameNumber<startFrame, continue; end
    if frameNumber>endFrame || selectedCount>=maxFrames, break; end

    image=rgb_to_luminance(rgb);
    if isempty(firstSize), firstSize=size(image); end
    if ~isempty(roi)
        image=apply_roi(image,roi);
    end
    if useSingle, image=single(image); else, image=double(image); end
    selectedCount=selectedCount+1;
    frames{selectedCount}=image; %#ok<AGROW>
end

if isempty(frames)
    error('read_video_frames:NoFrames','No frames were selected from %s.',inputPath);
end
video=cat(3,frames{:});
meta=struct('inputPath',inputPath,'frameRate',reader.FrameRate,...
    'durationSeconds',reader.Duration,'sourceWidth',firstSize(2),...
    'sourceHeight',firstSize(1),'startFrame',startFrame,...
    'endFrame',startFrame+selectedCount-1,'frameCount',selectedCount,...
    'roi',roi,'height',size(video,1),'width',size(video,2),...
    'class',class(video));
end

function value=get_option(options,name,defaultValue)
if isfield(options,name) && ~isempty(options.(name)), value=options.(name); else, value=defaultValue; end
end

function image=apply_roi(image,roi)
if ~isnumeric(roi) || numel(roi)~=4 || any(~isfinite(roi))
    error('read_video_frames:InvalidRoi','Roi must be [x y width height].');
end
roi=round(reshape(roi,1,4));
if roi(1)<1 || roi(2)<1 || roi(3)<1 || roi(4)<1
    error('read_video_frames:RoiOutOfBounds','Roi is outside the source frame.');
end
x1=roi(1); y1=roi(2); x2=x1+roi(3)-1; y2=y1+roi(4)-1;
if x2>size(image,2) || y2>size(image,1)
    error('read_video_frames:RoiOutOfBounds','Roi is outside the source frame.');
end
image=image(y1:y2,x1:x2);
end
