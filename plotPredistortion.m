function out = plotPredistortion(benchmark)
%PLOTPREDISTORTION Vorverzerrung sichtbar: Optimiert vs. OPP bei n = 48.
%   Vergleicht zwei Schaltmuster mit identischem Budget: die streckenbewusst
%   optimierte Loesung und das OPP-Muster (lineares Streckenmodell im
%   Guetemass), beide auf der realen Strecke bewertet. Oben die beiden
%   Treppenspannungen, unten die Stromfehler i - i_ideal. Die fast
%   deckungsgleichen Treppen mit deutlich verschiedenem Stromfehler zeigen
%   die implizite Vorverzerrung. Publikationsstil (400 pt, Palatino, Theme
%   light, Dezimalkomma), Export: Strict_NLM_Vorverzerrung.pdf.
%   Ohne Argument werden zwischengespeicherte Ergebnisse aus
%   Strict_NLM_Benchmark.mat geladen (benoetigt oppSchedules aus
%   analyzeOPPBaseline).

close all

if nargin < 1 || isempty(benchmark)
    matFile = fullfile(fileparts(mfilename('fullpath')),'Strict_NLM_Benchmark.mat');
    if ~isfile(matFile)
        error('chb:MissingBenchmark', ...
            'Strict_NLM_Benchmark.mat fehlt - zuerst benchmarkStrictNLM ausfuehren.');
    end
    benchmark = load(matFile);
end
if ~isfield(benchmark,'oppSchedules') || numel(benchmark.oppSchedules) < 48 || ...
        isempty(benchmark.oppSchedules{48})
    error('chb:MissingOPP', ...
        'oppSchedules fehlen - zuerst analyzeOPPBaseline ausfuehren.');
end
p = benchmark.parameters;
T = 1/p.frequency;
vStep = p.cellVoltage*p.cellsPerSM;

cases = { ...
    struct('name','IA-OPP','schedule',benchmark.bestResult.schedule, ...
    'color',[0.05 0.45 0.75]), ...
    struct('name','klass. OPP','schedule',benchmark.oppSchedules{48}, ...
    'color',[0.40 0.40 0.40])};

fontName = 'Palatino Linotype';
fontSize = 10;
fontSizeLegend = 9;

fig = figure('Theme','light','Color','w');
fig.Units = 'points';
fig.Position(3:4) = [400 340];
set(fig, ...
    'DefaultAxesFontName',fontName,'DefaultAxesFontSize',fontSize, ...
    'DefaultTextFontName',fontName,'DefaultTextFontSize',fontSize);
layout = tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');

axV = nexttile(layout);
axI = nexttile(layout);
hold(axV,'on'); hold(axI,'on');
handles = gobjects(1,numel(cases));
names = cell(1,numel(cases));
for k = 1:numel(cases)
    c = cases{k};
    r = strictNLMEvaluateSchedule(p,c.schedule,8192);
    stairsT = 1e3*[c.schedule.edges(1:end-1); c.schedule.edges(end)];
    stairsV = [c.schedule.levels; c.schedule.levels(end)]*vStep;
    handles(k) = stairs(axV,stairsT,stairsV,'Color',c.color,'LineWidth',1.0);
    plot(axI,1e3*r.t,r.currentError,'Color',c.color,'LineWidth',1.0);
    names{k} = germanNumber('%s (n=%d): %.2f %%',c.name, ...
        r.stepChanges,r.thdCurrent);
end
hold(axV,'off'); hold(axI,'off');
grid(axV,'on'); grid(axI,'on');
box(axV,'on'); box(axI,'on');
xlim(axV,[0 1e3*T]); xlim(axI,[0 1e3*T]);
ylabel(axV,'Spannung [V]');
xlabel(axI,'Zeit [ms]');
ylabel(axI,'Stromfehler [A]');
lgd = legend(axV,handles,names,'Location','southoutside','NumColumns',2, ...
    'FontName',fontName,'FontSize',fontSizeLegend);
lgd.ItemTokenSize = [12 12];
germanAxisTicks(axV,axI);

pdfFile = fullfile(fileparts(mfilename('fullpath')), ...
    'Strict_NLM_Vorverzerrung.pdf');
exportgraphics(fig,pdfFile,'ContentType','vector');
fprintf('Vektor-PDF gespeichert: %s\n',pdfFile);

out = struct();
out.figure = fig;
out.pdfFile = pdfFile;
end
