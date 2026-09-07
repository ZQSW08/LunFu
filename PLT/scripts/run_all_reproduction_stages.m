function run_all_reproduction_stages()
% RUN_ALL_REPRODUCTION_STAGES 执行研究报告中 V1/V2 的全部软件验证阶段。
% V1 图像跟踪由 run_reproduction 生成；这里追加周期、扰动、解耦和边界测试。

close all; clc; scriptPath=mfilename('fullpath'); projectRoot=fileparts(fileparts(scriptPath));
cfg=default_config(projectRoot); setup_project(cfg); addpath(fullfile(projectRoot,'tests'));
run_reproduction;
summary=struct(); summary.phaseWrap=test_phase_wrap_similarity(); summary.complexInterpolation=test_complex_interpolation(); summary.translation=test_translation(cfg); summary.periodicTexture=test_periodic_texture(); summary.noiseLightingBlur=test_noise_lighting_blur(cfg); summary.largePlusMicro=test_large_plus_micro(); summary.frequencyProximity=test_frequency_proximity(); summary.v3Predictive=test_v3_predictive_tracking();
outDir=fullfile(projectRoot,'outputs','all_stages'); if isfolder(outDir), rmdir(outDir,'s'); end, mkdir(outDir);
v2case=summary.largePlusMicro; coordinate=build_measurement_coordinate(v2case.dTotal,v2case.dMacroBandProtected);
save_decomposition_outputs(outDir,coordinate,v2case.dVibBandProtected,v2case.fps,cfg);
save(fullfile(outDir,'stage_summary.mat'),'summary','-v7.3'); fid=fopen(fullfile(outDir,'stage_summary.json'),'w','n','UTF-8'); if fid>0, fwrite(fid,jsonencode(summary),'char'); fclose(fid); end
fprintf('All reproduction stages completed.\n'); fprintf('periodic false-peak rates: %s\n',mat2str(summary.periodicTexture.falsePeakRate,4));
fprintf('temporal MSR=%.4f, band-protected MSR=%.4f, spatial MSR=%.4f\n',summary.largePlusMicro.metricsTemporal.MSR,summary.largePlusMicro.metricsBandProtected.MSR,summary.largePlusMicro.metricsSpatial.MSR);
fprintf('V3 median error=%.3f px, recovery count=%d, template updates=%d\n',summary.v3Predictive.medianCenterErrorPx,summary.v3Predictive.recoveryCount,summary.v3Predictive.templateUpdateCount);
fprintf('Outputs: %s\n',outDir);
end
