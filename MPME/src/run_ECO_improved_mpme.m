function results = run_ECO_improved_mpme(video_path, init_rect, options)
%RUN_ECO_IMPROVED_MPME MPME 内部 ECO-HC 跟踪适配器。
% 仅负责把视频和初始框转换成 ECO 的 sequence 接口；不改变 M-PME 后端。

if nargin < 3
    options = struct();
end

eco_root = get_option(options, 'eco_root', 'C:\Users\SPRING\Desktop\ECO\ECO-master');
if ~exist(eco_root, 'dir')
    fallback_root = 'C:\Users\SPRING\Desktop\ECO-master';
    if exist(fallback_root, 'dir')
        eco_root = fallback_root;
    else
        error('ECO root does not exist: %s', eco_root);
    end
end

cache_dir = get_option(options, 'cache_dir', fullfile(tempdir, 'eco_tracking_cache'));
if ~exist(cache_dir, 'dir')
    mkdir(cache_dir);
end

[~, video_name, ~] = fileparts(video_path);
seq_dir = fullfile(cache_dir, [video_name, '_eco_preprocessed']);
if ~exist(seq_dir, 'dir')
    mkdir(seq_dir);
end

video_reader = VideoReader(video_path);
frame_paths = {};
frame_index = 1;
while hasFrame(video_reader)
    frame = readFrame(video_reader);
    frame = preprocess_tracking_frame(frame, get_option(options, 'preprocess', struct('enabled', false)));
    frame_path = fullfile(seq_dir, sprintf('frame_%06d.jpg', frame_index));
    imwrite(frame, frame_path);
    frame_paths{frame_index, 1} = frame_path; %#ok<AGROW>
    frame_index = frame_index + 1;
end

seq = struct();
seq.format = 'otb';
seq.s_frames = frame_paths;
seq.init_rect = init_rect;

addpath(eco_root);
setup_paths();

params = build_eco_hc_params(options);
params.seq = seq;
% ECO 的 tracker 在其主循环中无条件读取这两个字段，即使不保存逐帧图像。
params.res_path = cache_dir;
params.bSaveImage = false;
results = tracker(params);

end

function params = build_eco_hc_params(options)
hog_params.cell_size = 6;
hog_params.compressed_dim = 10;

cn_params.tablename = 'CNnorm';
cn_params.useForGray = false;
cn_params.cell_size = 4;
cn_params.compressed_dim = 3;

ic_params.tablename = 'intensityChannelNorm6';
ic_params.useForColor = false;
ic_params.cell_size = 4;
ic_params.compressed_dim = 3;

params.t_features = {
    struct('getFeature', @get_fhog, 'fparams', hog_params), ...
    struct('getFeature', @get_table_feature, 'fparams', cn_params), ...
    struct('getFeature', @get_table_feature, 'fparams', ic_params), ...
    };

params.t_global.normalize_power = 2;
params.t_global.normalize_size = true;
params.t_global.normalize_dim = true;

params.search_area_shape = 'square';
params.search_area_scale = get_option(options, 'search_area_scale', 4.0);
params.min_image_sample_size = get_option(options, 'min_image_sample_size', 150^2);
params.max_image_sample_size = get_option(options, 'max_image_sample_size', 200^2);

params.refinement_iterations = get_option(options, 'refinement_iterations', 1);
params.newton_iterations = get_option(options, 'newton_iterations', 5);
params.clamp_position = false;

params.output_sigma_factor = get_option(options, 'output_sigma_factor', 1/16);
params.learning_rate = get_option(options, 'learning_rate', 0.009);
params.nSamples = get_option(options, 'nSamples', 30);
params.sample_replace_strategy = 'lowest_prior';
params.lt_size = 0;
params.train_gap = get_option(options, 'train_gap', 6);
params.skip_after_frame = get_option(options, 'skip_after_frame', 12);
params.use_detection_sample = true;

params.use_projection_matrix = true;
params.update_projection_matrix = true;
params.proj_init_method = 'pca';
params.projection_reg = 1e-7;

params.use_sample_merge = true;
params.sample_merge_type = 'Merge';
params.distance_matrix_update_type = 'exact';

params.CG_iter = 5;
params.init_CG_iter = 150;
params.init_GN_iter = 10;
params.CG_use_FR = false;
params.CG_standard_alpha = true;
params.CG_forgetting_rate = 50;
params.precond_data_param = 0.75;
params.precond_reg_param = 0.25;
params.precond_proj_param = 40;

params.use_reg_window = true;
params.reg_window_min = 1e-4;
params.reg_window_edge = 10e-3;
params.reg_window_power = 2;
params.reg_sparsity_threshold = 0.05;

params.interpolation_method = 'bicubic';
params.interpolation_bicubic_a = -0.75;
params.interpolation_centering = true;
params.interpolation_windowing = false;

params.number_of_scales = get_option(options, 'number_of_scales', 7);
params.scale_step = get_option(options, 'scale_step', 1.01);

params.use_scale_filter = true;
params.scale_sigma_factor = 1/16;
params.scale_learning_rate = get_option(options, 'scale_learning_rate', 0.025);
params.number_of_scales_filter = get_option(options, 'number_of_scales_filter', 17);
params.number_of_interp_scales = get_option(options, 'number_of_interp_scales', 33);
params.scale_model_factor = 1.0;
params.scale_step_filter = get_option(options, 'scale_step_filter', 1.02);
params.scale_model_max_area = 32 * 16;
params.scale_feature = 'HOG4';
params.s_num_compressed_dim = 'MAX';
params.lambda = 1e-2;
params.do_poly_interp = true;

params.visualization = get_option(options, 'visualization', 0);
params.debug = 0;
params.use_gpu = get_option(options, 'use_gpu', false);
params.gpu_id = [];
end

function value = get_option(options, field_name, default_value)
if isfield(options, field_name)
    value = options.(field_name);
else
    value = default_value;
end
end
