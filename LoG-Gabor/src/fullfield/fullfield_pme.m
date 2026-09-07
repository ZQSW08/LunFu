function result = fullfield_pme(video, taskMap, taskPixels, parameters, cfg, theta0)
%FULLFIELD_PME 将每个任务的最优滤波器应用于对应 3×3 像素组。
if nargin<6 || isempty(theta0), theta0=cfg.loggabor.theta0; end
[height,width,frames]=size(video); displacement=zeros(height,width,frames);
amplitude=zeros(height,width,frames);
for i=1:size(taskPixels,1)
    [amp,phase,~,meta]=loggabor_response(video,parameters(i,:),cfg,theta0);
    rows=find(taskMap==i); %#ok<FNDSB>
    if isempty(rows), continue; end
    [r,c]=ind2sub([height,width],rows); %#ok<ASGLU>
    phaseLocal=zeros(numel(rows),frames);
    for k=1:frames
        phaseFrame=phase(:,:,k);
        phaseLocal(:,k)=phaseFrame(rows);
    end
    phaseUnwrapped=unwrap_rows(phaseLocal,[],2);
    d=cat(2,zeros(numel(rows),1),cumsum(-diff(phaseUnwrapped,1,2)/meta.omega,2));
    for q=1:numel(rows)
        displacement(rows(q)+(0:frames-1)*height*width)=d(q,:);
        ampFrame=reshape(amp(r(q),c(q),:),1,frames);
        amplitude(rows(q)+(0:frames-1)*height*width)=ampFrame;
    end
end
result.displacement=displacement; result.amplitude=amplitude;
result.taskMap=taskMap; result.taskPixels=taskPixels; result.parameters=parameters;
end

function output = unwrap_rows(x,~,dim)
% 对每个像素的时间序列独立 unwrap，兼容 MATLAB 无隐式逐行 unwrap 的版本。
output=zeros(size(x));
for i=1:size(x,1), output(i,:)=unwrap(x(i,:),[],dim); end
end
