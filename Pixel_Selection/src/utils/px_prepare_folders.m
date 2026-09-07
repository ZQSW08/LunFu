function dirs = px_prepare_folders(outputRoot)
% 创建本次运行所需的输出目录。
if nargin < 1 || isempty(outputRoot)
    outputRoot = fullfile(pwd, 'outputs', 'unnamed_run');
end
if ~exist(outputRoot, 'dir')
    mkdir(outputRoot);
end
names = {'figures', 'process', 'videos', 'data'};
dirs.root = outputRoot;
for k = 1:numel(names)
    folder = fullfile(outputRoot, names{k});
    if ~exist(folder, 'dir')
        mkdir(folder);
    end
    dirs.(names{k}) = folder;
end
end
