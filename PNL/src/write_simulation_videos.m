function outputs = write_simulation_videos(cfg)
%WRITE_SIMULATION_VIDEOS 写出论文仿真所需的双目模拟视频。
%   视频以左右相机并排显示，保持论文 200 fps；不把视频帧全部留在内存。

[texture, xGrid, yGrid] = make_crossline_texture(cfg);
outputs = cell(1, 2);
corePath = fullfile(cfg.output.videos, 'simulation_coupled_stereo.avi');
outputs{1} = write_case(corePath, cfg, texture, xGrid, yGrid, cfg.nFrames, 'coupled');

ampCfg = cfg;
ampCfg.nFrames = round(cfg.amplitudeVideoDuration * cfg.fps);
ampPath = fullfile(cfg.output.videos, 'simulation_amplitude_stereo.avi');
outputs{2} = write_case(ampPath, ampCfg, texture, xGrid, yGrid, ampCfg.nFrames, 'amplitude');
end

function outputPath = write_case(outputPath, cfg, texture, xGrid, yGrid, nFrames, caseType)
writer = VideoWriter(outputPath, 'Motion JPEG AVI');
writer.FrameRate = cfg.fps;
writer.Quality = 95;
open(writer);
cleanup = onCleanup(@() close(writer));

for k = 1:nFrames
    t = (k - 1) / cfg.fps;
    motion = case_motion(cfg, t, caseType);
    center = cfg.marker.center + motion;
    [frames, ~] = render_stereo_frame(cfg, center, texture, xGrid, yGrid, 0);
    gray = uint8(255 * [frames{1}, frames{2}]);
    rgb = repmat(gray, 1, 1, 3);
    writeVideo(writer, rgb);
end
end

function motion = case_motion(cfg, t, caseType)
motion = zeros(3, 1);
if strcmpi(caseType, 'coupled')
    motion(1) = cfg.motion.xAmplitude * sin(2 * pi * cfg.motion.xFrequency * t);
    if t >= cfg.motion.zStart
        motion(3) = cfg.motion.zAmplitude * sin(2 * pi * cfg.motion.zFrequency * t);
    end
else
    % 论文 Fig. 18 的指数增幅 30 Hz 激励，幅值约从 0.002 mm 增长到 0.3 mm。
    growth = log(0.3 / 0.002) / cfg.amplitudeVideoDuration;
    motion(3) = 0.002 * exp(growth * t) * sin(2 * pi * 30 * t);
end
end
