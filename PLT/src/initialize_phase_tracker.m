function state = initialize_phase_tracker(firstFrame, roi, cfg)
% INITIALIZE_PHASE_TRACKER 建立首帧特征和不可更新的 anchor。

gray = to_gray_double_local(firstFrame);
pyramid = build_complex_gabor_pyramid(gray, cfg);
state = struct();
state.anchor = build_phase_template(gray, roi, pyramid, cfg);
state.templateBank = phase_template_bank(state.anchor,[],[]);
state.previousCenter = state.anchor.center;
state.previousPreviousCenter = state.anchor.center;
state.velocity = [0 0];
state.predictedCenter = state.anchor.center;
state.lastPyramid = pyramid;
state.frameIndex = 1;
state.status = 'PHASE_TRACK_OK';
state.lostCount = 0;
state.lastTemplateSource = 'anchor';
state.lastTemplateUpdated = false;
end

function img = to_gray_double_local(frame)
frame = double(frame);
if ndims(frame) == 3
    img = 0.298936*frame(:,:,1) + 0.587043*frame(:,:,2) + 0.114021*frame(:,:,3);
else
    img = frame;
end
if max(img(:)) > 1, img = img/255; end
img(~isfinite(img)) = 0;
end
