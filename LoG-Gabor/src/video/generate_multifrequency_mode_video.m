function [video, field] = generate_multifrequency_mode_video(reference, time, modes, frequencies, amplitudes, cfg)
%GENERATE_MULTIFREQUENCY_MODE_VIDEO SSRM 等价模拟：叠加两个激励频率的模态。
[height,width]=size(reference); [x,y]=meshgrid(1:width,1:height);
frames=numel(time); video=zeros(height,width,frames); field=zeros(height,width,frames);
for k=1:frames
    displacement=zeros(height,width);
    for q=1:numel(frequencies)
        displacement=displacement+amplitudes(q)*modes{q}*sin(2*pi*frequencies(q)*time(k));
    end
    field(:,:,k)=displacement;
    video(:,:,k)=interp2(x,y,reference,x,y-displacement,'linear',0);
end
if cfg.synthetic.noiseStd>0, video=video+cfg.synthetic.noiseStd*randn(size(video)); end
video=min(max(video,0),1);
end
