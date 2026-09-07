function [macroDisplacement,microCandidate,diagnostics] = estimate_macro_motion( ...
    rawDisplacement,fps,options)
%ESTIMATE_MACRO_MOTION 估计用于动态 ROI 的大运动趋势。
%
% 该函数是 VP-DROI（振动保持型动态 ROI）的公共前端：
%   raw = 大运动 + 微振动 + 跟踪误差
%   macro = raw 的低频趋势
%   microCandidate = raw - macro，仅作为诊断/共识信号
%
% 重要：trend 模式只让裁剪窗口跟随 macro，不直接跟随 raw，避免把微振动
% 一并稳定掉。full/fixed 模式用于消融对照，不应默认替代 trend。

if nargin < 2 || isempty(fps), fps = 1; end
if nargin < 3 || isempty(options), options = struct(); end
if size(rawDisplacement,2)~=2
    error('rawDisplacement 必须是 N×2 的有符号位移序列。');
end
rawDisplacement = double(rawDisplacement);
frameCount = size(rawDisplacement,1);
if frameCount==0
    macroDisplacement = rawDisplacement;
    microCandidate = rawDisplacement;
    diagnostics = struct('mode','trend','cutoffHz',NaN, ...
        'cleanedDisplacement',rawDisplacement,'outlierWindow',0);
    return;
end

mode = localText(localOption(options,'mode','trend'));
outlierWindowSeconds = localOption(options,'trajectoryOutlierWindowSeconds',0.15);
window = max(5,2*floor(outlierWindowSeconds*fps/2)+1);
if mod(window,2)==0, window = window+1; end

% 先消除孤立跟踪跳点；保留有符号坐标，绝不使用 abs(raw-raw(1))。
cleaned = rawDisplacement;
for axisIndex = 1:2
    signal = cleaned(:,axisIndex);
    if any(~isfinite(signal))
        signal = fillmissing(signal,'linear','EndValues','nearest');
    end
    if frameCount>=5
        signal = filloutliers(signal,'linear','movmedian',window, ...
            'ThresholdFactor',4);
    end
    cleaned(:,axisIndex) = signal;
end

if isfield(options,'macroTrendCutoffHz') && ...
        ~isempty(options.macroTrendCutoffHz)
    requestedCutoff = options.macroTrendCutoffHz;
elseif isfield(options,'macroTrendWindowSeconds') && ...
        ~isempty(options.macroTrendWindowSeconds)
    trendWindowSeconds = localOption(options,'macroTrendWindowSeconds',0.5);
    requestedCutoff = 1/max(2*trendWindowSeconds,eps);
else
    requestedCutoff = localOption(options,'largeMotionCutoffHz',1);
end
cutoffHz = min(double(requestedCutoff),0.45*fps);

switch mode
    case {'fixed','none'}
        macroDisplacement = zeros(frameCount,2);
        cutoffHz = 0;
    case {'full','full-follow','full_follow'}
        macroDisplacement = cleaned-cleaned(1,:);
    case {'trend','trend-follow','trend_follow','lowpass'}
        if cutoffHz>0 && cutoffHz<fps/2 && frameCount>18
            [filterB,filterA] = butter(3,cutoffHz/(fps/2),'low');
            macroDisplacement = zeros(size(cleaned));
            for axisIndex = 1:2
                macroDisplacement(:,axisIndex) = filtfilt( ...
                    filterB,filterA,cleaned(:,axisIndex));
            end
        elseif frameCount>=5
            macroDisplacement = smoothdata(cleaned,1,'sgolay', ...
                min(frameCount,window));
        else
            macroDisplacement = cleaned;
        end
    otherwise
        error('未知 dynamicRoi.mode: %s。可选 fixed、trend、full。',mode);
end

macroDisplacement = macroDisplacement-macroDisplacement(1,:);
trackingAxis = lower(localText(localOption(options,'trackingAxis','xy')));
switch trackingAxis
    case 'x'
        macroDisplacement(:,2) = 0;
    case 'y'
        macroDisplacement(:,1) = 0;
end
microCandidate = rawDisplacement-macroDisplacement;
diagnostics = struct('mode',mode,'cutoffHz',cutoffHz, ...
    'cleanedDisplacement',cleaned,'outlierWindow',window, ...
    'trackingAxis',trackingAxis);
end

function value = localOption(options,name,defaultValue)
if isfield(options,name) && ~isempty(options.(name))
    value = options.(name);
else
    value = defaultValue;
end
end

function value = localText(value)
if isstring(value), value = char(value); end
if isempty(value), value = ''; end
value = lower(strtrim(char(value)));
end
