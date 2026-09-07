function pyramid = build_gaussian_pyramid(image, levels)
%BUILD_GAUSSIAN_PYRAMID Paper pyramid: 3x3 Gaussian sigma=0.5, odd samples.

arguments
    image {mustBeNumeric}
    levels (1,1) double {mustBeInteger,mustBePositive}
end

coords = -1:1;
g = exp(-(coords.^2) / (2 * 0.5^2));
g = g / sum(g);
pyramid = cell(levels, 1);
pyramid{1} = double(image);
for level = 2:levels
    blurred = imfilter(pyramid{level-1}, g, 'symmetric', 'conv', 'same');
    blurred = imfilter(blurred, g.', 'symmetric', 'conv', 'same');
    pyramid{level} = blurred(1:2:end, 1:2:end);
end
end
