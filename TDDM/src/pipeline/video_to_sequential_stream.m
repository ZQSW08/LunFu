function stream=video_to_sequential_stream(videoPath,frameIndices)
%VIDEO_TO_SEQUENTIAL_STREAM 按顺序读取视频，避免每帧随机 seek 的开销。
v=VideoReader(videoPath); nextAbsolute=1; frameIndices=frameIndices(:)';
stream=struct('count',numel(frameIndices),'getFrame',@get_frame);
    function frame=get_frame(i)
        if i<1 || i>numel(frameIndices) || i~=round(i), error('无效帧索引。'); end
        target=frameIndices(i);
        if target<nextAbsolute, error('顺序视频流不支持回退读取。'); end
        while nextAbsolute<=target
            if ~hasFrame(v), error('视频实际可读帧数不足，停止于第 %d 帧。',nextAbsolute-1); end
            frame=readFrame(v); nextAbsolute=nextAbsolute+1;
        end
    end
end
