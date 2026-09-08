"""Read-only evidence collection; measurement itself is entirely MATLAB.
Figures: raw pixels and fitted laser pixels, missing observations stay NaN.
"""
import json, sys
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from scipy.io import loadmat
ROOT=Path(__file__).resolve().parent
OUT=ROOT/'outputs'

def main():
    dest=ROOT/'review';dest.mkdir(exist_ok=True)
    tables=[]
    for p in sorted(OUT.glob('*/laser_comparison.csv')):
        d=pd.read_csv(p);d.insert(0,'run',p.parent.name);tables.append(d)
    allruns=pd.concat(tables,ignore_index=True)
    allruns.to_csv(dest/'all_real_runs.csv',index=False)
    selected=allruns[(allruns.run=='release')&(allruns.method=='profile_ic')].copy()
    selected['engineering_gate']=(selected.status=='evaluated')&(selected.validFraction>=.95)&(selected.pcc>=.9)&(selected.nrmse<=.4)
    selected.to_csv(dest/'release_summary.csv',index=False)
    syn=pd.read_csv(OUT/'synthetic_release'/'metrics.csv')
    syn.to_csv(dest/'all_synthetic_results.csv',index=False)
    with plt.rc_context({'font.size':10,'axes.spines.top':False,'axes.spines.right':False,'pdf.fonttype':42}):
        fig,axes=plt.subplots(6,2,figsize=(12,15),constrained_layout=True)
        for row,(_,s) in enumerate(selected.iterrows()):
            d=pd.read_csv(OUT/'release'/s.caseName/'profile_ic_laser.csv')
            a=axes[row,0];mask=d.heldout.astype(bool);tt=d.time_s.to_numpy()
            a.plot(tt,d.band_px,color='#0072B2',lw=.7,label='Video, 5–45 Hz')
            a.plot(tt,np.where(mask,d.fitted_laser_px,np.nan),color='#D55E00',lw=.8,ls='--',label='Laser, training-fit scale/lag')
            a.axvspan(0,tt[len(tt)//2],color='0.93',label='Calibration half')
            a.set(title=f'{s.caseName}: coverage {s.validFraction:.1%}, PCC {s.pcc:.3f}',xlabel='Time (s)',ylabel='Displacement (px)')
            if row==0:a.legend(fontsize=8)
            b=axes[row,1];ids=np.flatnonzero(mask)
            if len(ids):
                start=tt[ids[0]];b.plot(tt,d.band_px,color='#0072B2',lw=1,label='Video');b.plot(tt,d.fitted_laser_px,color='#D55E00',ls='--',lw=1,label='Fitted laser');b.set_xlim(start,start+1)
            b.set(title=f'Held-out excerpt; NRMSE {s.nrmse:.3f}',xlabel='Time (s)',ylabel='Displacement (px)')
        fig.savefig(dest/'real_validation.png',dpi=180);fig.savefig(dest/'real_validation.pdf');plt.close(fig)
        primary=syn[syn.method=='spatial_ic'];names=list(dict.fromkeys(primary.scenario))
        fig,axes=plt.subplots(1,2,figsize=(12,4.8),constrained_layout=True)
        for seed,marker in [(42,'o'),(137,'s')]:
            sub=primary[primary.seed==seed].set_index('scenario').loc[names]
            axes[0].plot(names,sub.rmsePx,marker=marker,label=f'Seed {seed}')
            axes[1].plot(names,sub.amplitudeRatio,marker=marker,label=f'Seed {seed}')
        axes[0].axhline(.06,color='0.4',ls='--',label='Absolute error limit')
        axes[0].set(ylabel='Unfiltered RMSE (px)',ylim=(0,.065),title='Absolute error; weak case also has relative error gate')
        axes[1].axhline(1,color='0.4',ls='--');axes[1].set(ylabel='Measured / truth amplitude',ylim=(.75,1.25),title='Null case: amplitude ratio undefined')
        for a in axes:a.tick_params(axis='x',rotation=45);a.legend(fontsize=8)
        fig.savefig(dest/'synthetic_validation.png',dpi=180);fig.savefig(dest/'synthetic_validation.pdf');plt.close(fig)
    sys.path.insert(0,str(ROOT.parent/'MotionFusion'))
    from inspect_inputs import inventory
    before=json.loads((ROOT/'source_hashes_before.json').read_text());after=inventory()
    changes=[p for p in before if before[p]!=after.get(p)]
    audit={'original_source_files_checked':len(before),'changed_or_missing':changes,'added':[p for p in after if p not in before]}
    (dest/'source_integrity.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
    runtime=[]
    for p in (OUT/'release').glob('*/result.mat'):
        r=loadmat(p,simplify_cells=True);runtime.append({'case':p.parent.name,'frames_read':len(r['time']),'header_estimate':r.get('metadataEstimatedFrames'),'read_seconds':r['readSeconds'],'tracking_seconds':r['trackSeconds'],'algorithm_seconds':r['algorithmSeconds']})
    pd.DataFrame(runtime).to_csv(dest/'runtime.csv',index=False)
    manifest={'source_tables':['outputs/release/laser_comparison.csv','outputs/synthetic_release/metrics.csv'],
      'transformations':['Video bandpass: third-order Butterworth 5–45 Hz, separately on each half and each contiguous valid run','Laser assumed 100 Hz, column 3, values <= -900 missing','Laser lag and gain fitted on calibration half only','No gap filling, no amplitude normalization in figures'],
      'replicates':'2 synthetic texture/noise seeds; real videos are 6 previously explored recordings, not independent new acquisitions',
      'dimensions_inches':{'real_validation':[12,15],'synthetic_validation':[12,4.8]},'png_dpi':180,
      'destination':'Internal engineering review, no journal specification asserted'}
    (dest/'figure_provenance.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print(selected[['caseName','validFraction','pcc','nrmse','seconds','engineering_gate']].to_string(index=False))
    print('Source integrity:',audit)
    def mdtable(frame):
        cols=list(frame.columns)
        return '| '+' | '.join(cols)+' |\n| '+' | '.join(['---']*len(cols))+' |\n'+'\n'.join('| '+' | '.join('缺测/未定义' if pd.isna(x) else f'{x:.4f}' if isinstance(x,float) else str(x) for x in row)+' |' for row in frame.itertuples(index=False,name=None))
    realtable=mdtable(selected[['caseName','validFraction','pcc','nrmse','seconds','engineering_gate']])
    syntable=mdtable(primary[['scenario','seed','validFraction','rmsePx','nrmse','amplitudeRatio','passed']])
    failures=allruns[(allruns.status!='evaluated')|(allruns.validFraction<.95)|(allruns.pcc<.9)|(allruns.nrmse>.4)]
    failuretable=mdtable(failures[['run','caseName','method','status','validFraction','pcc','nrmse']])
    report=f'''# 运动物体测振：方法整合与验证记录（2026-09-05）

本轮建立了独立纯 MATLAB 工程，完成六段既有真实视频和 18 组解析合成图像的运行。下面列出实际结果、残余问题和证据位置。六段视频均参与过开发，不能把再次运行当作完全独立的新实验。方法配置按视频的参考可见性和模型适用性分别固定，不能把配置差异隐藏成单一无参数算法。

## 1. 原结论复核

旧 `cross_method_experiments/adaptive_macro_highfreq/validation_metrics.csv` 明确记录：6 Hz 大运动时，VPR=0.4827236703，最大残余=26.64650198 px。旧低频场景的有利结果不能覆盖它。旧报告的“已解决”应视为未经完整验证。

旧 13 Hz 双参考结果 `MotionFusion/outputs/real_final/motion13/summary.json` 中一个参考有效率只有 0.4364，整段相对位移有效率约 0.4334。较晚单参考发布结果虽然摆脱 insufficient_valid_samples，但 PCC 约 0.685，仍不是高精度位移验证。

旧十字视频只有一个叠加宏运动与微振动的目标，背景并不随该目标公共运动；它没有新方案需要的同刚体独立参考。因此不能在不增加信息的情况下声称新方案直接修好了该原始视频。新 6 Hz 压力测试验证的是具有独立参考的可辨识条件，原视频仍保留为失败证据。

## 2. 方法资产整理与取舍

| 工程 | 可复用思想 | 本轮处理 |
| --- | --- | --- |
| MPME | 多尺度、粗细位移分工 | 借鉴搜索与精测分离；既有输出用于对照 |
| AP-CV | 幅度定位、精细测量及坐标合成 | 采用粗定位后精配准，分别保存总量和相对量 |
| BPAF | 频带分析 | 仅作统一宽频带评价，不能靠预设峰值证明测量正确 |
| TDDM | 固定子区、仿射 IC-GN | 缓存雅可比与求解矩阵，独立 MATLAB 实现 |
| PLT | 锚点、预测、空间公共运动 | 固定首帧锚点，参考增量引导搜索，测量独立求解 |
| PNL | 几何方向及相位线性适用边界 | 亮条沿长度平均，减少无用方向自由度 |
| Pixel Selection | 可靠性与采样 | 保留逐点/逐帧可追溯质量；比较疏密采样 |
| SPOF | 局部结构与异常可靠性 | 用图像残差拒绝失配，不对缺测强行补出振动 |
| Crossline Phase | 明确几何标记的低维测量 | 当前视频不是十字标记，不强套零相位交点模型 |
| LoG-Gabor | 频带/方向选择、全场测量 | 当前单测点任务不引入全场滤波优化开销 |
| 旧 MotionFusion | 空间参考、IC 与质心两路 | 保留全部旧结果；新建纯 MATLAB 版本并修正失败环节 |

上述是思路融合，不是把每篇论文完整算法串联，也未证明学术首创性。复现源码校验 {len(before)} 个文件，本轮变化 {len(changes)} 个。

## 3. 实际算法

1. 首帧保存目标和独立参考，参考使用二维纹理的归一化相关粗定位。
2. 对局部图像使用缓存的固定模板逆组合仿射配准；投影掉亮度增益和偏置的影响。无需整视频金字塔或逐帧重算 Hessian。
3. 亮条目标使用沿长度方向的空间平均和一维亚像素轮廓配准，同时记录质心对照。轮廓尺度允许 0.5–2，仍须 NCC 与图像残差通过；尺度结果逐帧保存。该范围的调整源于真实图像中测得约 20.7% 放大，并非仅降低质量阈值。
4. 目标搜索采用上次目标位置加参考位移增量，避免失锁后的陈旧搜索，又避免把参考绝对坐标直接当作目标位置。纵向仅作搜索引导。
5. 只用参考区域估计公共运动：单参考平移，或两个参考拟合平面相似变换。目标不参加公共运动拟合。输出 `目标总位移 - 目标位置处的公共运动`。
6. 帧缺失保持 NaN。频带仅用于评价/显示，按连续有效区间处理。测量函数不读取激光、不读取振动真值，也不输入 13/27 Hz 期望峰。

二维相位与图像配准的优势不是在所有目标上等价的；这里优先减少目标形状允许的自由度。固定模板逆组合的计算依据参见 [Baker–Matthews](https://www.ri.cmu.edu/project/lucas-kanade-20-years-on/)。这套工程没有把生成的波形冒充观测。

## 4. 固定配置的真实视频结果

{realtable}

validFraction 是**实际用于 5–45 Hz 比较的覆盖率**；原始位移的有效率见每段 result.mat 的 geometryValid。短有效段会在滤波时被额外排除，不能把两种覆盖率混用。PCC 和 NRMSE 来自后半段；前半段拟合时间差、符号和 px/mm 比例。NRMSE=RMSE/后半段视频信号标准差。比例是拟合值，不证明绝对幅值标定正确。

engineering_gate 为内部工作判据：覆盖率≥0.95、PCC≥0.9、NRMSE≤0.4。它是开发阶段的工程筛查，不是文献标准或正式计量验收。请逐行查看，不用“频率正确”替代未通过项。

已知各记录激光第 3 列和采样率 100 Hz 沿用旧实验设定，尚未独立核实采集硬件时间戳；窄带周期波形的互相关可能有多个周期等价解。1000/1002 等 AVI 头部帧数与 MATLAB 实际读出的 999/1001 帧有尾部差异，已在 runtime.csv 记录。原始时间间隔始终保留。

图见 [全六段时域对照](review/real_validation.png)。每段另有 measurement.fig 可在 MATLAB 编辑。

## 5. 合成全验证集

240 帧、60 fps；宏运动峰值55 px，通常微振动0.35 px/6.7 Hz；独立解析纹理、像素孔径 sinc、噪声和 MJPEG Quality=100；两个纹理/噪声种子42、137。慢动、6 Hz 大运动、同频、转动/尺度、乱动、亮度变化、完全遮挡、零振动及0.02 px弱振动全部执行。所有主指标来自**未带通**相对位移。

{syntable}

合成通过条件：可见帧覆盖≥95%、RMSE<0.06 px、有振动时幅值比误差<20%且 NRMSE<0.3，遮挡假有效率<10%。弱振动不能仅凭绝对误差小而放行。早期 synthetic_v1 的绝对误差判据过宽，synthetic_release 增加相对误差要求；早期文件没有覆盖，保留用于追溯。

表格中 validFraction 对完全遮挡场景只以可见帧为分母；全片遮挡仍为 NaN。零振动幅值比和 NRMSE 不定义，不能填成1或0。参考损坏、失去必要参考、时间缺口和同频非唯一性另由 test_contracts 验证。

## 6. 简化、速度与尚未解决的问题

新方法逐帧读视频、缓存参考求解器、只对局部图像插值。耗时分成解码和跟踪，见 review/runtime.csv。与既有 MPME 的历史耗时相比可以判断实际使用成本，但旧 ROI、算法目标和运行环境并不完全相同，因此不能宣称严格同工况速度排名。未并行运行 release 与其他算法计时任务。

两个重要边界不能用再加滤波器解决：只有单个目标总轨迹时，同频宏运动和微振动没有唯一分解；参考和目标存在离面运动/视差时，二维平移/相似变换未必成立。当前工程测的是图像平面相对位移，不是任意三维运动物体的已标定真实振动。

由于已经用这些实拍做过 ROI 和模型调试，不能把本表称为完全独立盲测。正式下一步应固定本轮配置，采集新的同步视频和位移计记录，独立确定像素比例与时间戳，并加入强旋转、遮挡和低信噪比工况。

## 7. 探索阶段全部未通过/无结果记录

以下保留算法版本、质心消融和既有 MPME 对照中触及上述工作判据的全部行；没有删去不利结果。所有行，包括通过行，见 review/all_real_runs.csv。

{failuretable}

## 8. 交付入口

运行 `run_user_video.m` 使用自有视频；运行说明见 README.md。核心是 `+mfm/Tracker.m`、`+mfm/Profile.m`、`+mfm/compensate.m`，评价、图和真值生成分离。`review/source_integrity.json`、原始逐帧 MAT/CSV、所有版本日志和源代码快照共同提供复核依据。
'''
    (ROOT/'REVIEW_REPORT.md').write_text(report,encoding='utf-8')
if __name__=='__main__':main()
