function [macro, diagnostics] = estimate_macro_motion(rawDisplacement, valid, fps, options)
%ESTIMATE_MACRO_MOTION 将原始跟踪轨迹变成“只用于裁剪”的补偿轨迹。
% rawDisplacement 保留完整目标运动；macro 不得直接作为微振动测量结果。
defaults=rmptf.default_config();
if nargin<4, options=struct(); end
options=rmptf.merge_config(defaults.compensation,options);
raw=double(rawDisplacement);
if size(raw,2)~=2, error('rawDisplacement 必须为 N x 2。'); end
if nargin<2 || isempty(valid), valid=all(isfinite(raw),2); end
valid=logical(valid(:)) & all(isfinite(raw),2);
repaired=raw;
filled=raw;
for axis=1:2
    column=repaired(:,axis); column(~valid)=NaN;
    if all(isnan(column)), column=zeros(size(column));
    else, column=fillmissing(column,'linear','EndValues','nearest'); end
    filled(:,axis)=column;
    outlierWindow=max(3,round(options.outlierWindowSeconds*fps));
    if mod(outlierWindow,2)==0, outlierWindow=outlierWindow+1; end
    medianTrack=movmedian(column,outlierWindow,'omitnan');
    residual=column-medianTrack; limit=max(2.5,4*1.4826*median(abs(residual-median(residual)),'omitnan'));
    outliers=abs(residual)>limit; column(outliers)=medianTrack(outliers);
    repaired(:,axis)=column;
end

mode=lower(strtrim(char(options.mode)));
cutoff=options.cutoffHz;
switch mode
    case {'full','raw'}
        % 完整跟随轨迹。该分量只用于整数裁剪，不应直接当作微振动结果。
        macro=filled;
    case 'integer_macro'
        % 关键语义：整数宏观模式不能再套用 1 Hz 低通。
        % RMPTF 的 bbox/phase-safe-crop 最终以整数像素执行，原始跟踪轨迹
        % 已经是半像素/整数量化；继续低通会让较快的大运动泄漏到测量残差。
        % 保留原始（已修复缺失/离群点）轨迹，让裁剪层跟随任意频率的宏观移动。
        macro=filled;
    case 'robust_macro'
        % 用短窗中值而不是固定 1 Hz 低通：对大幅轨迹可快速跟随，
        % 同时把远小于宏观幅值的亚像素抖动作为离群项抑制。
        window=max(3,round(options.robustWindowFrames));
        if mod(window,2)==0, window=window+1; end
        window=min(window,max(3,2*floor((size(filled,1)-1)/2)+1));
        macro=movmedian(filled,window,1,'omitnan');
        if window>=5, macro=smoothdata(macro,'movmean',3); end
    case 'adaptive_macro'
        % 先保留传统趋势；若原始轨迹相对趋势的偏差已经达到数像素，
        % 视为快速大运动并直接补入宏观轨迹。这样不必把截止频率盲目
        % 提高到微振动频带内，也不会让快大运动泄漏到相位残差。
        trend=localZeroPhaseSmooth(repaired,fps,cutoff,options.windowSeconds);
        macro=trend;
        threshold=max(2.0,options.fastMotionThresholdPx);
        fastLarge=abs(filled-trend)>threshold;
        macro(fastLarge)=filled(fastLarge);
        macro=smoothdata(macro,'movmedian',3);
    case 'trend'
        macro=localZeroPhaseSmooth(repaired,fps,cutoff,options.windowSeconds);
    case 'band_protected'
        if isempty(options.targetBandHz) || numel(options.targetBandHz)~=2
            error('band_protected 模式必须提供 targetBandHz=[fL fH]。');
        end
        protectedCutoff=options.bandGuardFraction*min(options.targetBandHz);
        if isempty(cutoff) || ~isfinite(cutoff), cutoff=protectedCutoff;
        else, cutoff=min(cutoff,protectedCutoff); end
        macro=localZeroPhaseSmooth(repaired,fps,cutoff,options.windowSeconds);
    case 'geometry_follow'
        geometry=double(options.geometryDisplacement);
        if isempty(geometry) || size(geometry,1)~=size(raw,1) || size(geometry,2)~=2
            error('geometry_follow 模式必须提供与 rawDisplacement 同尺寸的 geometryDisplacement。');
        end
        geometry(~isfinite(geometry))=NaN;
        for axis=1:2
            geometry(:,axis)=fillmissing(geometry(:,axis),'linear','EndValues','nearest');
        end
        % 几何跟随使用多点/RANSAC 公共刚体分量，不对时间频率作低通，因而可在
        % 宏观运动与微振动同频时仍保留局部残差。
        macro=geometry;
    otherwise
        error('未知补偿模式：%s。',mode);
end

axisToken=lower(strtrim(char(options.trackingAxis)));
if strcmp(axisToken,'x')
    macro(:,2)=0;
elseif strcmp(axisToken,'y')
    macro(:,1)=0;
elseif ~strcmp(axisToken,'xy')
    error('trackingAxis 必须为 x、y 或 xy。');
end
macro=macro-macro(1,:);
diagnostics=struct('mode',mode,'cutoffHz',cutoff,'validFraction',mean(valid), ...
    'repairedTrajectory',repaired,'rawResidual',raw-macro);
end

function output=localZeroPhaseSmooth(input,fps,cutoff,windowSeconds)
if isempty(cutoff) || ~isfinite(cutoff) || cutoff<=0
    window=max(3,round(windowSeconds*fps));
else
    % 对称移动平均的近似 -3 dB 截止为 0.443*fps/window。
    window=max(3,round(0.443*fps/cutoff));
end
window=min(window,max(3,2*floor((size(input,1)-1)/2)+1));
if mod(window,2)==0, window=window+1; end
if window>size(input,1), window=size(input,1)-mod(size(input,1)+1,2); end
output=zeros(size(input));
for axis=1:2
    % 局部二次多项式在短序列端点比双向 IIR 稳定，并避免 movmedian 的
    % 非线性阶梯谐波；窗口过小时退回对称移动平均。
    if window>=5
        output(:,axis)=smoothdata(input(:,axis),'sgolay',window,'Degree',2);
    else
        output(:,axis)=movmean(input(:,axis),window,'omitnan');
    end
end
end
