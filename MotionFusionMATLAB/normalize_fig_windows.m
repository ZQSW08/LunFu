function normalize_fig_windows(parent)
files=dir(fullfile(parent,'*','*.fig'));
for j=1:numel(files)
    p=fullfile(files(j).folder,files(j).name);f=openfig(p,'invisible');
    set(f,'Visible','on','WindowState','normal');drawnow;savefig(f,p);close(f);
end
verify_figures(parent);
end
