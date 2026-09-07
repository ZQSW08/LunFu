function detection = detect_marker(I, expectedDiameter, cfg, centerHint)
%DETECT_MARKER 局部圆/椭圆标记检测，对应论文 2.3.1。
% 返回结构体 center、eccentricity、diameter、polarity 和 score；center 为输入图坐标。
if nargin < 4 || isempty(centerHint)
    centerHint = [(size(I, 2) + 1) / 2, (size(I, 1) + 1) / 2];
end
if size(I, 3) == 3
    I = rgb2gray(I);
end
I = im2uint8(I);
if cfg.impl.detectorUseCLAHE
    enhanced = adapthisteq(I);
else
    enhanced = I;
end
% 论文检测流程中的边缘证据；同时保留二值候选供过程输出审计。
edgeMask = edge(enhanced, 'Canny');

% 同时尝试亮标记和暗标记，避免把标记极性写死。
level = graythresh(enhanced);
binaryList = {imbinarize(enhanced, level), ~imbinarize(enhanced, level)};
best = [];
for polarity = 1:2
    BW = bwareaopen(binaryList{polarity}, cfg.impl.detectorMinArea);
    BW = imclose(BW, strel('disk', 1));
    stats = regionprops(BW, 'Area', 'Centroid', 'MajorAxisLength', ...
        'MinorAxisLength', 'Eccentricity', 'BoundingBox');
    for k = 1:numel(stats)
        major = stats(k).MajorAxisLength;
        minor = stats(k).MinorAxisLength;
        if major <= 0 || minor <= 0
            continue;
        end
        diameter = sqrt(major * minor);
        ratio = diameter / max(expectedDiameter, eps);
        distance = norm(stats(k).Centroid - centerHint);
        % 局部 ROI 已由 Tracking 提供中心先验；放宽到 2.5 倍会让纹理块
        % 在代理图中抢占候选，因此这里采用更保守的 1.5 倍邻域。
        if distance > 1.5 * max(expectedDiameter, 1)
            continue;
        end
        if stats(k).Eccentricity > cfg.paper.eccentricityMax || ...
                ratio < cfg.impl.detectorDiameterRatio(1) || ...
                ratio > cfg.impl.detectorDiameterRatio(2)
            continue;
        end
        score = distance / max(expectedDiameter, 1) + abs(ratio - 1);
        candidate = stats(k);
        candidate.diameter = diameter;
        candidate.polarity = polarity;
        candidate.score = score;
        if isempty(best) || score < best.score
            best = candidate;
        end
    end
end
if isempty(best)
    % 复杂纹理会把标记与背景连成一个大区域；论文的局部检测仍有中心先验，
    % 因此用中心邻域的局部对比度质心作为椭圆拟合失败时的稳健回退。
    h = max(ceil(expectedDiameter), 3);
    x1=max(1,round(centerHint(1)-2*h)); x2=min(size(enhanced,2),round(centerHint(1)+2*h));
    y1=max(1,round(centerHint(2)-2*h)); y2=min(size(enhanced,1),round(centerHint(2)+2*h));
    local=double(enhanced(y1:y2,x1:x2)); [XX,YY]=meshgrid(x1:x2,y1:y2);
    high=max(local-median(local(:)),0); low=max(median(local(:))-local,0);
    % 先在局部区域内取高亮连通区域；这对合成标记及常见白色圆标记更接近椭圆中心。
    localThreshold = median(local(:)) + 0.35 * (max(local(:)) - median(local(:)));
    localBW = bwareaopen(local >= localThreshold, max(4, round(expectedDiameter^2/20)));
    localStats = regionprops(localBW, 'Area', 'Centroid');
    if ~isempty(localStats)
        localDistances = arrayfun(@(s) norm(s.Centroid - (centerHint - [x1-1 y1-1])), localStats);
        [~,bestLocal] = min(localDistances);
        xyLocal = localStats(bestLocal).Centroid;
        xy = xyLocal + [x1-1 y1-1];
        detection=struct('center',xy,'eccentricity',0,'diameter',expectedDiameter, ...
            'polarity',1,'score',localDistances(bestLocal)/max(expectedDiameter,1), ...
            'area',localStats(bestLocal).Area,'boundingBox',[x1 y1 x2-x1+1 y2-y1+1], ...
            'enhanced',enhanced,'edgeMask',edgeMask,'binaryMask',localBW);
        return;
    end
    if sum(high(:)) >= sum(low(:)) && sum(high(:)) > 1e-8
        w=high; pol=1;
    elseif sum(low(:)) > 1e-8
        w=low; pol=2;
    else
        detection=[]; return;
    end
    xy=[sum(XX(:).*w(:))/sum(w(:)), sum(YY(:).*w(:))/sum(w(:))];
    detection=struct('center',xy,'eccentricity',0,'diameter',expectedDiameter, ...
        'polarity',pol,'score',norm(xy-centerHint)/max(expectedDiameter,1), ...
        'area',sum(w(:)>0),'boundingBox',[x1 y1 x2-x1+1 y2-y1+1], ...
        'enhanced',enhanced,'edgeMask',edgeMask,'binaryMask',[]);
else
    detection = struct('center', best.Centroid, 'eccentricity', best.Eccentricity, ...
        'diameter', best.diameter, 'polarity', best.polarity, 'score', best.score, ...
        'area', best.Area, 'boundingBox', best.BoundingBox, ...
        'enhanced',enhanced,'edgeMask',edgeMask,'binaryMask',binaryList{best.polarity});
end
end
