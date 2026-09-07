function ods = compute_ods(displacement, fs, referenceIndex, targetFrequencies)
%COMPUTE_ODS 按论文第 4.1 节提取频率处的复数 ODS。
%   displacement: 测点 x 时间样本的位移矩阵；每一行可为一个坐标分量。
%   该函数使用 cross-power / auto-power 比值构造相对于参考点的 ODS。
%   真实实验的 LDV/加速度计数据不可得，因此入口保留为数据接入接口。

if nargin < 3 || isempty(referenceIndex)
    referenceIndex = 1;
end
if nargin < 4 || isempty(targetFrequencies)
    targetFrequencies = [];
end
if size(displacement, 2) < 2
    error('displacement 至少需要两个时间样本。');
end

n = size(displacement, 2);
freq = (0:floor(n / 2)) * fs / n;
F = fft(displacement, [], 2);
F = F(:, 1:numel(freq));
ref = F(referenceIndex, :);
autoRef = abs(ref) .^ 2 + eps;

if isempty(targetFrequencies)
    [~, order] = sort(abs(ref), 'descend');
    keep = order(1:min(3, numel(order)));
    targetFrequencies = freq(keep);
end

ods = struct();
ods.frequency = targetFrequencies(:)';
ods.complexShape = zeros(size(displacement, 1), numel(targetFrequencies));
ods.realShape = zeros(size(displacement, 1), numel(targetFrequencies));
ods.frequencyAxis = freq;
ods.referenceIndex = referenceIndex;

for k = 1:numel(targetFrequencies)
    [~, idx] = min(abs(freq - targetFrequencies(k)));
    crossPower = F(:, idx) .* conj(ref(idx));
    ods.complexShape(:, k) = crossPower / autoRef(idx);
    ods.realShape(:, k) = real(ods.complexShape(:, k));
end
end
