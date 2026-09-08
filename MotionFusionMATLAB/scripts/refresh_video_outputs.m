function refresh_video_outputs(parent)
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(scriptRoot);addpath(fullfile(projectRoot,'src'));root=projectRoot;
% Recompute video-only signal processing and exports from saved raw results.
% Archive old signal outputs before replacing: no image tracking rerun needed.
files=dir(fullfile(parent,'*','result.mat'));
for k=1:numel(files)
    folder=files(k).folder;r=load(fullfile(folder,'result.mat'));if ~isfield(r,'publicConfig'),continue;end
    archive=fullfile(folder,'signal_history',datestr(now,'yyyymmdd_HHMMSSFFF'));mkdir(archive);
    if isfolder(fullfile(folder,'evaluation')),copyfile(fullfile(folder,'evaluation'),fullfile(archive,'evaluation'));end
    patterns={'result.mat','waveform_*','spectrum_*','signal_*','02_*','03_*'};
    for j=1:numel(patterns)
        matches=dir(fullfile(folder,patterns{j}));for h=1:numel(matches),if ~matches(h).isdir,copyfile(fullfile(folder,matches(h).name),fullfile(archive,matches(h).name));end;end
    end
    keys=fieldnames(r.signals);tt=tic;
    for j=1:numel(keys),key=keys{j};old=r.signals.(key);r.signals.(key)=mfm.clean_signal(old.raw,r.fps,r.publicConfig.analysisBandHz,r.publicConfig.denoise);end
    r.postprocessSeconds=toc(tt);save(fullfile(folder,'result.mat'),'-struct','r','-v7');
    export_real_outputs(r,imread(fullfile(folder,'first_frame.png')),false,true);
    fprintf('%s modes ',folder);disp(r.signals.(keys{1}).modesHz');
end
end



