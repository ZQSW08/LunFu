%GENERATE_PAPER_SV_VIDEOS 生成严格按论文 4.2 节规格的 SV1/SV2 视频。
% 输出到 outputs/videos/paper_sv，不覆盖旧的低分辨率 CPU 代理结果。

scriptPath = mfilename('fullpath');
projectRoot = fileparts(fileparts(scriptPath));
addpath(fullfile(projectRoot, 'src'));
cfg = bpaf.default_config();
outputs = bpaf.generate_paper_sv_videos(cfg, {'SV1', 'SV2'}); %#ok<NASGU>
disp(outputs);
