function output = mexResize(image, outputSize, ~)
%MEXRESIZE 安全 MATLAB 替代，避免旧 mexResize 在新 MATLAB 中破坏堆。
output=imresize(image,double(outputSize),'bilinear');
end
