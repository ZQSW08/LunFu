classdef DirectProfile < handle
    % Same first-frame support selection as legacy profile, with a single
    % consistent photometric objective for coarse/fractional matching.
    properties
        roi;cfg;matcher;
    end
    methods
        function o=DirectProfile(im,roi,cfg)
            selector=mfm.Profile(im,roi,cfg);o.roi=selector.roi;
            o.cfg=cfg;o.cfg.profileScale=false;
            o.matcher=mfm.AnchorProfile1D(im,o.roi,cfg);
        end
        function z=update(o,im,guide)
            z=o.matcher.update(im,guide);
            z.centroid=NaN;z.scale=1;z.refineShift=NaN;
        end
    end
end

