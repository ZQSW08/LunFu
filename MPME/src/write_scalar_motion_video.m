function write_scalar_motion_video(frames, outputPath, playbackFps, titleText, ...
    motionAxis, truth, estimateNames, estimateValues)
%WRITE_SCALAR_MOTION_VIDEO 将标量位移真值和估计值叠加到模拟帧并写 MP4。

writer = VideoWriter(outputPath, 'MPEG-4');
writer.FrameRate = playbackFps;
writer.Quality = 92;
open(writer);
frameCount = size(frames, 3);
centre = [(size(frames,2)+1)/2, (size(frames,1)+1)/2];
truthColor = [0 158 115];
estimateColors = [213 94 0; 0 114 178; 204 121 167];
for frameIndex = 1:frameCount
    gray = uint8(min(max(frames(:,:,frameIndex), 0), 255));
    rgb = repmat(gray, 1, 1, 3);
    truthPosition = centre;
    truthPosition(motionAxis) = truthPosition(motionAxis) + truth(frameIndex);
    rgb = insertMarker(rgb, truthPosition, 'o', 'Color', truthColor, 'Size', 7);
    annotation = sprintf('%s | f %d/%d\ntruth %.2f', ...
        titleText, frameIndex, frameCount, truth(frameIndex));
    for seriesIndex = 1:numel(estimateNames)
        estimatePosition = centre;
        estimatePosition(motionAxis) = estimatePosition(motionAxis) + ...
            estimateValues(frameIndex, seriesIndex);
        color = estimateColors(1+mod(seriesIndex-1,size(estimateColors,1)), :);
        rgb = insertMarker(rgb, estimatePosition, 'x', 'Color', color, 'Size', 8);
        annotation = sprintf('%s | %s %.2f', annotation, ...
            estimateNames{seriesIndex}, estimateValues(frameIndex, seriesIndex));
    end
    fontSize = max(7, min(10, round(size(rgb,2)/18)));
    rgb = insertText(rgb, [3 3], annotation, 'FontSize', fontSize, ...
        'TextColor', 'white', 'BoxColor', 'black', 'BoxOpacity', 0.65);
    rgb = insertText(rgb, [3 size(rgb,1)-14], ...
        'green=o truth; cross=estimate', 'FontSize', 7, ...
        'TextColor', 'white', 'BoxColor', 'black', 'BoxOpacity', 0.55);
    writeVideo(writer, rgb);
end
close(writer);
end
