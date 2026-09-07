function ok = test_detector(cfg)
%TEST_DETECTOR 验证圆标记的局部检测能返回有限中心。
[I, center] = make_synthetic_image(cfg);
det = detect_marker(I, cfg.impl.syntheticMarkerDiameter, cfg, center);
assert(~isempty(det));
assert(norm(det.center-center) < 2.0);
ok = true;
end
