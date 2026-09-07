function features = extract_phase_features(data, cfg, cachePath)
%EXTRACT_PHASE_FEATURES 按论文第3.1与3.4节提取最高频带局部相位和幅值权重。

if nargin < 3 || isempty(cachePath)
    cachePath = fullfile(cfg.resultDir, [lower(data.spec.id), '_phase_features.mat']);
end
if isfile(cachePath) && ~cfg.forceReextract
    features = load(cachePath);
    return;
end

startIndex = max(1, round(data.spec.analyzeStart * data.spec.fs) + 1);
count = round(data.spec.analyzeDuration * data.spec.fs);
endIndex = min(size(data.frames, 3), startIndex + count - 1);
frameIndices = startIndex:endIndex;
nFrames = numel(frameIndices);

firstFrame = im2double(data.frames(:, :, frameIndices(1)));
[pyr, pind] = buildSCFpyr(firstFrame, cfg.pyramidHeight, cfg.pyramidOrder);
band = spyrBand(pyr, pind, 1, cfg.orientationBand);
[bandH, bandW] = size(band);
phaseCube = zeros(bandH, bandW, nFrames, 'single');
spatialWeight = zeros(bandH, bandW, nFrames, 'single');
measurementMask=true(bandH,bandW);
if isfield(data,'measurementRoi') && ~isempty(data.measurementRoi)
    roi=double(data.measurementRoi);
    x1=max(1,floor((roi(1)-1)*bandW/size(data.frames,2))+1);
    y1=max(1,floor((roi(2)-1)*bandH/size(data.frames,1))+1);
    x2=min(bandW,ceil((roi(1)+roi(3)-1)*bandW/size(data.frames,2)));
    y2=min(bandH,ceil((roi(2)+roi(4)-1)*bandH/size(data.frames,1)));
    measurementMask=false(bandH,bandW); measurementMask(y1:y2,x1:x2)=true;
end

for outIdx = 1:nFrames
    frame = im2double(data.frames(:, :, frameIndices(outIdx)));
    [pyr, pind] = buildSCFpyr(frame, cfg.pyramidHeight, cfg.pyramidOrder);
    band = spyrBand(pyr, pind, 1, cfg.orientationBand);
    amplitude = abs(band);
    phaseCube(:, :, outIdx) = single(angle(band));

    % 论文式(28)：点幅值除以局部幅值标准差，再归一化到[0,1]。
    localStd = stdfilt(amplitude, true(cfg.localStdWindow));
    score = amplitude ./ max(localStd, 1e-8);
    score = score - min(score, [], 'all');
    score = score ./ max(max(score, [], 'all'), 1e-8);
    score(~measurementMask)=0;
    spatialWeight(:, :, outIdx) = single(score);
end

% 论文第3.1节：沿时间维进行2*pi相位展开。
phaseCube = unwrap(phaseCube, [], 3);
weighted = phaseCube .* spatialWeight;
rawSignal = squeeze(sum(weighted, [1, 2]) / (bandH*bandW));
rawSignal = double(rawSignal(:));

features = struct();
features.phaseCube = phaseCube;
features.spatialWeight = spatialWeight;
features.rawSignal = rawSignal;
features.time = (0:nFrames-1)' / data.spec.fs;
features.fs = data.spec.fs;
features.frameIndices = frameIndices;
features.spec = data.spec;
features.truthVibration = data.truth.vibrationPx(frameIndices);
features.truthLargeMotion = data.truth.largeMotionPx(frameIndices);
features.measurementMask=measurementMask;
features.cachePath = cachePath;
save(cachePath, '-struct', 'features', '-v7.3');
end
