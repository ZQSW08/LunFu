classdef TileReference < handle
    % Spatial redundancy inside the user reference ROI; fixed first-frame
    % templates. No temporal filtering, template adaptation or truth input.
    properties
        roi; trackers; centers; minimumSupport;
    end
    methods
        function o=TileReference(im,roi,cfg)
            o.roi=round(roi);r=o.roi;
            sz=max([20 20],round(r(3:4).*[.6 .45]));sz=min(sz,r(3:4));
            xs=unique(round(linspace(r(1),r(1)+r(3)-sz(1),2)));
            ys=unique(round(linspace(r(2),r(2)+r(4)-sz(2),3)));
            o.trackers={};o.centers=zeros(0,2);
            c=cfg;c.affine=false;c.maxSamples=min(cfg.maxSamples,1800);
            for yy=ys
                for xx=xs
                    patch=double(im(yy:yy+sz(2)-1,xx:xx+sz(1)-1));
                    [gx,gy]=gradient(patch);G=[gx(:) gy(:)];H=G'*G;
                    if std(patch(:),1)<2||rcond(H)<.001,continue;end
                    o.trackers{end+1}=mfm.Tracker(im,[xx yy sz],c);
                    o.centers(end+1,:)=[xx yy]+(sz-1)/2;
                end
            end
            o.minimumSupport=3;
        end
        function z=update(o,im)
            n=numel(o.trackers);dd=nan(n,2);scores=nan(n,1);errors=scores;
            for j=1:n
                a=o.trackers{j}.update(im);
                if a.valid,dd(j,:)=a.d; scores(j)=a.ncc;errors(j)=a.error;end
            end
            z=struct('d',[NaN NaN],'valid',false,'ncc',0,'error',NaN,...
                'support',0,'spread',NaN,'reason','insufficient_reference_tiles');
            good=all(isfinite(dd),2);
            if nnz(good)<o.minimumSupport,return;end
            % Fit local similarity to tile centers. Robust rejection uses
            % spatial agreement, never the desired temporal frequency.
            p=o.centers;center=o.roi(1:2)+(o.roi(3:4)-1)/2;p=p-center;
            B=[ones(n,1) zeros(n,1) p(:,1) -p(:,2);...
               zeros(n,1) ones(n,1) p(:,2) p(:,1)];
            w=double(good);
            for iter=1:5
                ix=find(w>0);ids=[ix;ix+n];ww=sqrt([w(ix);w(ix)]);
                X=B(ids,:).*ww;v=[dd(ix,1);dd(ix,2)].*ww;
                if rank(X)<4,return;end
                beta=X\v;err=sqrt(sum((dd-[B(1:n,:)*beta B(n+1:end,:)*beta]).^2,2));
                scale=max(.08,1.4826*median(abs(err(good)-median(err(good)))));
                w=double(good).*min(1,2.5*scale./max(err,eps));w(~isfinite(w))=0;
            end
            inlier=good & err<max(.6,3*scale);
            z.support=nnz(inlier);z.spread=median(err(good));
            if z.support<o.minimumSupport||z.spread>1.5,return;end
            z.d=beta(1:2)';z.valid=true;z.ncc=median(scores(inlier));
            z.error=median(errors(inlier));z.reason='reference_spatial_consensus';
        end
    end
end
