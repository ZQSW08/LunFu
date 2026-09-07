function open_bpaf_fig(figPath)
%OPEN_BPAF_FIG 在 MATLAB 中可靠打开 BPAF 导出的 FIG 文件。
% 用法：
%   open_bpaf_fig('D:\\LunFu\\BPAF\\outputs\\...\\08_bpaf_waveform.fig')
% 不提供路径时弹出文件选择框，避免依赖 Windows 的 .fig 文件关联。

if nargin < 1 || isempty(figPath)
    [fileName, fileDir] = uigetfile('*.fig', '选择 BPAF FIG 文件');
    if isequal(fileName, 0)
        return;
    end
    figPath = fullfile(fileDir, fileName);
end

figPath = char(figPath);
if ~isfile(figPath)
    error('BPAF:FigureNotFound', 'FIG 文件不存在：%s', figPath);
end
if ~strcmpi(get_file_extension(figPath), '.fig')
    error('BPAF:InvalidFigureFile', '输入文件不是 .fig：%s', figPath);
end

% openfig 是 MATLAB 原生 FIG 读取接口；显式传入 visible 可确保图窗显示。
openfig(figPath, 'visible');
end

function ext = get_file_extension(filePath)
[~, ~, ext] = fileparts(filePath);
end
