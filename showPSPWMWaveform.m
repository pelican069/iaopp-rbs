function result = showPSPWMWaveform(mf,p)
%SHOWPSPWMWAVEFORM Wellenformen eines PS-PWM-Benchmarkkandidaten anzeigen.
%   showPSPWMWaveform(mf) erzeugt das PS-PWM-Muster fuer das
%   Traegerverhaeltnis mf (Standard 2), bewertet es wie im Benchmark und
%   plottet eine volle Periode plus einen Zoom um den Sinusscheitel.
%   Die Parameter werden aus Strict_NLM_Benchmark.mat uebernommen, damit
%   exakt der Benchmarkfall gezeigt wird. Die Abbildung wird zusaetzlich
%   als PSPWM_Waveform_mf<mf>.png gespeichert.

if nargin < 1 || isempty(mf)
    mf = 2;
end
if nargin < 2
    matFile = fullfile(fileparts(mfilename('fullpath')),'Strict_NLM_Benchmark.mat');
    if ~isfile(matFile)
        error('chb:MissingBenchmark', ...
            'Strict_NLM_Benchmark.mat fehlt - zuerst benchmarkStrictNLM ausfuehren.');
    end
    s = load(matFile,'parameters');
    p = s.parameters;
end

schedule = psPWMSchedule(p,mf);
result = strictNLMEvaluateSchedule(p,schedule,2^15);
vStep = p.cellVoltage*p.cellsPerSM;
T = 1/p.frequency;

fig = figure('Name',sprintf('PS-PWM m_f = %d',mf),'Color','w');
try
    fig.Theme = 'light';
catch
end
fig.Position(3:4) = [1150 640];
layout = tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');
title(layout,germanNumber(['PS-PWM auf SM-Ebene: m_f = %d (f_c = %g Hz), %d Stufenwechsel/Periode, ', ...
    'Strom-THD %.3f %%'],mf,mf*p.frequency,result.stepChanges,result.thdCurrent));

stairsT = 1e3*[schedule.edges(1:end-1); schedule.edges(end)];
stairsV = [schedule.levels; schedule.levels(end)]*vStep;

ax1 = nexttile(layout);
hold(ax1,'on');
stairs(ax1,stairsT,stairsV,'Color',[0.9 0.35 0.05],'LineWidth',0.6);
plot(ax1,1e3*result.t,result.vIdeal,'Color',[0 0.42 0.72],'LineWidth',1.3);
plot(ax1,1e3*result.t,result.i,'Color',[0.42 0.15 0.55],'LineWidth',1.2);
plot(ax1,1e3*result.t,result.iIdeal,'--','Color',[0.25 0.65 0.25],'LineWidth',1.1);
hold(ax1,'off');
grid(ax1,'on');
xlim(ax1,[0 1e3*T]);
xlabel(ax1,'Zeit [ms]');
ylabel(ax1,'Spannung [V], Strom [A]');
legend(ax1,{'PWM-Spannung','Idealspannung','Laststrom','Idealstrom'}, ...
    'Location','southwest','NumColumns',2);
title(ax1,'Eine Periode');

zoomWindow = 1e3*[0.20 0.30]*T;
inZoom = 1e3*result.t >= zoomWindow(1) & 1e3*result.t <= zoomWindow(2);
ax2 = nexttile(layout);
hold(ax2,'on');
stairs(ax2,stairsT,stairsV,'Color',[0.9 0.35 0.05],'LineWidth',0.8);
plot(ax2,1e3*result.t(inZoom),result.vIdeal(inZoom),'Color',[0 0.42 0.72],'LineWidth',1.3);
plot(ax2,1e3*result.t(inZoom),result.i(inZoom),'Color',[0.42 0.15 0.55],'LineWidth',1.2);
hold(ax2,'off');
grid(ax2,'on');
xlim(ax2,zoomWindow);
xlabel(ax2,'Zeit [ms]');
ylabel(ax2,'Spannung [V], Strom [A]');
title(ax2,'Zoom um den Sinusscheitel');
germanAxisTicks(ax1,ax2);

pngFile = fullfile(fileparts(mfilename('fullpath')), ...
    sprintf('PSPWM_Waveform_mf%d.png',mf));
exportgraphics(fig,pngFile,'Resolution',150);
fprintf('Wellenform gespeichert: %s\n',pngFile);
end
