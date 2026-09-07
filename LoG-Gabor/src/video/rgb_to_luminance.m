function luminance = rgb_to_luminance(frame)
%RGB_TO_LUMINANCE Convert an RGB/RGBA video frame to normalized luminance.
%   The conversion follows the standard video luma weights. Integer frames
%   are mapped to [0,1]; floating-point frames are preserved unless they
%   look like 8-bit data.

if isempty(frame)
    luminance=zeros(0,0,'single');
    return;
end

if isinteger(frame)
    frame=single(frame)/single(intmax(class(frame)));
else
    frame=single(frame);
    finiteValues=frame(isfinite(frame));
    if ~isempty(finiteValues) && max(finiteValues)>1.5 && min(finiteValues)>=0
        frame=frame/255;
    end
end

if ismatrix(frame)
    luminance=frame;
elseif size(frame,3)==1
    luminance=frame(:,:,1);
else
    luminance=.299*frame(:,:,1)+.587*frame(:,:,2)+.114*frame(:,:,3);
end

luminance(~isfinite(luminance))=0;
luminance=min(max(luminance,0),1);
end
