function specs = dataset_specs(cfg)
%DATASET_SPECS 定义论文三组实验及真实实验的等价模拟代理。
% proxy=true 表示缺少作者原始实拍视频时构造的软件等价验证，不能表述为
% 已复现真实硬件实验。

h = cfg.frameSize(1);
w = cfg.frameSize(2);
common = struct('id', '', 'fs', 0, 'duration', 0, 'targetFrequency', 0, ...
    'description', '', 'height', h, 'width', w, 'analyzeStart', 0.5, ...
    'analyzeDuration', 4.0, 'proxy', false, 'targetType', 'ball');

specs = repmat(common, 1, 5);

specs(1).id = 'SV1';
specs(1).fs = 200;
specs(1).duration = 5;
specs(1).targetFrequency = 20;
specs(1).description = '论文式匀速大运动小球仿真';

specs(2) = specs(1);
specs(2).id = 'SV2';
specs(2).description = '论文式 Sigmoid 大运动小球仿真';

specs(3) = common;
specs(3).id = 'EXCITER_PROXY';
specs(3).fs = 200;
specs(3).duration = 4.5;
specs(3).analyzeStart = 0.25;
specs(3).analyzeDuration = 4.0;
specs(3).targetFrequency = 30.7;
specs(3).proxy = true;
specs(3).targetType = 'plate';
specs(3).description = '移动激振器等价模拟（幅值比约 800）';

specs(4) = common;
specs(4).id = 'BEAM_MOVING_PROXY';
specs(4).fs = 100;
specs(4).duration = 6.5;
specs(4).analyzeStart = 0.25;
specs(4).analyzeDuration = 6.0;
specs(4).targetFrequency = 5.3;
specs(4).proxy = true;
specs(4).targetType = 'beam';
specs(4).description = '移动悬臂梁等价模拟（幅值比约 100）';

specs(5) = specs(4);
specs(5).id = 'BEAM_STATIC_PROXY';
specs(5).description = '静止底座悬臂梁等价模拟真值';
end
