function [amplitudeMap, responseMap] = local_amplitude_map(frame, cfg, theta0)
%LOCAL_AMPLITUDE_MAP 计算 active-pixel 选择所需的方向局部振幅。
if nargin < 3 || isempty(theta0), theta0 = cfg.loggabor.theta0; end
[ampH, ~, ~] = loggabor_response(frame, cfg.loggabor.defaultParams, cfg, 0);
[ampV, ~, ~] = loggabor_response(frame, cfg.loggabor.defaultParams, cfg, pi/2);
amplitudeMap.horizontal = ampH(:,:,1);
amplitudeMap.vertical = ampV(:,:,1);
amplitudeMap.combined = hypot(amplitudeMap.horizontal, amplitudeMap.vertical);
responseMap.theta0 = theta0;
end
