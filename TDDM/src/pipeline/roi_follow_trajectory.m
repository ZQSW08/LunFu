function rects=roi_follow_trajectory(trace,initialROI,imageSize)
%ROI_FOLLOW_TRAJECTORY 根据 TDDM 最终位置生成跟随 ROI。
rects=zeros(numel(trace),4); w=round(initialROI(3)); h=round(initialROI(4));
start=trace(1).pFinal; if any(~isfinite(start)), start=initialROI(1:2)+[w-1 h-1]/2; end
for i=1:numel(trace)
    c=trace(i).pFinal; if any(~isfinite(c)), c=trace(i).pTracking; end
    if any(~isfinite(c)), c=start; end
    x=round(c(1)-(w-1)/2); y=round(c(2)-(h-1)/2);
    x=max(1,min(x,imageSize(2)-w+1)); y=max(1,min(y,imageSize(1)-h+1));
    rects(i,:)=[x y w h];
end
end
