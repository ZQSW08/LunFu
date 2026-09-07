function count = video_frame_count(videoPath,limit)
%VIDEO_FRAME_COUNT 统计实际可读帧数；limit 有值时只统计到上限。
if nargin<2 || isempty(limit), limit=Inf; end
v=VideoReader(videoPath); count=0;
while count<limit && hasFrame(v)
    readFrame(v); count=count+1;
end
end
