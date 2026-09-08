# 用户入口脚本说明

位置：`D:\LunFu\MotionFusionMATLAB\scripts`

六个脚本都调用 `src/run_real_video.m` 和 `src/run_measurement.m`。真正执行逐帧读取、ROI跟踪、参考运动估计、相对位移计算和结果保存的是 `src` 中的核心代码；这些脚本只是不同的配置入口，不能把它们理解成六套独立算法。

## 1. `run_user_video.m`：主入口

这是当前推荐的单视频入口。运行前主要修改视频路径、输出目录和五个配置区：

1. 输入与采样率：`videoPath`、`outputRoot`、`captureFPS`、`maxFrames`、`axis`。
2. 目标 ROI：第一帧交互框选目标，或改为 `manual` 填写 `[x y width height]`。
3. 宏观参考：默认 `translation + interactive`，依次框选目标和一个刚性参考区域。
4. 图像配准：默认 `targetMode='direct'`、`referenceTracker='flow'`。
5. 输出：默认不带通、不做 denoise，只保存原始测量和诊断图。

执行流程是：

```text
第一帧框选目标/参考
        ↓
run_real_video(u)
        ↓
resolve_rois 确定 ROI 和参考模型
        ↓
run_measurement 逐帧跟踪
        ↓
目标位移 - 宏观参考位移
        ↓
保存 result.mat、traces.csv、波形/频谱图
```

`analysisBandHz=[]` 时，频谱是原始测量频谱；它不会因为图形显示而自动去除低频大运动。三角光、激光等数据不进入跟踪或参数选择，只能在测量完成后独立评价。

## 2. `run_user_video_motion.m`：无参考运动分离诊断入口

这个脚本设置：

- `referenceModel='none'`：只测目标总位移；不声称已经消除了相机或结构大运动。
- `targetMode='profile'`：使用旧的剖面型目标测量器。
- `motionCutoffHz=3`、`motionOrder=4`：额外生成低频宏观趋势和振动候选。
- `exportTrackingVideo=true`：输出独立的追踪叠加视频。

它适合回答“没有参考区域时，低频运动分离模块表现如何”，不适合作为有参考 ROI 时的主配置。`05_motion_separation` 或对应的 `motion_separation_x.csv` 是候选分离结果，不能当作已经通过外部传感器验证的最终振动。

## 3. `run_user_video_baseline.m`：旧基线复现实验

这是用于保留旧方法对照的入口：

- `referenceModel='translation'`：目标减一个参考区域的平移。
- `targetMode='profile'`：旧剖面测量。
- `referenceTracker='anchor'`：固定模板式参考跟踪。
- `analysisBandHz=[2 45]`、`denoise=true`：生成带通和模态诊断。
- 同时导出追踪视频。

它的作用是和当前 `direct + flow` 配置比较速度、波形和频谱变化。它不是当前推荐的主入口，也不能把其中的带通后曲线当成原始测量结果。

## 4. `run_user_video_automatic.m`：自动寻找参考区域的交互入口

这个脚本只要求用户在第一帧框选目标 ROI，参考小块由 `referenceSelection='automatic'` 自动从搜索区域中寻找。

主要设置：

- `referenceModel='translation'`
- `targetMode='profile'`
- `referenceTracker='anchor'`
- `searchROI=[]` 表示在整幅图搜索；也可以填写 `[x y width height]` 限定同一运动物体范围。

自动选择只根据第一帧图像纹理、候选块质量和参考之间的一致性工作，不读取激光、三角光或目标频率。若搜索范围内包含多个独立运动物体，自动参考可能被拒绝或产生歧义，此时应使用手动参考入口。

## 5. `run_user_video_auto.m`：可被其他脚本调用的函数接口

它不是直接打开 MATLAB 编辑器运行的脚本，而是函数：

```matlab
result = run_user_video_auto(videoPath, outputRoot, targetROI, searchROI, overrides)
```

参数含义：

- `videoPath`：视频文件路径。
- `outputRoot`：结果根目录。
- `targetROI`：已经确定的目标框 `[x y width height]`。
- `searchROI`：自动寻找参考的范围，可为空表示全图。
- `overrides`：可选结构体，用来覆盖默认公开参数。

函数内部固定使用手动目标 ROI、自动参考、平移模型和 anchor 参考跟踪，然后调用 `run_real_video`。它适合批量实验或其他 MATLAB 函数复用，避免每次弹出目标 ROI 框选窗口。

## 6. `refresh_video_outputs.m`：只刷新后处理输出

调用方式：

```matlab
refresh_video_outputs('D:\LunFu\MotionFusionMATLAB\outputs\某个结果根目录')
```

它不会重新读取视频，也不会重新跟踪 ROI。脚本会：

1. 查找各视频目录中的 `result.mat`。
2. 将已有波形、频谱和 `02_*`、`03_*` 文件复制到 `signal_history\时间戳`。
3. 从 `result.signals.*.raw` 重新调用 `mfm.clean_signal`。
4. 更新 `result.mat` 并重新导出图形。

因此它适合修改带通、clean 或频谱显示逻辑后的快速重绘，不能用来修复跟踪错误或 ROI 错误。

## 输出文件的共同关系

- `result.mat`：逐帧位移、参考位移、相对位移、有效性、采样率和配置。
- `traces.csv`：便于表格检查的逐帧跟踪结果。
- `02_waveform*`：总位移、参考位移、原始相对位移和有效性相关图。
- `03_spectrum*`：原始或宽带处理后的频谱，取决于 `analysisBandHz`。
- `04_*`：可选的带通/模态诊断图；它不替换 `result.relative`。
- `tracking_overlay.avi`：只有 `exportTrackingVideo=true` 时生成，渲染时间与算法测量时间分开记录。

## 推荐选择

- 日常单视频测量：`run_user_video.m`。
- 有参考 ROI 的旧方法对照：`run_user_video_baseline.m`。
- 没有参考 ROI 时检查总运动与低频分离：`run_user_video_motion.m`。
- 目标框已知、希望自动找参考：`run_user_video_automatic.m`。
- 批量代码或其他函数调用：`run_user_video_auto.m`。
- 只改变 clean、频带或频谱图：`refresh_video_outputs.m`。
