function verify_figures(parent)
files=dir(fullfile(parent,'*','*.fig'));
for j=1:numel(files)
    p=fullfile(files(j).folder,files(j).name);s=load(p,'-mat');names=fieldnames(s);found=false;
    for k=1:numel(names)
        value=s.(names{k});
        if isstruct(value)&&isfield(value,'properties')&&isfield(value.properties,'Visible')
            assert(strcmp(value.properties.Visible,'on'),['Hidden FIG: ' p]);found=true;
            if isfield(value.properties,'WindowState'),assert(strcmp(value.properties.WindowState,'normal'),['Minimized FIG: ' p]);end
        end
    end
    assert(found,['Could not inspect FIG visibility: ' p]);
    f=openfig(p,'invisible');assert(~isempty(findall(f,'Type','axes')));close(f);
end
fprintf('Verified %d FIG files: stored Visible=on; all reopen with axes.\n',numel(files));
end
