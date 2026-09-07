function H = rotation_h(angleDeg, imageSize)
%ROTATION_H 0-based rigid rotation about image centre.

centerX = (imageSize(2) - 1) / 2;
centerY = (imageSize(1) - 1) / 2;
angle = deg2rad(angleDeg);
rotation = [cos(angle) -sin(angle) 0; sin(angle) cos(angle) 0; 0 0 1];
toOrigin = [1 0 -centerX; 0 1 -centerY; 0 0 1];
fromOrigin = [1 0 centerX; 0 1 centerY; 0 0 1];
H = fromOrigin * rotation * toOrigin;
end
