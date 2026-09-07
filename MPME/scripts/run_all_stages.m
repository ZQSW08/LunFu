%RUN_ALL_STAGES 一次运行论文复现的四个阶段，并导出图片、表格和模拟视频。
% 所有模拟数据都由本脚本固定随机种子生成；原始数值与可视化输出分开保存。
close all; clear all; clc; warning off;

rng(11, 'twister');

%% 工程路径与输出目录
projectRoot = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(projectRoot, 'src'));
outputDirectory = fullfile(projectRoot, 'outputs');
if ~exist(outputDirectory, 'dir'), mkdir(outputDirectory); end
figureDirectory = fullfile(outputDirectory, 'figures');
paperFigureDirectory = fullfile(outputDirectory, 'paper_style');
videoDirectory = fullfile(outputDirectory, 'simulation_videos');
tableDirectory = fullfile(outputDirectory, 'tables');
if ~exist(figureDirectory, 'dir'), mkdir(figureDirectory); end
if ~exist(paperFigureDirectory, 'dir'), mkdir(paperFigureDirectory); end
if ~exist(videoDirectory, 'dir'), mkdir(videoDirectory); end
if ~exist(tableDirectory, 'dir'), mkdir(tableDirectory); end

%% 阶段 1：传统单尺度 PME 的相位包裹范围
fprintf('Stage 1/4: single-scale PME phase-wrapping limit...\n');
gaussianImageSize = [96 128];
gaussianFrameCount = 100;
gaussianFps = 50;
commonTranslation = struct('lambda', 30, 'directions', 0, ...
    'model', 'translation', 'bandwidth', 1, 'psi', 0, ...
    'supportSigma', 2, 'confidenceThreshold', 0, ...
    'confidencePercentile', 72, 'useDirectionMask', false, ...
    'sampleStep', 1);
stage1Truth = zeros(gaussianFrameCount, 4);
stage1Pme = zeros(gaussianFrameCount, 4);
gaussianSequences = cell(4, 1);
for k = 1:4
    [frames, truth] = make_gaussian_sequence(gaussianImageSize, ...
        gaussianFrameCount, gaussianFps, k);
    gaussianSequences{k} = frames;
    stage1Truth(:, k) = truth;
    reference = frames(:, :, 1);
    for frameIndex = 2:gaussianFrameCount
        wrapped = pme_wrapped_translation(reference, frames(:, :, frameIndex), ...
            commonTranslation);
        stage1Pme(frameIndex, k) = wrapped(1);
    end
end
smallMotionMask = abs(stage1Truth(:, 1)) < 2 & abs(stage1Truth(:, 1)) > 0.2;
stage1SmallMotionMae = mean(abs(stage1Pme(smallMotionMask, 1) - ...
    stage1Truth(smallMotionMask, 1)));
stage1LargeMotionMae = mean(abs(stage1Pme(:, 4) - stage1Truth(:, 4)));

%% 阶段 2：两层 M-PME 从粗到细恢复大位移
fprintf('Stage 2/4: two-level coarse-to-fine M-PME...\n');
stage2Params = commonTranslation;
stage2Params.levels = 2;
stage2Params.iterationsPerLevel = 1;
stage2Mpme = zeros(gaussianFrameCount, 4);
for k = 1:4
    frames = gaussianSequences{k};
    reference = frames(:, :, 1);
    for frameIndex = 2:gaussianFrameCount
        H = mpme_estimate_affine(reference, frames(:, :, frameIndex), stage2Params);
        stage2Mpme(frameIndex, k) = H(1, 3);
    end
end
stage2Mae = mean(abs(stage2Mpme - stage1Truth), 1);

%% 阶段 3：四方向 Gabor 与局部仿射约束的二维旋转
fprintf('Stage 3/4: four-scale 2-D rotation with affine phase constraints...\n');
rotationImageSize = [192 192];
[rotorReference, rotorMask, featurePoints] = make_rotor_image(rotationImageSize, 1975);
rotationAngles = 0:10:180;
rotationFrames = zeros([rotationImageSize numel(rotationAngles)]);
rotationTruth = repmat(eye(3), 1, 1, numel(rotationAngles));
for angleIndex = 1:numel(rotationAngles)
    rotationTruth(:, :, angleIndex) = rotation_h(rotationAngles(angleIndex), rotationImageSize);
    rotationFrames(:, :, angleIndex) = warp_image_h(rotorReference, ...
        inv(rotationTruth(:, :, angleIndex)), median(rotorReference(:)));
end
rotationParams = struct('levels', 4, 'lambda', 30, ...
    'directions', [0 45 90 135], 'model', 'affine', ...
    'bandwidth', 1, 'psi', 0, 'supportSigma', 2, ...
    'confidenceThreshold', 25, 'confidencePercentile', 55, ...
    'useDirectionMask', false, 'sampleStep', 2, ...
    'iterationsPerLevel', 1, ...
    'usePhaseNonlinearityWeight', true, 'phaseNonlinearityWindow', 7, ...
    'phaseNonlinearityScale', 0.35, 'phaseNonlinearityPercentile', 88);
[rotationEstimate, rotationDiagnostics] = track_sequence_affine( ...
    rotationFrames, rotationParams, 'adjacent');
rotationMaeX = zeros(numel(rotationAngles), 1);
rotationMaeY = zeros(numel(rotationAngles), 1);
rotationStd = zeros(numel(rotationAngles), 1);
rotationMax = zeros(numel(rotationAngles), 1);
rotationCumulativeMae = zeros(numel(rotationAngles), 1);
for angleIndex = 2:numel(rotationAngles)
    previousPoints = transform_points_h(rotationTruth(:, :, angleIndex-1), featurePoints);
    truthPoints = transform_points_h(rotationTruth(:, :, angleIndex), featurePoints);
    estimatedStep = rotationEstimate(:, :, angleIndex) / rotationEstimate(:, :, angleIndex-1);
    estimatePoints = transform_points_h(estimatedStep, previousPoints);
    pointError = estimatePoints - truthPoints;
    rotationMaeX(angleIndex) = mean(abs(pointError(:, 1)));
    rotationMaeY(angleIndex) = mean(abs(pointError(:, 2)));
    rotationStd(angleIndex) = std(pointError(:));
    rotationMax(angleIndex) = max(abs(pointError(:)));
    cumulativePoints = transform_points_h(rotationEstimate(:, :, angleIndex), featurePoints);
    rotationCumulativeMae(angleIndex) = mean(abs(cumulativePoints(:) - truthPoints(:)));
end

%% 阶段 4：塔架和运行叶片的同规格合成代理
fprintf('Stage 4/4: tower and operating-blade data pipelines on synthetic proxies...\n');
% 塔架代理保留论文的帧率和三层金字塔。由于代理图像尺寸较小，lambda 按比例
% 使用 30；真实数据入口仍使用论文的 lambda=60。
towerSize = [128 96];
[towerX, towerY] = meshgrid(0:towerSize(2)-1, 0:towerSize(1)-1);
towerMask = abs(towerX-(towerSize(2)-1)/2) < 11 & towerY > 12 & towerY < 116;
towerReference = 205 + 5*sin(0.09*towerX + 0.13*towerY);
towerTexture = 65 + 35*sin(0.31*towerX).*cos(0.23*towerY) + ...
    20*imgaussfilt(randn(towerSize), 0.7);
towerReference(towerMask) = towerTexture(towerMask);
towerFrameCount = 120;
towerFps = 60;
towerTime = (0:towerFrameCount-1).' / towerFps;
towerTruthPixels = 13*sin(2*pi*1.25*towerTime) + 2.2*sin(2*pi*4.2*towerTime);
towerFrames = zeros([towerSize towerFrameCount]);
for frameIndex = 1:towerFrameCount
    truthH = [1 0 0; 0 1 towerTruthPixels(frameIndex); 0 0 1];
    towerFrames(:, :, frameIndex) = warp_image_h(towerReference, inv(truthH), 205);
end
towerParams = commonTranslation;
towerParams.directions = 90;
towerParams.lambda = 30;
towerParams.levels = 3;
towerParams.confidencePercentile = 70;
towerParams.sampleStep = 2;
towerParams.iterationsPerLevel = 1;
[towerEstimateH, towerDiagnostics] = track_sequence_affine( ...
    towerFrames, towerParams, 'fixed');
towerEstimatePixels = squeeze(towerEstimateH(2, 3, :));
towerPmePixels = zeros(towerFrameCount, 1);
for frameIndex = 2:towerFrameCount
    wrappedTower = pme_wrapped_translation(towerFrames(:,:,1), ...
        towerFrames(:,:,frameIndex), towerParams);
    towerPmePixels(frameIndex) = wrappedTower(2);
end
towerMaePixels = mean(abs(towerEstimatePixels - towerTruthPixels));
scalePixelsPerMm = 1.574;
sensorDelayFrames = 6;
sensorDisplacement = [zeros(sensorDelayFrames,1); ...
    towerTruthPixels(1:end-sensorDelayFrames)] / scalePixelsPerMm + ...
    0.03*randn(towerFrameCount,1);
[correlation, lags] = xcorr(detrend(towerEstimatePixels), ...
    detrend(sensorDisplacement * scalePixelsPerMm), 20, 'coeff');
[~, bestLagIndex] = max(correlation);
estimatedSensorLagFrames = lags(bestLagIndex);

% 运行叶片代理使用 30 r/min、20 fps、10 s，与论文的一个工况保持一致。
bladeSize = [160 160];
[bladeReference, ~, bladePoints] = make_rotor_image(bladeSize, 800);
bladeFps = 20;
bladeFrameCount = 200; % 10 s, matching the paper's operating-blade record length.
bladeSpeedRpm = 30;
bladeTime = (0:bladeFrameCount-1).' / bladeFps;
bladeAngles = 360 * (bladeSpeedRpm / 60) * bladeTime;
bladeFrames = zeros([bladeSize bladeFrameCount]);
bladeTruthH = repmat(eye(3), 1, 1, bladeFrameCount);
for frameIndex = 1:bladeFrameCount
    bladeTruthH(:, :, frameIndex) = rotation_h(bladeAngles(frameIndex), bladeSize);
    bladeFrames(:, :, frameIndex) = warp_image_h(bladeReference, ...
        inv(bladeTruthH(:, :, frameIndex)), median(bladeReference(:)));
end
bladeParams = rotationParams;
bladeParams.levels = 4;
bladeParams.sampleStep = 3;
bladeParams.enforceRigid = true;
bladeParams.rigidCenter = [(bladeSize(2)-1)/2 (bladeSize(1)-1)/2];
[bladeAdjacentH, bladeDiagnostics] = track_sequence_affine( ...
    bladeFrames, bladeParams, 'adjacent');
[bladeIntegratedH, bladeRawStepAngles, bladeIntegratedStepAngles] = ...
    stabilize_rotation_sequence(bladeAdjacentH, bladeSize, 5, bladeParams.rigidCenter);
anchorOptions = struct('angularSamples',720,'radialSamples',72, ...
    'radiusFraction',[0.10 0.48],'minimumQuality',1.02,'symmetryOrder',1);
[bladeEstimateH, bladeAnchoredAngles, bladeAnchorAngles, bladeAnchorQuality] = ...
    anchor_rotation_sequence(bladeFrames, bladeIntegratedH, ...
    bladeParams.rigidCenter, anchorOptions);
bladeStepAngles = [0; diff(bladeAnchoredAngles)];
[~, farthestIndex] = max(sum((bladePoints - (bladeSize(1)-1)/2).^2, 2));
measurementPoint = bladePoints(farthestIndex, :);
bladeEstimateY = zeros(bladeFrameCount, 1);
bladeTruthY = zeros(bladeFrameCount, 1);
for frameIndex = 1:bladeFrameCount
    estimatedPoint = transform_points_h(bladeEstimateH(:, :, frameIndex), measurementPoint);
    truthPoint = transform_points_h(bladeTruthH(:, :, frameIndex), measurementPoint);
    bladeEstimateY(frameIndex) = estimatedPoint(2);
    bladeTruthY(frameIndex) = truthPoint(2);
end
[bladeFrequency, spectrumFrequency, spectrumAmplitude] = ...
    estimate_dominant_frequency(bladeEstimateY, bladeFps, [0.1 2]);
bladeTruthFrequency = bladeSpeedRpm / 60;
bladeFrequencyErrorPercent = 100 * abs(bladeFrequency - bladeTruthFrequency) / ...
    bladeTruthFrequency;
bladePointMae = mean(abs(bladeEstimateY - bladeTruthY));

bladeIntegratedY = zeros(bladeFrameCount,1);
for frameIndex = 1:bladeFrameCount
    integratedPoint = transform_points_h(bladeIntegratedH(:,:,frameIndex),measurementPoint);
    bladeIntegratedY(frameIndex) = integratedPoint(2);
end
bladeIntegratedPointMae = mean(abs(bladeIntegratedY-bladeTruthY));

% 选择叶片上三个不同半径的测点，复现论文 Fig. 19/Fig. 20 的多测点时程和频谱。
bladeCentre = [(bladeSize(2)-1)/2 (bladeSize(1)-1)/2];
bladeRadius = sqrt(sum((bladePoints - bladeCentre).^2, 2));
targetRadii = [0.18 0.29 0.39] * min(bladeSize);
bladeSelectedPoints = zeros(3, 2);
for pointIndex = 1:3
    [~, selectedIndex] = min(abs(bladeRadius - targetRadii(pointIndex)));
    bladeSelectedPoints(pointIndex, :) = bladePoints(selectedIndex, :);
end

%% 阶段 4c：非线性水平大运动叠加微振动
% “非线性”在这里指运动轨迹随时间并非单一正弦；只要逐层残差仍处于可解范围，
% 相位法并不会因为轨迹有加速度或高阶谐波而自动失效。
fprintf('Stage 4c: nonlinear large translation plus micro-vibration...\n');
mixedSize = [112 176];
[mixedXGrid,mixedYGrid] = meshgrid(0:mixedSize(2)-1,0:mixedSize(1)-1);
mixedCentre = [(mixedSize(2)-1)/2 (mixedSize(1)-1)/2];
mixedMask = hypot(mixedXGrid-mixedCentre(1),mixedYGrid-mixedCentre(2)) <= 24;
mixedReference = 198 + 7*sin(0.05*mixedXGrid+0.08*mixedYGrid);
mixedTexture = 82 + 34*sin(0.31*mixedXGrid).*cos(0.23*mixedYGrid) + ...
    25*imgaussfilt(randn(mixedSize),0.65);
mixedReference(mixedMask) = mixedTexture(mixedMask);
mixedFps = 60;
mixedFrameCount = 300;
mixedTime = (0:mixedFrameCount-1).'/mixedFps;
mixedLargeTruth = 14*sin(2*pi*0.28*mixedTime) + ...
    5*sin(2*pi*0.28*mixedTime).^3 + 2.5*sin(2*pi*0.63*mixedTime);
mixedMicroTruth = 0.42*sin(2*pi*6.2*mixedTime);
mixedTruth = mixedLargeTruth + mixedMicroTruth;
mixedFrames = zeros([mixedSize mixedFrameCount]);
for frameIndex = 1:mixedFrameCount
    truthH = [1 0 mixedTruth(frameIndex); 0 1 0; 0 0 1];
    mixedFrames(:,:,frameIndex) = warp_image_h(mixedReference,inv(truthH),198);
end
mixedParams = commonTranslation;
mixedParams.levels = 3;
mixedParams.iterationsPerLevel = 1;
mixedParams.confidencePercentile = 68;
mixedParams.sampleStep = 2;
mixedParams.usePhaseNonlinearityWeight = true;
mixedParams.phaseNonlinearityWindow = 7;
mixedParams.phaseNonlinearityScale = 0.35;
mixedParams.phaseNonlinearityPercentile = 88;
[mixedEstimateH,mixedDiagnostics] = track_sequence_affine(mixedFrames,mixedParams,'fixed');
mixedEstimate = squeeze(mixedEstimateH(1,3,:));
[lowpassB,lowpassA] = butter(4,1.5/(mixedFps/2),'low');
mixedLargeEstimate = filtfilt(lowpassB,lowpassA,mixedEstimate);
mixedMicroEstimate = mixedEstimate-mixedLargeEstimate;
mixedValid = mixedTime>=0.5 & mixedTime<=mixedTime(end)-0.5;
mixedTotalMae = mean(abs(mixedEstimate(mixedValid)-mixedTruth(mixedValid)));
mixedMicroMae = mean(abs(mixedMicroEstimate(mixedValid)-mixedMicroTruth(mixedValid)));
[mixedMicroFrequency,mixedSpectrumF,mixedSpectrumA] = estimate_dominant_frequency( ...
    mixedMicroEstimate(mixedValid),mixedFps,[2 12]);
bladeTruthTracks = zeros(3, 2, bladeFrameCount);
bladeEstimateTracks = zeros(3, 2, bladeFrameCount);
bladePointFrequency = zeros(3, 1);
bladePointSpectrum = cell(3, 1);
for frameIndex = 1:bladeFrameCount
    bladeTruthTracks(:,:,frameIndex) = transform_points_h( ...
        bladeTruthH(:,:,frameIndex), bladeSelectedPoints);
    bladeEstimateTracks(:,:,frameIndex) = transform_points_h( ...
        bladeEstimateH(:,:,frameIndex), bladeSelectedPoints);
end
for pointIndex = 1:3
    [bladePointFrequency(pointIndex), pointSpectrumFrequency, pointSpectrumAmplitude] = ...
        estimate_dominant_frequency(squeeze(bladeEstimateTracks(pointIndex,2,:)), ...
        bladeFps, [0.1 2]);
    bladePointSpectrum{pointIndex} = [pointSpectrumFrequency pointSpectrumAmplitude];
end

%% 导出论文对应的分阶段图片
% 统一使用黑色真值、橙色 PME、蓝色 M-PME，并辅以不同线型和标记。
truthColor = [0 0 0];
pmeColor = [0.84 0.37 0.00];
mpmeColor = [0.00 0.45 0.70];
timeGaussian = (0:gaussianFrameCount-1).' / gaussianFps;

stage1Figure = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1250 760]);
stage1Layout = tiledlayout(stage1Figure, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(stage1Layout, '阶段 1：传统 PME 在不同运动幅值下的相位包裹');
for k = 1:4
    nexttile;
    plot(timeGaussian, stage1Truth(:,k), '-', 'Color', truthColor, 'LineWidth', 1.4); hold on;
    plot(timeGaussian, stage1Pme(:,k), '--', 'Color', pmeColor, 'LineWidth', 1.2);
    grid on; xlabel('时间 (s)'); ylabel('x 位移 (px)'); title(sprintf('k = %d', k));
    legend('真值','PME','Location','best');
end
exportgraphics(stage1Figure, fullfile(figureDirectory, 'stage1_pme_wrapping.png'), 'Resolution', 180);
close(stage1Figure);

stage2Figure = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1250 760]);
stage2Layout = tiledlayout(stage2Figure, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(stage2Layout, '阶段 2：M-PME 从粗到细恢复大位移');
for k = 1:4
    nexttile;
    plot(timeGaussian, stage1Truth(:,k), '-', 'Color', truthColor, 'LineWidth', 1.4); hold on;
    plot(timeGaussian, stage1Pme(:,k), ':', 'Color', pmeColor, 'LineWidth', 1.0);
    plot(timeGaussian, stage2Mpme(:,k), '--', 'Color', mpmeColor, 'LineWidth', 1.2);
    grid on; xlabel('时间 (s)'); ylabel('x 位移 (px)'); title(sprintf('k = %d', k));
    legend('真值','PME','M-PME','Location','best');
end
exportgraphics(stage2Figure, fullfile(figureDirectory, 'stage2_mpme_gaussian.png'), 'Resolution', 180);
close(stage2Figure);
save_pyramid_preview(gaussianSequences{4}(:,:,2), 2, ...
    fullfile(figureDirectory, 'stage2_gaussian_pyramid.png'), '高斯面两层金字塔');

rotationInputFigure = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1250 350]);
rotationInputLayout = tiledlayout(rotationInputFigure, 1, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
title(rotationInputLayout, '阶段 3：旋转叶片模拟输入');
rotationPreviewIndices = [1 7 13 19];
for previewIndex = 1:4
    nexttile; imshow(rotationFrames(:,:,rotationPreviewIndices(previewIndex)), []);
    title(sprintf('%g deg', rotationAngles(rotationPreviewIndices(previewIndex))));
end
exportgraphics(rotationInputFigure, fullfile(figureDirectory, 'stage3_rotation_inputs.png'), 'Resolution', 180);
close(rotationInputFigure);
save_pyramid_preview(rotationFrames(:,:,2), 4, ...
    fullfile(figureDirectory, 'stage3_rotation_pyramid.png'), '旋转图像四层高斯金字塔');
save_gabor_diagnostics(rotationFrames(:,:,1), rotationFrames(:,:,2), rotationParams, ...
    fullfile(figureDirectory, 'stage3_gabor_confidence.png'), ...
    '四方向 Gabor 响应与高置信点分布');

fieldAngleIndex = 7;
fieldSelection = 1:60:size(featurePoints,1);
fieldPoints = featurePoints(fieldSelection,:);
truthFieldPoints = transform_points_h(rotationTruth(:,:,fieldAngleIndex), fieldPoints);
estimateFieldPoints = transform_points_h(rotationEstimate(:,:,fieldAngleIndex), fieldPoints);
fieldFigure = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1100 470]);
fieldLayout = tiledlayout(fieldFigure, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile; imshow(rotorReference, []); hold on;
quiver(fieldPoints(:,1)+1, fieldPoints(:,2)+1, ...
    truthFieldPoints(:,1)-fieldPoints(:,1), truthFieldPoints(:,2)-fieldPoints(:,2), ...
    0, 'Color', [0 0.62 0.45], 'LineWidth', 1.1);
title(sprintf('真值位移场（%g deg）', rotationAngles(fieldAngleIndex)));
nexttile; imshow(rotorReference, []); hold on;
quiver(fieldPoints(:,1)+1, fieldPoints(:,2)+1, ...
    estimateFieldPoints(:,1)-fieldPoints(:,1), estimateFieldPoints(:,2)-fieldPoints(:,2), ...
    0, 'Color', mpmeColor, 'LineWidth', 1.1);
title('M-PME 估计位移场');
exportgraphics(fieldFigure, fullfile(figureDirectory, 'stage3_rotation_motion_field.png'), 'Resolution', 180);
close(fieldFigure);

rotationErrorFigure = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1350 390]);
rotationErrorLayout = tiledlayout(rotationErrorFigure, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile;
plot(rotationAngles, rotationMaeX, '-o', 'Color', pmeColor, 'LineWidth', 1.1); hold on;
plot(rotationAngles, rotationMaeY, '--s', 'Color', mpmeColor, 'LineWidth', 1.1);
yline(0.4, 'k:'); grid on; xlabel('累计角度 (deg)'); ylabel('MAE (px)');
title('平均绝对误差'); legend('x','y','论文参考 0.4','Location','best');
nexttile;
plot(rotationAngles, rotationStd, '-d', 'Color', [0 0.62 0.45], 'LineWidth', 1.1);
yline(0.04, 'k:'); grid on; xlabel('累计角度 (deg)'); ylabel('STD (px)');
title('误差标准差'); legend('M-PME','论文参考 0.04','Location','best');
nexttile;
plot(rotationAngles, rotationMax, '-^', 'Color', [0.80 0.47 0.65], 'LineWidth', 1.1);
yline(0.7, 'k:'); grid on; xlabel('累计角度 (deg)'); ylabel('MaxE (px)');
title('最大绝对误差'); legend('M-PME','论文参考 0.7','Location','best');
exportgraphics(rotationErrorFigure, fullfile(figureDirectory, 'stage3_rotation_errors.png'), 'Resolution', 180);
close(rotationErrorFigure);

[towerFrequency, towerSpectrumFrequency, towerSpectrumAmplitude] = ...
    estimate_dominant_frequency(towerEstimatePixels, towerFps, [0.1 10]);
towerAlignedSensorPixels = sensorDisplacement * scalePixelsPerMm;
towerFigure = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1300 760]);
towerLayout = tiledlayout(towerFigure, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(towerLayout, '阶段 4a：塔架大幅平移代理结果');
nexttile;
plot(towerTime, towerTruthPixels, '-', 'Color', truthColor, 'LineWidth', 1.4); hold on;
plot(towerTime, towerPmePixels, ':', 'Color', pmeColor, 'LineWidth', 1.0);
plot(towerTime, towerEstimatePixels, '--', 'Color', mpmeColor, 'LineWidth', 1.2);
grid on; xlabel('时间 (s)'); ylabel('y 位移 (px)'); title('位移时程');
legend('真值','PME','M-PME','Location','best');
nexttile;
plot(towerTime, towerEstimatePixels-towerTruthPixels, '-', 'Color', pmeColor, 'LineWidth', 1.0);
yline(0, 'k:'); grid on; xlabel('时间 (s)'); ylabel('误差 (px)');
title(sprintf('M-PME 误差，MAE = %.3f px', towerMaePixels));
nexttile;
plot(towerSpectrumFrequency, towerSpectrumAmplitude, '-', 'Color', mpmeColor, 'LineWidth', 1.2);
xline(towerFrequency, 'k--'); grid on; xlim([0 10]); xlabel('频率 (Hz)'); ylabel('幅值');
title(sprintf('M-PME 频谱，主频 %.3f Hz', towerFrequency));
nexttile;
plot(towerTime, towerTruthPixels, '-', 'Color', truthColor, 'LineWidth', 1.2); hold on;
plot(towerTime, towerAlignedSensorPixels, ':', 'Color', [0.80 0.47 0.65], 'LineWidth', 1.0);
plot(towerTime, towerEstimatePixels, '--', 'Color', mpmeColor, 'LineWidth', 1.1);
grid on; xlabel('时间 (s)'); ylabel('位移 (px)'); title('视觉与模拟传感器对照（未移位）');
legend('真值','传感器','M-PME','Location','best');
exportgraphics(towerFigure, fullfile(figureDirectory, 'stage4_tower_results.png'), 'Resolution', 180);
close(towerFigure);
save_pyramid_preview(towerFrames(:,:,2), 3, ...
    fullfile(figureDirectory, 'stage4_tower_pyramid.png'), '塔架代理三层高斯金字塔');

bladeFigure = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1450 760]);
bladeLayout = tiledlayout(bladeFigure, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(bladeLayout, '阶段 4b：运行叶片三个测点的运动时程与频谱');
for pointIndex = 1:3
    nexttile(pointIndex);
    plot(bladeTime, squeeze(bladeTruthTracks(pointIndex,2,:)), '-', ...
        'Color', truthColor, 'LineWidth', 1.2); hold on;
    plot(bladeTime, squeeze(bladeEstimateTracks(pointIndex,2,:)), '--', ...
        'Color', mpmeColor, 'LineWidth', 1.0);
    grid on; xlabel('时间 (s)'); ylabel('y 坐标 (px)'); title(sprintf('测点 P%d 时程', pointIndex));
    legend('真值','M-PME','Location','best');
    nexttile(3+pointIndex);
    pointSpectrum = bladePointSpectrum{pointIndex};
    plot(pointSpectrum(:,1), pointSpectrum(:,2), '-', 'Color', mpmeColor, 'LineWidth', 1.1); hold on;
    xline(bladeTruthFrequency, 'k--'); xline(bladePointFrequency(pointIndex), ':', 'Color', pmeColor);
    grid on; xlim([0 2]); xlabel('频率 (Hz)'); ylabel('幅值');
    title(sprintf('P%d 主频 %.3f Hz', pointIndex, bladePointFrequency(pointIndex)));
    legend('频谱','真值','估计','Location','northeast');
end
exportgraphics(bladeFigure, fullfile(figureDirectory, 'stage4_blade_three_points.png'), 'Resolution', 180);
close(bladeFigure);
save_pyramid_preview(bladeFrames(:,:,2), 4, ...
    fullfile(figureDirectory, 'stage4_blade_pyramid.png'), '运行叶片四层高斯金字塔');
save_gabor_diagnostics(bladeFrames(:,:,1), bladeFrames(:,:,2), bladeParams, ...
    fullfile(figureDirectory, 'stage4_blade_gabor_confidence.png'), ...
    '运行叶片四方向 Gabor 响应与高置信点');

%% 导出简洁的论文式结果：输入单图；曲线仅使用“时程 + 频谱”双栏
for k = 1:4
    save_motion_spectrum_figure(timeGaussian, ...
        [stage1Truth(:,k) stage1Pme(:,k) stage2Mpme(:,k)], ...
        {'真值','PME','M-PME'},gaussianFps,[0.1 10], ...
        fullfile(paperFigureDirectory,sprintf('stage12_gaussian_k%d.png',k)), ...
        'x 位移 (px)',sprintf('高斯面工况 k=%d',k));
end
for previewIndex = 1:numel(rotationPreviewIndices)
    index = rotationPreviewIndices(previewIndex);
    save_single_frame_figure(rotationFrames(:,:,index), ...
        fullfile(paperFigureDirectory,sprintf('stage3_rotation_%03gdeg.png', ...
        rotationAngles(index))),sprintf('旋转输入：%g°',rotationAngles(index)));
end

metricNames = {'MAE_x','MAE_y','STD','MaxE'};
metricValues = {rotationMaeX,rotationMaeY,rotationStd,rotationMax};
metricLabels = {'MAE_x (px)','MAE_y (px)','STD (px)','MaxE (px)'};
for metricIndex = 1:numel(metricNames)
    fig = figure('Visible','off','Color','w','Position',[50 50 560 390]);
    plot(rotationAngles,metricValues{metricIndex},'-o','Color',mpmeColor, ...
        'LineWidth',1.15,'MarkerSize',4); grid on; box on;
    xlabel('累计角度 (deg)'); ylabel(metricLabels{metricIndex});
    title(sprintf('旋转误差：%s',metricNames{metricIndex}),'FontWeight','normal');
    set(gca,'FontName','Microsoft YaHei','FontSize',9,'TickDir','out');
    exportgraphics(fig,fullfile(paperFigureDirectory, ...
        sprintf('stage3_rotation_%s.png',lower(metricNames{metricIndex}))),'Resolution',240);
    close(fig);
end

save_motion_spectrum_figure(towerTime, ...
    [towerTruthPixels towerPmePixels towerEstimatePixels], ...
    {'真值','PME','M-PME'},towerFps,[0.1 10], ...
    fullfile(paperFigureDirectory,'stage4_tower_waveform_spectrum.png'), ...
    'y 位移 (px)','塔架代理：大运动恢复');

for pointIndex = 1:3
    save_motion_spectrum_figure(bladeTime, ...
        [squeeze(bladeTruthTracks(pointIndex,2,:)) ...
         squeeze(bladeEstimateTracks(pointIndex,2,:))], ...
        {'真值','M-PME + 绝对转角锚定'},bladeFps,[0.1 2], ...
        fullfile(paperFigureDirectory,sprintf('stage4_blade_P%d_waveform_spectrum.png',pointIndex)), ...
        'y 坐标 (px)',sprintf('运行叶片测点 P%d',pointIndex));
end
save_motion_spectrum_figure(bladeTime, ...
    [bladeTruthY bladeIntegratedY bladeEstimateY], ...
    {'真值','仅帧间累计','加入首帧锚定'},bladeFps,[0.1 2], ...
    fullfile(paperFigureDirectory,'stage4_blade_drift_correction.png'), ...
    '测点 y 坐标 (px)','运行叶片：后半段累计漂移修正');

save_single_frame_figure(mixedFrames(:,:,1), ...
    fullfile(paperFigureDirectory,'stage4c_large_micro_input.png'), ...
    '水平大运动 + 微振动模拟输入');
save_motion_spectrum_figure(mixedTime, ...
    [mixedTruth mixedEstimate],{'真值','M-PME'},mixedFps,[0.1 12], ...
    fullfile(paperFigureDirectory,'stage4c_total_waveform_spectrum.png'), ...
    'x 位移 (px)','非线性水平大运动叠加微振动：总位移');
save_motion_spectrum_figure(mixedTime(mixedValid), ...
    [mixedMicroTruth(mixedValid) mixedMicroEstimate(mixedValid)], ...
    {'微振动真值','零相位分离结果'},mixedFps,[2 12], ...
    fullfile(paperFigureDirectory,'stage4c_micro_waveform_spectrum.png'), ...
    '微振动位移 (px)','大运动背景下的微振动恢复');

%% 导出便于复核的 CSV 数值表
gaussianTable = table((1:4).', mean(abs(stage1Pme-stage1Truth),1).', stage2Mae.', ...
    'VariableNames', {'k','PME_MAE_px','MPME_MAE_px'});
writetable(gaussianTable, fullfile(tableDirectory, 'gaussian_error_summary.csv'));
rotationTable = table(rotationAngles(:), rotationMaeX, rotationMaeY, rotationStd, ...
    rotationMax, rotationCumulativeMae, 'VariableNames', ...
    {'angle_deg','MAE_x_px','MAE_y_px','STD_px','MaxE_px','cumulative_MAE_px'});
writetable(rotationTable, fullfile(tableDirectory, 'rotation_error_by_angle.csv'));
towerTable = table(towerTime, towerTruthPixels, towerPmePixels, towerEstimatePixels, ...
    towerAlignedSensorPixels, 'VariableNames', ...
    {'time_s','truth_px','PME_px','MPME_px','sensor_px_unaligned'});
writetable(towerTable, fullfile(tableDirectory, 'tower_time_history.csv'));
bladeTable = table(bladeTime, bladeAngles, bladeRawStepAngles, bladeStepAngles, ...
    squeeze(bladeTruthTracks(1,2,:)), squeeze(bladeEstimateTracks(1,2,:)), ...
    squeeze(bladeTruthTracks(2,2,:)), squeeze(bladeEstimateTracks(2,2,:)), ...
    squeeze(bladeTruthTracks(3,2,:)), squeeze(bladeEstimateTracks(3,2,:)), ...
    'VariableNames', {'time_s','truth_angle_deg','raw_step_angle_deg','corrected_step_angle_deg', ...
    'P1_truth_y_px','P1_MPME_y_px','P2_truth_y_px','P2_MPME_y_px', ...
    'P3_truth_y_px','P3_MPME_y_px'});
writetable(bladeTable, fullfile(tableDirectory, 'blade_three_points.csv'));
bladeFrequencyTable = table((1:3).', bladePointFrequency, ...
    100*abs(bladePointFrequency-bladeTruthFrequency)/bladeTruthFrequency, ...
    'VariableNames', {'point','frequency_Hz','error_percent'});
writetable(bladeFrequencyTable, fullfile(tableDirectory, 'blade_frequency_summary.csv'));
mixedTable = table(mixedTime,mixedTruth,mixedLargeTruth,mixedMicroTruth, ...
    mixedEstimate,mixedLargeEstimate,mixedMicroEstimate, ...
    'VariableNames',{'time_s','truth_total_px','truth_large_px','truth_micro_px', ...
    'MPME_total_px','estimated_large_px','estimated_micro_px'});
writetable(mixedTable,fullfile(tableDirectory,'large_motion_plus_micro_vibration.csv'));

%% 导出各阶段模拟视频，直观看运动生成与估计效果
write_scalar_motion_video(gaussianSequences{4}, ...
    fullfile(videoDirectory, 'stage1_pme_wrapping.mp4'), 25, ...
    'Stage 1: PME phase wrapping', 1, stage1Truth(:,4), {'PME'}, stage1Pme(:,4));
write_scalar_motion_video(gaussianSequences{4}, ...
    fullfile(videoDirectory, 'stage2_mpme_recovery.mp4'), 25, ...
    'Stage 2: coarse-to-fine M-PME', 1, stage1Truth(:,4), ...
    {'PME','M-PME'}, [stage1Pme(:,4) stage2Mpme(:,4)]);

rotationVideoPoints = featurePoints(round(linspace(1,size(featurePoints,1),3)),:);
rotationTruthTracks = zeros(3,2,numel(rotationAngles));
rotationEstimateTracks = zeros(3,2,numel(rotationAngles));
for frameIndex = 1:numel(rotationAngles)
    rotationTruthTracks(:,:,frameIndex) = transform_points_h( ...
        rotationTruth(:,:,frameIndex), rotationVideoPoints);
    rotationEstimateTracks(:,:,frameIndex) = transform_points_h( ...
        rotationEstimate(:,:,frameIndex), rotationVideoPoints);
end
write_point_tracks_video(rotationFrames, ...
    fullfile(videoDirectory, 'stage3_rotation_tracking.mp4'), 5, ...
    'Stage 3: affine rotation tracking', rotationTruthTracks, rotationEstimateTracks, ...
    rotationAngles(:), 'angle (deg)');
write_scalar_motion_video(towerFrames, ...
    fullfile(videoDirectory, 'stage4_tower_motion.mp4'), 30, ...
    'Stage 4a: tower motion', 2, towerTruthPixels, {'PME','M-PME'}, ...
    [towerPmePixels towerEstimatePixels]);
write_point_tracks_video(bladeFrames, ...
    fullfile(videoDirectory, 'stage4_blade_rotation.mp4'), bladeFps, ...
    'Stage 4b: operating blade', bladeTruthTracks, bladeEstimateTracks, ...
    bladeAngles, 'angle (deg)');
write_scalar_motion_video(mixedFrames, ...
    fullfile(videoDirectory,'stage4c_large_motion_plus_micro_vibration.mp4'),30, ...
    'Stage 4c: nonlinear large motion + micro vibration',1,mixedTruth, ...
    {'M-PME'},mixedEstimate);

%% 保存所有数值，保证图片和视频均可追溯到原始数组
results = struct;
results.generatedAt = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
results.stage1 = struct('smallMotionMaePx', stage1SmallMotionMae, ...
    'largeMotionMaePx', stage1LargeMotionMae, 'truth', stage1Truth, 'pme', stage1Pme);
results.stage2 = struct('maePxByK', stage2Mae, 'mpme', stage2Mpme);
results.stage3 = struct('anglesDeg', rotationAngles, 'maeX', rotationMaeX, ...
    'maeY', rotationMaeY, 'std', rotationStd, 'maxError', rotationMax, ...
    'cumulativeMae', rotationCumulativeMae, ...
    'transforms', rotationEstimate, 'diagnostics', {rotationDiagnostics});
results.stage4 = struct('towerMaePx', towerMaePixels, ...
    'towerEstimatedSensorLagFrames', estimatedSensorLagFrames, ...
    'towerTruthPx', towerTruthPixels, 'towerPmePx', towerPmePixels, ...
    'towerMpmePx', towerEstimatePixels, 'towerFrequencyHz', towerFrequency, ...
    'bladeFrequencyHz', bladeFrequency, 'bladeTruthFrequencyHz', bladeTruthFrequency, ...
    'bladeFrequencyErrorPercent', bladeFrequencyErrorPercent, ...
    'bladePointFrequencyHz', bladePointFrequency, ...
    'bladeSelectedPoints', bladeSelectedPoints, ...
    'bladeTruthTracks', bladeTruthTracks, 'bladeEstimateTracks', bladeEstimateTracks, ...
    'bladePointMaePx', bladePointMae, ...
    'bladeIntegratedPointMaePx', bladeIntegratedPointMae, ...
    'bladeAnchoredAnglesDeg', bladeAnchoredAngles, ...
    'bladeAnchorAnglesDeg', bladeAnchorAngles, ...
    'bladeAnchorQuality', bladeAnchorQuality, ...
    'bladeStepAnglesDeg', bladeStepAngles, ...
    'bladeRawStepAnglesDeg', bladeRawStepAngles, ...
    'bladeTransforms', bladeEstimateH, 'towerDiagnostics', {towerDiagnostics}, ...
    'bladeDiagnostics', {bladeDiagnostics});
results.stage4c = struct('totalMaePx',mixedTotalMae,'microMaePx',mixedMicroMae, ...
    'microFrequencyHz',mixedMicroFrequency,'microTruthFrequencyHz',6.2, ...
    'truthTotalPx',mixedTruth,'estimateTotalPx',mixedEstimate, ...
    'truthMicroPx',mixedMicroTruth,'estimateMicroPx',mixedMicroEstimate, ...
    'diagnostics',{mixedDiagnostics});
save(fullfile(outputDirectory, 'all_stages_results.mat'), 'results');

summaryFigure = figure('Visible', 'off', 'Color', 'w', 'Position', [50 50 1400 850]);
layout = tiledlayout(summaryFigure, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(layout, 'M-PME four-stage reproduction (synthetic/data-ready validation)');
nexttile;
plot((0:gaussianFrameCount-1)/gaussianFps, stage1Truth(:,4), 'k-', 'LineWidth', 1.4); hold on;
plot((0:gaussianFrameCount-1)/gaussianFps, stage1Pme(:,4), 'r--', 'LineWidth', 1.1);
grid on; xlabel('Time (s)'); ylabel('x displacement (px)');
title('Stage 1: PME wrapping, k=4'); legend('Truth','PME','Location','best');
nexttile;
plot((0:gaussianFrameCount-1)/gaussianFps, stage1Truth(:,4), 'k-', 'LineWidth', 1.4); hold on;
plot((0:gaussianFrameCount-1)/gaussianFps, stage1Pme(:,4), 'r:', 'LineWidth', 1.0);
plot((0:gaussianFrameCount-1)/gaussianFps, stage2Mpme(:,4), 'b--', 'LineWidth', 1.1);
grid on; xlabel('Time (s)'); ylabel('x displacement (px)');
title('Stage 2: coarse-to-fine recovery'); legend('Truth','PME','M-PME','Location','best');
nexttile;
plot(rotationAngles, rotationMaeX, 'r-o', rotationAngles, rotationMaeY, 'b-s', 'LineWidth', 1.1);
yline(0.4, 'k--', 'Paper MAE target'); grid on;
xlabel('Cumulative angle (deg)'); ylabel('MAE (px)'); title('Stage 3: rotation');
legend('x','y','Location','best');
nexttile;
plot(towerTime, towerTruthPixels, 'k-', towerTime, towerEstimatePixels, 'b--', 'LineWidth', 1.1);
grid on; xlabel('Time (s)'); ylabel('y displacement (px)'); title('Stage 4a: tower proxy');
legend('Truth','M-PME','Location','best');
nexttile;
plot(bladeTime, bladeTruthY, 'k-', bladeTime, bladeEstimateY, 'b--', 'LineWidth', 1.0);
grid on; xlabel('Time (s)'); ylabel('Point y (px)'); title('Stage 4b: rotating blade proxy');
legend('Truth','M-PME','Location','best');
nexttile;
plot(spectrumFrequency, spectrumAmplitude, 'Color', [0.15 0.35 0.75], 'LineWidth', 1.1); hold on;
xline(bladeTruthFrequency, 'k--'); xline(bladeFrequency, 'r:');
xlim([0 2]); grid on; xlabel('Frequency (Hz)'); ylabel('Amplitude'); title('Stage 4b: response spectrum');
legend('Spectrum','Truth','Estimate','Location','northeast');
exportgraphics(summaryFigure, fullfile(outputDirectory, 'all_stages_summary.png'), 'Resolution', 180);
close(summaryFigure);

%% 控制台摘要
fprintf('\nFour-stage run complete.\n');
fprintf('Stage 1 small-motion PME MAE: %.4f px; k=4 MAE: %.4f px\n', ...
    stage1SmallMotionMae, stage1LargeMotionMae);
fprintf('Stage 2 M-PME MAE [k=1..4]: %s px\n', mat2str(stage2Mae, 4));
fprintf('Stage 3 maximum angle-wise MAE x/y: %.4f / %.4f px\n', ...
    max(rotationMaeX), max(rotationMaeY));
fprintf('Stage 4 tower MAE: %.4f px; recovered sensor lag: %d frames\n', ...
    towerMaePixels, estimatedSensorLagFrames);
fprintf('Stage 4 blade point MAE: integrated %.4f px -> anchored %.4f px\n', ...
    bladeIntegratedPointMae,bladePointMae);
fprintf('Stage 4c total/micro MAE: %.4f / %.4f px; micro frequency %.4f Hz\n', ...
    mixedTotalMae,mixedMicroMae,mixedMicroFrequency);
fprintf('Stage 4 blade frequency: %.4f Hz (truth %.4f Hz, error %.2f%%); point MAE %.4f px\n', ...
    bladeFrequency, bladeTruthFrequency, bladeFrequencyErrorPercent, bladePointMae);
fprintf('Outputs: %s\n', outputDirectory);
fprintf('Figures: %s\n', figureDirectory);
fprintf('Simulation videos: %s\n', videoDirectory);
fprintf('CSV tables: %s\n', tableDirectory);
