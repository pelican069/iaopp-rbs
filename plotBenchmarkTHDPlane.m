function fig = plotBenchmarkTHDPlane(benchmark,showChosen)
%PLOTBENCHMARKTHDPLANE Publikationsplot der THD-/Rekonfigurationsebene.
%   plotBenchmarkTHDPlane(benchmark) zeichnet die linke Benchmark-Ebene
%   (Strom-THD gegen Stufenwechsel-Frequenz, beide Achsen logarithmisch)
%   aus dem Rückgabestruct von benchmarkStrictNLM und exportiert sie als
%   400 pt breite Vektor-PDF (Strict_NLM_Benchmark_THD_Ebene.pdf).
%   Ohne Argument (oder mit []) werden zwischengespeicherte Ergebnisse
%   aus Strict_NLM_Benchmark.mat geladen; fehlt die Datei, wird
%   benchmarkStrictNLM zunächst ausgeführt.
%   plotBenchmarkTHDPlane(benchmark,true) markiert zusätzlich die vom
%   Optimierer gewählte Lösung (Stern, Anker-Label n=48); standardmäßig
%   bleibt der Vergleichsplot verfahrensneutral ohne diese Markierung —
%   die gewählte Lösung zeigt plotChosenSolution.

close all

if nargin < 2 || isempty(showChosen)
    showChosen = false;
end
if nargin < 1 || isempty(benchmark)
    matFile = fullfile(fileparts(mfilename('fullpath')),'Strict_NLM_Benchmark.mat');
    if isfile(matFile)
        benchmark = load(matFile);
    else
        benchmark = benchmarkStrictNLM();
    end
end

fontName = 'Palatino Linotype';
fontSize = 10;
fontSizeLegend = 9;
colorOpt = [0.05 0.45 0.75];
colorFixed = [0.80 0.25 0.30];
colorPWM = [0.15 0.55 0.35];
colorPWMModule = [0.55 0.25 0.65];
colorChosen = [0.93 0.55 0.05];

fig = figure('Theme','light','Color','w');
fig.Units = 'points';
fig.Position(3:4) = [400 220];
set(fig, ...
    'DefaultAxesFontName',fontName,'DefaultAxesFontSize',fontSize, ...
    'DefaultTextFontName',fontName,'DefaultTextFontSize',fontSize);

ax = axes(fig);
hold(ax,'on');

opt = benchmark.optimizerTable;
fx = benchmark.fixedTable;
best = benchmark.bestResult;

handles = gobjects(0);
names = {};

okOpt = isfinite(opt.THD_I_pct) & isfinite(opt.fRekonf_Hz);
idx = okOpt & opt.zulaessig;
if any(idx)
    h = plot(ax,opt.THD_I_pct(idx),opt.fRekonf_Hz(idx),'-o','Color',colorOpt, ...
        'MarkerFaceColor',colorOpt,'MarkerSize',3.5,'LineWidth',1.0);
    handles(end+1) = h; names{end+1} = 'IA-OPP'; %#ok<*AGROW>
end
idx = okOpt & ~opt.zulaessig;
if any(idx)
    h = plot(ax,opt.THD_I_pct(idx),opt.fRekonf_Hz(idx),'o','Color',colorOpt, ...
        'MarkerSize',4,'LineWidth',0.8,'LineStyle','none');
    handles(end+1) = h; names{end+1} = 'IA-OPP (Toleranz verletzt)';
end

okFixed = isfinite(fx.THD_I_pct) & isfinite(fx.fRekonf_Hz);
idx = okFixed & fx.zulaessig;
if any(idx)
    h = plot(ax,fx.THD_I_pct(idx),fx.fRekonf_Hz(idx),'s','Color',colorFixed, ...
        'MarkerFaceColor',colorFixed,'MarkerSize',5.5,'LineStyle','none');
    handles(end+1) = h; names{end+1} = 'Feste Stufe NLM';
end
idx = okFixed & ~fx.zulaessig;
if any(idx)
    h = plot(ax,fx.THD_I_pct(idx),fx.fRekonf_Hz(idx),'s','Color',colorFixed, ...
        'MarkerSize',5.5,'LineWidth',0.9,'LineStyle','none');
    handles(end+1) = h; names{end+1} = 'Feste Stufe NLM (Toleranz verletzt)';
end
% Punkte auf gleicher Frequenzstufe werden abwechselnd links/rechts
% beschriftet, damit sich die Labels enger Cluster nicht überlappen.
idxAll = find(okFixed(:)).';
for yValue = unique(fx.fRekonf_Hz(idxAll)).'
    group = idxAll(fx.fRekonf_Hz(idxAll) == yValue);
    [~,order] = sort(fx.THD_I_pct(group));
    group = group(order);
    for k = 1:numel(group)
        n = group(k);
        if numel(group) > 1 && mod(k,2) == 1
            labelText = sprintf('%dS ',fx.S(n));
            alignment = 'right';
        else
            labelText = sprintf(' %dS',fx.S(n));
            alignment = 'left';
        end
        text(ax,fx.THD_I_pct(n),fx.fRekonf_Hz(n),labelText, ...
            'Color',colorFixed,'FontName',fontName,'FontSize',fontSize, ...
            'VerticalAlignment','middle','HorizontalAlignment',alignment);
    end
end

if isfield(benchmark,'pwmTable')
    pw = benchmark.pwmTable;
    okPWM = isfinite(pw.THD_I_pct) & isfinite(pw.fRekonf_Hz);
    idx = okPWM & pw.zulaessig;
    if any(idx)
        h = plot(ax,pw.THD_I_pct(idx),pw.fRekonf_Hz(idx),'-^','Color',colorPWM, ...
            'MarkerFaceColor',colorPWM,'MarkerSize',4.5,'LineWidth',1.0);
        handles(end+1) = h; names{end+1} = 'PS-PWM (1S)';
    end
    idx = okPWM & ~pw.zulaessig;
    if any(idx)
        h = plot(ax,pw.THD_I_pct(idx),pw.fRekonf_Hz(idx),'^','Color',colorPWM, ...
            'MarkerSize',5,'LineWidth',0.9,'LineStyle','none');
        handles(end+1) = h; names{end+1} = 'PS-PWM (Toleranz verletzt)';
    end
    for n = find(okPWM(:)).'
        text(ax,pw.THD_I_pct(n),pw.fRekonf_Hz(n),sprintf(' m_f=%d',pw.mf(n)), ...
            'Color',colorPWM,'FontName',fontName,'FontSize',fontSize, ...
            'VerticalAlignment','middle','HorizontalAlignment','left');
    end
end

if isfield(benchmark,'pwmModuleTable')
    pm = benchmark.pwmModuleTable;
    okPWMMod = isfinite(pm.THD_I_pct) & isfinite(pm.fRekonf_Hz);
    idx = okPWMMod & pm.zulaessig;
    if any(idx)
        h = plot(ax,pm.THD_I_pct(idx),pm.fRekonf_Hz(idx),'-v','Color',colorPWMModule, ...
            'MarkerFaceColor',colorPWMModule,'MarkerSize',4.5,'LineWidth',1.0);
        handles(end+1) = h; names{end+1} = sprintf('PS-PWM (Modul, %dS)',pm.S(1));
    end
    idx = okPWMMod & ~pm.zulaessig;
    if any(idx)
        % Offene Marker sind durch den NLM-Eintrag bereits als
        % "Toleranz verletzt" etabliert - kein eigener Legendeneintrag.
        plot(ax,pm.THD_I_pct(idx),pm.fRekonf_Hz(idx),'v','Color',colorPWMModule, ...
            'MarkerSize',5,'LineWidth',0.9,'LineStyle','none');
    end
    for n = find(okPWMMod(:)).'
        text(ax,pm.THD_I_pct(n),pm.fRekonf_Hz(n),sprintf(' m_f=%d',pm.mf(n)), ...
            'Color',colorPWMModule,'FontName',fontName,'FontSize',fontSize, ...
            'VerticalAlignment','middle','HorizontalAlignment','left');
    end
end

if isfield(benchmark,'oppTable')
    % OPP-Baseline: mit linearem Streckenmodell optimiert, real bewertet.
    ot = benchmark.oppTable;
    okOPP = isfinite(ot.THD_real_pct) & ot.zulaessig;
    if any(okOPP)
        h = plot(ax,ot.THD_real_pct(okOPP),ot.fRekonf_Hz(okOPP),'-x', ...
            'Color',[0.40 0.40 0.40],'MarkerSize',4.5,'LineWidth',0.9);
        handles(end+1) = h; names{end+1} = 'klass. OPP';
    end
end

% Ankerpunkte der optimierten Front beschriften (Enden, Knie, Meilenstein).
% Links vom Punkt; bei Bedarf unten links, damit Kurvenzug bzw. die
% 7S-/10S-Labels nicht überdeckt werden. n = Stufenwechsel/Periode.
if showChosen
    h = plot(ax,best.thdCurrent,best.reconfigurationFrequency,'p', ...
        'Color',colorChosen,'MarkerFaceColor',colorChosen,'MarkerSize',11, ...
        'LineStyle','none');
    handles(end+1) = h; names{end+1} = 'Gewählte Lösung';
    optLabelBudgets = [4 8 12 24 48 96];
    optLabelBelow = [4 8 12];
else
    % Ohne Stern ersetzt n=32 (erstmals besser als 1S-NLM) das n=48-Label.
    optLabelBudgets = [4 8 12 24 32 96];
    optLabelBelow = [4 8 12 24];
end
for budget = optLabelBudgets
    n = find(opt.Stufenwechsel == budget,1);
    if isempty(n) || ~isfinite(opt.THD_I_pct(n))
        continue
    end
    if ismember(budget,optLabelBelow)
        vAlign = 'top';
    else
        vAlign = 'middle';
    end
    text(ax,opt.THD_I_pct(n),opt.fRekonf_Hz(n),sprintf('n=%d ',budget), ...
        'Color',colorOpt,'FontName',fontName,'FontSize',fontSize, ...
        'VerticalAlignment',vAlign,'HorizontalAlignment','right');
end

hold(ax,'off');
set(ax,'XScale','log','YScale','log');
grid(ax,'on');
box(ax,'on');
% Etwas Luft links der Achse, damit die n=...-Labels der dichten Front
% nicht am Achsenrand abgeschnitten werden.
xl = xlim(ax);
xlim(ax,[10^(log10(min(opt.THD_I_pct,[],'omitnan'))-0.14) xl(2)]);
xlabel(ax,'Strom-THD [%]');
% ylabel(ax,'Rekonfigurationsfrequenz eines Stranges [Hz]');
ylabel(ax, {'Rekonfigurationsfrequenz'; 'eines Stranges [Hz]'})
legend(ax,handles,names,'Location','best', ...
    'FontName',fontName,'FontSize',fontSizeLegend);
germanAxisTicks(ax);

pdfFile = fullfile(fileparts(mfilename('fullpath')), ...
    'Strict_NLM_Benchmark_THD_Ebene.pdf');
exportgraphics(fig,pdfFile,'ContentType','vector');
fprintf('Vektor-PDF gespeichert: %s\n',pdfFile);
end
