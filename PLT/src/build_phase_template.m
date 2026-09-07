function template = build_phase_template(grayFrame, roi, pyramid, cfg)
% BUILD_PHASE_TEMPLATE 保存首帧的 immutable anchor 模板。
% 模板包含自然纹理 ROI 内的 amplitude、phase、unit phasor 和可靠性掩码。

grayFrame = double(grayFrame);
x = roi(1); y = roi(2); w = roi(3); h = roi(4);
template = struct();
template.roi = double(roi(:).');
template.center = [x + (w-1)/2, y + (h-1)/2];
template.grayCrop = grayFrame(y:y+h-1, x:x+w-1);
template.channels = pyramid;

for s = 1:size(pyramid,1)
    for o = 1:size(pyramid,2)
        template.channels(s,o).amplitude = pyramid(s,o).amplitude(y:y+h-1, x:x+w-1);
        template.channels(s,o).phase = pyramid(s,o).phase(y:y+h-1, x:x+w-1);
        template.channels(s,o).unitPhasor = pyramid(s,o).unitPhasor(y:y+h-1, x:x+w-1);
        template.channels(s,o).reliability = pyramid(s,o).reliability(y:y+h-1, x:x+w-1);
    end
end
template.numValidPixels = sum(template.channels(1,1).reliability(:));
template.phaseCongruencySupport = compute_phase_congruency_support(template.channels);
template.methodName = cfg.method.name;
end
