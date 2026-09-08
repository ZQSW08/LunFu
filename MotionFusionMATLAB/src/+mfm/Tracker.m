classdef Tracker < handle
    % Fixed-anchor photometric IC alignment. No temporal frequency priors.
    properties
        roi; template; origin; position; velocity; A; misses=0; cfg;
        xy; t; solve; center;
    end
    methods
        function obj=Tracker(im,roi,cfg)
            obj.cfg=cfg; obj.roi=round(roi); r=obj.roi;
            assert(all(r(1:2)>=1)&&all(r(3:4)>=12)&&r(1)+r(3)-1<=size(im,2)&&r(2)+r(4)-1<=size(im,1),'Invalid ROI');
            obj.origin=r(1:2); obj.position=obj.origin; obj.velocity=[0 0]; obj.A=eye(2);
            obj.template=double(im(r(2):r(2)+r(4)-1,r(1):r(1)+r(3)-1));
            w=r(3); h=r(4); obj.center=[(w-1)/2;(h-1)/2];
            step=max(1,ceil(sqrt((w-8)*(h-8)/cfg.maxSamples)));
            [x,y]=meshgrid(4:step:w-5,4:step:h-5); idx=sub2ind([h w],y+1,x+1);
            tt=obj.template(idx); tt=tt(:); st=std(tt,1);
            assert(st>1,'ROI lacks texture'); obj.t=(tt-mean(tt))/st;
            [gx,gy]=gradient(obj.template); gx=gx(idx)/st; gy=gy(idx)/st;
            obj.xy=[x(:)';y(:)']-obj.center;
            J=[gx(:) gy(:)];
            if cfg.affine
                xn=obj.xy(1,:)'/w; yn=obj.xy(2,:)'/h;
                J=[J gx(:).*xn gx(:).*yn gy(:).*xn gy(:).*yn];
            end
            J=J-mean(J,1); J=J-obj.t*(obj.t'*J/numel(tt));
            obj.solve=pinv(J'*J,1e-5)*J';
        end
        function o=update(obj,im)
            c=obj.cfg; r=obj.roi; pred=obj.position+obj.velocity;
            rad=min(180,c.radius*(1+obj.misses));
            [p,score]=obj.locate(im,pred,rad);
            if score<c.minNCC&&mod(obj.misses,10)==2
                [p,score]=obj.locate(im,pred,Inf);
            end
            o=struct('d',[NaN NaN],'valid',false,'ncc',score,'error',NaN,'iterations',0);
            if score<c.minNCC
                obj.misses=obj.misses+1; obj.position=min(max(pred,[1 1]),[size(im,2)-r(3)+1,size(im,1)-r(4)+1]); obj.velocity=.7*obj.velocity; return
            end
            integer=p; margin=max(12,ceil(.6*max(r(3:4))));
            lo=max([1 1],p-margin); hi=min([size(im,2) size(im,1)],p+r(3:4)-1+margin);
            F=griddedInterpolant({lo(2):hi(2),lo(1):hi(1)},double(im(lo(2):hi(2),lo(1):hi(1))),'spline','none');
            A=obj.A; err=Inf;
            for it=1:c.maxIterations
                xy=A*obj.xy+obj.center+p';
                v=F(xy(2,:)',xy(1,:)');
                if any(~isfinite(v))||std(v,1)<1
                    if it==1,A=eye(2);p=integer;continue;else,break;end
                end
                z=(v-mean(v))/std(v,1); residual=z-obj.t;
                dp=max(-1,min(1,obj.solve*residual));
                if c.affine
                    dA=[1+dp(3)/r(3) dp(4)/r(4);dp(5)/r(3) 1+dp(6)/r(4)];
                    A=A/dA;
                end
                p=p-(A*dp(1:2))'; err=sqrt(mean(residual.^2));
                if norm(dp)<5e-4,break;end
            end
            o.error=err; o.iterations=it;
            o.valid=isfinite(err)&&err<c.maxError&&norm(p-integer)<8&&det(A)>.5&&det(A)<2;
            if o.valid
                obj.velocity=.5*obj.velocity+.5*(p-obj.position);obj.position=p;obj.A=A;obj.misses=0;o.d=p-obj.origin;
            else
                obj.misses=obj.misses+1;
            end
        end
        function [p,score]=locate(obj,im,pred,rad)
            r=obj.roi; sz=[size(im,2) size(im,1)];
            if obj.cfg.fastSearch&&obj.misses==0&&isfinite(rad)
                p=round(pred);
                if all(p>=1)&&all(p+r(3:4)-1<=sz)
                    patch=double(im(p(2):p(2)+r(4)-1,p(1):p(1)+r(3)-1));aa=patch(:)-mean(patch(:));bb=obj.template(:)-mean(obj.template(:));
                    score=(aa'*bb)/max(eps,norm(aa)*norm(bb));
                    if score>=.90,return;end
                end
            end
            lo=max([1 1],round(pred)-rad);hi=min(sz,round(pred)+r(3:4)-1+rad);
            if any(hi-lo+1<r(3:4)),p=pred;score=0;return;end
            search=double(im(lo(2):hi(2),lo(1):hi(1)));
            cc=normxcorr2(obj.template,search);
            cc=cc(r(4):size(search,1),r(3):size(search,2));
            [score,ind]=max(cc(:));[yy,xx]=ind2sub(size(cc),ind);p=lo+[xx-1 yy-1];
        end
    end
end
