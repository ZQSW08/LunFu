function result = detect_crossline_center(frame, searchRoi, options)
%DETECT_CROSSLINE_CENTER 由复 Gabor 相位零交叉拟合十字标志交点。
% 每帧独立检测两条相位零交叉直线，因此不会把逐帧相位差误差累计成漂移。
defaults = rmptf.default_config();
if nargin < 3, options = struct(); end
options = rmptf.merge_config(defaults.phaseCrossline,options);
gray = localGray(frame);
[roi,crop] = localCrop(gray,searchRoi);
[h,w] = size(crop);

lambda = max(4,double(options.wavelength));
sigma = max(2,double(options.sigma));
radius = max(3,ceil(3*sigma));
[x,y] = meshgrid(-radius:radius,-radius:radius);
envelope = exp(-(x.^2+y.^2)/(2*sigma^2));
kernelVertical = envelope.*exp(1i*2*pi*x/lambda);
kernelHorizontal = envelope.*exp(1i*2*pi*y/lambda);
kernelVertical = kernelVertical-mean(kernelVertical(:));
kernelHorizontal = kernelHorizontal-mean(kernelHorizontal(:));
responseV = conv2(crop,kernelVertical,'same');
responseH = conv2(crop,kernelHorizontal,'same');

[xCandidates,yCandidates,wVertical] = localVerticalCandidates(responseV,options);
[x2Candidates,y2Candidates,wHorizontal] = localHorizontalCandidates(responseH,options);
[vertical,verticalOk] = localRobustLine(yCandidates,xCandidates,wVertical, ...
    options.minimumLinePoints); % x = a*y+b
[horizontal,horizontalOk] = localRobustLine(x2Candidates,y2Candidates,wHorizontal, ...
    options.minimumLinePoints); % y = a*x+b

verticalCoverage=vertical.inlierCount/max(h,1);
horizontalCoverage=horizontal.inlierCount/max(w,1);
% 真十字线应跨越搜索窗的大部分行/列；随机纹理即便偶然拟合出短线也不得通过。
valid = verticalOk && horizontalOk && verticalCoverage>=0.35 && ...
    horizontalCoverage>=0.35 && vertical.rmse<=2.5 && horizontal.rmse<=2.5;
centerLocal = [NaN NaN]; determinant = 0;
if valid
    matrix = [1 -vertical.slope; -horizontal.slope 1];
    determinant = abs(det(matrix));
    if determinant > 0.08
        centerLocal = (matrix\[vertical.intercept;horizontal.intercept])';
        valid = all(isfinite(centerLocal)) && centerLocal(1)>=1 && centerLocal(1)<=w && ...
            centerLocal(2)>=1 && centerLocal(2)<=h;
    else
        valid = false;
    end
end

if valid
    centerXY = centerLocal + roi(1:2)-1;
else
    centerXY = [NaN NaN];
end
pointScore = min(1,max(0,(min(verticalCoverage,horizontalCoverage)-0.25)/0.65));
fitScore = exp(-0.5*(vertical.rmse+horizontal.rmse));
quality = double(valid)*min(1,max(0,0.45*pointScore+0.35*fitScore+0.20*min(1,determinant)));
result = struct('valid',valid,'centerXY',centerXY,'quality',quality, ...
    'searchRoi',roi,'verticalLine',vertical,'horizontalLine',horizontal, ...
    'verticalCandidateCount',numel(xCandidates), ...
    'horizontalCandidateCount',numel(y2Candidates), ...
    'verticalCoverage',verticalCoverage,'horizontalCoverage',horizontalCoverage, ...
    'phaseMethod','complex_gabor_zero_crossing');
end

function gray = localGray(frame)
if ndims(frame)==3, frame=rgb2gray(frame); end
gray=im2double(frame);
gray=gray-mean(gray(:));
scale=std(gray(:)); if scale>eps, gray=gray/scale; end
end

function [roi,crop] = localCrop(frame,roi)
roi=round(double(roi));
roi(3)=min(max(8,roi(3)),size(frame,2)); roi(4)=min(max(8,roi(4)),size(frame,1));
roi(1)=min(max(1,roi(1)),size(frame,2)-roi(3)+1);
roi(2)=min(max(1,roi(2)),size(frame,1)-roi(4)+1);
crop=frame(roi(2):roi(2)+roi(4)-1,roi(1):roi(1)+roi(3)-1);
end

function [xc,yc,wc] = localVerticalCandidates(response,options)
phase=angle(response); amplitude=abs(response); threshold=prctile(amplitude(:),options.amplitudePercentile);
xc=[]; yc=[]; wc=[];
for row=1:size(response,1)
    s=sin(phase(row,:)); c=cos(phase(row,:)); a=amplitude(row,:);
    indices=find(s(1:end-1).*s(2:end)<=0 & c(1:end-1)>0 & c(2:end)>0 & ...
        min(a(1:end-1),a(2:end))>=threshold);
    if isempty(indices), continue; end
    scores=min(a(indices),a(indices+1)); [best,b]=max(scores); col=indices(b);
    fraction=abs(s(col))/(abs(s(col))+abs(s(col+1))+eps);
    xc(end+1,1)=col+fraction; yc(end+1,1)=row; wc(end+1,1)=best; %#ok<AGROW>
end
end

function [xc,yc,wc] = localHorizontalCandidates(response,options)
phase=angle(response); amplitude=abs(response); threshold=prctile(amplitude(:),options.amplitudePercentile);
xc=[]; yc=[]; wc=[];
for col=1:size(response,2)
    s=sin(phase(:,col)); c=cos(phase(:,col)); a=amplitude(:,col);
    indices=find(s(1:end-1).*s(2:end)<=0 & c(1:end-1)>0 & c(2:end)>0 & ...
        min(a(1:end-1),a(2:end))>=threshold);
    if isempty(indices), continue; end
    scores=min(a(indices),a(indices+1)); [best,b]=max(scores); row=indices(b);
    fraction=abs(s(row))/(abs(s(row))+abs(s(row+1))+eps);
    xc(end+1,1)=col; yc(end+1,1)=row+fraction; wc(end+1,1)=best; %#ok<AGROW>
end
end

function [line,ok] = localRobustLine(independent,dependent,weights,minimumPoints)
line=struct('slope',0,'intercept',0,'rmse',Inf,'inlierCount',0,'inlierMask',false(size(independent)));
ok=numel(independent)>=minimumPoints;
if ~ok, return; end
weights=max(double(weights(:)),eps); independent=double(independent(:)); dependent=double(dependent(:));
inliers=true(size(independent));
for iteration=1:3
    design=[independent(inliers) ones(nnz(inliers),1)]; wi=weights(inliers);
    coefficients=(design.*sqrt(wi))\(dependent(inliers).*sqrt(wi));
    residual=dependent-(coefficients(1)*independent+coefficients(2));
    center=median(residual(inliers)); spread=1.4826*median(abs(residual(inliers)-center));
    inliers=abs(residual-center)<=max(1.25,3*spread);
    if nnz(inliers)<minimumPoints, ok=false; return; end
end
design=[independent(inliers) ones(nnz(inliers),1)]; wi=weights(inliers);
coefficients=(design.*sqrt(wi))\(dependent(inliers).*sqrt(wi));
residual=dependent(inliers)-(coefficients(1)*independent(inliers)+coefficients(2));
line=struct('slope',coefficients(1),'intercept',coefficients(2), ...
    'rmse',sqrt(mean(residual.^2)),'inlierCount',nnz(inliers),'inlierMask',inliers);
end
