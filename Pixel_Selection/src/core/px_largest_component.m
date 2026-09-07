function output = px_largest_component(mask)
% 用八邻域广度优先搜索保留面积最大的连通域，不依赖图像处理工具箱。
mask = logical(mask);
[height, width] = size(mask);
visited = false(height, width);
output = false(height, width);
bestSize = 0;
neighborOffsets = [-1 -1; -1 0; -1 1; 0 -1; 0 1; 1 -1; 1 0; 1 1];

for row = 1:height
    for col = 1:width
        if ~mask(row, col) || visited(row, col)
            continue;
        end
        queue = zeros(height * width, 2);
        head = 1;
        tail = 1;
        queue(tail, :) = [row, col];
        visited(row, col) = true;
        component = zeros(height * width, 2);
        componentSize = 0;
        while head <= tail
            point = queue(head, :);
            head = head + 1;
            componentSize = componentSize + 1;
            component(componentSize, :) = point;
            for neighbor = 1:size(neighborOffsets, 1)
                nextRow = point(1) + neighborOffsets(neighbor, 1);
                nextCol = point(2) + neighborOffsets(neighbor, 2);
                if nextRow >= 1 && nextRow <= height && nextCol >= 1 && nextCol <= width && ...
                        mask(nextRow, nextCol) && ~visited(nextRow, nextCol)
                    tail = tail + 1;
                    queue(tail, :) = [nextRow, nextCol];
                    visited(nextRow, nextCol) = true;
                end
            end
        end
        if componentSize > bestSize
            output(:) = false;
            linear = sub2ind([height, width], component(1:componentSize, 1), component(1:componentSize, 2));
            output(linear) = true;
            bestSize = componentSize;
        end
    end
end
end
