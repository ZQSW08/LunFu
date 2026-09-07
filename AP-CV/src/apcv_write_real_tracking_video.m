function apcv_write_real_tracking_video(frames, result, outputPath, frameRate, ...
    physicalScaleProvided, direction, videoPath, frameIndices, analysisRoiTrajectory, tracking)
%APCV_WRITE_REAL_TRACKING_VIDEO 在原始视频画面上叠加 ROI 追踪结果。
%
% 旧版本把 AP-CV 输入的裁剪帧直接写入 AVI，无法观察 ROI 是否跟住目标。
% 当前版本优先重新读取原始视频，并叠加：fDSST 原始目标框（黄色）、
% 实际送入 AP-CV 的保持型分析窗口（青色）、帧号、位移、追踪质量和触边标志。
% 最后一组可选参数缺省时仍兼容旧的“只写裁剪帧”调用。

if nargin < 6 || isempty(direction), direction = 'vertical'; end
direction = apcv_normalize_direction(direction);
if strcmpi(direction,'horizontal'), axisName = 'X'; else, axisName = 'Y'; end
useOriginal = nargin >= 7 && ~isempty(videoPath) && isfile(videoPath) && ...
    nargin >= 9 && ~isempty(analysisRoiTrajectory);
if useOriginal
    reader = VideoReader(videoPath);
    if nargin < 8 || isempty(frameIndices), frameIndices = (1:size(frames,3)).'; end
    frameIndices = double(frameIndices(:));
else
    reader = [];
    frameIndices = (1:size(frames,3)).';
end
if nargin < 10 || isempty(tracking), tracking = struct(); end
if nargin < 9 || isempty(analysisRoiTrajectory)
    analysisRoiTrajectory = repmat([1 1 size(frames,2) size(frames,1)],size(frames,3),1);
end
analysisRoiTrajectory = double(analysisRoiTrajectory);

writer = VideoWriter(outputPath,'Motion JPEG AVI');
writer.FrameRate = frameRate;
writer.Quality = 90;
open(writer);
cleanupObj = onCleanup(@() close(writer)); %#ok<NASGU>
sourceIndex = 0;
for k = 1:size(frames,3)
    if useOriginal
        targetIndex = frameIndices(min(k,numel(frameIndices)));
        while sourceIndex < targetIndex && hasFrame(reader)
            sourceIndex = sourceIndex + 1;
            sourceFrame = readFrame(reader);
        end
        if sourceIndex ~= targetIndex
            error('跟踪视频读取提前结束：第 %d 个处理帧对应原视频帧 %d。',k,targetIndex);
        end
        image = im2uint8(sourceFrame);
    else
        image = im2uint8(frames(:,:,k));
    end
    image = padToEvenSize(image);

    roiIndex = min(k,size(analysisRoiTrajectory,1));
    analysisRoi = analysisRoiTrajectory(roiIndex,:);
    if useOriginal
        % 动态模式额外显示 fDSST 的当前尺度框；青色框是实际分析窗口。
        rawRoi = [];
        if isfield(tracking,'rawRoiTrajectory') && ~isempty(tracking.rawRoiTrajectory)
            rawIndex = min(k,size(tracking.rawRoiTrajectory,1));
            rawRoi = tracking.rawRoiTrajectory(rawIndex,:);
        end
        if ~isempty(rawRoi)
            image = insertShape(image,'Rectangle',round(rawRoi), ...
                'Color',[255 190 0],'LineWidth',3);
        end
        image = insertShape(image,'Rectangle',round(analysisRoi), ...
            'Color',[0 210 255],'LineWidth',3);
        status = char(string(getFieldOr(tracking,'trackerType','ROI')));
        quality = getIndexedField(tracking,'quality',k,NaN);
        hitBoundary = logical(getIndexedField(tracking,'hitBoundary',k,false));
        if hitBoundary, status = [status ' / BOUNDARY']; end %#ok<AGROW>
        if isfinite(quality)
            roiLabel = sprintf('%s | Q=%.3f | analysis ROI',status,quality);
        else
            roiLabel = sprintf('%s | analysis ROI',status);
        end
        image = insertText(image,[5 35],roiLabel,'TextColor','white', ...
            'BoxColor','black','FontSize',13,'BoxOpacity',0.65);
    end
    if physicalScaleProvided
        label = sprintf('Frame %d | %s %.4f mm',k,axisName,result.proposedMm(k));
    else
        label = sprintf('Frame %d | %s %.4f pixel',k,axisName,result.proposedPx(k));
    end
    annotated = insertText(image,[5 5],label,'TextColor','white', ...
        'BoxColor','black','FontSize',14,'BoxOpacity',0.65);
    writeVideo(writer,annotated);
end
end

function value = getFieldOr(data,name,defaultValue)
if isstruct(data) && isfield(data,name) && ~isempty(data.(name)), value=data.(name); else, value=defaultValue; end
end

function value = getIndexedField(data,name,index,defaultValue)
value = defaultValue;
if ~isstruct(data) || ~isfield(data,name) || isempty(data.(name)), return; end
candidate = data.(name);
if numel(candidate)>=index, value=candidate(index); end
end

function image = padToEvenSize(image)
if mod(size(image,1),2)==1, image(end+1,:,:) = image(end,:,:); end
if mod(size(image,2),2)==1, image(:,end+1,:) = image(:,end,:); end
end
