function results = run_tddm(frames, initialCenter, initialROI, cfg)
%RUN_TDDM 执行论文的 Tracking -> Detecting -> Correction -> IC-GN 数据流。
% frames 可以是图像 cell 数组或图像文件路径 cell 数组。
if nargin < 4, cfg = paper_config(); end
if iscell(frames)
    if isempty(frames), error('frames cannot be empty.'); end
    frameCount = numel(frames);
    getFrame = @(idx) frames{idx};
elseif isstruct(frames) && isfield(frames, 'count') && isfield(frames, 'getFrame')
    frameCount = frames.count;
    getFrame = frames.getFrame;
else
    error('frames must be a cell array or a stream struct with count/getFrame.');
end
referenceFrame = read_frame(getFrame(1));
referenceCenter = double(initialCenter(:)');
diameter = cfg.impl.syntheticMarkerDiameter;
if numel(initialROI) >= 4
    diameter = max(4, min(initialROI(3), initialROI(4)) / 2);
end
featurePoints = init_klt_points(referenceFrame, initialROI, cfg);
previousFrame = referenceFrame;
previousCenter = referenceCenter;
empty = struct('frame', 0, 'pTracking', [NaN NaN], 'pDetection', [NaN NaN], ...
    'pCorrected', [NaN NaN], 'pFinal', [NaN NaN], 'NCC_T', NaN, 'NCC_D', NaN, ...
    'q', NaN(6,1), 'ZNSSD', NaN, 'ICGNConverged', false, 'ICGNIterations', 0, ...
    'failureReason', '', 'fusionMode', '', 'fbErrorMedian', NaN);
results = repmat(empty, 1, frameCount);
results(1).frame = 1;
results(1).pTracking = referenceCenter;
results(1).pDetection = referenceCenter;
results(1).pCorrected = referenceCenter;
results(1).pFinal = referenceCenter;
results(1).q = zeros(6,1);
results(1).ZNSSD = 0;
results(1).ICGNConverged = true;
results(1).failureReason = '';

% 真实视频可通过 cfg.video.progressEveryFrames 显示处理进度；合成实验默认关闭。
progressEvery = 0;
showProgress = false;
if isfield(cfg,'video')
    if isfield(cfg.video,'progressEveryFrames') && isfinite(cfg.video.progressEveryFrames)
        progressEvery = max(0,round(cfg.video.progressEveryFrames));
    end
    if isfield(cfg.video,'showProgress'), showProgress = logical(cfg.video.showProgress); end
end

for i = 2:frameCount
    current = read_frame(getFrame(i));
    results(i).frame = i;
    failure = {};
    if cfg.impl.enableTracking
        tr = track_klt(previousFrame, current, featurePoints, cfg);
    else
        tr = struct('success',false,'failureReason','tracking_disabled');
    end
    if tr.success
        good = tr.valid;
        d = tr.currPoints(good,:) - tr.prevPoints(good,:);
        pT = previousCenter + median(d, 1);
        featurePoints = tr.currPoints(good,:);
        results(i).fbErrorMedian = median(tr.fbError(good));
    else
        [pT, ~, okTM] = template_match_integer(previousFrame, current, previousCenter, ...
            floor(cfg.paper.templateSize/2), 5);
        if ~okTM
            pT = previousCenter;
        end
        featurePoints = init_klt_points(current, [pT(1)-diameter, pT(2)-diameter, ...
            2*diameter, 2*diameter], cfg);
        failure{end+1} = tr.failureReason; %#ok<AGROW>
    end
    results(i).pTracking = pT;

    side = max(cfg.paper.templateSize, round(cfg.impl.roiWindowFactor * diameter));
    [localROI, origin, localHint] = crop_marker_roi(current, pT, side);
    if cfg.impl.enableDetection
        if isfield(cfg.impl,'detectorMode') && strcmpi(cfg.impl.detectorMode,'texture')
            det = detect_texture_match(previousFrame,current,previousCenter,pT,localROI,origin,cfg);
        else
            det = detect_marker(localROI, diameter, cfg, localHint);
        end
    else
        det = [];
    end
    if isempty(det)
        pD = [NaN NaN];
        failure{end+1} = 'local_detection_failed'; %#ok<AGROW>
    else
        pD = det.center + origin - 1;
        if isfield(cfg.impl,'detectorMode') && strcmpi(cfg.impl.detectorMode,'texture')
            pD = det.center;
        end
    end
    results(i).pDetection = pD;

    [refPatch, validRef] = extract_patch(previousFrame, previousCenter, floor(cfg.paper.templateSize/2));
    [trackPatch, validTrack] = extract_patch(current, pT, floor(cfg.paper.templateSize/2));
    if all(validRef(:)) && all(validTrack(:))
        nccT = ncc_patch(refPatch, trackPatch);
    else
        nccT = -Inf;
    end
    if all(isfinite(pD))
        [detPatch, validDet] = extract_patch(current, pD, floor(cfg.paper.templateSize/2));
        if all(validRef(:)) && all(validDet(:))
            nccD = ncc_patch(refPatch, detPatch);
        else
            nccD = -Inf;
        end
    else
        nccD = -Inf;
    end
    results(i).NCC_T = nccT;
    results(i).NCC_D = nccD;
    if isfield(cfg.fusion, 'mode') && strcmpi(cfg.fusion.mode, 'paper_literal') && all(isfinite(pD))
        dT = pT - previousCenter; dD = pD - previousCenter;
        dCor = fuse_paper_literal(dT, dD, pD-pT, nccT, nccD, cfg.paper.nccGate);
        pCor = previousCenter + dCor; fusionMode = 'paper_literal';
    else
        [pCor, fusionMode] = fuse_positions(pT, pD, nccT, nccD, cfg.paper.nccGate);
    end
    results(i).pCorrected = pCor;
    results(i).fusionMode = fusionMode;

    q0 = [pCor(1)-referenceCenter(1); pCor(2)-referenceCenter(2); zeros(4,1)];
    if cfg.impl.enableICGN
        [q, info] = affine_icgn(referenceFrame, current, referenceCenter, q0, cfg);
    else
        q = q0;
        [refForMetric, ~] = extract_patch(referenceFrame, referenceCenter, floor(cfg.paper.templateSize/2));
        [curForMetric, validMetric] = extract_patch(current, pCor, floor(cfg.paper.templateSize/2));
        if all(validMetric(:)), metric = znssd(refForMetric, curForMetric); else, metric = NaN; end
        info = struct('converged',true,'iterations',0,'ZNSSD',metric,'engine','disabled');
    end
    results(i).q = q;
    results(i).ZNSSD = info.ZNSSD;
    results(i).ICGNConverged = info.converged;
    results(i).ICGNIterations = info.iterations;
    pFinal = referenceCenter + q(1:2)';
    results(i).pFinal = pFinal;
    if ~info.converged
        failure{end+1} = 'icgn_not_converged'; %#ok<AGROW>
    end
    results(i).failureReason = strjoin(failure, '|');
    if isfield(cfg.impl,'saveProcess') && cfg.impl.saveProcess && any(cfg.impl.processFrames == i)
        save_tddm_process_frame(i, previousFrame, current, localROI, pT, pD, pCor, pFinal, ...
            nccT, nccD, q, info, cfg.impl.processOutputRoot, det);
    end
    previousFrame = current;
    previousCenter = pFinal;
    if isempty(featurePoints)
        featurePoints = init_klt_points(current, [pFinal(1)-diameter, pFinal(2)-diameter, ...
            2*diameter, 2*diameter], cfg);
    end
    if showProgress && progressEvery > 0 && (i == 2 || mod(i,progressEvery) == 0 || i == frameCount)
        fprintf('[TDDM] frame %d/%d (%.1f%%)\n',i,frameCount,100*i/max(frameCount,1));
    end
end
end

function I = read_frame(frame)
if ischar(frame) || isstring(frame)
    I = imread(frame);
else
    I = frame;
end
if size(I, 3) == 3
    I = rgb2gray(I);
end
I = im2double(I);
end
