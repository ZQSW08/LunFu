classdef ConsensusProfile < handle
    % Independent strip observations in one frame, fixed anchor. The target
    % is never used to estimate reference motion. No temporal band selection.
    properties
        roi;cfg;strips;weights;rowCenters;lastGuide=[0 0];
    end
    methods
        function o=ConsensusProfile(im,roi,cfg)
            o.roi=round(roi);o.cfg=cfg;o.cfg.profileScale=false;
            r=o.roi;edges=round(linspace(0,r(4),6));o.strips={};o.weights=[];o.rowCenters=[];
            margin=round(.15*r(3));
            c=cfg;c.autoProfileRows=false;c.profileScale=false;
            % Row geometry follows explicit references; do not maximize
            % correlation over unrelated rows (aperture ambiguity).
            c.referenceModel='translation';
            for j=1:5
                h=edges(j+1)-edges(j);rr=[r(1)+margin r(2)+edges(j) r(3)-2*margin h];
                p=mean(double(im(rr(2):rr(2)+h-1,rr(1):rr(1)+rr(3)-1)),1);
                if std(p,1)<2,continue;end
                o.strips{end+1}=mfm.AnchorProfile1D(im,rr,c);
                o.weights(end+1)=sum(diff(p).^2);
                o.rowCenters(end+1)=(edges(j)+h/2-r(4)/2)/r(4);
            end
            if ~isempty(o.weights),o.weights=min(o.weights,3*median(o.weights));end
        end
        function z=update(o,im,guide)
            n=numel(o.strips);dx=nan(n,1);err=dx;score=dx;
            if all(isfinite(guide)),o.lastGuide=guide;end
            % Independent target observation continues even when references
            % are lost. Such frames must NEVER become valid relative data.
            guide=o.lastGuide;
            for j=1:n
                a=o.strips{j}.update(im,guide);score(j)=a.ncc;
                if a.valid,dx(j)=a.d(1);err(j)=a.error;end
            end
            z=struct('d',[NaN NaN],'valid',false,'ncc',0,'error',NaN,...
                'centroid',NaN,'scale',1,'refineShift',NaN,'support',0,...
                'spread',NaN,'reason','insufficient_target_strips');
            good=isfinite(dx);if nnz(good)<3,return;end
            % Small in-plane rotation produces a line of horizontal shifts
            % across rows. Fit that spatial line instead of rejecting tilt
            % or averaging different physical heights indiscriminately.
            B=[ones(n,1) o.rowCenters(:)];w=double(good);
            for iter=1:4
                ix=find(w>0);ww=sqrt(w(ix));beta=(B(ix,:).*ww)\(dx(ix).*ww);
                residual=abs(dx-B*beta);sig=max(.03,1.4826*median(residual(good)));
                w=double(good).*min(1,2.5*sig./max(residual,eps));w(~isfinite(w))=0;
            end
            spread=median(residual(good));inlier=good&residual<=max(.5,3*sig);
            z.support=nnz(inlier);z.spread=spread;z.ncc=median(score(good));
            if z.support<3||spread>1, z.reason='target_strips_disagree';return;end
            w=o.weights(:)./max(.05,err).^2;w(~inlier)=0;
            w=min(w,3*median(w(inlier)));w(~inlier)=0;
            ww=sqrt(w(inlier));beta=(B(inlier,:).*ww)\(dx(inlier).*ww);
            z.d=[beta(1) guide(2)];
            z.valid=true;z.error=median(err(inlier));z.reason='target_spatial_consensus';
        end
    end
end
