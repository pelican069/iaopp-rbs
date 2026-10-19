function out = plotHarmonicSpectrum(benchmark)
%PLOTHARMONICSPECTRUM Stromharmonische der Benchmark-Strategien.
%   Zeichnet die Stromharmonischen h = 2..maxHarmonic (bezogen auf die
%   jeweilige Grundschwingung, logarithmische y-Achse) fuer die gewaehlte
%   optimierte Loesung, 1S-NLM und beide PS-PWM-Strategien, im
%   Publikationsstil (400 pt breit, Palatino Linotype, Theme Light).
%   Export als Vektor-PDF (Strict_NLM_Spektrum.pdf). Ohne Argument werden
%   zwischengespeicherte Ergebnisse aus Strict_NLM_Benchmark.mat geladen.

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
mfSM = 2;
mfModule = 10;

cases = { ...
    struct('name','IA-OPP (n=48)','schedule',benchmark.bestResult.schedule, ...
    'color',[0.05 0.45 0.75]), ...
    struct('name','1S-NLM','schedule',fixedStepNLMSchedule(p,1), ...
    'color',[0.80 0.25 0.30]), ...
    struct('name',sprintf('PS-PWM SM (m_f=%d)',mfSM),'schedule',psPWMSchedule(p,mfSM), ...
    'color',[0.15 0.55 0.35]), ...
    struct('name',sprintf('PS-PWM Modul (m_f=%d)',mfModule), ...
    'schedule',psPWMSchedule(p,mfModule,p.smPerModule),'color',[0.55 0.25 0.65])};
if isfield(benchmark,'oppSchedules') && numel(benchmark.oppSchedules) >= 48 && ...
        ~isempty(benchmark.oppSchedules{48})
    cases{end+1} = struct('name','klass. OPP (n=48)', ...
        'schedule',benchmark.oppSchedules{48},'color',[0.40 0.40 0.40]);
end

fontName = 'Palatino Linotype';
fontSize = 10;
fontSizeLegend = 9;

fig = figure('Theme','light','Color','w');
fig.Units = 'points';
fig.Position(3:4) = [400 220];
set(fig, ...
    'DefaultAxesFontName',fontName,'DefaultAxesFontSize',fontSize, ...
    'DefaultTextFontName',fontName,'DefaultTextFontSize',fontSize);
ax = axes(fig);
hold(ax,'on');

orders = [];
spectra = [];
names = cell(1,numel(cases));
results = cell(1,numel(cases));
for k = 1:numel(cases)
    r = strictNLMEvaluateSchedule(p,cases{k}.schedule,0);
    results{k} = r;
    orders = r.harmonicOrders(2:end);
    relative = 100*r.currentHarmonicRms(2:end)/r.currentHarmonicRms(1);
    relative(relative <= 0) = nan;
    spectra(:,k) = relative; %#ok<AGROW>
    names{k} = germanNumber('%s: %.2f %%',cases{k}.name,r.thdCurrent);
end

hBars = bar(ax,orders,spectra,1.0,'grouped','EdgeColor','none');
for k = 1:numel(cases)
    hBars(k).FaceColor = cases{k}.color;
end
hold(ax,'off');
set(ax,'YScale','log');
grid(ax,'on');
box(ax,'on');
xlim(ax,[1.5 orders(end)+0.5]);
ylim(ax,[1e-3 2]);
xticks(ax,[3 5 7 9 11 15 20 25 30 35 40 45 50]);
xlabel(ax,'Harmonische Ordnung h');
ylabel(ax,{'Stromharmonische'; '[% der Grundschwingung]'});
legend(ax,hBars,names,'Location','northeast', ...
    'FontName',fontName,'FontSize',fontSizeLegend);
germanAxisTicks(ax);

pdfFile = fullfile(fileparts(mfilename('fullpath')),'Strict_NLM_Spektrum.pdf');
exportgraphics(fig,pdfFile,'ContentType','vector');
fprintf('Vektor-PDF gespeichert: %s\n',pdfFile);

out = struct();
out.orders = orders;
out.spectraPercent = spectra;
out.names = {cases{:}};
out.results = results;
out.figure = fig;
out.pdfFile = pdfFile;
end
