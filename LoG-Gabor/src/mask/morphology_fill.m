function filled = morphology_fill(edgeMask)
%MORPHOLOGY_FILL 执行论文 Eq. (12)-(14) 所述闭环内部填充。
% MATLAB Image Processing Toolbox 可用时优先调用 imfill；否则采用同义的
% 8 邻域边界泛洪，避免依赖隐藏的工具箱状态。
edgeMask = logical(edgeMask);
try
    filled = imfill(edgeMask, 'holes');
catch
    outside = flood_fill(~edgeMask);
    filled = ~outside;
end
end

function outside = flood_fill(open)
[h,w] = size(open);
outside = false(h,w);
queue = zeros(h*w,2); head = 1; tail = 0;
for c = 1:w
    if open(1,c), tail=tail+1; queue(tail,:)=[1,c]; end
    if h>1 && open(h,c), tail=tail+1; queue(tail,:)=[h,c]; end
end
for r = 2:h-1
    if open(r,1), tail=tail+1; queue(tail,:)=[r,1]; end
    if w>1 && open(r,w), tail=tail+1; queue(tail,:)=[r,w]; end
end
while head <= tail
    r=queue(head,1); c=queue(head,2); head=head+1;
    if outside(r,c), continue; end
    outside(r,c)=true;
    for dr=-1:1
        for dc=-1:1
            rr=r+dr; cc=c+dc;
            if rr>=1 && rr<=h && cc>=1 && cc<=w && open(rr,cc) && ~outside(rr,cc)
                tail=tail+1; queue(tail,:)=[rr,cc];
            end
        end
    end
end
end
