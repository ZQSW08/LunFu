function fig = plot_process_result(I,result,figTitle)
%PLOT_PROCESS_RESULT 绘制论文 Fig.2 风格的单帧处理证据图。
if nargin<3, figTitle='Crossline phase zero-crossing'; end
fig=figure('Name',figTitle,'NumberTitle','off','Color','w','Visible','on'); set(fig,'Position',[80 80 1100 760]);
tiledlayout(fig,2,3,'Padding','compact','TileSpacing','compact');
nexttile; imshow(I,[]); title('Input ROI'); hold on;
if result.valid, plot(result.center(1),result.center(2),'r+','MarkerSize',12,'LineWidth',1.5); plot(result.geometry.roughCenter(1),result.geometry.roughCenter(2),'bo','MarkerSize',8); end
nexttile; imshow(result.BW,[]); title('Segmentation');
nexttile; imshow(I,[]); title('Coarse geometry'); hold on;
if result.geometry.valid
    draw_line(result.geometry.lines(1),size(I)); draw_line(result.geometry.lines(2),size(I)); plot(result.geometry.roughCenter(1),result.geometry.roughCenter(2),'r+','LineWidth',1.5);
end
for k=1:2
    nexttile; imagesc(result.phaseMaps{k}); axis image off; colormap gray; colorbar; title(sprintf('Phase %d',k)); hold on;
    if result.valid, draw_line(result.zeroLines{k},size(I),'r'); end
end
nexttile; imshow(I,[]); title('Precise center'); hold on;
if result.valid, draw_line(result.zeroLines{1},size(I),'r'); draw_line(result.zeroLines{2},size(I),'g'); plot(result.center(1),result.center(2),'b+','MarkerSize',14,'LineWidth',2); end
sgtitle(fig,figTitle,'FontWeight','bold');
end
function draw_line(line,sz,color)
if nargin<3, color='y'; end
if ~isfinite(line.a), return; end
if abs(line.b)>abs(line.a), xx=[1 sz(2)]; yy=-(line.a*xx+line.c)/line.b; else, yy=[1 sz(1)]; xx=-(line.b*yy+line.c)/line.a; end
plot(xx,yy,'Color',color,'LineWidth',1.2);
end
