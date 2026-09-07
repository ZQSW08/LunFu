function result = global_poc_search(templateGray, searchGray, previousCenter)
% GLOBAL_POC_SEARCH 用 phase-only correlation 给出全图粗定位。
% POC 只承担几十/几百像素的粗捕获，不承担最终亚像素测量。

templateGray = to_gray_poc(templateGray);
searchGray = to_gray_poc(searchGray);
[ht, wt] = size(templateGray);
[hs, ws] = size(searchGray);
if ht > hs || wt > ws
    result = struct('center', previousCenter, 'topLeft', [1 1], ...
        'peakScore', 0, 'peakRatio', 1, 'valid', false);
    return;
end

% 汉宁窗降低模板边界突变；使用本地构造避免额外工具箱依赖。
wx = 0.5 - 0.5*cos(2*pi*(0:wt-1)/max(wt-1,1));
wy = 0.5 - 0.5*cos(2*pi*(0:ht-1)'/max(ht-1,1));
window = wy * wx;
templateGray = (templateGray - mean(templateGray(:))) .* window;
searchGray = searchGray - mean(searchGray(:));

Fsearch = fft2(searchGray, hs, ws);
Ftemplate = fft2(templateGray, hs, ws);
crossPower = Fsearch .* conj(Ftemplate);
correlation = real(ifft2(crossPower ./ max(abs(crossPower), eps)));
% 显式固定为二维 [hs, ws]，避免单通道三维数组触发逻辑索引的模糊维度错误。
if numel(correlation) ~= hs*ws
    error('POC 相关结果尺寸异常：correlation=%s，期望=[%d %d]。', ...
        mat2str(size(correlation)),hs,ws);
end
correlation = reshape(correlation, hs, ws);

% 只接受能够完整容纳模板的位置，排除环绕相关的伪峰。
% 用行列切片屏蔽无效区域，不再使用逻辑数组索引，彻底规避 MATLAB 的模糊维度问题。
firstInvalidRow=hs-ht+2;
firstInvalidCol=ws-wt+2;
if firstInvalidRow<=hs, correlation(firstInvalidRow:hs,:)= -Inf; end
if firstInvalidCol<=ws, correlation(:,firstInvalidCol:ws)= -Inf; end
[peakScore, linearIndex] = max(correlation(:));
[peakY, peakX] = ind2sub([hs, ws], linearIndex);
topLeft = [peakX, peakY];

exclusion = true(size(correlation));
yrange = max(1,peakY-3):min(hs,peakY+3);
xrange = max(1,peakX-3):min(ws,peakX+3);
exclusion(yrange, xrange) = false;
secondScore = max(correlation(exclusion));
if ~isfinite(secondScore), secondScore = 0; end
peakRatio = (peakScore - secondScore) / max(abs(secondScore), eps);

result = struct();
result.center = topLeft + [(wt-1)/2, (ht-1)/2];
result.topLeft = topLeft;
result.peakScore = peakScore;
result.peakRatio = peakRatio;
result.valid = isfinite(peakScore) && all(result.center >= 1);
end

function gray=to_gray_poc(frame)
% POC 入口统一压成二维灰度，避免彩色视频或单通道三维数组造成掩膜尺寸不一致。
frame=double(frame);
if ndims(frame)>=3
    if size(frame,3)>=3
        gray=0.298936*frame(:,:,1)+0.587043*frame(:,:,2)+0.114021*frame(:,:,3);
    else
        gray=squeeze(frame(:,:,1));
    end
else
    gray=frame;
end
gray=squeeze(gray);
end
