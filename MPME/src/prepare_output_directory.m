function prepare_output_directory(outputDirectory,projectRoot,clearPrevious)
%PREPARE_OUTPUT_DIRECTORY 安全准备单次运行目录，可按配置清除上次结果。
% 只允许清理 projectRoot 内的具体子目录，并保护工程根、outputs 和 experiments 根。

if nargin < 3, clearPrevious = false; end
resolvedOutput = char(java.io.File(outputDirectory).getCanonicalPath());
resolvedProject = char(java.io.File(projectRoot).getCanonicalPath());
outputsRoot = char(java.io.File(fullfile(projectRoot,'outputs')).getCanonicalPath());
experimentsRoot = char(java.io.File(fullfile(projectRoot,'experiments')).getCanonicalPath());
protected = {resolvedProject,outputsRoot,experimentsRoot};
if any(strcmpi(resolvedOutput,protected))
    error('拒绝清理受保护目录：%s',resolvedOutput);
end
allowedPrefixes = {[lower(outputsRoot) filesep],[lower(experimentsRoot) filesep]};
if ~any(cellfun(@(prefix) startsWith(lower(resolvedOutput),prefix),allowedPrefixes))
    error('输出目录必须位于 MPME 的 outputs 或 experiments 具体子目录内：%s', ...
        resolvedOutput);
end

if clearPrevious && exist(resolvedOutput,'dir')
    fprintf('清理上次运行结果：%s\n',resolvedOutput);
    [success,message] = rmdir(resolvedOutput,'s');
    if ~success, error('无法清理旧输出：%s',message); end
end
if ~exist(resolvedOutput,'dir')
    [success,message] = mkdir(resolvedOutput);
    if ~success, error('无法创建输出目录：%s',message); end
end
end
