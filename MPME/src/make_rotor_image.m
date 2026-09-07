function [image, objectMask, points] = make_rotor_image(imageSize, pointCount)
%MAKE_ROTOR_IMAGE Deterministic three-blade textured target for rotation tests.

if nargin < 2 || isempty(pointCount), pointCount = 1975; end
rng(7, 'twister');
height = imageSize(1);
width = imageSize(2);
[x, y] = meshgrid(0:width-1, 0:height-1);
centerX = (width - 1) / 2;
centerY = (height - 1) / 2;
x0 = x - centerX;
y0 = y - centerY;
radius = hypot(x0, y0);
angleGrid = atan2(y0, x0);

objectMask = radius <= 12;
for blade = 0:2
    localAngle = atan2(sin(angleGrid - blade * 2*pi/3), ...
        cos(angleGrid - blade * 2*pi/3));
    tangential = radius .* sin(localAngle);
    radial = radius .* cos(localAngle);
    halfWidth = 3.5 + 0.035 * max(radial, 0);
    bladeMask = radial >= 8 & radial <= 0.42 * min(imageSize) & ...
        abs(tangential) <= halfWidth;
    objectMask = objectMask | bladeMask;
end

noiseTexture = imgaussfilt(randn(height, width), 0.8);
fineTexture = sin(0.31*x + 0.17*y) + 0.6*cos(0.13*x - 0.29*y);
image = 205 + 6 * imgaussfilt(randn(height, width), 3);
image(objectMask) = 85 + 32 * noiseTexture(objectMask) + 22 * fineTexture(objectMask);
image(radius <= 12) = 45 + 18 * fineTexture(radius <= 12);
image = min(max(image, 0), 255);

[pointY, pointX] = find(objectMask & radius > 10);
available = numel(pointX);
selection = unique(round(linspace(1, available, min(pointCount, available))));
points = [pointX(selection)-1, pointY(selection)-1];
end
