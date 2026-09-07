function positions = run_detection_sequence(frames, initialCenter, expectedDiameter, cfg)
%RUN_DETECTION_SEQUENCE 逐帧全图检测，用于论文 Detection 对照。
if iscell(frames)
    n = numel(frames); getFrame = @(i) frames{i};
else
    n = frames.count; getFrame = frames.getFrame;
end
center = double(initialCenter(:)');
positions = NaN(n, 2); positions(1,:) = center;
for i = 2:n
    I = getFrame(i);
    det = detect_marker(I, expectedDiameter, cfg, center);
    if isempty(det)
        positions(i,:) = positions(i-1,:);
    else
        positions(i,:) = det.center;
    end
    center = positions(i,:);
end
end
