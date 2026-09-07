function summary=run_real_video(config)
%RUN_REAL_VIDEO 用本论文方法处理一个真实视频。
% 入口只负责流程编排；公式和图像处理均位于 src/。
% 真实视频没有位移真值，滤波器训练使用“真实首帧 + 已知人工运动”。

if nargin<1 || ~isstruct(config)
    error('run_real_video:InvalidConfig','Input must be the config struct from run_real_data.');
end
projectRoot=fileparts(fileparts(mfilename('fullpath')));
addpath(genpath(fullfile(projectRoot,'src'))); addpath(fullfile(projectRoot,'configs'));
config=complete_config(config,projectRoot);
if ~isfile(config.videoPath)
    error('run_real_video:MissingVideo','Video not found: %s',config.videoPath);
end

% 先读取首帧并确认 ROI，再决定是否清理本次输出目录。
[roi,cancelled]=select_video_roi(config.videoPath,config.roi,'LoG-Gabor real-video ROI');
if cancelled
    summary=struct('cancelled',true,'videoPath',config.videoPath);
    fprintf('Real-video run cancelled before output cleanup.\n');
    return;
end
config.roi=roi;
if roi(3)*roi(4)>config.method.maxTrainingPixels && ~config.method.allowLargeTraining
    error('run_real_video:TrainingRoiTooLarge', ...
        ['ROI has %d pixels; the default training limit is %d.\n' ...
         'Select a smaller ROI, reduce the task region, or explicitly set ' ...
        'method.allowLargeTraining=true.'],roi(3)*roi(4),config.method.maxTrainingPixels);
end
outputDir=prepare_output_directory(config,projectRoot);

readOptions=struct('Roi',config.roi,'StartFrame',config.startFrame,...
    'EndFrame',config.endFrame,'MaxFrames',config.maxFrames,'UseSingle',true);
[video,videoMeta]=read_video_frames(config.videoPath,readOptions);
if videoMeta.frameCount<3, error('run_real_video:TooFewFrames','At least 3 frames are required.'); end

cfg=default_config(); cfg.synthetic.height=size(video,1); cfg.synthetic.width=size(video,2);
cfg.synthetic.frames=videoMeta.frameCount; cfg.synthetic.fs=processing_fps(config,videoMeta.frameRate);
cfg.synthetic.frequency=config.method.trainingFrequency; cfg.synthetic.amplitude=config.method.trainingAmplitude;
cfg.synthetic.motionAngle=config.method.theta0;
cfg.mato.populationSize=config.method.populationSize; cfg.mato.generations=config.method.generations;

reference=video(:,:,1); active=active_pixel_selection(reference,cfg);
taskInfo=build_task_map(size(reference,1),size(reference,2),active.activeMask);
if isempty(config.method.taskPixels)
    selected=select_task_centers(taskInfo.activeTaskPixels,config.method.maxTasks);
else
    selected=validate_task_pixels(config.method.taskPixels,size(reference));
end
taskMap=make_nearest_task_map(size(reference),selected);

% 用真实首帧生成训练视频，只用于寻找图像特征对应的最优滤波器。
trainCfg=cfg; trainCfg.synthetic.frames=max(3,round(config.method.trainingFrames));
% 解析 Fourier shift 不含随机噪声；训练阶段固定为无噪声，避免把随机噪声
% 重复写入高分辨率三维视频，同时保证目标函数可重复。
trainCfg.synthetic.noiseStd=0;
trainTime=(0:trainCfg.synthetic.frames-1)'/trainCfg.synthetic.fs;
if config.method.trainingFrequency<=0 || config.method.trainingFrequency>=trainCfg.synthetic.fs/2
    error('run_real_video:InvalidTrainingFrequency','Training frequency must be below Nyquist.');
end
delta=config.method.trainingAmplitude*sin(2*pi*config.method.trainingFrequency*trainTime);
if abs(cos(config.method.theta0))>=abs(sin(config.method.theta0)), trainXY=[delta,zeros(size(delta))];
else, trainXY=[zeros(size(delta)),delta]; end
trainingTruthXY=trainXY; trainingVideo=[];
if config.output.saveTrainingVideo
    [trainingVideo,trainingTruthXY]=generate_synthetic_video(reference,trainXY,trainCfg);
end
truth=trainingTruthXY(:,1)*cos(config.method.theta0)+trainingTruthXY(:,2)*sin(config.method.theta0);
taskTruth=repmat(truth(:).',size(selected,1),1);
trainCfg.optimization.trainingReference=reference;
trainCfg.optimization.trainingDisplacementXY=trainingTruthXY;

if config.method.useMaTO
    estimatedEvaluations=size(selected,1)*cfg.mato.populationSize*(cfg.mato.generations+1);
    if estimatedEvaluations>config.method.maxObjectiveEvaluations
        error('run_real_video:BudgetExceeded', ...
            ['Estimated MaTO objective evaluations: %d.\n' ...
             'Reduce maxTasks/populationSize/generations/trainingFrames, or raise ' ...
             'method.maxObjectiveEvaluations deliberately.'],estimatedEvaluations);
    end
    fprintf('MaTO budget: %d objective evaluations (%d tasks, %d particles, %d generations).\n',...
        estimatedEvaluations,size(selected,1),cfg.mato.populationSize,cfg.mato.generations);
    mato=mato_optimize(trainingVideo,taskTruth,selected,trainCfg,config.method.theta0);
else
    mato=struct('bestX',repmat(cfg.loggabor.defaultParams,size(selected,1),1),...
        'bestFitness',nan(size(selected,1),1),'taskPixels',selected,'method','defaultParamsOnly');
end

fieldResult=fullfield_pme(video,taskMap,selected,mato.bestX,cfg,config.method.theta0);
fieldResult.rawDisplacement=fieldResult.displacement; fieldResult.activeMask=active.activeMask;
fieldResult.displacement=fieldResult.displacement.*repmat(active.activeMask,1,1,size(video,3));
representative=pme_measure(video,mato.bestX(1,:),cfg,selected(1,:),config.method.theta0);

if isfinite(config.method.targetFrequency), targetFrequency=config.method.targetFrequency; source='user';
else, targetFrequency=estimate_frequency(representative.displacement,cfg.synthetic.fs); source='estimated'; end
if isempty(config.method.instantFrame), frameIndex=round(size(video,3)/2); else, frameIndex=round(config.method.instantFrame); end
frameIndex=min(max(1,frameIndex),size(video,3));
odsInstant=instantaneous_ods(fieldResult.displacement,frameIndex);
odsFrequency=frequency_ods(fieldResult.displacement,cfg.synthetic.fs,targetFrequency,cfg.ods.bandwidth);

metadata=videoMeta; metadata.roi=config.roi; metadata.processingFps=cfg.synthetic.fs;
metadata.targetFrequency=targetFrequency; metadata.targetFrequencySource=source;
metadata.trainingFrequency=config.method.trainingFrequency; metadata.trainingAmplitude=config.method.trainingAmplitude;
metadata.taskCount=size(selected,1); metadata.activePixelCount=nnz(active.activeMask);
resultFile=fullfile(outputDir,[config.outputName '_result.mat']);
if config.output.saveVideoInMat
    save(resultFile,'video','reference','active','taskInfo','selected','taskMap','mato','fieldResult',...
        'representative','odsInstant','odsFrequency','metadata','config','-v7.3');
else
    save(resultFile,'reference','active','taskInfo','selected','taskMap','mato','fieldResult',...
        'representative','odsInstant','odsFrequency','metadata','config','-v7.3');
end
save_real_video_outputs(reference,active,taskInfo,selected,fieldResult,representative,odsInstant,odsFrequency,targetFrequency,outputDir);
if config.output.saveTrainingVideo
    write_video_preview(trainingVideo,fullfile(outputDir,[config.outputName '_training_from_first_frame.avi']),cfg.synthetic.fs);
end

summary=struct('cancelled',false,'videoPath',videoMeta.inputPath,'frameCount',videoMeta.frameCount,...
    'videoFps',videoMeta.frameRate,'processingFps',cfg.synthetic.fs,'imageSize',[videoMeta.height,videoMeta.width],...
    'roi',config.roi,'activePixelCount',nnz(active.activeMask),'taskCount',size(selected,1),...
    'targetFrequency',targetFrequency,'targetFrequencySource',source,'outputDirectory',outputDir,...
    'resultFile',resultFile);
save(fullfile(outputDir,[config.outputName '_summary.mat']),'summary','metadata');
fprintf('Real-video processing complete: %d frames, %d tasks, %.6g Hz.\n',...
    summary.frameCount,summary.taskCount,summary.targetFrequency);
end

function config=complete_config(config,projectRoot)
if ~isfield(config,'videoPath') || isempty(config.videoPath), error('run_real_video:MissingPath','Set config.videoPath first.'); end
config.videoPath=char(config.videoPath);
config=put_default(config,'outputDirectory',fullfile(projectRoot,'outputs','real_video'));
config=put_default(config,'outputName','real_case'); config=put_default(config,'roi',[]);
config=put_default(config,'startFrame',1); config=put_default(config,'endFrame',inf); config=put_default(config,'maxFrames',inf);
config=put_default(config,'fpsOverride',[]);
if ~isfield(config,'method'), config.method=struct; end
config.method=put_default(config.method,'theta0',pi/2); config.method=put_default(config.method,'maxTasks',8);
config.method=put_default(config.method,'taskPixels',[]); config.method=put_default(config.method,'trainingFrames',60);
config.method=put_default(config.method,'trainingFrequency',5); config.method=put_default(config.method,'trainingAmplitude',.10);
config.method=put_default(config.method,'useMaTO',true); config.method=put_default(config.method,'targetFrequency',NaN);
config.method=put_default(config.method,'populationSize',5); config.method=put_default(config.method,'generations',8);
config.method=put_default(config.method,'maxObjectiveEvaluations',2000);
config.method=put_default(config.method,'maxTrainingPixels',262144);
config.method=put_default(config.method,'allowLargeTraining',false);
config.method=put_default(config.method,'instantFrame',[]);
if ~isfield(config,'output'), config.output=struct; end
config.output=put_default(config.output,'clearPreviousResults',false);
config.output=put_default(config.output,'saveTrainingVideo',false); config.output=put_default(config.output,'saveVideoInMat',false);
end

function s=put_default(s,name,value)
if ~isfield(s,name) || isempty(s.(name)), s.(name)=value; end
end

function fps=processing_fps(config,videoFps)
if isempty(config.fpsOverride), fps=videoFps; else, fps=config.fpsOverride; end
if ~isfinite(fps) || fps<=0, error('run_real_video:InvalidFps','Processing FPS must be positive.'); end
end

function outputDir=prepare_output_directory(config,projectRoot)
base=fullfile(projectRoot,'outputs'); outputDir=fullfile(config.outputDirectory,config.outputName);
if ~is_under(outputDir,base), error('run_real_video:UnsafeOutput','Output must stay under the current project outputs folder.'); end
if isfolder(outputDir)
    if config.output.clearPreviousResults, rmdir(outputDir,'s');
    else, error('run_real_video:OutputExists','Output exists; change outputName or set clearPreviousResults=true.'); end
end
mkdir(outputDir);
end

function yes=is_under(pathValue,base)
pathValue=char(java.io.File(pathValue).getCanonicalPath()); base=char(java.io.File(base).getCanonicalPath());
yes=strncmpi(pathValue,[base filesep],length([base filesep]));
end

function selected=validate_task_pixels(selected,imageSize)
if ~isnumeric(selected) || size(selected,2)~=2 || isempty(selected) || any(~isfinite(selected(:)))
    error('run_real_video:InvalidTaskPixels','taskPixels must be N-by-2 [row col].');
end
selected=round(selected);
if any(selected(:,1)<1) || any(selected(:,1)>imageSize(1)) || any(selected(:,2)<1) || any(selected(:,2)>imageSize(2))
    error('run_real_video:TaskPixelsOutOfBounds','taskPixels lie outside the processed ROI.');
end
end

function taskMap=make_nearest_task_map(imageSize,centers)
[x,y]=meshgrid(1:imageSize(2),1:imageSize(1)); %#ok<ASGLU>
taskMap=zeros(imageSize);
for r=1:imageSize(1)
    for c=1:imageSize(2)
        [~,taskMap(r,c)]=min((centers(:,1)-r).^2+(centers(:,2)-c).^2);
    end
end
end

function f0=estimate_frequency(signal,fs)
signal=double(signal(:)); signal=signal-finite_mean(signal); n=numel(signal);
if n<3, f0=0; return; end
freq=(0:floor(n/2))'*fs/n; magnitude=abs(fft(signal)); magnitude=magnitude(1:numel(freq));
[~,index]=max(magnitude(2:end)); f0=freq(index+1);
end

function m=finite_mean(x)
x=x(isfinite(x)); if isempty(x), m=0; else, m=mean(x); end
end
