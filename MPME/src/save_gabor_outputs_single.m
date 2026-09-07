function save_gabor_outputs_single(reference,moving,params,outputDirectory,prefix)
%SAVE_GABOR_OUTPUTS_SINGLE 将四方向响应、置信点和相位非线性各合并为一张图。
% 直接比较的热力图使用同一颜色范围，避免各面板自动缩放造成视觉误导。

directionCount = numel(params.directions);
responses = cell(directionCount,1);
highConfidenceMasks = cell(directionCount,1);
nonlinearities = cell(directionCount,1);
confidenceCutoffs = zeros(directionCount,1);
responseLimits = zeros(directionCount,1);
nonlinearityLimits = zeros(directionCount,1);

for directionIndex = 1:directionCount
    theta = params.directions(directionIndex);
    q1 = gabor_response(reference,params.lambda,theta,params.bandwidth, ...
        params.psi,params.supportSigma);
    q2 = gabor_response(moving,params.lambda,theta,params.bandwidth, ...
        params.psi,params.supportSigma);
    responses{directionIndex} = abs(q2);
    responseLimits(directionIndex) = localPercentile( ...
        responses{directionIndex}(isfinite(responses{directionIndex})),99);

    amplitude1 = abs(q1).^2;
    amplitude2 = abs(q2).^2;
    confidence = (amplitude1.*amplitude2) ./ ...
        max((amplitude1+amplitude2).^(3/2),eps);
    cutoff = localPercentile(confidence(isfinite(confidence) & confidence>0), ...
        params.confidencePercentile);
    cutoff = max(cutoff,params.confidenceThreshold);
    confidenceCutoffs(directionIndex) = cutoff;
    highConfidenceMasks{directionIndex} = confidence>=cutoff;

    [gx,gy] = localPhaseGradientPair(q1,q2);
    windowSize = 7;
    if isfield(params,'phaseNonlinearityWindow')
        windowSize = max(3,2*floor(params.phaseNonlinearityWindow/2)+1);
    end
    meanGx = imboxfilt(gx,windowSize,'Padding','symmetric');
    meanGy = imboxfilt(gy,windowSize,'Padding','symmetric');
    nonlinearity = hypot(gx-meanGx,gy-meanGy) ./ ...
        max(hypot(meanGx,meanGy),0.1*2*pi/params.lambda);
    nonlinearities{directionIndex} = nonlinearity;
    nonlinearityLimits(directionIndex) = localPercentile( ...
        nonlinearity(isfinite(nonlinearity)),95);
end

responseUpper = max(max(responseLimits),eps);
nonlinearityUpper = max(max(nonlinearityLimits),eps);
columnCount = min(2,directionCount);
rowCount = ceil(directionCount/columnCount);

responseFigure = figure('Visible','off','Color','w','Position',[50 50 980 760]);
responseLayout = tiledlayout(responseFigure,rowCount,columnCount, ...
    'TileSpacing','compact','Padding','compact');
responseAxes = gobjects(directionCount,1);
for directionIndex = 1:directionCount
    responseAxes(directionIndex) = nexttile(responseLayout);
    imagesc(responseAxes(directionIndex),responses{directionIndex});
    axis(responseAxes(directionIndex),'image','off');
    clim(responseAxes(directionIndex),[0 responseUpper]);
    title(responseAxes(directionIndex),sprintf('\\theta = %g°', ...
        params.directions(directionIndex)),'FontWeight','normal');
end
colormap(responseFigure,parula);
colorbarHandle = colorbar(responseAxes(end));
colorbarHandle.Layout.Tile = 'east';
title(responseLayout,'四方向 Gabor 幅值响应（共享色标）','FontWeight','normal');
localStyle(responseFigure);
exportgraphics(responseFigure,fullfile(outputDirectory, ...
    sprintf('%s_gabor_responses.png',prefix)),'Resolution',240);
close(responseFigure);

confidenceFigure = figure('Visible','off','Color','w','Position',[50 50 980 760]);
confidenceLayout = tiledlayout(confidenceFigure,rowCount,columnCount, ...
    'TileSpacing','compact','Padding','compact');
sampleStep = max(1,params.sampleStep);
samplingMask = false(size(moving));
samplingMask(1:sampleStep:end,1:sampleStep:end) = true;
for directionIndex = 1:directionCount
    axesHandle = nexttile(confidenceLayout);
    imshow(moving,[],'Parent',axesHandle); hold(axesHandle,'on');
    [row,column] = find(highConfidenceMasks{directionIndex} & samplingMask);
    plot(axesHandle,column,row,'.','Color',[0.85 0.20 0.18],'MarkerSize',2);
    title(axesHandle,sprintf('\\theta = %g°，C ≥ %.2f', ...
        params.directions(directionIndex),confidenceCutoffs(directionIndex)), ...
        'FontWeight','normal');
end
title(confidenceLayout,'四方向高置信相位点','FontWeight','normal');
localStyle(confidenceFigure);
exportgraphics(confidenceFigure,fullfile(outputDirectory, ...
    sprintf('%s_confidence_points.png',prefix)),'Resolution',240);
close(confidenceFigure);

nonlinearityFigure = figure('Visible','off','Color','w','Position',[50 50 980 760]);
nonlinearityLayout = tiledlayout(nonlinearityFigure,rowCount,columnCount, ...
    'TileSpacing','compact','Padding','compact');
nonlinearityAxes = gobjects(directionCount,1);
for directionIndex = 1:directionCount
    nonlinearityAxes(directionIndex) = nexttile(nonlinearityLayout);
    imagesc(nonlinearityAxes(directionIndex),nonlinearities{directionIndex});
    axis(nonlinearityAxes(directionIndex),'image','off');
    clim(nonlinearityAxes(directionIndex),[0 nonlinearityUpper]);
    title(nonlinearityAxes(directionIndex),sprintf('\\theta = %g°', ...
        params.directions(directionIndex)),'FontWeight','normal');
end
colormap(nonlinearityFigure,turbo);
colorbarHandle = colorbar(nonlinearityAxes(end));
colorbarHandle.Layout.Tile = 'east';
title(nonlinearityLayout,'四方向相位非线性指标（共享色标）','FontWeight','normal');
localStyle(nonlinearityFigure);
exportgraphics(nonlinearityFigure,fullfile(outputDirectory, ...
    sprintf('%s_phase_nonlinearity.png',prefix)),'Resolution',240);
close(nonlinearityFigure);
end

function localStyle(figureHandle)
set(findall(figureHandle,'-property','FontName'),'FontName','Microsoft YaHei');
set(findall(figureHandle,'Type','axes'),'FontSize',9,'LineWidth',0.8,'TickDir','out');
end

function [gx,gy] = localPhaseGradientPair(q1,q2)
gx = 0.5*(localGradient(q1,2)+localGradient(q2,2));
gy = 0.5*(localGradient(q1,1)+localGradient(q2,1));
end

function gradient = localGradient(q,dimension)
gradient = zeros(size(q));
if dimension==2
    gradient(:,2:end-1) = 0.5*angle(q(:,3:end).*conj(q(:,1:end-2)));
    gradient(:,1) = angle(q(:,2).*conj(q(:,1)));
    gradient(:,end) = angle(q(:,end).*conj(q(:,end-1)));
else
    gradient(2:end-1,:) = 0.5*angle(q(3:end,:).*conj(q(1:end-2,:)));
    gradient(1,:) = angle(q(2,:).*conj(q(1,:)));
    gradient(end,:) = angle(q(end,:).*conj(q(end-1,:)));
end
end

function value = localPercentile(values,percentile)
values = sort(values(:));
if isempty(values), value = 0; return; end
position = 1+(numel(values)-1)*min(max(percentile,0),100)/100;
lower = floor(position); upper = ceil(position);
if lower==upper
    value = values(lower);
else
    value = values(lower)*(upper-position)+values(upper)*(position-lower);
end
end
