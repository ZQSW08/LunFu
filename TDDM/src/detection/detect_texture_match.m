function detection=detect_texture_match(reference,current,referenceCenter,searchCenter,localROI,origin,cfg)
%DETECT_TEXTURE_MATCH 非圆形目标的局部模板检测模式。
% 论文的 Detection 针对圆/椭圆标记；无圆形标记时用局部纹理 NCC 替代几何约束。
half=floor(cfg.paper.templateSize/2);
radius=max(3,round(get_field(cfg.impl,'textureSearchRadiusPx',12)));
[center,score,ok]=template_match_from_reference(reference,current,referenceCenter,searchCenter,half,radius);
if ~ok, detection=[]; return; end
detection=struct('center',center,'score',score,'diameter',NaN,'eccentricity',NaN, ...
    'polarity',NaN,'area',NaN,'boundingBox',[origin max(1,origin(2)) size(localROI,2) size(localROI,1)], ...
    'enhanced',localROI,'edgeMask',edge(im2uint8(localROI),'Canny'),'binaryMask',[],'mode','texture');
end
function [center,score,ok]=template_match_from_reference(reference,current,referenceCenter,searchCenter,half,radius)
[T,validT]=extract_patch(reference,referenceCenter,half,'linear');
center=searchCenter; score=-Inf; ok=false;
if ~all(validT(:)) || any(~isfinite(T(:))), return; end

% 用一次局部 normxcorr2 替代逐候选 patch 循环，保持 NCC 定义不变，
% 但将非圆形目标的局部搜索从 O((2r+1)^2) 次 MATLAB 调用降为一次卷积。
if exist('normxcorr2','file') == 2
    [hT,wT]=size(T);
    x1=max(1,floor(searchCenter(1)-radius-half));
    y1=max(1,floor(searchCenter(2)-radius-half));
    x2=min(size(current,2),ceil(searchCenter(1)+radius+half));
    y2=min(size(current,1),ceil(searchCenter(2)+radius+half));
    area=current(y1:y2,x1:x2);
    if size(area,1)>=hT && size(area,2)>=wT
        corrMap=normxcorr2(T,area);
        validRows=hT:(size(area,1)); validCols=wT:(size(area,2));
        corrMap=corrMap(validRows,validCols);
        [cc,rr]=meshgrid(1:size(corrMap,2),1:size(corrMap,1));
        cx=x1+cc-1+half; cy=y1+rr-1+half;
        allowed=abs(cx-searchCenter(1))<=radius & abs(cy-searchCenter(2))<=radius;
        corrMap(~allowed | ~isfinite(corrMap))=-Inf;
        [score,linearIndex]=max(corrMap(:));
        if isfinite(score)
            [row,col]=ind2sub(size(corrMap),linearIndex);
            center=[cx(row,col) cy(row,col)]; ok=true; return;
        end
    end
end

% 没有 Image Processing Toolbox 时保留同一 NCC 定义的兼容回退。
for dy=-radius:radius
    for dx=-radius:radius
        candidate=searchCenter+[dx dy]; [C,validC]=extract_patch(current,candidate,half,'linear');
        if all(validC(:)) && all(isfinite(C(:)))
            s=ncc_patch(T,C); if s>score, score=s; center=candidate; end
        end
    end
end
ok=isfinite(score);
end
function value=get_field(s,name,default)
if isfield(s,name) && ~isempty(s.(name)), value=s.(name); else, value=default; end
end
