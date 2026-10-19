function out = analyzeRobustness(benchmark)
%ANALYZEROBUSTNESS THD-Robustheit fester Schaltmuster gegen Modellfehler.
%   Die Schaltmuster (optimierte Loesung, Fixed-S-NLM, PS-PWM) werden mit
%   den Nominalparametern erzeugt und anschliessend auf gestoerten
%   Strecken ausgewertet: Lastinduktivitaet, Lastwiderstand,
%   Batteriezellwiderstand und Zellspannung werden einzeln um -30..+30 %
%   variiert. Da die optimierte Loesung die stufenabhaengige
%   Widerstandsmodulation modellbasiert vorverzerrt, zeigt die Analyse,
%   wie viel ihres THD-Vorsprungs bei Modellfehlern erhalten bleibt.
%   Export als Vektor-PDF (Strict_NLM_Robustheit.pdf); ohne Argument
%   werden die Ergebnisse aus Strict_NLM_Benchmark.mat geladen.

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

cases = { ...
    struct('name','IA-OPP (n=48)','schedule',benchmark.bestResult.schedule, ...
    'color',[0.05 0.45 0.75]), ...
    struct('name','1S-NLM','schedule',fixedStepNLMSchedule(p,1), ...
    'color',[0.80 0.25 0.30]), ...
    struct('name','2S-NLM','schedule',fixedStepNLMSchedule(p,2), ...
    'color',[0.93 0.55 0.05]), ...
    struct('name','PS-PWM SM (m_f=2)','schedule',psPWMSchedule(p,2), ...
    'color',[0.15 0.55 0.35]), ...
    struct('name','PS-PWM Modul (m_f=10)','schedule',psPWMSchedule(p,10,p.smPerModule), ...
    'color',[0.55 0.25 0.65])};

sweeps = { ...
    struct('field','loadL','label','Lastinduktivität L'), ...
    struct('field','loadR','label','Lastwiderstand R'), ...
    struct('field','rBattery','label','Batteriezellwiderstand'), ...
    struct('field','cellVoltage','label','Zellspannung')};
factors = 0.7:0.05:1.3;

thd = nan(numel(factors),numel(cases),numel(sweeps));
for sw = 1:numel(sweeps)
    for f = 1:numel(factors)
        pp = p;
        pp.(sweeps{sw}.field) = p.(sweeps{sw}.field)*factors(f);
        for k = 1:numel(cases)
            r = strictNLMEvaluateSchedule(pp,cases{k}.schedule,0);
            thd(f,k,sw) = r.thdCurrent;
        end
    end
end

fontName = 'Palatino Linotype';
fontSize = 10;
fontSizeLegend = 9;

fig = figure('Theme','light','Color','w');
fig.Units = 'points';
fig.Position(3:4) = [400 400];
set(fig, ...
    'DefaultAxesFontName',fontName,'DefaultAxesFontSize',fontSize, ...
    'DefaultTextFontName',fontName,'DefaultTextFontSize',fontSize);
layout = tiledlayout(fig,2,2,'Padding','compact','TileSpacing','compact');

deviation = 100*(factors-1);
handles = gobjects(1,numel(cases));
axesList = gobjects(1,numel(sweeps));
for sw = 1:numel(sweeps)
    ax = nexttile(layout);
    axesList(sw) = ax;
    hold(ax,'on');
    for k = 1:numel(cases)
        h = plot(ax,deviation,thd(:,k,sw),'-','Color',cases{k}.color,'LineWidth',1.1);
        if sw == 1
            handles(k) = h;
        end
    end
    hold(ax,'off');
    grid(ax,'on');
    box(ax,'on');
    set(ax,'YScale','log');
    xlim(ax,[deviation(1) deviation(end)]);
    title(ax,sweeps{sw}.label,'FontWeight','normal');
    if sw >= 3
        xlabel(ax,'Parameterabweichung [%]');
    end
    if mod(sw,2) == 1
        ylabel(ax,'Strom-THD [%]');
    end
end
lgd = legend(handles,cellfun(@(c)c.name,cases,'UniformOutput',false), ...
    'NumColumns',3,'FontName',fontName,'FontSize',fontSizeLegend);
lgd.Layout.Tile = 'south';
germanAxisTicks(axesList(:).');

pdfFile = fullfile(fileparts(mfilename('fullpath')),'Strict_NLM_Robustheit.pdf');
exportgraphics(fig,pdfFile,'ContentType','vector');
fprintf('Vektor-PDF gespeichert: %s\n',pdfFile);

% Konsolenzusammenfassung: nominale und Worst-Case-THD je Kandidat
nominalIdx = find(abs(factors-1) < 1e-12,1);
fprintf('\nTHD nominal / Worst-Case ueber alle Sweeps (+-30 %%):\n');
for k = 1:numel(cases)
    worst = max(thd(:,k,:),[],'all');
    fprintf('  %-24s %.3f %%  ->  %.3f %%\n',cases{k}.name, ...
        thd(nominalIdx,k,1),worst);
end

% Gemeinsame Extremkombinationen: alle 16 Ecken des +-30-%-Stoerwuerfels
% (alle vier Parameter gleichzeitig auf Minimum oder Maximum).
cornerSigns = dec2bin(0:15) - '0';
cornerFactors = 0.7 + 0.6*cornerSigns;                % 0.7 oder 1.3
cornerTHD = nan(size(cornerFactors,1),numel(cases));
for c = 1:size(cornerFactors,1)
    pp = p;
    for sw = 1:numel(sweeps)
        pp.(sweeps{sw}.field) = p.(sweeps{sw}.field)*cornerFactors(c,sw);
    end
    for k = 1:numel(cases)
        r = strictNLMEvaluateSchedule(pp,cases{k}.schedule,0);
        cornerTHD(c,k) = r.thdCurrent;
    end
end
fprintf('\nEckpunkte des Stoerwuerfels (L, R, rBat, Uz gleichzeitig +-30 %%):\n');
fprintf('   L    R   rBat  Uz  |');
caseNames = cellfun(@(c)c.name,cases,'UniformOutput',false);
fprintf('  %-12.12s',caseNames{:});
fprintf('\n');
for c = 1:size(cornerFactors,1)
    fprintf(' %+3.0f%% %+3.0f%% %+3.0f%% %+3.0f%% |',100*(cornerFactors(c,:)-1));
    fprintf('  %-12.4f',cornerTHD(c,:));
    fprintf('\n');
end
[~,bestPerCorner] = min(cornerTHD,[],2);
optimalEverywhere = all(bestPerCorner == 1);
fprintf('Worst-Case ueber alle Ecken:');
fprintf('  %s %.3f %%;',cases{1}.name,max(cornerTHD(:,1)));
fprintf('  beste Baseline %.3f %%.\n',max(min(cornerTHD(:,2:end),[],2)));
if optimalEverywhere
    fprintf('Die optimierte Loesung ist an allen 16 Eckpunkten die beste.\n');
else
    fprintf('ACHTUNG: An %d Eckpunkten ist eine Baseline besser.\n', ...
        sum(bestPerCorner ~= 1));
end

out = struct();
out.cornerFactors = cornerFactors;
out.cornerTHD = cornerTHD;
out.cornerOptimalEverywhere = optimalEverywhere;
out.factors = factors;
out.sweeps = sweeps;
out.cases = {cases{:}};
out.thd = thd;
out.figure = fig;
out.pdfFile = pdfFile;
end
