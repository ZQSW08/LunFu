function tracking = track_video_roi(videoPath, initialRoi, maxFrames, options)
%TRACK_VIDEO_ROI 生成振动保持型动态 ROI（VP-DROI）轨迹。
% 跟踪器只用于定位目标和估计宏观运动；BPAF 的相位与时域滤波仍在外部完成。
% 默认优先调用师兄第四章 fDSST，依赖不可用时回退到模板平移跟随。

arguments
    videoPath (1,:) char
    initialRoi (1,4) double
    maxFrames (1,1) double {mustBePositive}
    options.tracker (1,:) char = 'fdsst'
    options.macroTrendWindowSeconds (1,1) double {mustBePositive} = 0.15
    options.searchRadiusPx (1,1) double {mustBePositive} = 180
    options.minMatchScore (1,1) double = 0.35
    options.maxStepPixels (1,1) double {mustBePositive} = 120
end

reader = VideoReader(videoPath);
fps = reader.FrameRate;
if isinf(maxFrames)
    requestedFrames = max(1, floor(reader.Duration * fps));
else
    requestedFrames = max(1, round(maxFrames));
end

% 先尝试 fDSST：它同时提供平移和尺度轨迹，但不会替代 BPAF 测量。
backend = 'template_translation';
rawBbox = [];
trackerError = '';
if strcmpi(options.tracker, 'fdsst') && exist('DSST_Function', 'file') == 2
    try
        rawBbox = DSST_Function(initialRoi, reader, requestedFrames);
        rawBbox = double(rawBbox);
        rawBbox = rawBbox(1:min(requestedFrames,size(rawBbox,1)),:);
        if size(rawBbox,2) ~= 4 || size(rawBbox,1) < 1 || any(~isfinite(rawBbox(1,:)))
            error('fDSST 返回的 bbox 为空或维度无效。');
        end
        backend = 'fdsst_sunjiajian';
    catch caughtError
        trackerError = caughtError.message;
        rawBbox = [];
    end
end

if isempty(rawBbox)
    if strcmpi(options.tracker, 'fdsst') && ~isempty(trackerError)
        fprintf('fDSST 不可用（%s），VP-DROI 回退到模板平移跟随。\n',trackerError);
    elseif strcmpi(options.tracker, 'fdsst')
        fprintf('未找到 fDSST 依赖，VP-DROI 回退到模板平移跟随。\n');
    end
    [rawBbox, confidence] = template_track(reader, initialRoi, requestedFrames, options);
else
    confidence = fdsst_confidence(rawBbox, initialRoi, options.maxStepPixels);
end

n = size(rawBbox,1);
rawBbox = sanitize_bbox(rawBbox, initialRoi, reader.Width, reader.Height);
center = [rawBbox(:,1)+0.5*rawBbox(:,3), rawBbox(:,2)+0.5*rawBbox(:,4)];
scale = sqrt(rawBbox(:,3).*rawBbox(:,4)) / sqrt(initialRoi(3)*initialRoi(4));
valid = all(isfinite(rawBbox),2) & confidence >= 0;

% 仅用宏观轨迹移动裁剪窗口；裁剪尺寸保持首帧尺寸，避免每帧缩放破坏 BPAF 相位。
window = max(3, round(options.macroTrendWindowSeconds * fps));
if mod(window,2)==0, window=window+1; end
macroCenter = smooth_track_center(center, window);
cropBbox = zeros(n,4);
for idx=1:n
    cropBbox(idx,:) = clamp_bbox([macroCenter(idx,:)-0.5*initialRoi(3:4), initialRoi(3:4)], ...
        reader.Width, reader.Height);
end

tracking = struct();
tracking.backend = backend;
tracking.fps = fps;
tracking.time_s = (0:n-1)'/fps;
tracking.bbox_xywh = rawBbox;
tracking.center_xy = center;
tracking.scale = scale;
tracking.confidence = confidence(:);
tracking.valid = valid(:);
tracking.macro_center_xy = macroCenter;
tracking.crop_bbox_xywh = cropBbox;
tracking.boundary = any(cropBbox(:,1:2)<=1,2) | ...
    cropBbox(:,1)+cropBbox(:,3)-1>=reader.Width | cropBbox(:,2)+cropBbox(:,4)-1>=reader.Height;
tracking.macro_displacement_xy = macroCenter - center(1,:);
tracking.fallback = strcmp(backend,'template_translation');
tracking.trendWindowSeconds = window/fps;
end

function [bbox, confidence] = template_track(reader, initialRoi, requestedFrames, options)
reader.CurrentTime = 0;
first = readFrame(reader);
gray = to_gray(first);
template = crop_frame(gray, initialRoi);
bbox = zeros(requestedFrames,4); confidence = zeros(requestedFrames,1);
previous = initialRoi;
index = 0;
while hasFrame(reader) && index<requestedFrames
    frame = to_gray(readFrame(reader)); index=index+1;
    if index==1
        current=initialRoi; score=1;
    else
        [current,score]=match_template(frame,template,previous,options.searchRadiusPx);
        if ~isfinite(score), current=previous; score=0; end
        if score<options.minMatchScore, current=previous; end
    end
    current=clamp_bbox(current,size(frame,2),size(frame,1));
    bbox(index,:)=current; confidence(index)=score; previous=current;
end
bbox=bbox(1:index,:); confidence=confidence(1:index);
end

function [candidate, score] = match_template(frame, template, previous, radius)
[h,w]=size(frame); [th,tw]=size(template);
x1=max(1,previous(1)-radius); y1=max(1,previous(2)-radius);
x2=min(w,previous(1)+previous(3)-1+radius);
y2=min(h,previous(2)+previous(4)-1+radius);
search=frame(y1:y2,x1:x2);
if size(search,1)<th || size(search,2)<tw
    candidate=previous; score=0; return;
end
corr=normxcorr2(template,search);
[score,peak]=max(corr(:)); [py,px]=ind2sub(size(corr),peak);
candidate=[x1+px-tw,y1+py-th,previous(3),previous(4)];
end

function confidence = fdsst_confidence(bbox, initialRoi, maxStep)
center=[bbox(:,1)+0.5*bbox(:,3),bbox(:,2)+0.5*bbox(:,4)];
step=[0; hypot(diff(center(:,1)),diff(center(:,2)))];
scale=sqrt(bbox(:,3).*bbox(:,4))/sqrt(initialRoi(3)*initialRoi(4));
confidence=exp(-step/max(maxStep,eps)) .* exp(-abs(log(max(scale,eps))));
confidence(~isfinite(confidence))=0;
end

function center = smooth_track_center(center, window)
center=fillmissing(center,'linear','EndValues','nearest');
center(:,1)=movmedian(center(:,1),window,'omitnan');
center(:,2)=movmedian(center(:,2),window,'omitnan');
center(:,1)=movmean(center(:,1),window,'omitnan');
center(:,2)=movmean(center(:,2),window,'omitnan');
end

function bbox = sanitize_bbox(bbox, fallback, imageWidth, imageHeight)
for idx=1:size(bbox,1)
    if any(~isfinite(bbox(idx,:))) || bbox(idx,3)<2 || bbox(idx,4)<2
        bbox(idx,:)=fallback;
    end
    bbox(idx,:)=clamp_bbox(bbox(idx,:),imageWidth,imageHeight);
end
end

function bbox=clamp_bbox(bbox,imageWidth,imageHeight)
bbox=round(double(bbox));
bbox(3)=min(max(2,bbox(3)),max(2,imageWidth));
bbox(4)=min(max(2,bbox(4)),max(2,imageHeight));
bbox(1)=min(max(1,bbox(1)),max(1,imageWidth-bbox(3)+1));
bbox(2)=min(max(1,bbox(2)),max(1,imageHeight-bbox(4)+1));
end

function crop=crop_frame(frame,bbox)
bbox=clamp_bbox(bbox,size(frame,2),size(frame,1));
crop=frame(bbox(2):bbox(2)+bbox(4)-1,bbox(1):bbox(1)+bbox(3)-1);
end

function gray=to_gray(frame)
if size(frame,3)==3, gray=rgb2gray(frame); else, gray=frame; end
gray=im2single(gray);
end
