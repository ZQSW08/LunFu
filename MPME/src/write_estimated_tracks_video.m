function write_estimated_tracks_video(frames, outputPath, playbackFps, titleText, ...
    tracks, frameValues, valueLabel)
%WRITE_ESTIMATED_TRACKS_VIDEO 为真实视频叠加 M-PME 测点轨迹，不虚构真值。
% tracks: pointCount x 2 x frameCount，坐标为 ROI 内的 0-based 坐标。

writer = VideoWriter(outputPath, 'MPEG-4');
writer.FrameRate = playbackFps;
writer.Quality = 92;
open(writer);
frameCount = size(frames, 3);
for frameIndex = 1:frameCount
    gray = uint8(min(max(frames(:,:,frameIndex), 0), 255));
    rgb = repmat(gray, 1, 1, 3);
    positions = squeeze(tracks(:,:,frameIndex)) + 1;
    rgb = insertMarker(rgb, positions, 'o', 'Color', [0 114 178], 'Size', 8);
    for pointIndex = 1:size(positions,1)
        rgb = insertText(rgb, positions(pointIndex,:)+[4 -10], sprintf('P%d',pointIndex), ...
            'FontSize', 10, 'TextColor', 'yellow', 'BoxOpacity', 0);
    end
    annotation = sprintf('%s | f %d/%d\n%s = %.2f', ...
        titleText, frameIndex, frameCount, valueLabel, frameValues(frameIndex));
    fontSize = max(7, min(10, round(size(rgb,2)/20)));
    rgb = insertText(rgb, [3 3], annotation, 'FontSize', fontSize, ...
        'TextColor', 'white', 'BoxColor', 'black', 'BoxOpacity', 0.65);
    writeVideo(writer, rgb);
end
close(writer);
end
