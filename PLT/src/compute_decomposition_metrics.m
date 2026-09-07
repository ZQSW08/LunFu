function metrics=compute_decomposition_metrics(dMacro,dMacroTrue,dVib,dVibTrue,fps)
% COMPUTE_DECOMPOSITION_METRICS 仅用于有真值的合成实验。
metrics=struct('MSR',NaN,'VPR',NaN,'frequencyErrorHz',NaN,'amplitudeError',NaN);
if nargin<5, fps=1; end
if ~isempty(dMacroTrue)
    rawRms=sqrt(mean((dMacroTrue(:)-mean(dMacroTrue(:))).^2)); residualRms=sqrt(mean((dMacro(:)-dMacroTrue(:)).^2));
    metrics.MSR=1-residualRms/max(rawRms,eps);
end
if ~isempty(dVibTrue)
    metrics.VPR=sqrt(mean(dVib(:).^2))/max(sqrt(mean(dVibTrue(:).^2)),eps);
    sx=compute_single_sided_spectrum(dVib,fps); st=compute_single_sided_spectrum(dVibTrue,fps);
    [~,ix]=max(sx.amplitude); [~,it]=max(st.amplitude); if ~isempty(ix)&&~isempty(it), metrics.frequencyErrorHz=abs(sx.frequencyHz(ix)-st.frequencyHz(it)); end
    metrics.amplitudeError=abs(max(sx.amplitude)-max(st.amplitude));
end
end
