function write_point_tracks_video(frames, outputPath, playbackFps, titleText, ...
    truthTracks, estimateTracks, frameValues, valueLabel)
%WRITE_POINT_TRACKS_VIDEO 在旋转/仿真视频上叠加真值点与估计点。
% truthTracks/estimateTracks: pointCount x 2 x frameCount，坐标为 0-based。

writer = VideoWriter(outputPath, 'MPEG-4');
writer.FrameRate = playbackFps;
writer.Quality = 92;
open(writer);
frameCount = size(frames, 3);
for frameIndex = 1:frameCount
    gray = uint8(min(max(frames(:,:,frameIndex), 0), 255));
    rgb = repmat(gray, 1, 1, 3);
    truthPosition = squeeze(truthTracks(:,:,frameIndex)) + 1;
    estimatePosition = squeeze(estimateTracks(:,:,frameIndex)) + 1;
    rgb = insertMarker(rgb, truthPosition, 'o', 'Color', [0 158 115], 'Size', 7);
    rgb = insertMarker(rgb, estimatePosition, 'x', 'Color', [213 94 0], 'Size', 8);
    annotation = sprintf('%s | f %d/%d\n%s = %.2f', ...
        titleText, frameIndex, frameCount, valueLabel, frameValues(frameIndex));
    fontSize = max(7, min(10, round(size(rgb,2)/20)));
    rgb = insertText(rgb, [3 3], annotation, 'FontSize', fontSize, ...
        'TextColor', 'white', 'BoxColor', 'black', 'BoxOpacity', 0.65);
    rgb = insertText(rgb, [3 size(rgb,1)-14], ...
        'green=o truth; orange=x M-PME', 'FontSize', 7, ...
        'TextColor', 'white', 'BoxColor', 'black', 'BoxOpacity', 0.55);
    writeVideo(writer, rgb);
end
close(writer);
end
