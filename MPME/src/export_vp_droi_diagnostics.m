function export_vp_droi_diagnostics(outputDirectory,time,tracking,roiTrajectory, ...
    initialRoi,fps,metadata)
%EXPORT_VP_DROI_DIAGNOSTICS 导出振动保持型动态 ROI 的可审计结果。
%
% 输出内容控制在判断动态 ROI 是否真正“跟随大运动、保留微振动”所需的
% 最小集合：有符号跟踪/趋势/裁剪 CSV、两张合并诊断图、MAT 和 JSON 元数据。

if nargin < 8 || isempty(metadata), metadata = struct(); end
frameCount = numel(time);
time = double(time(:));
rawBox = localField(tracking,'bbox_xywh',repmat(initialRoi,frameCount,1));
rawBox = localResize(rawBox,frameCount,4,repmat(initialRoi,frameCount,1));
rawCenter = localField(tracking,'center_xy',rawBox(:,1:2)+0.5*rawBox(:,3:4));
rawCenter = localResize(rawCenter,frameCount,2,zeros(frameCount,2));
scale = localField(tracking,'scale',rawBox(:,3:4)./initialRoi(3:4));
scale = localResize(scale,frameCount,2,ones(frameCount,2));
confidence = localField(tracking,'confidence',localField(tracking,'quality',nan(frameCount,1)));
confidence = localResize(confidence,frameCount,1,nan(frameCount,1));
valid = logical(localResize(localField(tracking,'valid',true(frameCount,1)), ...
    frameCount,1,true(frameCount,1)));
lost = logical(localResize(localField(tracking,'lost',false(frameCount,1)), ...
    frameCount,1,false(frameCount,1)));
redetect = logical(localResize(localField(tracking,'redetect',false(frameCount,1)), ...
    frameCount,1,false(frameCount,1)));
boundary = logical(localResize(localField(tracking,'hitBoundary',false(frameCount,1)), ...
    frameCount,1,false(frameCount,1)));
macro = localResize(localField(tracking,'largeMotionContinuous',zeros(frameCount,2)), ...
    frameCount,2,zeros(frameCount,2));
expected = localResize(localField(tracking,'expectedCoarseDisplacement',macro), ...
    frameCount,2,macro);
crop = localResize(roiTrajectory,frameCount,4,repmat(initialRoi,frameCount,1));
cropValid = ~boundary;
if isfield(tracking,'crop') && isfield(tracking.crop,'valid')
    cropValid = logical(localResize(tracking.crop.valid,frameCount,1,cropValid));
end

trajectoryTable = table(time,rawCenter(:,1)-rawCenter(1,1), ...
    rawCenter(:,2)-rawCenter(1,2),rawBox(:,3),rawBox(:,4),scale(:,1),scale(:,2), ...
    confidence,valid,lost,redetect,boundary,macro(:,1),macro(:,2), ...
    expected(:,1),expected(:,2),crop(:,1),crop(:,2),crop(:,3),crop(:,4),cropValid, ...
    'VariableNames',{'time_s','x_track_signed_px','y_track_signed_px', ...
    'track_width_px','track_height_px','scale_x','scale_y','tracking_confidence', ...
    'tracking_valid','tracking_lost','redetect_used','crop_boundary', ...
    'macro_x_px','macro_y_px','expected_macro_x_px','expected_macro_y_px', ...
    'crop_x_px','crop_y_px','crop_width_px','crop_height_px','crop_valid'});
writetable(trajectoryTable,fullfile(outputDirectory,'03_tracking_trajectory.csv'));

figureHandle = figure('Visible','off','Color','w','Position',[50 50 880 650]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;
plot(time,rawCenter(:,1)-rawCenter(1,1),'Color',[0.65 0.65 0.65],'LineWidth',0.8); hold on;
plot(time,macro(:,1),'Color',[0.00 0.35 0.75],'LineWidth',1.3); grid on; box on;
xlabel('时间 (s)'); ylabel('x (px)'); title('有符号 x：原始跟踪与大运动趋势','FontWeight','normal');
legend('raw track','macro trend','Location','best','Box','off');
nexttile;
plot(time,rawCenter(:,2)-rawCenter(1,2),'Color',[0.65 0.65 0.65],'LineWidth',0.8); hold on;
plot(time,macro(:,2),'Color',[0.85 0.25 0.10],'LineWidth',1.3); grid on; box on;
xlabel('时间 (s)'); ylabel('y (px)'); title('有符号 y：原始跟踪与大运动趋势','FontWeight','normal');
legend('raw track','macro trend','Location','best','Box','off');
nexttile;
plot(time,scale(:,1),'LineWidth',1.1); hold on; plot(time,scale(:,2),'LineWidth',1.1);
yline(1,'k:'); grid on; box on; xlabel('时间 (s)'); ylabel('相对尺度');
title('跟踪框尺度变化（仅作诊断）','FontWeight','normal'); legend('width','height','initial','Location','best','Box','off');
nexttile;
plot(time,crop(:,1)-initialRoi(1),'Color',[0.00 0.45 0.70],'LineWidth',1.1); hold on;
plot(time,crop(:,2)-initialRoi(2),'Color',[0.85 0.35 0.10],'LineWidth',1.1);
bad = ~cropValid;
if any(bad)
    plot(time(bad),crop(bad,1)-initialRoi(1),'k.','MarkerSize',8);
    legend('crop x','crop y','boundary/invalid','Location','best','Box','off');
else
    legend('crop x','crop y','Location','best','Box','off');
end
grid on; box on; xlabel('时间 (s)'); ylabel('裁剪原点偏移 (px)');
title('实际分析裁剪轨迹','FontWeight','normal');
set(findall(figureHandle,'-property','FontName'),'FontName','Microsoft YaHei');
exportgraphics(figureHandle,fullfile(outputDirectory,'04_macro_vs_raw_track.png'),'Resolution',240);
% PNG 在后台生成；FIG 保存前显式改为 Visible=on，保证双击后可见。
set(figureHandle,'Visible','on');
savefig(figureHandle,fullfile(outputDirectory,'04_macro_vs_raw_track.fig'));
set(figureHandle,'Visible','off');
close(figureHandle);

figureHandle = figure('Visible','off','Color','w','Position',[50 50 880 600]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
nexttile;
plot(rawCenter(:,1)-rawCenter(1,1),rawCenter(:,2)-rawCenter(1,2), ...
    'Color',[0.60 0.60 0.60],'LineWidth',0.8); hold on;
plot(macro(:,1),macro(:,2),'Color',[0.00 0.35 0.75],'LineWidth',1.2);
axis equal; grid on; box on; xlabel('x (px)'); ylabel('y (px)');
title('跟踪中心与宏观轨迹','FontWeight','normal'); legend('raw','macro','Location','best','Box','off');
nexttile;
plot(time,rawCenter(:,1)-rawCenter(1,1)-macro(:,1),'LineWidth',1.0); hold on;
plot(time,rawCenter(:,2)-rawCenter(1,2)-macro(:,2),'LineWidth',1.0);
yline(0,'k:'); grid on; box on; xlabel('时间 (s)'); ylabel('残差 (px)');
title('跟踪残差（微振动候选）','FontWeight','normal'); legend('x residual','y residual','Location','best','Box','off');
nexttile([1 2]);
plot(time,crop(:,1),time,crop(:,2),'LineWidth',1.1); hold on;
plot(time,rawBox(:,1),':','Color',[0.40 0.40 0.40]);
plot(time,rawBox(:,2),':','Color',[0.40 0.40 0.40]);
grid on; box on; xlabel('时间 (s)'); ylabel('图像坐标 (px)');
title('动态 ROI 原点：分析裁剪 vs 跟踪框原点','FontWeight','normal');
legend('crop x','crop y','track box x','track box y','Location','best','Box','off');
set(findall(figureHandle,'-property','FontName'),'FontName','Microsoft YaHei');
exportgraphics(figureHandle,fullfile(outputDirectory,'06_dynamic_crop_diagnostics.png'),'Resolution',240);
set(figureHandle,'Visible','on');
savefig(figureHandle,fullfile(outputDirectory,'06_dynamic_crop_diagnostics.fig'));
set(figureHandle,'Visible','off');
close(figureHandle);

result = struct('time_s',time,'initialRoi',initialRoi,'fps',fps, ...
    'rawBox',rawBox,'rawCenter',rawCenter,'scale',scale,'macro',macro, ...
    'expectedMacro',expected,'cropBox',crop,'valid',valid,'lost',lost, ...
    'redetect',redetect,'boundary',boundary,'cropValid',cropValid);
save(fullfile(outputDirectory,'vp_dynamic_roi_result.mat'),'-struct','result');
jsonMetadata = metadata;
jsonMetadata.initialRoi = initialRoi;
jsonMetadata.fps = fps;
jsonMetadata.frameCount = frameCount;
jsonMetadata.output = 'trend-follow crop + M-PME backend';
fid = fopen(fullfile(outputDirectory,'vp_dynamic_roi_config.json'),'w','n','UTF-8');
if fid<0, error('无法写入 VP-DROI 配置文件。'); end
fwrite(fid,jsonencode(jsonMetadata),'char');
fclose(fid);
end

function value = localField(data,name,defaultValue)
if isstruct(data) && isfield(data,name) && ~isempty(data.(name))
    value = data.(name);
else
    value = defaultValue;
end
end

function value = localResize(value,rowCount,columnCount,defaultValue)
value = double(value);
if isvector(value) && columnCount==1, value = value(:); end
if size(value,2)~=columnCount
    value = defaultValue;
end
if size(value,1)<rowCount
    if isempty(value), value = defaultValue; else, value(end+1:rowCount,:) = value(end,:); end
elseif size(value,1)>rowCount
    value = value(1:rowCount,:);
end
end
