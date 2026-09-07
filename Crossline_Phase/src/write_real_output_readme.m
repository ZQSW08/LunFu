function write_real_output_readme(outDir, videoPath, roi, fps, nFrames, validRate, runtimeSummary)
%WRITE_REAL_OUTPUT_README 为每次真实视频处理写入简短的结果说明。
% 便于用户直接区分波形、频谱、原始表格和 MATLAB FIG 文件。
if nargin < 7, runtimeSummary = struct(); end
[~, baseName, ext] = fileparts(char(videoPath));
if isempty(ext), videoName = baseName; else, videoName = [baseName ext]; end

fid = fopen(fullfile(outDir, 'README.txt'), 'w');
if fid < 0, warning('Crossline:OutputReadme', '无法写入结果说明文件。'); return; end
c = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'Crossline Phase 真实视频结果\r\n');
fprintf(fid, '==============================\r\n\r\n');
fprintf(fid, '输入视频：%s\r\n', videoName);
fprintf(fid, 'ROI：[x y width height] = [%.1f %.1f %.1f %.1f]\r\n', roi);
fprintf(fid, '处理帧率：%.4f Hz；处理帧数：%d；有效率：%.2f%%\r\n\r\n', fps, nFrames, 100*validRate);

fprintf(fid, '重点查看文件\r\n');
fprintf(fid, '--------------\r\n');
fprintf(fid, '1) crossline_waveform.png：x、y 图像平面位移波形；红点为有效检测，蓝叉为异常/无效帧。\r\n');
fprintf(fid, '   crossline_waveform.fig：同一张波形图的 MATLAB 可编辑版本，保存时 Visible 固定为 on。\r\n');
fprintf(fid, '2) crossline_spectrum.png：x、y 位移的一侧 FFT 频谱，横轴为 Hz；黑线为去均值 Hann 窗 FFT，灰线为未加窗原始 FFT；\r\n');
fprintf(fid, '   crossline_spectrum.fig：同一张频谱图的 MATLAB 可编辑版本，保存时 Visible 固定为 on。\r\n');
fprintf(fid, '   crossline_spectrum.mat：频率向量、Hann 窗幅值和原始幅值数组，可用于精确读取峰值。\r\n');
fprintf(fid, '   若配置了已知激励频率，还会生成 crossline_spectrum_zoom.png/.fig，专门放大目标频率附近。\r\n');
fprintf(fid, '3) crossline_trajectory.csv：每帧位置、ROI、几何量、帧间跳变和 valid 标志。\r\n');
fprintf(fid, '4) crossline_results.mat：完整 MATLAB 结果及运行时间统计。\r\n');
fprintf(fid, '5) 01_initial_roi.png：实际确认的初始 ROI。\r\n\r\n');

fprintf(fid, '频谱阅读提示\r\n');
fprintf(fid, '--------------\r\n');
fprintf(fid, '频谱中的每个峰不一定对应一个真实振动源。有限时长、非整周期截断、噪声、运动模糊、\r\n');
fprintf(fid, '异常定位点和大运动波形的谐波都会产生旁瓣或额外峰。应结合波形、valid 标志和\r\n');
fprintf(fid, 'crossline_spectrum.mat 中的幅值共同判断；已知激励频率附近的稳定峰通常更可信。\r\n');
fprintf(fid, '本工程不静默删除峰值，也不把频谱峰自动等同于物理频率。\r\n\r\n');

if isfield(runtimeSummary, 'mean_s_per_frame')
    fprintf(fid, '运行统计\r\n');
    fprintf(fid, '----------\r\n');
    fprintf(fid, '平均单帧：%.6f s；吞吐：%.3f fps；fastMode：%d\r\n', ...
        runtimeSummary.mean_s_per_frame, runtimeSummary.throughput_fps, runtimeSummary.fastMode);
    if isfield(runtimeSummary, 'rejectLargeJumps')
        fprintf(fid, '异常帧间跳变门控：%d；门限：%.3f pixel\r\n', ...
            runtimeSummary.rejectLargeJumps, runtimeSummary.maxFrameJumpPx);
    end
end
end
