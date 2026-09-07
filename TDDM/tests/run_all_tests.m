function report = run_all_tests(cfg)
%RUN_ALL_TESTS 只执行与当前复现核心风险直接相关的最小数学验证。
report = struct();
report.ncc = test_ncc();
report.affine = test_affine();
report.icgn = test_icgn_translation(cfg);
report.detector = test_detector(cfg);
report.coordinates = test_coordinate_system();
disp('TDDM core tests passed.');
end
