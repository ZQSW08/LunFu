function cases = apcv_case_definitions(site, cfg)
%APCV_CASE_DEFINITIONS 生成论文实验对应的可重复等价位移真值。
% 这些信号不是作者原始 LDV 数据，所有结果均应标注为 synthetic equivalent。

fs = cfg.frameRate;
switch lower(site)
    case 'lab'
        t = (0:round(cfg.lab.duration*fs)-1)'/fs;
        cases(1) = makeCase('0.5 Hz', t, 42*sin(2*pi*0.5*t));
        cases(2) = makeCase('1 Hz', t, 39*sin(2*pi*1.0*t));
        f0 = 0.5; f1 = 3.0; T = t(end);
        sweepPhase = 2*pi*(f0*t + 0.5*(f1-f0)/T*t.^2);
        cases(3) = makeCase('Sweep 0.5-3 Hz', t, 31*sin(sweepPhase));
        rng(cfg.randomSeed + 101, 'twister');
        rbv1 = lowpass(randn(size(t)), 1.2, fs) + 0.35*sin(2*pi*2.1*t);
        rbv1 = 26 * rbv1 / max(abs(rbv1));
        cases(4) = makeCase('RBV1', t, rbv1);
        rng(cfg.randomSeed + 102, 'twister');
        rbv2 = lowpass(randn(size(t)), 0.8, fs) + 0.25*sin(2*pi*2.7*t);
        rbv2 = 22 * rbv2 / max(abs(rbv2));
        cases(5) = makeCase('RBV2', t, rbv2);
    case 'bridge'
        t = (0:round(cfg.bridge.duration*fs)-1)'/fs;
        amplitudes = [0.80, 0.95, 1.35, 1.55, 2.10, 2.25, 2.45, 2.51];
        for i = 1:8
            slow = -0.55 * amplitudes(i) * sin(pi*t/t(end)).^2;
            if i <= 2
                high = 0.10*amplitudes(i)*sin(2*pi*(2.1+0.2*i)*t);
            elseif i < 8
                envelope = exp(-0.5*((t-(2.2+0.22*i))/0.75).^2);
                high = 0.52*amplitudes(i)*envelope.*sin(2*pi*(2.4+0.18*i)*t);
            else
                envelope = exp(-0.5*((t-2.0)/1.0).^2);
                high = amplitudes(i)*envelope.*sin(2*pi*3.4*t);
                slow = zeros(size(t));
            end
            truth = slow + high;
            cases(i) = makeCase(sprintf('Scenario %d', i), t, truth); %#ok<AGROW>
        end
    otherwise
        error('未知实验站点: %s', site);
end
end

function c = makeCase(name, time, truthMm)
c.name = name;
c.time = time;
c.truthMm = truthMm(:);
end
