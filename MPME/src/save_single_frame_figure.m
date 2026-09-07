function save_single_frame_figure(frame, outputPath, titleText, points, hubCenter)
%SAVE_SINGLE_FRAME_FIGURE 每个输入/测点预览单独保存为一张无冗余面板的图片。
if nargin < 4, points = []; end
if nargin < 5, hubCenter = []; end
fig = figure('Visible','off','Color','w','Position',[50 50 620 520]);
imshow(frame,[]); hold on;
if ~isempty(hubCenter)
    plot(hubCenter(1)+1,hubCenter(2)+1,'+','Color',[0.93 0.69 0.13], ...
        'MarkerSize',13,'LineWidth',2);
end
for k = 1:size(points,1)
    plot(points(k,1)+1,points(k,2)+1,'o','Color',[0 0.45 0.70], ...
        'MarkerSize',8,'LineWidth',1.5);
    text(points(k,1)+6,points(k,2)+1,sprintf('P%d',k), ...
        'Color',[1 0.85 0.1],'FontWeight','bold');
end
title(titleText,'FontWeight','normal'); axis image off;
exportgraphics(fig,outputPath,'Resolution',240);
close(fig);
end
