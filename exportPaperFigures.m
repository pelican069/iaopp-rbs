function exportPaperFigures
%EXPORTPAPERFIGURES Englische IEEE-Abbildungen fuer das Journal-Paper.
%   Erzeugt die in paper/figures/FIGURES_TODO.md bestellten fuenf
%   Abbildungen aus den .mat-Caches: 252 pt Breite (IEEE single column),
%   Times New Roman 8 pt, Dezimalpunkt, englische Labels, Vektor-PDF.
%   Die deutschen Dissertationsskripte bleiben unveraendert.

close all

thisDir = fileparts(mfilename('fullpath'));
figDir = fullfile(thisDir,'paper','figures');
s = load(fullfile(thisDir,'Strict_NLM_Benchmark.mat'));
op = load(fullfile(thisDir,'Strict_NLM_Betriebspunkte.mat'));
p = s.parameters;

W = 252;                       % IEEE single column [pt]
fontName = 'Times New Roman';
fs = 8;
colIA = [0.05 0.45 0.75];
colNLM = [0.80 0.25 0.30];
colNLM2 = [0.93 0.55 0.05];
colPWM = [0.15 0.55 0.35];
colPWMM = [0.55 0.25 0.65];
colOPP = [0.40 0.40 0.40];
vStep = p.cellVoltage*p.cellsPerSM;
T = 1/p.frequency;

%% Fig. 1: chosen IA-OPP solution (waveforms, one period)
r = strictNLMEvaluateSchedule(p,s.bestResult.schedule,8192);
fig = newFigure(W,160,fontName,fs);
ax = axes(fig); hold(ax,'on');
sch = s.bestResult.schedule;
hV = stairs(ax,1e3*[sch.edges(1:end-1);sch.edges(end)], ...
    [sch.levels;sch.levels(end)]*vStep,'Color',[0.9 0.35 0.05],'LineWidth',0.7);
hVi = plot(ax,1e3*r.t,r.vIdeal,'Color',colIA,'LineWidth',0.9);
hI = plot(ax,1e3*r.t,r.i,'Color',[0.42 0.15 0.55],'LineWidth',0.9);
hIi = plot(ax,1e3*r.t,r.iIdeal,'--','Color',[0.25 0.65 0.25],'LineWidth',0.8);
hold(ax,'off'); finishAxes(ax);
xlim(ax,[0 1e3*T]);
xlabel(ax,'Time (ms)');
ylabel(ax,'Voltage (V), current (A)');
lgd = legend(ax,[hV hVi hI hIi],{'IA-OPP voltage','ideal voltage', ...
    'load current','ideal current'},'Location','northeast', ...
    'FontName',fontName,'FontSize',fs);
lgd.ItemTokenSize = [10 10];
exportgraphics(fig,fullfile(figDir,'fig_chosen_solution.pdf'),'ContentType','vector');
fprintf('fig_chosen_solution.pdf gespeichert.\n');

%% Fig. 2: current harmonic spectrum (5 series)
cases = { ...
    'IA-OPP',             s.bestResult.schedule,               colIA; ...
    '1S-NLM',             fixedStepNLMSchedule(p,1),           colNLM; ...
    'PS-PWM (submodule)', psPWMSchedule(p,2),                  colPWM; ...
    'PS-PWM (module)',    psPWMSchedule(p,10,p.smPerModule),   colPWMM; ...
    'classical OPP',      s.oppSchedules{48},                  colOPP};
spectra = [];
for k = 1:size(cases,1)
    rk = strictNLMEvaluateSchedule(p,cases{k,2},0);
    rel = 100*rk.currentHarmonicRms(2:end)/rk.currentHarmonicRms(1);
    rel(rel <= 0) = nan;
    spectra(:,k) = rel; %#ok<AGROW>
end
orders = (2:p.maxHarmonic).';
fig = newFigure(W,190,fontName,fs);
ax = axes(fig);
hB = bar(ax,orders,spectra,1.0,'grouped','EdgeColor','none');
for k = 1:size(cases,1)
    hB(k).FaceColor = cases{k,3};
end
set(ax,'YScale','log'); finishAxes(ax);
xlim(ax,[1.5 orders(end)+0.5]); ylim(ax,[1e-3 2]);
xticks(ax,[3 5 7 11 15 20 30 40 50]);
xlabel(ax,'Harmonic order');
ylabel(ax,'Current harmonic (% of fundamental)');
% Legende unterhalb der Achse, damit das Traegerband der Modul-PWM
% (h >= 43) frei sichtbar bleibt (Paper-Review-Auftrag 5).
lgd = legend(ax,hB,cases(:,1),'Location','southoutside','NumColumns',2, ...
    'FontName',fontName,'FontSize',fs);
lgd.ItemTokenSize = [8 8];
exportgraphics(fig,fullfile(figDir,'fig_spectrum.pdf'),'ContentType','vector');
fprintf('fig_spectrum.pdf gespeichert.\n');

%% Fig. 3: predistortion (IA-OPP vs. classical OPP at n = 48)
fig = newFigure(W,240,fontName,fs);
layout = tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');
axV = nexttile(layout); axI = nexttile(layout);
hold(axV,'on'); hold(axI,'on');
pd = {'IA-OPP',s.bestResult.schedule,colIA; ...
      'classical OPP',s.oppSchedules{48},colOPP};
handles = gobjects(1,2);
for k = 1:2
    rk = strictNLMEvaluateSchedule(p,pd{k,2},8192);
    handles(k) = stairs(axV,1e3*[pd{k,2}.edges(1:end-1);pd{k,2}.edges(end)], ...
        [pd{k,2}.levels;pd{k,2}.levels(end)]*vStep,'Color',pd{k,3},'LineWidth',0.7);
    plot(axI,1e3*rk.t,rk.currentError,'Color',pd{k,3},'LineWidth',0.8);
end
hold(axV,'off'); hold(axI,'off');
finishAxes(axV); finishAxes(axI);
xlim(axV,[0 1e3*T]); xlim(axI,[0 1e3*T]);
ylabel(axV,'Source voltage (V)');
xlabel(axI,'Time (ms)');
ylabel(axI,'Current error (A)');
lgd = legend(axV,handles,pd(:,1),'Location','northeast', ...
    'FontName',fontName,'FontSize',fs);
lgd.ItemTokenSize = [10 10];
exportgraphics(fig,fullfile(figDir,'fig_predistortion.pdf'),'ContentType','vector');
fprintf('fig_predistortion.pdf gespeichert.\n');

%% Fig. 4: THD plane (current THD vs. string reconfiguration frequency)
fig = newFigure(W,210,fontName,fs);
ax = axes(fig); hold(ax,'on');
handles = gobjects(0); names = {};
ot = s.optimizerTable;
idx = isfinite(ot.THD_I_pct) & ot.zulaessig;
h = plot(ax,ot.THD_I_pct(idx),1e-3*ot.fRekonf_Hz(idx),'-o','Color',colIA, ...
    'MarkerFaceColor',colIA,'MarkerSize',2.2,'LineWidth',0.9);
handles(end+1) = h; names{end+1} = 'IA-OPP';
oppT = s.oppTable;
idx = isfinite(oppT.THD_real_pct) & oppT.zulaessig;
h = plot(ax,oppT.THD_real_pct(idx),1e-3*oppT.fRekonf_Hz(idx),'-x','Color',colOPP, ...
    'MarkerSize',3.5,'LineWidth',0.7);
handles(end+1) = h; names{end+1} = 'classical OPP';
fx = s.fixedTable;
idx = fx.zulaessig;
h = plot(ax,fx.THD_I_pct(idx),1e-3*fx.fRekonf_Hz(idx),'s','Color',colNLM, ...
    'MarkerFaceColor',colNLM,'MarkerSize',3.5,'LineStyle','none');
handles(end+1) = h; names{end+1} = 'fixed-step NLM';
idx = ~fx.zulaessig;
h = plot(ax,fx.THD_I_pct(idx),1e-3*fx.fRekonf_Hz(idx),'s','Color',colNLM, ...
    'MarkerSize',3.5,'LineWidth',0.6,'LineStyle','none');
handles(end+1) = h; names{end+1} = 'fixed-step NLM (tol. violated)';
% Beschriftung der S-Punkte, in Clustern alternierend links/rechts
idxAll = find(isfinite(fx.THD_I_pct(:))).';
for yValue = unique(fx.fRekonf_Hz(idxAll)).'
    group = idxAll(fx.fRekonf_Hz(idxAll) == yValue);
    [~,order] = sort(fx.THD_I_pct(group));
    group = group(order);
    for k = 1:numel(group)
        n = group(k);
        if numel(group) > 1 && mod(k,2) == 1
            txt = sprintf('%dS ',fx.S(n)); alignment = 'right';
        else
            txt = sprintf(' %dS',fx.S(n)); alignment = 'left';
        end
        text(ax,fx.THD_I_pct(n),1e-3*fx.fRekonf_Hz(n),txt,'Color',colNLM, ...
            'FontName',fontName,'FontSize',fs-1, ...
            'VerticalAlignment','middle','HorizontalAlignment',alignment);
    end
end
pw = s.pwmTable;
h = plot(ax,pw.THD_I_pct,1e-3*pw.fRekonf_Hz,'-^','Color',colPWM, ...
    'MarkerFaceColor',colPWM,'MarkerSize',2.8,'LineWidth',0.8);
handles(end+1) = h; names{end+1} = 'PS-PWM (submodule)';
pm = s.pwmModuleTable;
idx = pm.zulaessig;
h = plot(ax,pm.THD_I_pct(idx),1e-3*pm.fRekonf_Hz(idx),'-v','Color',colPWMM, ...
    'MarkerFaceColor',colPWMM,'MarkerSize',2.8,'LineWidth',0.8);
handles(end+1) = h; names{end+1} = 'PS-PWM (module)';
plot(ax,pm.THD_I_pct(~idx),1e-3*pm.fRekonf_Hz(~idx),'v','Color',colPWMM, ...
    'MarkerSize',3.2,'LineWidth',0.6,'LineStyle','none');
hold(ax,'off');
set(ax,'XScale','log','YScale','log'); finishAxes(ax);
xlabel(ax,'Current THD (%)');
ylabel(ax,'String reconfiguration frequency (kHz)');
lgd = legend(ax,handles,names,'Location','northeast', ...
    'FontName',fontName,'FontSize',fs-1);
lgd.ItemTokenSize = [9 9];
exportgraphics(fig,fullfile(figDir,'fig_thd_plane.pdf'),'ContentType','vector');
fprintf('fig_thd_plane.pdf gespeichert.\n');

%% Fig. 5: operating-point sweep
t = op.resultTable;
fig = newFigure(W,180,fontName,fs);
ax = axes(fig); hold(ax,'on');
series = { ...
    t.Opt48_THD,   isfinite(t.Opt48_THD),  'IA-OPP (n = 48)',        colIA,  'o','-'; ...
    t.OptBest_THD, isfinite(t.OptBest_THD),'IA-OPP (best n \leq 96)',colIA,  's','--'; ...
    t.NLM1S_THD,   t.NLM1S_ok,             '1S-NLM',                 colNLM, '^','-'; ...
    t.NLM2S_THD,   t.NLM2S_ok,             '2S-NLM',                 colNLM2,'v','-'; ...
    t.PWMSM2_THD,  t.PWMSM2_ok,            'PS-PWM (submodule)',     colPWM, 'd','-'; ...
    t.PWMMod10_THD,t.PWMMod10_ok,          'PS-PWM (module)',        colPWMM,'<','-'};
handles = gobjects(1,size(series,1));
for k = 1:size(series,1)
    handles(k) = plot(ax,t.ma,series{k,1},[series{k,6} series{k,5}], ...
        'Color',series{k,4},'MarkerFaceColor',series{k,4}, ...
        'MarkerSize',2.8,'LineWidth',0.8);
    open = ~series{k,2} & isfinite(series{k,1});
    if any(open)
        plot(ax,t.ma(open),series{k,1}(open),series{k,5},'Color',series{k,4}, ...
            'MarkerFaceColor','w','MarkerSize',3.2,'LineStyle','none');
    end
end
hold(ax,'off');
set(ax,'YScale','log'); finishAxes(ax);
xlabel(ax,'Modulation index');
ylabel(ax,'Current THD (%)');
lgd = legend(ax,handles,series(:,3),'Location','southeast', ...
    'FontName',fontName,'FontSize',fs-1);
lgd.ItemTokenSize = [9 9];
exportgraphics(fig,fullfile(figDir,'fig_operating_points.pdf'),'ContentType','vector');
fprintf('fig_operating_points.pdf gespeichert.\n');
end

function fig = newFigure(widthPt,heightPt,fontName,fs)
fig = figure('Theme','light','Color','w');
fig.Units = 'points';
fig.Position(3:4) = [widthPt heightPt];
set(fig, ...
    'DefaultAxesFontName',fontName,'DefaultAxesFontSize',fs, ...
    'DefaultTextFontName',fontName,'DefaultTextFontSize',fs);
end

function finishAxes(ax)
grid(ax,'on');
box(ax,'on');
end
