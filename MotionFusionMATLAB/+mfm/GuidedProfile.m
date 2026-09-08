classdef GuidedProfile < handle
    % Separate coarse two-dimensional localization from subpixel measurement.
    properties
        coarse;fine;roi;cfg;
    end
    methods
        function o=GuidedProfile(im,roi,cfg)
            c=cfg;c.affine=false;c.maxSamples=min(c.maxSamples,400);
            o.coarse=mfm.Tracker(im,roi,c);
            c=cfg;c.referenceModel='translation';
            o.fine=mfm.Profile(im,roi,c);o.roi=o.fine.roi;o.cfg=o.fine.cfg;
        end
        function z=update(o,im,~)
            guide=o.coarse.update(im);
            if ~guide.valid
                z=struct('d',[NaN NaN],'valid',false,'ncc',guide.ncc,...
                    'error',guide.error,'centroid',NaN);return;
            end
            z=o.fine.update(im,guide.d);
        end
    end
end
