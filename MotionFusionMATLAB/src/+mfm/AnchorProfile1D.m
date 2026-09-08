classdef AnchorProfile1D < handle
    % Coarse and fractional matching use EXACTLY the same fixed anchor
    % support. This avoids the legacy full-window NCC / inner-window IC
    % objective mismatch. Only subpixel translation and gain/offset removal.
    properties
        roi;cfg;t;energy;position;previousGuide=[0 0];velocity=0;options;anchorLeft;anchorOffset=0;age=0;keyframes=0;
    end
    methods
        function o=AnchorProfile1D(im,roi,cfg)
            o.roi=round(roi);o.cfg=cfg;r=o.roi;o.position=r(1);o.anchorLeft=r(1);
            p=mean(double(im(r(2):r(2)+r(4)-1,r(1):r(1)+r(3)-1)),1)';
            o.t=p-mean(p);o.energy=sum(o.t.^2);
            o.options=optimset('Display','off','TolX',1e-4,'MaxIter',16);
        end
        function z=update(o,im,guide)
            r=o.roi;n=r(3);sz=size(im);
            z=struct('d',[NaN NaN],'valid',false,'ncc',0,'error',NaN);
            if o.energy<n,return;end
            prediction=o.position+guide(1)-o.previousGuide(1);
            left=max(1,round(prediction)-o.cfg.radius-2);
            right=min(sz(2),round(prediction)+n-1+o.cfg.radius+2);
            yy=r(2)+guide(2);base=floor(yy);alpha=yy-base;
            if base<1||base+r(4)>sz(1)||right-left+1<n+4,return;end
            p=(1-alpha)*mean(double(im(base:base+r(4)-1,left:right)),1)+...
                 alpha*mean(double(im(base+1:base+r(4),left:right)),1);
            sums=conv(p,ones(1,n),'valid');sq=conv(p.^2,ones(1,n),'valid');
            cc=conv(p,o.t(end:-1:1)','valid')./sqrt(max(eps,o.energy*(sq-sums.^2/n)));
            cc(1)=NaN;cc(end)=NaN;[score,ix]=max(cc);z.ncc=score;
            if ~isfinite(score)||score<.65,return;end
            first=left+ix-1;sp=spline(left:right,p);template=o.t/sqrt(o.energy/n);
            obj=@(delta) alignmentCost(delta,sp,first,n,template);
            [delta,cost]=fminbnd(obj,-1,1,o.options);z.error=sqrt(cost);
            if ~isfinite(cost)||z.error>=o.cfg.maxError||abs(delta)>.98,return;end
            shift=first+delta;z.valid=true;z.d=[o.anchorOffset+shift-o.anchorLeft guide(2)];
            o.velocity=shift-o.position;o.position=shift;o.previousGuide=guide;
            o.age=o.age+1;
            % Refresh only after image residual documents appearance change.
            % Copy raw integer samples, carry the measured coordinate offset;
            % no smoothed waveform, no fractional template resampling.
            if o.cfg.profileKeyframes&&z.error>.18&&o.age>=5
                newLeft=round(shift);ids=(newLeft-left+1):(newLeft-left+n);
                if all(ids>=1&ids<=numel(p))
                    tmp=p(ids)';o.t=tmp-mean(tmp);o.energy=sum(o.t.^2);
                    o.anchorOffset=z.d(1);o.anchorLeft=newLeft;o.position=newLeft;
                    o.age=0;o.keyframes=o.keyframes+1;
                end
            end
            z.keyframes=o.keyframes;
        end
    end
end
function e=alignmentCost(delta,sp,first,n,t)
p=ppval(sp,(first+delta+(0:n-1))');sd=std(p,1);
if sd<1,e=Inf;else,e=mean(((p-mean(p))/sd-t).^2);end
end
