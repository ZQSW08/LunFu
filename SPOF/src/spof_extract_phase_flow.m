function out = spof_extract_phase_flow(video, fs, cfg)
% SPOF_EXTRACT_PHASE_FLOW 从视频提取 Gabor 局部相位和相位光流。
% 输入 video 为 HxWxT 灰度 double；输出 vx/vy 单位为像素/秒。
% 论文对应：式(10)-(11) Gabor 响应、式(8)-(9) 相位光流。

video = double(video);
[h, w, n] = size(video);
bank = spof_make_gabor_bank(cfg);
responses = cell(2, 1);
phases = cell(2, 1);
amplitudes = cell(2, 1);
vx = zeros(h, w, n, 'single');
vy = zeros(h, w, n, 'single');
validX = false(h, w, n);
validY = false(h, w, n);

for k = 1:2
    % 对整段视频做批量 FFT 卷积，结果等价于逐帧 conv2(...,'same')，
    % 但可显著降低论文多场景复现时的重复卷积开销。
    kh = size(bank{k}, 1); kw = size(bank{k}, 2);
    hp = h + kh - 1; wp = w + kw - 1;
    videoFFT = fft2(video, hp, wp);
    kernelFFT = fft2(bank{k}, hp, wp);
    fullResponse = ifft2(bsxfun(@times, videoFFT, kernelFFT));
    rowIndex = floor(kh/2) + (1:h);
    colIndex = floor(kw/2) + (1:w);
    response = fullResponse(rowIndex, colIndex, :);
    phase = unwrap(angle(response), [], 3);
    amp = abs(response);
    responses{k} = response;
    phases{k} = phase;
    amplitudes{k} = amp;

    % 用相邻复响应的相位增量求时间导数，避免先逐点 unwrap 后产生伪跳变。
    dphaseDt = zeros(h, w, n);
    if n > 1
        increment = angle(response(:, :, 2:n) .* conj(response(:, :, 1:n-1))) * fs;
        dphaseDt(:, :, 1) = increment(:, :, 1);
        dphaseDt(:, :, n) = increment(:, :, end);
        if n > 2
            dphaseDt(:, :, 2:n-1) = (increment(:, :, 2:end) + increment(:, :, 1:end-1)) / 2;
        end
    end

    if cfg.useNominalSpatialFrequency
        % Fourier shift theorem：Gabor 名义载频 k=2*pi/lambda。
        denominator = 2*pi/cfg.gabor.lambda;
        good = amp > cfg.minAmplitude;
        if k == 1
            vx(good) = single(-dphaseDt(good) / denominator);
            validX = validX | good;
        elseif k == 2
            vy(good) = single(-dphaseDt(good) / denominator);
            validY = validY | good;
        end
    else
        % 可选的论文式局部相位梯度实现，适合已知纹理方向稳定的真实数据。
        dphaseDx = zeros(h, w, n);
        dphaseDy = zeros(h, w, n);
        for t = 1:n
            % 不直接对 angle/unwrap 相位做空间 gradient：空间上的 2*pi
            % 跳变会被误认为巨大相位梯度。对复响应 z=a+ib 使用
            % d(arg z)=(a*db-b*da)/(a^2+b^2)，等价于解析相位导数。
            realResponse = real(response(:, :, t));
            imagResponse = imag(response(:, :, t));
            [realDy, realDx] = gradient(realResponse);
            [imagDy, imagDx] = gradient(imagResponse);
            denominator = amp(:, :, t).^2 + eps;
            dphaseDx(:, :, t) = (realResponse .* imagDx - ...
                imagResponse .* realDx) ./ denominator;
            dphaseDy(:, :, t) = (realResponse .* imagDy - ...
                imagResponse .* realDy) ./ denominator;
        end
        denominator = dphaseDx;
        good = amp > cfg.minAmplitude & abs(denominator) > cfg.minPhaseGradient;
        tmp = -dphaseDt ./ max(abs(denominator), cfg.minPhaseGradient) .* sign(denominator);
        if k == 1
            vx(good) = single(tmp(good));
            validX = validX | good;
        end
        denominator = dphaseDy;
        good = amp > cfg.minAmplitude & abs(denominator) > cfg.minPhaseGradient;
        tmp = -dphaseDt ./ max(abs(denominator), cfg.minPhaseGradient) .* sign(denominator);
        if k == 2
            vy(good) = single(tmp(good));
            validY = validY | good;
        end
    end
end

% 两个正交方向分别估计一个分量；低振幅/低梯度点保留为无效点。
out = struct('vx', vx, 'vy', vy, 'validX', validX, 'validY', validY, ...
    'responses', {responses}, 'phases', {phases}, 'amplitudes', {amplitudes}, ...
    'gaborBank', {bank});
end
