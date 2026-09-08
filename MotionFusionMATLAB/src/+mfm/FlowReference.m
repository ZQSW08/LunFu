classdef FlowReference < handle
    % Image-only KLT reference. Fixed initial landmark coordinates; cumulative
    % optical-flow drift is possible and is explicitly retained in raw output.
    properties
        roi;tracker;initial;minimumSupport=8;ready=false;previousD=[0 0];previousPoints;accumulatedA=eye(2);age=0;
    end
    methods
        function o=FlowReference(im,roi,~)
            o.roi=round(roi);p=detectMinEigenFeatures(im,'ROI',o.roi,'MinQuality',.001);
            p=p.selectStrongest(100);o.initial=p.Location;
            if size(o.initial,1)<o.minimumSupport,return;end
            o.tracker=vision.PointTracker('MaxBidirectionalError',.5,'NumPyramidLevels',4,...
                'BlockSize',[15 15],'MaxIterations',20);
            o.initial=double(o.initial);o.previousPoints=o.initial;initialize(o.tracker,o.initial,im);o.ready=true;
        end
        function z=update(o,im)
            z=struct('d',[NaN NaN],'valid',false,'ncc',0,'error',NaN,...
                'support',0,'spread',NaN,'reason','insufficient_reference_features');
            if ~o.ready,return;end
            [points,valid]=o.tracker(im);good=find(valid);
            if numel(good)<o.minimumSupport,return;end
            % Deterministic robust similarity fit, no RANSAC random seed
            % and no temporal desired-frequency constraints.
            center=o.roi(1:2)+(o.roi(3:4)-1)/2;
            currentCenter=center+o.previousD;
            p=double(o.previousPoints(good,:))-currentCenter;
            q=double(points(good,:))-double(o.previousPoints(good,:));
            n=size(p,1);B=[ones(n,1) zeros(n,1) p zeros(n,2);...
                          zeros(n,1) ones(n,1) zeros(n,2) p];
            w=ones(n,1);
            for iter=1:6
                ww=sqrt([w;w]);beta=(B.*ww)\([q(:,1);q(:,2)].*ww);
                residual=sqrt(sum((q-[B(1:n,:)*beta B(n+1:end,:)*beta]).^2,2));
                sig=max(.03,1.4826*median(abs(residual-median(residual))));
                w=min(1,2.5*sig./max(residual,eps));
            end
            inlier=residual<max(.5,3*sig);z.support=nnz(inlier);
            z.spread=median(residual);z.error=z.spread;z.ncc=z.support/size(o.initial,1);
            if z.support<o.minimumSupport||z.spread>1, z.reason='reference_feature_geometry_failed';return;end
            A=eye(2)+[beta(3:4)';beta(5:6)'];scale=det(A);if scale<.5||scale>2,return;end
            z.d=o.previousD+beta(1:2)';z.valid=true;z.reason='reference_bidirectional_flow';
            o.accumulatedA=A*o.accumulatedA;o.previousPoints=double(points);
            o.previousD=z.d;o.age=o.age+1;
            if nnz(valid)<.65*size(o.initial,1)||o.age>=40
                corners=[0 0;o.roi(3) 0;0 o.roi(4);o.roi(3:4)] + o.roi(1:2)-center;
                corners=corners*o.accumulatedA'+center+z.d;
                lo=max([1 1],ceil(min(corners,[],1)));hi=min([size(im,2) size(im,1)],floor(max(corners,[],1)));
                if all(hi-lo>=20)
                    fresh=detectMinEigenFeatures(im,'ROI',[lo hi-lo],'MinQuality',.001);
                    fresh=fresh.selectStrongest(100);qnew=double(fresh.Location);
                    if size(qnew,1)>=o.minimumSupport
                        o.initial=qnew;o.previousPoints=qnew;o.age=0;
                        setPoints(o.tracker,qnew);
                        z.reason='reference_flow_reseeded_image_only';
                    end
                end
            end
        end
        function delete(o)
            if o.ready,release(o.tracker);end
        end
    end
end
