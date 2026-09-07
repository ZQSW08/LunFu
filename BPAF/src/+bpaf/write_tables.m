function write_tables(results, cfg)
%WRITE_TABLES 导出与论文表2-9对应的复现指标。

methodNames = {'Acc2017','Acc2018','Acc2022','BPAF'};

method = strings(8,1); video = strings(8,1); prior = strings(8,1);
pf = zeros(8,1); per = zeros(8,1); rmse = zeros(8,1);
row = 0;
for methodIdx = 1:4
    for caseIdx = 1:2
        row = row+1; r = results.sim(caseIdx).methods(methodIdx);
        method(row)=methodNames{methodIdx}; video(row)=results.sim(caseIdx).id;
        prior(row)=mat2str(r.prior); pf(row)=r.metrics.PF;
        per(row)=r.metrics.PER; rmse(row)=r.metrics.RMSE;
    end
end
writetable(table(method,video,prior,pf,per,rmse), ...
    fullfile(cfg.tableDir,'table02_simulation_comparison.csv'));

model = strings(6,1); video = strings(6,1); pf = zeros(6,1); per = zeros(6,1); rmse = zeros(6,1);
row=0;
for caseIdx=1:2
    entries={results.sim(caseIdx).pve,results.sim(caseIdx).bp,results.sim(caseIdx).methods(4)};
    names={'PVE','BP','BP+NS'};
    for idx=1:3
        row=row+1; model(row)=names{idx}; video(row)=results.sim(caseIdx).id;
        pf(row)=entries{idx}.metrics.PF; per(row)=entries{idx}.metrics.PER; rmse(row)=entries{idx}.metrics.RMSE;
    end
end
writetable(table(model,video,pf,per,rmse),fullfile(cfg.tableDir,'table03_ablation.csv'));

runtime = vertcat(results.sim.runtime);
writetable(array2table(runtime,'VariableNames',methodNames,'RowNames',{'SV1','SV2'}), ...
    fullfile(cfg.tableDir,'table04_runtime_cpu_seconds.csv'),'WriteRowNames',true);

method=strings(12,1); level=strings(12,1); pf=zeros(12,1); per=zeros(12,1); row=0;
for methodIdx=1:4
    for lev=1:3
        row=row+1; r=results.exciter.methods(lev,methodIdx);
        method(row)=methodNames{methodIdx}; level(row)="L"+lev; pf(row)=r.metrics.PF; per(row)=r.metrics.PER;
    end
end
writetable(table(method,level,pf,per),fullfile(cfg.tableDir,'table05_exciter_proxy.csv'));
writematrix(results.exciter.gridPF,fullfile(cfg.tableDir,'table06_exciter_proxy_pf_grid.csv'));
writematrix(results.exciter.gridPER,fullfile(cfg.tableDir,'table07_exciter_proxy_per_grid.csv'));

method=strings(12,1); level=strings(12,1); pf=zeros(12,1); pcc=zeros(12,1); row=0;
for methodIdx=1:4
    for lev=1:3
        row=row+1; r=results.beam.methods(lev,methodIdx);
        method(row)=methodNames{methodIdx}; level(row)="L"+lev; pf(row)=r.metrics.PF; pcc(row)=r.metrics.PCC;
    end
end
writetable(table(method,level,pf,pcc),fullfile(cfg.tableDir,'table08_beam_proxy.csv'));

band=strings(4,1); pf=zeros(4,1); pcc=zeros(4,1);
for idx=1:4
    band(idx)=mat2str(results.beam.limitBands(idx,:));
    pf(idx)=results.beam.limits(idx).metrics.PF; pcc(idx)=results.beam.limits(idx).metrics.PCC;
end
writetable(table(band,pf,pcc),fullfile(cfg.tableDir,'table09_beam_proxy_limited_prior.csv'));
end
