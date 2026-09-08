function export_real_outputs(r,im,showFigures,makeFigures)
% Primary evidence is always UNFILTERED displacement and its full spectrum.
% Optional legacy band/modal plots are additional, never replace raw evidence.
out=r.cfg.output;keys=fieldnames(r.signals);
kind='reference-relative displacement';
automatic=isfield(r.cfg,'referenceSelection')&&strcmp(r.cfg.referenceSelection,'automatic');
if automatic,kind='automatic reference-consensus relative displacement';end
if isfield(r,'measurementKind')&&strcmp(r.measurementKind,'total_target_displacement')
    kind='total target displacement (macro motion NOT separated)';
end
if makeFigures
    f=figure('Visible','off','Color','w');imshow(im,[]);hold on;
    rectangle('Position',r.cfg.rois(1,:),'EdgeColor',[0 .7 1],'LineWidth',2);
    for j=2:size(r.cfg.rois,1),rectangle('Position',r.cfg.rois(j,:),'EdgeColor',[1 .6 0],'LineWidth',2);end
    if isfield(r,'profileSupport'),rectangle('Position',r.profileSupport,'EdgeColor',[0 1 0],'LineWidth',1.5);end
    title('Target (cyan), reference patches (orange), measurement support (green)');saveFigure(f,'01_first_frame_rois');
end
for j=1:numel(keys)
    key=keys{j};s=r.signals.(key);raw=mfm.spectrum(s.raw,r.fps);
    id=1;if strcmp(key,'y'),id=2;end
    total=r.displacements(:,1,id);ref=r.macro(:,id);
    if isfield(r,'motionSeparation')&&isfield(r.motionSeparation,key)
        ms=r.motionSeparation.(key);
        interior=ms.vibration;interior(~ms.interior)=NaN;
        sp=mfm.spectrum(interior,r.fps);
        writetable(table(sp.frequency,sp.amplitude,'VariableNames',{'frequency_Hz','candidate_amplitude_px'}),...
            fullfile(out,['motion_candidate_spectrum_' key '.csv']));
        normalizedCandidate=nan(size(sp.amplitude));
        peak=max(sp.amplitude,[],'omitnan');
        if ~isempty(peak)&&isfinite(peak)&&peak>0,normalizedCandidate=sp.amplitude/peak;end
        writetable(table(sp.frequency,normalizedCandidate,'VariableNames',{'frequency_Hz','normalized_candidate_amplitude'}),...
            fullfile(out,['motion_candidate_spectrum_' key '_normalized.csv']));
        if makeFigures
            f=figure('Visible','off','Color','w','Position',[100 100 1100 900]);tiledlayout(4,1);
            nexttile;plot(r.time,total,r.time,ref);legend('Target total','Reference');ylabel('px');grid on;
            nexttile;plot(r.time,s.raw,r.time,ms.trend);
            legend('Raw relative/total','Smooth trend');ylabel('px');grid on;
            nexttile;plot(r.time,interior);ylabel('Candidate px');xlabel('Time (s)');grid on;
            title(sprintf('Model-dependent candidate; cutoff %g Hz; edge samples excluded',ms.cutoffHz));
            nexttile;plot(sp.frequency,sp.amplitude);xlabel('Hz');ylabel('Candidate px');grid on;
            saveFigure(f,['05_motion_separation_' key]);
        end
    end
    dat=table(r.time,total,ref,s.raw,s.broad,s.clean,isfinite(total),isfinite(s.raw),...
        'VariableNames',{'time_s','total_target_px','reference_motion_px','raw_relative_px',...
        'optional_broad_px','optional_modal_px','target_valid','relative_valid'});
    writetable(dat,fullfile(out,['waveform_' key '.csv']));
    writetable(table(raw.frequency,raw.amplitude,'VariableNames',{'frequency_Hz','raw_amplitude_px'}),...
        fullfile(out,['spectrum_' key '.csv']));
    normReference=max(raw.amplitude,[],'omitnan');
    normalized=nan(size(raw.amplitude));
    if isfinite(normReference)&&normReference>0,normalized=raw.amplitude/normReference;end
    writetable(table(raw.frequency,normalized,'VariableNames',{'frequency_Hz','normalized_amplitude'}),...
        fullfile(out,['spectrum_' key '_normalized.csv']));
    info=rmfield(s,{'raw','broad','clean'});info.measurementKind=kind;
    info.primarySpectrum='unfiltered measurement; linear detrend and Hann only';
    info.spectrumStartFrame=raw.startFrame;info.spectrumSamples=raw.samples;
    info.frequencyResolutionHz=raw.resolutionHz;info.targetCoverage=mean(isfinite(total));
    info.relativeCoverage=mean(isfinite(s.raw));info.accuracyValidated=false;
    info.spectrumNormalization='raw amplitude divided by maximum finite raw amplitude; raw spectrum remains primary';
    info.spectrumNormalizationReferencePx=normReference;
    if automatic
        info.referenceAssumption=r.referenceConsensusCaveat;
        info.referenceConsensusCoverage=mean(strcmp(r.referenceStatus,'ok'));
        info.referenceSupportMedian=median(r.referenceSupport);
    end
    fid=fopen(fullfile(out,['signal_' key '.json']),'w');fwrite(fid,jsonencode(info,'PrettyPrint',true));fclose(fid);
    if ~makeFigures,continue;end
    f=figure('Visible','off','Color','w','Position',[100 100 1100 750]);
    tiledlayout(3,1,'TileSpacing','compact');nexttile;
    plot(r.time,total,'-');hold on;plot(r.time,ref,'--');grid on;
    legend('Target total','Reference motion','Location','best');ylabel('px');title(kind);
    nexttile;plot(r.time,s.raw,'Color',[0 .447 .698]);grid on;ylabel(['Unfiltered ' key ' (px)']);
    title(sprintf('Original timestamps; missing samples are gaps; coverage %.1f%%',100*mean(isfinite(s.raw))));
    nexttile;stairs(r.time,double(isfinite(total)),'-');hold on;
    stairs(r.time,double(isfinite(s.raw)),'--');ylim([-.1 1.1]);grid on;
    ylabel('Accepted');xlabel('Time (s)');legend('Target','Relative','Location','best');
    saveFigure(f,['02_waveform_' key]);
    f=figure('Visible','off','Color','w','Position',[100 100 1100 650]);
    tiledlayout(2,1,'TileSpacing','compact');nexttile;
    plot(raw.frequency,raw.amplitude,'Color',[0 .447 .698]);ylabel('Amplitude (px)');grid on;xlim([0 r.fps/2]);
    title(sprintf('UNFILTERED spectrum; longest contiguous run: %d samples; resolution %.3g Hz',raw.samples,raw.resolutionHz));
    nexttile;semilogy(raw.frequency,max(raw.amplitude,realmin),'Color',[0 .447 .698]);
    ylabel('Amplitude (px, log)');xlabel('Frequency (Hz)');grid on;xlim([0 r.fps/2]);
    saveFigure(f,['03_spectrum_' key]);
    f=figure('Visible','off','Color','w','Position',[100 100 1100 500]);
    plot(raw.frequency,normalized,'Color',[.494 .184 .556],'LineWidth',1);hold on;
    yline(1,'--','Color',[.35 .35 .35]);grid on;xlim([0 r.fps/2]);ylim([0 1.05]);
    xlabel('Frequency (Hz)');ylabel('Normalized amplitude (a/a_{max})');
    title(sprintf('Normalized raw spectrum; reference %.5g px',normReference));
    saveFigure(f,['03_spectrum_' key '_normalized']);
    if ~isempty(s.bandHz)
        f=figure('Visible','off','Color','w','Position',[100 100 1100 650]);
        tiledlayout(3,1,'TileSpacing','compact');
        nexttile;hRaw=plot(r.time,s.raw,'Color',[.65 .65 .65]);grid on;
        xlabel('Time (s)');ylabel('Raw px');title('Unfiltered measurement');legend(hRaw,'Unfiltered');
        nexttile;hold on;hasBroadTime=any(isfinite(s.broad));
        modalIdentified=isfield(s,'modalIdentified')&&logical(s.modalIdentified);
        if ~modalIdentified&&isfield(s,'status')
            modalIdentified=strcmp(s.status,'video_identified_modal_component');
        end
        hasModal=modalIdentified&&any(isfinite(s.clean));
        if hasBroadTime,hBroad=plot(r.time,s.broad,'--');end
        if hasModal,hModal=plot(r.time,s.clean,'LineWidth',1);end
        grid on;xlabel('Time (s)');ylabel('Processed px');
        title(['Band-limited/modal diagnostic: ' strrep(s.status,'_',' ')],'Interpreter','none');
        if hasBroadTime&&hasModal
            legend([hBroad hModal],{'Broad band','Modal component'});
        elseif hasBroadTime
            legend(hBroad,'Broad band');
            fallbackStatus='unknown';if isfield(s,'status'),fallbackStatus=strrep(s.status,'_',' ');end
            text(.5,.5,['No modal component; clean is broad-band fallback (' fallbackStatus ')'],...
                'Units','normalized','HorizontalAlignment','center','Color',[.75 .1 .05]);
        elseif hasModal
            legend(hModal,'Modal component');
            text(.5,.5,'No finite broad-band signal available',...
                'Units','normalized','HorizontalAlignment','center','Color',[.75 .1 .05]);
        else
            text(.5,.5,'No finite processed signal available',...
                'Units','normalized','HorizontalAlignment','center','Color',[.75 .1 .05]);
        end
        nexttile;a=mfm.spectrum(s.broad,r.fps);b=mfm.spectrum(s.clean,r.fps);
        hasBroadSpectrum=~isempty(a.frequency)&&any(isfinite(a.amplitude));
        hasModalSpectrum=modalIdentified&&~isempty(b.frequency)&&any(isfinite(b.amplitude));
        % Normalize the processed spectra with one shared reference.  Using
        % one reference keeps broad/modal relative amplitude comparable;
        % normalizing each curve independently would hide that difference.
        processedAmplitudes=[];
        if hasBroadSpectrum,processedAmplitudes=[processedAmplitudes; a.amplitude(isfinite(a.amplitude))];end
        if hasModalSpectrum,processedAmplitudes=[processedAmplitudes; b.amplitude(isfinite(b.amplitude))];end
        processedNorm=max(processedAmplitudes,[],'omitnan');
        hasProcessedReference=~isempty(processedNorm)&&isscalar(processedNorm)&&...
            isfinite(processedNorm)&&processedNorm>0;
        aNormalized=nan(size(a.amplitude));bNormalized=nan(size(b.amplitude));
        if hasProcessedReference
            if hasBroadSpectrum,aNormalized=a.amplitude/processedNorm;end
            if hasModalSpectrum,bNormalized=b.amplitude/processedNorm;end
        end
        if hasBroadSpectrum
            writetable(table(a.frequency,aNormalized,'VariableNames',...
                {'frequency_Hz','normalized_broad_amplitude'}),...
                fullfile(out,['spectrum_' key '_broad_normalized.csv']));
        end
        if hasModalSpectrum
            writetable(table(b.frequency,bNormalized,'VariableNames',...
                {'frequency_Hz','normalized_modal_amplitude'}),...
                fullfile(out,['spectrum_' key '_modal_normalized.csv']));
        end
        hold on;if hasBroadSpectrum,hA=plot(a.frequency,aNormalized,'--');end
        if hasModalSpectrum,hB=plot(b.frequency,bNormalized,'LineWidth',1);end
        grid on;xlim([0 r.fps/2]);ylim([0 1.05]);xlabel('Hz');
        ylabel('Normalized amplitude (a/A_{max,processed})');
        if hasProcessedReference
            title(sprintf('Normalized processed spectrum; shared reference %.5g px',processedNorm));
        else
            title('Normalized processed spectrum; no finite reference');
        end
        if hasBroadSpectrum&&hasModalSpectrum
            legend([hA hB],{'Broad band','Modal component'});
        elseif hasBroadSpectrum
            legend(hA,'Broad band');
            text(.5,.5,'No modal spectrum: clean is broad-band fallback or evidence was rejected',...
                'Units','normalized','HorizontalAlignment','center','Color',[.75 .1 .05]);
        elseif hasModalSpectrum
            legend(hB,'Modal component');
            text(.5,.5,'No broad-band spectrum available',...
                'Units','normalized','HorizontalAlignment','center','Color',[.75 .1 .05]);
        else
            text(.5,.5,'No finite spectrum available for this signal',...
                'Units','normalized','HorizontalAlignment','center','Color',[.75 .1 .05]);
        end
        saveFigure(f,['04_optional_filter_' key]);
    end
end
    function saveFigure(f,name)
        exportgraphics(f,fullfile(out,[name '.png']),'Resolution',160);
        set(f,'Visible','on','WindowState','normal');drawnow;savefig(f,fullfile(out,[name '.fig']));
        if ~showFigures,close(f);end
    end
end
