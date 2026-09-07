function image = make_reference_scene(height, width, sceneType)
%MAKE_REFERENCE_SCENE 生成保留结构纹理的等价实验参考帧。
% 真实论文实验视频未随项目提供，因此这里使用边缘、螺栓、杆件和纹理
% 构造可重复的代理场景；它只用于验证算法链，不声称是论文原始图像。

[x, y] = meshgrid(1:width, 1:height);
image = 0.08 + 0.015 * sin(2*pi*x/17) .* cos(2*pi*y/23);
switch lower(sceneType)
    case 'cable'
        body = abs(x - width*0.50) <= width*0.09;
        image = image + 0.72*body;
        image = image + 0.12*exp(-((x-width*0.50).^2)/(2*(width*0.025)^2));
        image = image + 0.08*(y/height);
    case 'steel'
        plate = x > width*0.16 & x < width*0.84 & y > height*0.12 & y < height*0.88;
        image = image + 0.38*plate;
        for cx = [0.26 0.74]*width
            for cy = [0.24 0.76]*height
                image = image + 0.40*exp(-((x-cx).^2+(y-cy).^2)/(2*(width*0.045)^2));
            end
        end
        image = image + 0.22*(abs(x-width*0.35)<1.2 | abs(y-height*0.57)<1.2);
    case 'ssrm'
        panel = x > width*0.12 & x < width*0.88 & y > height*0.12 & y < height*0.88;
        image = image + 0.25*panel;
        image = image + 0.30*(abs(x-width*0.50)<width*0.045);
        image = image + 0.25*(abs(y-height*0.30)<height*0.035 & panel);
        image = image + 0.18*(abs(y-height*0.68)<height*0.028 & panel);
        image = image + 0.16*sin(2*pi*x/7).*sin(2*pi*y/11).*panel;
    otherwise
        image = image + 0.25*(abs(x-width*0.5)<2 | abs(y-height*0.5)<2);
end
image = image - min(image(:));
image = image / max(image(:));
end
