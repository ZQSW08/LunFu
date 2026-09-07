function stream = video_to_stream(videoPath, exactCount)
%VIDEO_TO_STREAM 把 VideoReader 封装为按帧数据源。
% exactCount=true 时使用实际可读帧数，避免视频元数据造成越界。
v=VideoReader(videoPath);
if nargin < 2 || isempty(exactCount) || ~exactCount
    count=max(1,floor(v.Duration*v.FrameRate+0.5));
elseif islogical(exactCount)
    count=video_frame_count(videoPath);
else
    count=exactCount;
end
if count < 1, error('视频中没有可读取的帧：%s',videoPath); end
stream=struct('count',count,'getFrame',@(idx) read(v,validate_index(idx,count)));
end

function idx=validate_index(idx,count)
if ~isnumeric(idx) || ~isscalar(idx) || ~isfinite(idx) || idx<1 || idx>count || idx~=round(idx)
    error('帧索引超出实际可读范围 1..%d。',count);
end
idx=round(idx);
end
