function result = build_task_map(height, width, activeMask)
%BUILD_TASK_MAP 按论文 3×3 down-sampling 将中心任务映射到九像素组。
rows = 2:3:height-1; cols = 2:3:width-1;
[cc,rr] = meshgrid(cols,rows); centers=[rr(:),cc(:)];
taskMap=zeros(height,width); taskPixels=zeros(size(centers));
for i=1:size(centers,1)
    r=centers(i,1); c=centers(i,2); taskPixels(i,:)=[r,c];
    taskMap(max(1,r-1):min(height,r+1),max(1,c-1):min(width,c+1))=i;
end
activeTasks=unique(taskMap(activeMask)); activeTasks=activeTasks(activeTasks>0);
result.taskMap=taskMap; result.taskPixels=taskPixels; result.activeTasks=activeTasks;
result.activeTaskPixels=taskPixels(activeTasks,:);
end
