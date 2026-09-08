"""Audit frozen outputs and summarize actual results; no measurement code."""
from pathlib import Path
import sys,json,hashlib
import numpy as np
import pandas as pd
from scipy.io import loadmat
ROOT=Path(__file__).resolve().parent
BASE=ROOT/'outputs'/'real_v3'
REVIEW=ROOT/'review_upgrade';REVIEW.mkdir(exist_ok=True)
def hashes():
    return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for pattern in ['*/result.mat','*/waveform_*.csv','*/spectrum_*.csv','*/config.json','*/roi_provenance.json'] for p in BASE.glob(pattern)}
if '--freeze' in sys.argv:
    (REVIEW/'before_laser_hashes.json').write_text(json.dumps(hashes(),indent=2));print('Frozen',len(hashes()),'measurement files');sys.exit()
before=json.loads((REVIEW/'before_laser_hashes.json').read_text());after=hashes();changed=[p for p in before if before[p]!=after.get(p)]
assert not changed,changed
(REVIEW/'laser_isolation_check.json').write_text(json.dumps({'checked_files':len(before),'changed_measurement_files':changed},indent=2))
metrics=pd.read_csv(BASE/'comparison_all.csv');details=[]
for p in sorted(BASE.glob('*/result.mat')):
    r=loadmat(p,simplify_cells=True);s=r['signals']['x'];roi=np.asarray(r['cfg']['rois'])[0];source=r['roiProvenance']['targetSource'];old=loadmat(source,variable_names=['roi'],simplify_cells=True)['roi'];assert np.array_equal(roi,old)
    spectrum=pd.read_csv(p.parent/'spectrum_x.csv');f=spectrum.frequency_Hz.to_numpy();broad=spectrum.broad_amplitude_px.to_numpy();clean=spectrum.clean_amplitude_px.to_numpy();bands=np.asarray(s['bandsHz']).reshape(-1,2);inside=np.zeros(len(f),bool)
    for a,b in bands:inside|=(f>=a)&(f<=b)
    within=(f>=2)&(f<=45);outside=within&~inside
    suppression=10*np.log10(max(np.sum(broad[outside]**2),1e-30)/max(np.sum(clean[outside]**2),1e-30)) if len(bands) else np.nan
    previous=ROOT/'outputs'/'real_v2'/p.parent.name/'result.mat';r0=loadmat(previous,simplify_cells=True)
    details.append(dict(video=p.parent.name,roi=str(roi.tolist()),roi_source=source,measured_fraction=float(np.mean(r['geometryValid'])),clean_fraction=float(np.mean(np.isfinite(s['clean']))),modes_hz=str(np.atleast_1d(s['modesHz']).round(3).tolist()),outside_mode_suppression_db=suppression,measurement_seconds=r['algorithmSeconds'],postprocessing_seconds=r['postprocessSeconds'],v2_seconds=r0['algorithmSeconds'],speed_gain_percent=100*(1-r['algorithmSeconds']/r0['algorithmSeconds'])))
d=pd.DataFrame(details);d.to_csv(REVIEW/'video_summary.csv',index=False);metrics.to_csv(REVIEW/'laser_metrics.csv',index=False)
def table(frame):
    return '| '+' | '.join(frame.columns)+' |\n| '+' | '.join(['---']*len(frame.columns))+' |\n'+'\n'.join('| '+' | '.join('未定义' if pd.isna(v) else f'{v:.4f}' if isinstance(v,float) else str(v) for v in row)+' |' for row in frame.itertuples(index=False,name=None))
text=f'''# 2026-09-06 升级报告：保存 ROI、视频独立降噪与标准输出

## 本轮落实的四项要求

1. 六段实拍的目标 ROI 均从对应 MPME `real_data_result.mat` **只读取 roi 变量**，并逐一数值核对相等。参考 ROI 读取之前保存的图像跟踪配置。每段都有 `roi_provenance.json` 和 `01_first_frame_rois.png/.fig`。青色框是原保存目标，绿色框是其内部实际测量支持，橙色框是刚性参考。绿色窗口依据首帧图像选取，没有使用激光、文件名中的频率或目标波形。
2. 测量入口 `run_real_video` 和公共配置 `mfm.real_defaults` 没有激光参数；`compare_laser_v2` 是独立后处理。此次评价前后逐一核对 {len(before)} 个算法输出文件 SHA-256，改变数量为 {len(changed)}。评价只在 evaluation 子目录和单独的对照图中写入结果，没有覆盖测量波形。
3. 正式输出为 `outputs/real_v3/视频文件名（去扩展名）/`。每段有独立波形与频谱 PNG、FIG、CSV，FIG 在保存前设置 Visible=on，重新加载检查。旧同名输出仅在带 `.mfm_output` 标记时自动归档到 `_history`；不会删除原始视频或其他工程文件。
4. `run_user_video.m` 只需修改顶部配置：视频路径、输出根目录、采集帧率、最大帧数、测量方向、ROI模式/来源/坐标、参考区域、分析频带、降噪与显示开关。支持 x/y；xy 需要 texture。对未保存参考的新视频会在首帧提示选择刚性参考。

## 具体算法升级

目标框内先选取一致的行；检测到右边缘更亮且有暗谷隔开的外壳时，仅收缩内部测量支持，避免匹配换目标。单边轮廓不强行同时估计平移与宽度，降低不可辨识自由度。参考定位先验证预测位置的归一化相关，达到0.90才省略完整搜索；否则运行原搜索与精配准。两种路径仍须通过亚像素图像残差门控。

降噪属于**视频证据支持的稳定模态提取**：2秒窗、1秒步长，在至少4个时间窗检查频谱显著性、出现比例和相位一致性。缺帧在频率估计中使用原时间坐标且权重为零，不插值成测量数据。多个稳定峰可以同时保留；证据不足或模态过多时保留宽带结果并给出状态。频率全部从视频估计，没有指定13或27 Hz。窄带范围由视频估计中心±至少1.25 Hz确定。

必须区分三个结果：raw_relative_px 是未滤波空间相对位移；broad_px 是配置频带内的测量分量；clean_modal_px 是含稳定模态假设的滤波结果，不是对所有真实宽带/瞬态运动的完整恢复。原始波形、缺测和所有被滤掉的成分都可复查。

## 六段真实视频与速度

{table(d[['video','measured_fraction','clean_fraction','modes_hz','outside_mode_suppression_db','measurement_seconds','speed_gain_percent']])}

outside_mode_suppression_db 表示相同连续时间区间和幅度刻度上，2–45 Hz 内、自动选择模态频带之外的频谱功率降低量。它说明滤波抑制了多少带外分量，不证明那些成分全是噪声，更不是绝对精度。部分视频保留约10 Hz的稳定次峰，没有按激光答案强删。速度比较为本轮 v2 与 v3 的测量阶段耗时，不包含绘图；乱动案例 v2 曾失效，因此其速度数字不能独立表示公平精度条件下的排名。

## 激光仅用于事后对比

{table(metrics[['videoName','method','samples','coverage','pcc','rmsePx','nrmseToLaser','status']])}

激光CSV第3列、采样率100 Hz沿用既有实验设定，<=-900按无效值处理；未独立核实硬件同步时间戳。前半段只用宽带视频拟合一次延迟、符号和像素比例，宽带与降噪结果共用这些参数，再比较后半段同一批有效样本。延迟候选须保留至少85%的可用后半段时间覆盖，但没有用后半段波形选择延迟。NRMSE使用同一个拟合激光信号标准差作分母。不能把拟合比例当作独立毫米标定，也不能由高PCC推出绝对振幅测准。

本轮ROI/降噪模型在已见视频上做了工程开发，因此这些结果是开发验证，尚不是独立新采集盲测。离面运动、视差、参考本身振动和极弱信号仍是适用边界。

## 保留的失败与纠正

`outputs/real_v2/4-25mvpp-luandong` 保留了内部窗口受边缘外壳影响、原始测量有效率约9.8%的失败。它没有被改成成功结果；v3新增首帧暗谷分隔后再独立重跑。`signal_history` 保留功率筛选及先前信号处理版本，新增跨窗相位一致性避免仅凭两个重叠窗把低频扰动当作稳定模式。

上次对话中“相关性超过0.93，因此绝对振幅已可靠恢复、可以统一替代”的结论不成立，撤回。当前只能按此表分别评价覆盖、波形一致性和像素误差；缺少独立标定时不声称绝对幅值已验证。

## 已执行检查

- 两个非整数频率11.3/23.7 Hz均保留，随机噪声不产生稳定模态；合成RMSE约0.03571降至0.01158 px。
- 缺测NaN保留；必要参考缺失时拒绝输出；同频空间补偿与不可辨识边界检查通过。
- y方向转置验证误差约0.00071 px；快速/原搜索在6 Hz大运动合成短片的位移差约0。
- 六段目标ROI与原保存坐标完全相同。首帧叠框人工查看。
- 波形、频谱及激光对照的FIG逐个确认保存属性Visible=on，并重新打开检查坐标轴。
- 评价前后算法文件哈希不变，见 `review_upgrade/laser_isolation_check.json`。

## 文件入口

运行：`run_user_video.m`。直接函数：`run_real_video(u)`。独立评价：`compare_laser_v2(resultDirectory,laserPath,laserFPS,column)`。

总表：`review_upgrade/video_summary.csv`、`review_upgrade/laser_metrics.csv`。完整新结果：`outputs/real_v3/`。上次版本和本轮失败版本均保留。

FIG保存与重开语义依据 [MathWorks savefig](https://www.mathworks.com/help/matlab/ref/savefig.html) 和 [openfig](https://www.mathworks.com/help/matlab/ref/openfig.html)；科学可视化保留原始数据、共享幅度刻度、显式缺测，没有对频谱峰值归一化来掩盖幅度差。
'''
(ROOT/'UPGRADE_REPORT_20260906.md').write_text(text,encoding='utf-8')
print(d.to_string(index=False));print(metrics[['videoName','method','pcc','rmsePx','nrmseToLaser']].to_string(index=False))
