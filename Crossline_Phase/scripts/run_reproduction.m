function run_reproduction(cfg)
%RUN_REPRODUCTION 执行 Crossline_Phase 的论文忠实复现主线。
% 运行顺序：S0 单线 -> S1/S2 核心定位 -> S3 像素级成像 -> Table 1-4 -> Fig.6。
% 论文未公开完整相机内参，因此 Table/Fig.6 是等价 pixel-wise 成像复现。
close all; clc;
scriptPath=fileparts(mfilename('fullpath')); projectRoot=fileparts(scriptPath); addpath(genpath(fullfile(projectRoot,'src'))); addpath(genpath(fullfile(projectRoot,'simulation'))); addpath(genpath(fullfile(projectRoot,'third_party','matlabPyrTools')));
if nargin<1 || isempty(cfg), cfg=config_default(projectRoot); end
rng(cfg.simulation.randomSeed,'twister'); outRoot=fullfile(cfg.output.root,'paper_reproduction'); if ~isfolder(outRoot), mkdir(outRoot); end

% S0：已知真值单线，确认 Gabor 方向和 phase zero-crossing。
[I,truth]=make_single_line_image([128 128],[64.5 64.5],32,3.6,80); [G,~]=build_complex_gabor(32,3.6,80,cfg.method); [resp,phase]=extract_phase(I,G); [zl,ok,~]=find_phase_zero_line(resp,phase,truth,32,cfg.method);
s0=struct('truth',truth,'zeroLine',zl,'valid',ok); save(fullfile(outRoot,'S0_single_line.mat'),'s0');
f0=figure('Name','S0 single-line test','NumberTitle','off','Color','w','Visible','on'); imagesc(phase); axis image; colormap gray; hold on; if ok, plot_zero_line(zl,size(I),'r'); end; plot(truth(1),truth(2),'b+','MarkerSize',12,'LineWidth',1.5); title('S0: phase zero-crossing and known line center'); save_figure_pair(f0,fullfile(outRoot,'S0_single_line')); close(f0);

% S1：理想十字两条零相位线求交；S2：保持姿态不变的平移扫描。
sim=cfg.simulation; [I1,gt1,meta1]=simulate_camera_crossline(35,2,[0 0 0],[0 0 sim.tz],sim); r1=crossline_process_frame(I1,cfg); save(fullfile(outRoot,'S1_ideal_crossline.mat'),'I1','gt1','meta1','r1');
if r1.valid, pf=plot_process_result(I1,r1,'S1 ideal crossline intersection'); save_figure_pair(pf,fullfile(outRoot,'S1_ideal_crossline')); savefig(pf,fullfile(outRoot,'S1_ideal_crossline.fig')); close(pf); end
s2shift=-3:0.5:3; s2det=NaN(numel(s2shift),2); s2gt=NaN(numel(s2shift),2);
for ii=1:numel(s2shift), [Ii,gti]=simulate_camera_crossline(35,2,[0 0 0],[s2shift(ii) 0 sim.tz],sim); ri=crossline_process_frame(Ii,cfg); s2gt(ii,:)=gti; if ri.valid, s2det(ii,:)=ri.center; end, end
s2=struct('translationMm',s2shift(:),'truth',s2gt,'detected',s2det,'error',s2det-s2gt); save(fullfile(outRoot,'S2_subpixel_translation.mat'),'s2');
f2=figure('Name','S2 subpixel translation','NumberTitle','off','Color','w','Visible','on'); plot(s2gt(:,1),s2det(:,1)-s2gt(:,1),'k-o','LineWidth',1); grid on; xlabel('Ground-truth x (pixel)'); ylabel('Error (pixel)'); title('S2: fixed-pose translation error'); save_figure_pair(f2,fullfile(outRoot,'S2_subpixel_translation')); close(f2);

% S3：一次 improved pixel-wise 相机成像证据。
[I3,gt3,meta3]=simulate_camera_crossline(35,2,[0 0 0],[0 0 sim.tz],sim); r3=crossline_process_frame(I3,cfg); save(fullfile(outRoot,'S3_pixelwise_demo.mat'),'I3','gt3','meta3','r3');
if r3.valid, pf=plot_process_result(I3,r3,'S3 pixel-wise crossline detection'); save_figure_pair(pf,fullfile(outRoot,'S3_pixelwise_process')); savefig(pf,fullfile(outRoot,'S3_pixelwise_process.fig')); close(pf); end

if cfg.simulation.runTables, tables=run_table_experiments(cfg,fullfile(outRoot,'tables')); else, tables=[]; end %#ok<NASGU>
if cfg.simulation.runFigure6, fig6=run_fig6_experiment(cfg,fullfile(outRoot,'figure6')); else, fig6=[]; end %#ok<NASGU>
save(fullfile(outRoot,'reproduction_config.mat'),'cfg');
fprintf('论文复现入口完成。结果目录：%s\n',outRoot);
end

function plot_zero_line(line,sz,color)
if abs(line.b)>abs(line.a), xx=[1 sz(2)]; yy=-(line.a*xx+line.c)/line.b; else, yy=[1 sz(1)]; xx=-(line.b*yy+line.c)/line.a; end
plot(xx,yy,color,'LineWidth',1.2);
end
