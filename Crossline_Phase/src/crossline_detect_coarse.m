function [geometry, BW, diagnostics] = crossline_detect_coarse(I, coarseCfg)
%CROSSLINE_DETECT_COARSE 粗分割、形态学处理和两条线的几何估计。
% 论文明确处理顺序；阈值、结构元素、Hough 与宽度统计属于复现推断。
if nargin < 2, coarseCfg = struct(); end
defaults = struct('adaptiveSensitivity',0.52,'minArea',8,'closeRadius',1, ...
    'houghPeakFraction',0.25,'houghPeakCount',20,'lineDistanceTolerance',2.5, ...
    'brightMarkerThreshold',[]);
names = fieldnames(defaults);
for k = 1:numel(names)
    if ~isfield(coarseCfg,names{k}), coarseCfg.(names{k}) = defaults.(names{k}); end
end
if ndims(I) == 3, Igray = rgb2gray(I); else, Igray = I; end
Igray = im2double(Igray);
if ~isempty(coarseCfg.brightMarkerThreshold)
    % 仅在用户明确指定时启用：适用于白色 crossline 位于暗色实体物体表面。
    BW = Igray >= coarseCfg.brightMarkerThreshold;
elseif exist('imbinarize','file') == 2
    try
        BW = imbinarize(Igray,'adaptive','Sensitivity',coarseCfg.adaptiveSensitivity, ...
            'ForegroundPolarity','bright');
    catch
        BW = Igray > graythresh(Igray);
    end
else
    BW = Igray > graythresh(Igray);
end
if exist('bwareaopen','file') == 2
    BW = bwareaopen(BW,coarseCfg.minArea);
    if coarseCfg.closeRadius > 0
        BW = imclose(BW,strel('disk',coarseCfg.closeRadius,0));
    end
    BW = imfill(BW,'holes');
end
geometry = struct('valid',false,'roughCenter',[NaN NaN], ...
    'lineAnglesDeg',[NaN NaN],'lineWidthsPx',[NaN NaN], ...
    'lineLengthsPx',[NaN NaN],'lines',[],'area',nnz(BW));
diagnostics = struct('thresholdImage',Igray,'houghPeaks',[],'message','');
if nnz(BW) < coarseCfg.minArea
    diagnostics.message = '分割后没有足够的前景像素；请检查 ROI 内是否存在高对比度 crossline 标记。'; return;
end
[H,theta,rho] = hough(BW);
threshold = max(1,coarseCfg.houghPeakFraction*max(H(:)));
try
    peaks = houghpeaks(H,coarseCfg.houghPeakCount,'Threshold',threshold,'NHoodSize',[15 15]);
catch
    [~,idx] = sort(H(:),'descend');
    count = min(coarseCfg.houghPeakCount,numel(idx));
    [rr,cc] = ind2sub(size(H),idx(1:count)); peaks = [rr cc];
end
diagnostics.houghPeaks = peaks;
if size(peaks,1) < 2
    diagnostics.message = 'Hough 未找到两条独立直线。'; return;
end
% 选择方向差最接近 90 度的一对峰，避免同一厚线产生的重复峰。
best = []; bestScore = Inf;
for i = 1:size(peaks,1)-1
    for j = i+1:size(peaks,1)
        d = abs(theta(peaks(i,2))-theta(peaks(j,2))); d = min(d,180-d);
        score = abs(d-90)-1e-4*(H(peaks(i,1),peaks(i,2))+H(peaks(j,1),peaks(j,2)));
        if d > 45 && d < 135 && score < bestScore, bestScore = score; best = [i j]; end
    end
end
if isempty(best), best = [1 2]; end
[rows,cols] = find(BW); xy = [cols rows];
lines = repmat(struct('a',NaN,'b',NaN,'c',NaN,'points',[],'support',0,'residual',Inf),1,2);
angles = zeros(1,2); lengths = zeros(1,2);
for k = 1:2
    peak = peaks(best(k),:); a0 = cosd(theta(peak(2))); b0 = sind(theta(peak(2))); rho0 = rho(peak(1));
    dist = abs(a0*cols+b0*rows-rho0); selected = xy(dist <= coarseCfg.lineDistanceTolerance,:);
    if size(selected,1) < 2, selected = xy; end
    lines(k) = fit_line_tls(selected);
    angles(k) = mod(atan2d(-lines(k).a,lines(k).b),180);
    projection = selected*[cosd(angles(k));sind(angles(k))];
    lengths(k) = max(projection)-min(projection)+1;
end
[roughCenter,ok] = intersect_phase_lines(lines(1),lines(2));
if ~ok, diagnostics.message = '两条粗拟合直线近似平行。'; return; end
roughCenter(1) = min(max(roughCenter(1),1),size(BW,2));
roughCenter(2) = min(max(roughCenter(2),1),size(BW,1));
estimatedWidth = nnz(BW)/max(sum(lengths),eps);
estimatedWidth = min(max(estimatedWidth,0.5),max(size(BW)));
geometry.valid = true; geometry.roughCenter = roughCenter; geometry.lineAnglesDeg = angles;
geometry.lineWidthsPx = [estimatedWidth estimatedWidth]; geometry.lineLengthsPx = lengths;
geometry.lines = lines;
end
