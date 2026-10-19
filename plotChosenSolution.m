function out = plotChosenSolution(benchmark)
%PLOTCHOSENSOLUTION Ergebnisplot der vom Optimierer gewählten Lösung.
%   Zeichnet eine Periode der gewählten Lösung aus dem Benchmark
%   (Treppenspannung, Idealspannung, Last- und Idealstrom) im selben
%   Publikationsstil wie plotBenchmarkTHDPlane (400 pt breit, Palatino
%   Linotype, Theme Light) und exportiert sie als Vektor-PDF
%   (Strict_NLM_GewaehlteLoesung.pdf). Die Kennzahlen werden als Tabelle
%   auf der Konsole ausgegeben und im Rückgabestruct zurückgegeben.
%   Ohne Argument werden zwischengespeicherte Ergebnisse aus
%   Strict_NLM_Benchmark.mat geladen.

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
r = strictNLMEvaluateSchedule(p,benchmark.bestResult.schedule,8192);

fontName = 'Palatino Linotype';
fontSize = 10;
fontSizeLegend = 9;

fig = figure('Theme','light','Color','w');
fig.Units = 'points';
fig.Position(3:4) = [400 200];
set(fig, ...
    'DefaultAxesFontName',fontName,'DefaultAxesFontSize',fontSize, ...
    'DefaultTextFontName',fontName,'DefaultTextFontSize',fontSize);

ax = axes(fig);
hold(ax,'on');
schedule = r.schedule;
vStep = p.cellVoltage*p.cellsPerSM;
stairsT = 1e3*[schedule.edges(1:end-1); schedule.edges(end)];
stairsV = [schedule.levels; schedule.levels(end)]*vStep;
tms = 1e3*r.t;

hV = stairs(ax,stairsT,stairsV,'Color',[0.9 0.35 0.05],'LineWidth',0.9);
hVi = plot(ax,tms,r.vIdeal,'Color',[0 0.42 0.72],'LineWidth',1.2);
hI = plot(ax,tms,r.i,'Color',[0.42 0.15 0.55],'LineWidth',1.2);
hIi = plot(ax,tms,r.iIdeal,'--','Color',[0.25 0.65 0.25],'LineWidth',1.0);
hold(ax,'off');
grid(ax,'on');
box(ax,'on');
xlim(ax,[0 1e3/p.frequency]);
xlabel(ax,'Zeit [ms]');
ylabel(ax,'Spannung [V], Strom [A]');
legend(ax,[hV hVi hI hIi], ...
    {'IA-OPP-Spannung','Idealspannung','Laststrom','Idealstrom'}, ...
    'Location','northeast','FontName',fontName,'FontSize',fontSizeLegend);
germanAxisTicks(ax);

pdfFile = fullfile(fileparts(mfilename('fullpath')), ...
    'Strict_NLM_GewaehlteLoesung.pdf');
exportgraphics(fig,pdfFile,'ContentType','vector');
fprintf('Vektor-PDF gespeichert: %s\n',pdfFile);

names = {'Strom-THD';'Spannungs-THD';'Stufenwechsel / Periode'; ...
    'Rekonfigurationsfrequenz';'SM-Zustandsänderungen / Periode'; ...
    'SM-Schaltfrequenz';'Fundamentalspannung Peak';'Fundamentalfehler'; ...
    'Wirkleistung P';'Blindleistung Q';'Scheinleistung S'; ...
    'Leistungsfaktor';'Ohmsche Verluste'};
values = {sprintf('%.3f %%',r.thdCurrent);sprintf('%.3f %%',r.thdVoltage); ...
    sprintf('%d',r.stepChanges);sprintf('%.0f Hz',r.reconfigurationFrequency); ...
    sprintf('%d',r.smChanges);sprintf('%.0f Hz',r.smChanges*p.frequency); ...
    sprintf('%.3f V',r.fundamentalVoltagePeak); ...
    sprintf('%.3f %%',100*r.fundamentalAmplitudeError); ...
    sprintf('%.2f W',r.P);sprintf('%.2f var',r.Q);sprintf('%.2f VA',r.S); ...
    sprintf('%.4f',r.powerFactor);sprintf('%.2f W',r.converterLoss)};
metrics = table(names,values,'VariableNames',{'Kennzahl','Wert'});
fprintf('Kennzahlen der gewählten Lösung:\n');
disp(metrics);

out = struct();
out.result = r;
out.metrics = metrics;
out.figure = fig;
out.pdfFile = pdfFile;
end
