function out = plotSolutionComparison(benchmark)
%PLOTSOLUTIONCOMPARISON Wellenformvergleich der Benchmark-Strategien.
%   Zeichnet Spannungsverlaeufe (oben) und Stromfehler i-i_ideal (unten)
%   einer Periode
%   fuer die gewaehlte optimierte Loesung, beide PS-PWM-Strategien mit
%   sinnvollem Traegerverhaeltnis und zwei Fixed-S-NLM-Referenzen, im
%   Publikationsstil (400 pt breit, Palatino Linotype, Theme Light).
%   Export als Vektor-PDF (Strict_NLM_Vergleich_Wellenformen.pdf).
%   Ohne Argument werden zwischengespeicherte Ergebnisse aus
%   Strict_NLM_Benchmark.mat geladen. Die Auswahl (m_f, S) ist am
%   Funktionsanfang einstellbar.

close all

if nargin < 1 || isempty(benchmark)
    matFile = fullfile(fileparts(mfilename('fullpath')),'Strict_NLM_Benchmark.mat');
    if ~isfile(matFile)
        error('chb:MissingBenchmark', ...
            'Strict_NLM_Benchmark.mat fehlt - zuerst benchmarkStrictNLM ausfuehren.');
    end
    benchmark = load(matFile);
end
p = benchmark.parameters;

% Auswahl der Vergleichskandidaten
mfSM = 2;          % PS-PWM SM-Ebene: erreicht ab m_f=2 ihren THD-Boden
mfModule = 10;     % PS-PWM Modul-Ebene: Rekonfig. vergleichbar mit n=96
nlmS = [2 7];      % Fixed-S-NLM-Referenzen

cases = {};
cases{end+1} = struct('name','IA-OPP (n=48)', ...
    'schedule',benchmark.bestResult.schedule,'color',[0.05 0.45 0.75],'width',1.1);
cases{end+1} = struct('name',sprintf('PS-PWM SM (m_f=%d)',mfSM), ...
    'schedule',psPWMSchedule(p,mfSM),'color',[0.15 0.55 0.35],'width',0.5);
cases{end+1} = struct('name',sprintf('PS-PWM Modul (m_f=%d)',mfModule), ...
    'schedule',psPWMSchedule(p,mfModule,p.smPerModule),'color',[0.55 0.25 0.65],'width',0.5);
for s = nlmS
    cases{end+1} = struct('name',sprintf('%dS-NLM',s), ...
        'schedule',fixedStepNLMSchedule(p,s),'color',[0.80 0.25 0.30],'width',0.8); %#ok<AGROW>
    if s == nlmS(1)
        cases{end}.color = [0.80 0.25 0.30];
    else
        cases{end}.color = [0.93 0.55 0.05];
    end
end

fontName = 'Palatino Linotype';
fontSize = 10;
fontSizeLegend = 9;
vStep = p.cellVoltage*p.cellsPerSM;
T = 1/p.frequency;

fig = figure('Theme','light','Color','w');
fig.Units = 'points';
fig.Position(3:4) = [400 360];
set(fig, ...
    'DefaultAxesFontName',fontName,'DefaultAxesFontSize',fontSize, ...
    'DefaultTextFontName',fontName,'DefaultTextFontSize',fontSize);
layout = tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');

axV = nexttile(layout);
axI = nexttile(layout);
hold(axV,'on'); hold(axI,'on');

handles = gobjects(0);
names = {};
results = cell(numel(cases),1);
% Hinterste Kurven zuerst zeichnen (Modul-PWM ist die unruhigste),
% die optimierte Loesung zuletzt, damit sie oben liegt.
drawOrder = [3 2 5 4 1];
for k = drawOrder
    c = cases{k};
    r = strictNLMEvaluateSchedule(p,c.schedule,8192);
    results{k} = r;
    stairsT = 1e3*[c.schedule.edges(1:end-1); c.schedule.edges(end)];
    stairsV = [c.schedule.levels; c.schedule.levels(end)]*vStep;
    stairs(axV,stairsT,stairsV,'Color',c.color,'LineWidth',c.width);
    plot(axI,1e3*r.t,r.currentError,'Color',c.color,'LineWidth',max(c.width,0.8));
end
% Legende in Kandidatenreihenfolge, mit THD-Angabe
for k = 1:numel(cases)
    r = results{k};
    h = plot(axV,nan,nan,'-','Color',cases{k}.color, ...
        'LineWidth',max(cases{k}.width,1.0));
    handles(end+1) = h; %#ok<AGROW>
    names{end+1} = germanNumber('%s: %.2f %%',cases{k}.name,r.thdCurrent); %#ok<AGROW>
end
hold(axV,'off'); hold(axI,'off');
grid(axV,'on'); grid(axI,'on');
box(axV,'on'); box(axI,'on');
xlim(axV,[0 1e3*T]); xlim(axI,[0 1e3*T]);
ylabel(axV,'Spannung [V]');
xlabel(axI,'Zeit [ms]');
ylabel(axI,'Stromfehler [A]');
lgd = legend(axV,handles,names,'Location','southoutside','NumColumns',3, ...
    'FontName',fontName,'FontSize',fontSizeLegend);
lgd.ItemTokenSize = [12 12];
lgd.Box = "off";
germanAxisTicks(axV,axI);

pdfFile = fullfile(fileparts(mfilename('fullpath')), ...
    'Strict_NLM_Vergleich_Wellenformen.pdf');
exportgraphics(fig,pdfFile,'ContentType','vector');
fprintf('Vektor-PDF gespeichert: %s\n',pdfFile);

out = struct();
out.cases = cases;
out.results = results;
out.figure = fig;
out.pdfFile = pdfFile;
end
