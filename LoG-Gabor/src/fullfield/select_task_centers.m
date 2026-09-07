function selected=select_task_centers(activeTaskPixels,maxCount)
%SELECT_TASK_CENTERS Deterministically subsample active task centers.
if nargin<2 || isempty(maxCount), maxCount=size(activeTaskPixels,1); end
if isempty(activeTaskPixels)
    error('select_task_centers:Empty','No active task pixels were found.');
end
maxCount=max(1,round(maxCount));
if size(activeTaskPixels,1)<=maxCount
    selected=activeTaskPixels;
else
    selected=activeTaskPixels(round(linspace(1,size(activeTaskPixels,1),maxCount)),:);
end
end
