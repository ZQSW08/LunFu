function px_write_json(value, filePath)
% 使用MATLAB内置JSON编码器保存可交换的结果摘要。
text = jsonencode(value, 'PrettyPrint', true);
fid = fopen(filePath, 'w', 'n', 'UTF-8');
if fid < 0
    error('无法创建JSON结果文件：%s', filePath);
end
cleanup = onCleanup(@() fclose(fid));
fwrite(fid, text, 'char');
end
