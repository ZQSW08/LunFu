function outputs = generate_paper_sv_videos(cfg, ids)
%GENERATE_PAPER_SV_VIDEOS 生成论文规格的 SV1/SV2 小球模拟视频。
%
% 论文 4.2 节明确给出：960x540、1000 FPS、5 s、20 Hz 微振动，
% SV1 为 5*t 匀速大运动，SV2 为 50/(1+exp(-0.75*t))-25。
% 当前函数只生成视频和真值，不尝试把 5000 帧高分辨率数据全部放入
% 相位立方体；这样可以保留论文规格的视频，同时不破坏 CPU 代理 baseline。

arguments
    cfg struct = bpaf.default_config()
    ids = {'SV1', 'SV2'}
end

bpaf.setup_project(cfg);
videoDir = fullfile(cfg.outputDir, 'videos', 'paper_sv');
truthDir = fullfile(cfg.dataDir, 'paper_sv');
if ~isfolder(videoDir), mkdir(videoDir); end
if ~isfolder(truthDir), mkdir(truthDir); end

height = 540;
width = 960;
fs = 1000;
duration = 5;
targetFrequency = 20;
scalePxPerMeter = 30;
radiusPx = 38;
originX = 90;
centerY = height / 2;
[xx, yy] = meshgrid(1:width, 1:height);

% 静态、近似无纹理的环境；运动信息主要来自可见的小球，符合论文中
% “背景不含其他物体、整幅图像作为目标区域”的模拟场景描述。
background = 0.10 + 0.025 * (yy / height) + 0.012 * cos(2*pi*yy/180);
background = single(background);

outputs = repmat(struct('id', '', 'videoPath', '', 'truthPath', '', ...
    'frameRate', fs, 'frameCount', fs*duration, 'size', [height width]), 1, numel(ids));

for caseIdx = 1:numel(ids)
    id = upper(char(ids{caseIdx}));
    if ~ismember(id, {'SV1', 'SV2'})
        error('generate_paper_sv_videos:UnknownId', '只支持 SV1 或 SV2，收到：%s', id);
    end

    nFrames = fs * duration;
    t = (0:nFrames-1)' / fs;
    switch id
        case 'SV1'
            largeMotionM = 5 * t;
        case 'SV2'
            largeMotionM = 50 ./ (1 + exp(-0.75 * t)) - 25;
    end
    vibrationM = 0.01 * sin(40*pi*t);
    totalMotionM = largeMotionM + vibrationM;

    videoPath = fullfile(videoDir, [lower(id), '_paper_960x540_1000fps.avi']);
    truthPath = fullfile(truthDir, [lower(id), '_paper_truth.mat']);
    writer = VideoWriter(videoPath, 'Motion JPEG AVI');
    writer.FrameRate = fs;
    writer.Quality = 95;
    open(writer);
    cleanupWriter = onCleanup(@() close_writer(writer)); %#ok<NASGU>

    for frameIdx = 1:nFrames
        centerX = originX + scalePxPerMeter * totalMotionM(frameIdx);
        dx = xx - centerX;
        dy = yy - centerY;
        radial = hypot(dx, dy);
        edge = 1 ./ (1 + exp((radial - radiusPx) / 1.0));
        inside = max(0, 1 - (radial / radiusPx).^2);
        shading = 0.35 + 0.55 * sqrt(inside) + 0.10 * (dx / radiusPx);
        % 球面上的细微高频纹理使亚像素水平运动能够进入相位子带，
        % 同时保留清晰可见的小球外形，不再用几乎不可见的 0.005 灰度遮罩。
        texture = 0.55 + 0.25*cos(2*pi*dx/10) + ...
            0.12*cos(2*pi*dy/14) + 0.08*cos(2*pi*(dx+dy)/19);
        ball = edge .* min(max(shading .* texture, 0), 1);
        frame = min(max(background + 0.78 * ball, 0), 1);
        rgb = repmat(im2uint8(frame), 1, 1, 3);
        writeVideo(writer, rgb);
    end
    close(writer);
    clear cleanupWriter;

    truth = struct();
    truth.time = t;
    truth.largeMotionM = largeMotionM;
    truth.vibrationM = vibrationM;
    truth.totalMotionM = totalMotionM;
    truth.fs = fs;
    truth.duration = duration;
    truth.targetFrequency = targetFrequency;
    truth.resolution = [height width];
    truth.scalePxPerMeter = scalePxPerMeter;
    truth.originX = originX;
    truth.centerY = centerY;
    truth.equation = id;
    truth.description = '论文 4.2 节小球模拟规格：背景无其他物体，水平大运动叠加 20 Hz 微振动';
    save(truthPath, 'truth', '-v7.3');

    outputs(caseIdx).id = id;
    outputs(caseIdx).videoPath = videoPath;
    outputs(caseIdx).truthPath = truthPath;
end
end

function close_writer(writer)
try
    close(writer);
catch
end
end
