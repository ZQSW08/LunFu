function e = shift_error(estimated, truth)
%SHIFT_ERROR 计算二维位移欧氏误差。
e = sqrt(sum((double(estimated(:)) - double(truth(:))).^2));
end
