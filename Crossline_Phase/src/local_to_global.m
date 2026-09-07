function globalCenter = local_to_global(localCenter, roiPosition)
%LOCAL_TO_GLOBAL 将 ROI 内 1-based 坐标转换为整帧 1-based 坐标。
globalCenter = [roiPosition(1)-1+localCenter(1),roiPosition(2)-1+localCenter(2)];
end
