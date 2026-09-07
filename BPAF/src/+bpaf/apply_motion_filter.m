function result = apply_motion_filter(features, kernel, useNonlinearSuppression, source)
%APPLY_MOTION_FILTER 实现论文式(23)-(29)并返回目标区域平均振动信号。
% source='cube' 使用完整相位场；source='aggregate' 用于大量参数扫描，
% 在已完成空间幅值加权的1D信号上执行同一时域核。

arguments
    features struct
    kernel double = []
    useNonlinearSuppression (1,1) logical = false
    source char {mustBeMember(source, {'cube', 'aggregate'})} = 'cube'
end

if strcmp(source, 'cube')
    inputSignal = features.phaseCube;
    if isempty(kernel)
        filtered = inputSignal;
    else
        robustInput = nonlinear_gate(inputSignal, numel(kernel), useNonlinearSuppression, 3);
        filtered = imfilter(robustInput, reshape(double(kernel), 1, 1, []), ...
            'symmetric', 'conv');
    end
    weighted = filtered .* features.spatialWeight;
    signal = squeeze(sum(weighted, [1, 2]) / ...
        (size(weighted, 1)*size(weighted, 2)));
    signal = double(signal(:));
else
    inputSignal = double(features.rawSignal(:));
    if isempty(kernel)
        signal = inputSignal;
    else
        robustInput = nonlinear_gate(inputSignal, numel(kernel), useNonlinearSuppression, 1);
        signal = imfilter(robustInput, kernel(:), 'symmetric', 'conv');
    end
    filtered = [];
end

% 对称边界扩展避免卷积端点伪峰，因此全部分析窗口均可用于论文指标。
margin = 0;
result = struct('signal', signal, 'filteredPhase', filtered, ...
    'marginSamples', margin, 'usedNonlinearSuppression', useNonlinearSuppression, ...
    'source', source);
end

function output = nonlinear_gate(input, kernelLength, enabled, dimension)
if ~enabled
    output = input;
    return;
end

halfWidth = floor(kernelLength/2);
window = [halfWidth, halfWidth];
localMean = movmean(input, window, dimension, 'Endpoints', 'shrink');
oscillation = input - localMean;
% 论文式(25)：令 omega_n*epsilon 等于局部平均绝对相位变化。
localAbsMean = movmean(abs(oscillation), window, dimension, 'Endpoints', 'shrink');
% 论文只建议 omega_n*epsilon 取区间平均绝对相位，但未明确数字实现中如何
% 避免把正常正弦峰值也当成异常值。这里采用三倍局部平均绝对相位作为
% “不衰减区”，仅对超出该区间的非线性跃变施加式(25)高斯衰减。
threshold = 3*localAbsMean;
excess = max(abs(oscillation)-threshold, 0);
sigmaEpsilon = localAbsMean / sqrt(2*log(2)) + eps('single');
amplitudeKernel = exp(-(excess.^2) ./ (2*sigmaEpsilon.^2));
output = localMean + amplitudeKernel .* oscillation;
end
