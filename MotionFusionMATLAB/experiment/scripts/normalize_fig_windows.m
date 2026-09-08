function normalize_fig_windows(parent)
scriptRoot=fileparts(mfilename('fullpath'));projectRoot=fileparts(fileparts(scriptRoot));addpath(fullfile(projectRoot,'src'));root=projectRoot;
files=dir(fullfile(parent,'*','*.fig'));
for j=1:numel(files)
    p=fullfile(files(j).folder,files(j).name);f=openfig(p,'invisible');
    set(f,'Visible','on','WindowState','normal');drawnow;savefig(f,p);close(f);
end
verify_figures(parent);
end



