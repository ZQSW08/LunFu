# RMPTF：可靠、测量保持型跟踪公共前端

RMPTF（Reliable Measurement-Preserving Tracking Frontend）服务于 `MPME`、`BPAF` 和 `AP-CV`。它是研究扩展，不属于三篇论文的原始 baseline。

核心约束：

- raw tracking 只回答“同一目标在哪里”；
- compensation trajectory 只驱动固定尺寸整数 ROI，不做亚像素图像稳像；
- 低可靠帧冻结外观更新，短时预测，随后用永久首帧 anchor 局部/全局重检测；
- `full / trend / integer_macro / robust_macro / adaptive_macro / band_protected / geometry_follow` 可做测量保持消融；
- 可选 Fourier phase correlation 粗定位和 Complex-Gabor 十字线 phase-zero-crossing 精定位；
- 三个论文后端的相位公式均保持不变，最终全局位移由“整数裁剪位移 + 后端局部残差”恢复。

MATLAB 使用：

```matlab
addpath('D:\LunFu\shared\RMPTF\src');
cfg = rmptf.default_config();
cfg.compensation.mode = 'band_protected';
cfg.compensation.targetBandHz = [5 8];
[frames,fps,roiTrajectory,tracking] = rmptf.process_video( ...
    videoPath,maxFrames,initialRoi,cfg,previewPath);
```

完整阶段实验与三后端验收：

```matlab
addpath('D:\LunFu\shared\RMPTF\experiments');
run_stage_experiments('D:\LunFu\cross_method_experiments\stage_matrix_full',true);
run_crossline_route_comparison('D:\LunFu\cross_method_experiments\crossline_routes_full');
run_backend_acceptance('D:\LunFu\cross_method_experiments\backend_acceptance_final');
```

正式入口默认采用单遍 `rmptf` hybrid；需要 fDSST 粗跟踪时显式改成 `rmptf_fdsst`，有十字标志时可用 `rmptf_crossline` 或 `rmptf_fdsst_crossline`。画面中的大黄色框（初始 ROI 图）只是 Tracking 搜索上下文，不是第二个 tracker 输出；视频中黄色 bbox 才是实际目标框，青色框是 Analysis guard band。完整阶段核对见 `D:\LunFu\STAGE_IMPLEMENTATION_MATRIX.md`。

`cfg.tracker.useSafeMatlabFeatures=true`（默认）会用纯 MATLAB FHOG/resize 兼容层替代旧 fDSST MEX：精度在当前对照中不变，但 180 帧约慢一倍。仅在已验证二进制兼容性后才可设为 `false` 使用原 MEX。

统一合成验证：

```matlab
addpath('D:\LunFu\shared\RMPTF\tests');
run_synthetic_validation('D:\LunFu\cross_method_experiments\synthetic_validation');
```
