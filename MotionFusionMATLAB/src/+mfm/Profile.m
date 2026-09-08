classdef Profile < handle
    % Spatial averaging along a bright strip; fractional vertical guide.
    % Simultaneously records centroid and gain/offset-normalized 1-D IC shift.
    properties
        roi; cfg; template; t; x; solve; position; yPosition; velocity=0; initialCentroid; previousGuide=0; previousGuideY=0; centeredTemplate; templateEnergy; onesKernel;
    end
    methods
        function o=Profile(im,roi,cfg)
            o.cfg=cfg;o.roi=round(roi);r=o.roi;o.position=r(1);o.yPosition=r(2);
            if cfg.autoProfileRows&&r(4)>=40
                patch=double(im(r(2):r(2)+r(4)-1,r(1):r(1)+r(3)-1));
                z=(patch-mean(patch,2))./max(std(patch,1,2),1);height=max(24,round(.55*r(4)));best=-Inf;first=1;
                for start=1:r(4)-height+1
                    meanShape=mean(z(start:start+height-1,:),1);
                    score=mean(meanShape.^2)-.02*((start+height/2)/r(4)-.5)^2;
                    if std(mean(patch(start:start+height-1,:),1),1)<2,continue;end
                    if score>best,best=score;first=start;end
                end
                r(2)=r(2)+first-1;r(4)=height;
                % Exclude an unrelated bright boundary object separated by a
                % dark valley; keep this measurement support INSIDE saved ROI.
                p=mean(patch(first:first+height-1,:),1);w=r(3);middle=max(p(round(.25*w):round(.75*w)));
                right=round(.7*w):w-4;[valley,idx]=min(p(right));
                if mean(p(end-2:end))>1.5*middle&&valley<.25*middle,r(3)=right(idx)+1;end
                o.roi=r;
            end
            o.template=mean(double(im(r(2):r(2)+r(4)-1,r(1):r(1)+r(3)-1)),1)';
            o.x=(4:r(3)-5)'; tt=o.template(o.x+1); st=std(tt,1);assert(st>1,'Flat target profile');
            o.t=(tt-mean(tt))/st;g=gradient(o.template);g=g(o.x+1)/st;
            J=g;
            twoEdges=min(sum(max(g,0).^2),sum(min(g,0).^2))>.1*sum(g.^2);
            o.cfg.profileScale=cfg.profileScale&&twoEdges;
            if o.cfg.profileScale,J=[g g.*(o.x-(r(3)-1)/2)/r(3)];end
            J=J-mean(J,1);J=J-o.t*(o.t'*J/numel(tt));o.solve=pinv(J'*J,1e-6)*J';
            o.initialCentroid=o.centroid(o.template);
            o.centeredTemplate=o.template-mean(o.template);o.templateEnergy=sum(o.centeredTemplate.^2);o.onesKernel=ones(1,r(3));
        end
        function z=update(o,im,guide)
            r=o.roi; sz=size(im); rad=o.cfg.radius;
            % Reference-guided search also recovers after long reference gaps.
            % The guide only centers SEARCH; subpixel target is fitted freely.
            prediction=o.position+guide(1)-o.previousGuide;
            left=max(1,round(prediction)-rad);right=min(sz(2),round(prediction)+r(3)-1+rad);
            if strcmp(o.cfg.referenceModel,'none')
                % A target-only run cannot borrow a reference's vertical
                % displacement. Search a bounded vertical band in the
                % target ROI instead of freezing the first-frame row.
                % Frame-to-frame vertical motion is expected to be small;
                % limiting the band prevents a false high-NCC row from
                % jumping to a different object in the same frame.
                vrad=min(rad,8);
                yCandidates=max(1,round(o.yPosition)-vrad):min(sz(1)-r(4)+1,round(o.yPosition)+vrad);
            else
                yCandidates=r(2);
            end
            z=struct('d',[NaN NaN],'valid',false,'ncc',0,'error',NaN,'iterations',0,'centroid',NaN,'scale',NaN,'refineShift',NaN);
            n=r(3);t=o.centeredTemplate;energy=o.templateEnergy;
            score=-Inf;k=1;y0=yCandidates(1);bestProfile=[];
            for yc=yCandidates
                yy=yc+guide(2); ybase=floor(yy); alpha=yy-ybase;
                if ybase<1||ybase+r(4)>sz(1),continue;end
                % Fractional sampling removes row quantization from vertical motion.
                profile=(1-alpha)*mean(double(im(ybase:ybase+r(4)-1,left:right)),1)+alpha*mean(double(im(ybase+1:ybase+r(4),left:right)),1);
                numerator=conv(profile,flipud(t)','valid');s=conv(profile,o.onesKernel,'valid');ss=conv(profile.^2,o.onesKernel,'valid');
                cc=numerator./sqrt(max(1e-12,energy*(ss-s.^2/n)));
                [sc,kk]=max(cc);
                if sc>score,score=sc;k=kk;y0=ybase;bestProfile=profile;end
            end
            z.ncc=score;if score<.65||isempty(bestProfile),return;end
            profile=bestProfile;
            initial=left+k-1;local=profile(k:k+n-1);cen=o.centroid(local);
            z.centroid=initial+cen-r(1)-o.initialCentroid;
            shift=initial;scale=1;center=(n-1)/2;sp=spline(left:right,profile);
            for it=1:o.cfg.maxIterations
                xx=scale*(o.x-center)+center+shift;v=ppval(sp,xx);
                if std(v,1)<1,return;end
                residual=(v-mean(v))/std(v,1)-o.t;dp=max(-1,min(1,o.solve*residual));
                if o.cfg.profileScale,scale=scale/(1+dp(2)/n);end
                shift=shift-scale*dp(1);
                if norm(dp)<1e-4,break;end
            end
            z.error=sqrt(mean(residual.^2));z.iterations=it;z.scale=scale;z.refineShift=shift-initial;
            maxRefineShift=4;
            if strcmp(o.cfg.referenceModel,'none'),maxRefineShift=8;end
            z.valid=z.error<o.cfg.maxError&&abs(shift-initial)<maxRefineShift&&scale>.5&&scale<2;
            if z.valid
                z.d=[shift-r(1) y0-r(2)];o.velocity=.5*o.velocity+.5*(shift-o.position);o.position=shift;o.yPosition=y0;o.previousGuide=guide(1);o.previousGuideY=guide(2);
            end
        end
    end
    methods(Static)
        function c=centroid(p)
            w=max(p-prctile(p,15),0);c=(0:numel(p)-1)*w(:)/sum(w);
        end
    end
end
