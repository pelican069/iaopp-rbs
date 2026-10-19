function out = plotOperatingPoints()
%PLOTOPERATINGPOINTS Betriebspunkt-Abbildung aus gecachten Sweep-Daten.
%   Rendert die THD-ueber-Modulationsgrad-Abbildung aus
%   Strict_NLM_Betriebspunkte.mat (erzeugt von analyzeOperatingPoints)
%   und exportiert sie als Vektor-PDF (Strict_NLM_Betriebspunkte.pdf).
%   Damit lassen sich Stil-Anpassungen ohne erneuten Sweep-Lauf machen.

thisDir = fileparts(mfilename('fullpath'));
matFile = fullfile(thisDir,'Strict_NLM_Betriebspunkte.mat');
if ~isfile(matFile)
    error('chb:MissingSweep', ...
        'Strict_NLM_Betriebspunkte.mat fehlt - zuerst analyzeOperatingPoints ausfuehren.');
end
s = load(matFile,'resultTable');
t = s.resultTable;
ma = t.ma;

fontName = 'Palatino Linotype';
fontSize = 10;
fontSizeLegend = 9;
fig = figure('Theme','light','Color','w');
fig.Units = 'points';
fig.Position(3:4) = [400 240];
set(fig, ...
    'DefaultAxesFontName',fontName,'DefaultAxesFontSize',fontSize, ...
    'DefaultTextFontName',fontName,'DefaultTextFontSize',fontSize);
ax = axes(fig);
hold(ax,'on');
series = { ...
    struct('y',t.Opt48_THD,'ok',isfinite(t.Opt48_THD),'name','IA-OPP (n=48)', ...
    'color',[0.05 0.45 0.75],'marker','o','style','-'), ...
    struct('y',t.OptBest_THD,'ok',isfinite(t.OptBest_THD),'name','IA-OPP (bestes n \leq 96)', ...
    'color',[0.05 0.45 0.75],'marker','s','style','--'), ...
    struct('y',t.NLM1S_THD,'ok',t.NLM1S_ok,'name','1S-NLM', ...
    'color',[0.80 0.25 0.30],'marker','^','style','-'), ...
    struct('y',t.NLM2S_THD,'ok',t.NLM2S_ok,'name','2S-NLM', ...
    'color',[0.93 0.55 0.05],'marker','v','style','-'), ...
    struct('y',t.PWMSM2_THD,'ok',t.PWMSM2_ok,'name','PS-PWM SM (m_f=2)', ...
    'color',[0.15 0.55 0.35],'marker','d','style','-')};
if ismember('PWMMod10_THD',t.Properties.VariableNames)
    series{end+1} = struct('y',t.PWMMod10_THD,'ok',t.PWMMod10_ok, ...
        'name','PS-PWM Modul (m_f=10)','color',[0.55 0.25 0.65], ...
        'marker','<','style','-');
end
handles = gobjects(1,numel(series));
for k = 1:numel(series)
    sr = series{k};
    handles(k) = plot(ax,ma,sr.y,[sr.style sr.marker],'Color',sr.color, ...
        'MarkerFaceColor',sr.color,'MarkerSize',4.5,'LineWidth',1.0);
    open = ~sr.ok & isfinite(sr.y);
    if any(open)
        plot(ax,ma(open),sr.y(open),sr.marker,'Color',sr.color, ...
            'MarkerFaceColor','w','MarkerSize',5,'LineStyle','none');
    end
end
hold(ax,'off');
set(ax,'YScale','log');
grid(ax,'on');
box(ax,'on');
xlabel(ax,'Modulationsgrad m_a [-]');
ylabel(ax,'Strom-THD [%]');
legend(ax,handles,cellfun(@(s)s.name,series,'UniformOutput',false), ...
    'Location','southeast','FontName',fontName,'FontSize',fontSizeLegend);
germanAxisTicks(ax);

pdfFile = fullfile(thisDir,'Strict_NLM_Betriebspunkte.pdf');
exportgraphics(fig,pdfFile,'ContentType','vector');
fprintf('Vektor-PDF gespeichert: %s\n',pdfFile);

out = struct();
out.table = t;
out.figure = fig;
out.pdfFile = pdfFile;
end