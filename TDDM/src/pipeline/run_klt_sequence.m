function positions = run_klt_sequence(frames, initialCenter, initialROI, cfg)
%RUN_KLT_SEQUENCE 仅运行论文中的初始 KLT tracking，作为振动对照。
if iscell(frames)
    n = numel(frames); getFrame = @(i) frames{i};
else
    n = frames.count; getFrame = frames.getFrame;
end
prev = to_gray_double(getFrame(1));
center = double(initialCenter(:)');
pts = init_klt_points(prev, initialROI, cfg);
positions = NaN(n, 2); positions(1,:) = center;
for i = 2:n
    curr = to_gray_double(getFrame(i));
    tr = track_klt(prev, curr, pts, cfg);
    if tr.success
        good = tr.valid;
        center = center + median(tr.currPoints(good,:) - tr.prevPoints(good,:), 1);
        pts = tr.currPoints(good,:);
    else
        [center, ~, ok] = template_match_integer(prev, curr, center, floor(cfg.paper.templateSize/2), 5);
        if ~ok, center = positions(i-1,:); end
        pts = init_klt_points(curr, [center(1)-20 center(2)-20 40 40], cfg);
    end
    positions(i,:) = center;
    prev = curr;
end
end

function I = to_gray_double(I)
if size(I,3) == 3, I = rgb2gray(I); end
I = im2double(I);
end
