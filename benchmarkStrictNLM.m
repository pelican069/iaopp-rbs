function benchmark = benchmarkStrictNLM(p)
%BENCHMARKSTRICTNLM Fixed-S-NLM-Baselines gegen die optimierte Pareto-Front.
%   benchmark = benchmarkStrictNLM() vergleicht klassische NLM mit fester
%   Stufengranularitaet (1S, 2S, ... 12S) gegen die budgetweise optimierten
%   Schaltmuster. Alle Kandidaten werden durch strictNLMEvaluateSchedule
%   bewertet, damit Lastmodell, THD-Definition und Verlustwiderstaende
%   identisch sind. Zwei Ergebnisebenen (x-Achse jeweils Strom-THD):
%     1) Stufenwechsel-Frequenz  -> Strangrekonfigurationen (Datenbus-Last)
%     2) SM-Schaltfrequenz       -> reale Schalthandlungen (Verlust-Proxy)
%   Punkte ausserhalb der Fundamentaltoleranz sind offen markiert.
%
%   Optional kann eine Parameterstruktur wie in der GUI uebergeben werden.
%   Rueckgabe: Tabellen beider Verfahren, Optimierer-Diagnostik und die
%   Handles der erzeugten Abbildung.

if nargin < 1
    p = defaultParameters();
end
if ~isfield(p,'benchmarkMaxEvents')
    p.benchmarkMaxEvents = 96;
end
if ~isfield(p,'pwmCarrierRatios')
    p.pwmCarrierRatios = [1 2 3 5 7 10];
end
if ~isfield(p,'pwmModuleCarrierRatios')
    p.pwmModuleCarrierRatios = [1 2 3 5 7 10 15 20];
end

sValues = 1:12;
frequency = p.frequency;

%% Fixed-S-NLM-Baselines
fixedCount = numel(sValues);
fixedTHD = nan(fixedCount,1);
fixedStepChanges = nan(fixedCount,1);
fixedSMChanges = nan(fixedCount,1);
fixedFundError = nan(fixedCount,1);
fixedLoss = nan(fixedCount,1);
for n = 1:fixedCount
    schedule = fixedStepNLMSchedule(p,sValues(n));
    if isempty(schedule)
        continue
    end
    r = strictNLMEvaluateSchedule(p,schedule,p.outputSamples);
    fixedTHD(n) = r.thdCurrent;
    fixedStepChanges(n) = r.stepChanges;
    fixedSMChanges(n) = r.smChanges;
    fixedFundError(n) = r.fundamentalAmplitudeError;
    fixedLoss(n) = r.converterLoss;
end
fixedFeasible = fixedFundError <= p.fundamentalTolerance + 1e-12;

fixedTable = table(sValues(:),fixedStepChanges,frequency*fixedStepChanges, ...
    fixedSMChanges,frequency*fixedSMChanges,fixedTHD,100*fixedFundError, ...
    fixedLoss,fixedFeasible,'VariableNames',{'S','Stufenwechsel','fRekonf_Hz', ...
    'SMWechsel','fSM_Hz','THD_I_pct','FundFehler_pct','Verluste_W','zulaessig'});

%% PS-PWM-Baseline (phasenversetzte Traeger auf SM-Ebene, 1S-Schritte)
mfValues = p.pwmCarrierRatios(:);
pwmCount = numel(mfValues);
pwmTHD = nan(pwmCount,1);
pwmStepChanges = nan(pwmCount,1);
pwmSMChanges = nan(pwmCount,1);
pwmFundError = nan(pwmCount,1);
pwmLoss = nan(pwmCount,1);
for n = 1:pwmCount
    schedule = psPWMSchedule(p,mfValues(n));
    r = strictNLMEvaluateSchedule(p,schedule,0);
    pwmTHD(n) = r.thdCurrent;
    pwmStepChanges(n) = r.stepChanges;
    pwmSMChanges(n) = r.smChanges;
    pwmFundError(n) = r.fundamentalAmplitudeError;
    pwmLoss(n) = r.converterLoss;
end
pwmFeasible = pwmFundError <= p.fundamentalTolerance + 1e-12;

pwmTable = table(mfValues,frequency*mfValues,pwmStepChanges, ...
    frequency*pwmStepChanges,pwmSMChanges,frequency*pwmSMChanges,pwmTHD, ...
    100*pwmFundError,pwmLoss,pwmFeasible,'VariableNames',{'mf','fc_Hz', ...
    'Stufenwechsel','fRekonf_Hz','SMWechsel','fSM_Hz','THD_I_pct', ...
    'FundFehler_pct','Verluste_W','zulaessig'});

%% PS-PWM auf Modul-Ebene (klassisch: ein Traeger je H-Bruecke)
blockSize = p.smPerModule;
mfModValues = p.pwmModuleCarrierRatios(:);
pwmModCount = numel(mfModValues);
pwmModTHD = nan(pwmModCount,1);
pwmModStepChanges = nan(pwmModCount,1);
pwmModSMChanges = nan(pwmModCount,1);
pwmModFundError = nan(pwmModCount,1);
pwmModLoss = nan(pwmModCount,1);
for n = 1:pwmModCount
    schedule = psPWMSchedule(p,mfModValues(n),blockSize);
    r = strictNLMEvaluateSchedule(p,schedule,0);
    pwmModTHD(n) = r.thdCurrent;
    pwmModStepChanges(n) = r.stepChanges;
    pwmModSMChanges(n) = r.smChanges;
    pwmModFundError(n) = r.fundamentalAmplitudeError;
    pwmModLoss(n) = r.converterLoss;
end
pwmModFeasible = pwmModFundError <= p.fundamentalTolerance + 1e-12;

pwmModuleTable = table(repmat(blockSize,pwmModCount,1),mfModValues, ...
    frequency*mfModValues,pwmModStepChanges,frequency*pwmModStepChanges, ...
    pwmModSMChanges,frequency*pwmModSMChanges,pwmModTHD,100*pwmModFundError, ...
    pwmModLoss,pwmModFeasible,'VariableNames',{'S','mf','fc_Hz', ...
    'Stufenwechsel','fRekonf_Hz','SMWechsel','fSM_Hz','THD_I_pct', ...
    'FundFehler_pct','Verluste_W','zulaessig'});

%% Optimierte Pareto-Front ueber alle Ereignisbudgets
po = p;
po.mode = 'events';
po.maxEvents = p.benchmarkMaxEvents;
po.searchMaxEvents = po.maxEvents;
fprintf('Optimiere alle Budgets bis %d Stufenwechsel pro Periode ...\n',po.maxEvents);
progress = @(fraction,message) fprintf('  %3.0f %%  %s\n',100*fraction,message);
[best,diag] = strictNLMOptimizeSchedule(po,progress);

tested = diag.testedBudgets;
optTHD = diag.candidateTHD(tested);
optStepFreq = frequency*tested;
optSMFreq = frequency*diag.candidateSMChanges(tested);
optFundError = diag.candidateFundamentalError(tested);
optLoss = diag.candidateConverterLoss(tested);
optFeasible = optFundError <= p.fundamentalTolerance + 1e-12;

optimizerTable = table(tested,optStepFreq,diag.candidateSMChanges(tested), ...
    optSMFreq,optTHD,100*optFundError,optLoss,optFeasible, ...
    'VariableNames',{'Stufenwechsel','fRekonf_Hz','SMWechsel','fSM_Hz', ...
    'THD_I_pct','FundFehler_pct','Verluste_W','zulaessig'});

%% Konsolenausgabe
fprintf('\nFixed-S-NLM-Baselines:\n');
disp(fixedTable);
fprintf('PS-PWM-Baselines (SM-Ebene, 1S):\n');
disp(pwmTable);
fprintf('PS-PWM-Baselines (Modul-Ebene, %dS):\n',blockSize);
disp(pwmModuleTable);
fprintf('Optimierte Kandidaten je Budget:\n');
disp(optimizerTable);
fprintf(['Gewaehlte optimierte Loesung: %.3f %% THD, %d Stufenwechsel ', ...
    '(%.0f Hz), %d SM-Wechsel (%.0f Hz), %.2f W Verluste.\n\n'], ...
    best.thdCurrent,best.stepChanges,frequency*best.stepChanges, ...
    best.smChanges,frequency*best.smChanges,best.converterLoss);

%% Ergebnisebenen
fig = figure('Name','Strict-NLM-Benchmark','Color','w','Position',[80 80 1240 540]);
try
    fig.Theme = 'light';
catch
end
layout = tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
title(layout,sprintf(['Benchmark: Fixed-S-NLM gegen optimierte Schaltmuster ', ...
    '(%g V Peak, %g Hz, R = %g Ohm, L = %g mH)'],p.voltagePeak,p.frequency, ...
    p.loadR,1e3*p.loadL));

pwmName = 'PS-PWM SM (1S)';
pwmModName = sprintf('PS-PWM Modul (%dS)',blockSize);
pwmColor = [0.15 0.55 0.35];
pwmModColor = [0.55 0.25 0.65];
pwmStepList = { ...
    struct('thd',pwmTHD,'freq',frequency*pwmStepChanges,'feasible',pwmFeasible, ...
    'mf',mfValues,'name',pwmName,'color',pwmColor,'marker','^'), ...
    struct('thd',pwmModTHD,'freq',frequency*pwmModStepChanges,'feasible',pwmModFeasible, ...
    'mf',mfModValues,'name',pwmModName,'color',pwmModColor,'marker','v')};
pwmSMList = { ...
    struct('thd',pwmTHD,'freq',frequency*pwmSMChanges,'feasible',pwmFeasible, ...
    'mf',mfValues,'name',pwmName,'color',pwmColor,'marker','^'), ...
    struct('thd',pwmModTHD,'freq',frequency*pwmModSMChanges,'feasible',pwmModFeasible, ...
    'mf',mfModValues,'name',pwmModName,'color',pwmModColor,'marker','v')};

ax1 = nexttile(layout);
plotPlane(ax1,optTHD,optStepFreq,optFeasible,fixedTHD, ...
    frequency*fixedStepChanges,fixedFeasible,sValues,pwmStepList, ...
    best.thdCurrent,frequency*best.stepChanges, ...
    'Stufenwechsel-Frequenz [Hz]','Strangrekonfigurationen (Datenbus-Last)','log');

ax2 = nexttile(layout);
plotPlane(ax2,optTHD,optSMFreq,optFeasible,fixedTHD, ...
    frequency*fixedSMChanges,fixedFeasible,sValues,pwmSMList, ...
    best.thdCurrent,frequency*best.smChanges, ...
    'SM-Schaltfrequenz [Hz]','SM-Schalthandlungen (Verlust-Proxy)','log');

pngFile = fullfile(fileparts(mfilename('fullpath')),'Strict_NLM_Benchmark.png');
exportgraphics(fig,pngFile,'Resolution',150);
fprintf('Abbildung gespeichert: %s\n',pngFile);

benchmark = struct();
benchmark.fixedTable = fixedTable;
benchmark.pwmTable = pwmTable;
benchmark.pwmModuleTable = pwmModuleTable;
benchmark.optimizerTable = optimizerTable;
benchmark.bestResult = best;
benchmark.diagnostics = diag;
benchmark.parameters = p;

matFile = fullfile(fileparts(mfilename('fullpath')),'Strict_NLM_Benchmark.mat');
save(matFile,'-struct','benchmark');
fprintf('Ergebnisse gespeichert: %s\n',matFile);

benchmark.figure = fig;
benchmark.pngFile = pngFile;
end

function plotPlane(ax,optTHD,optFreq,optFeasible,fixedTHD,fixedFreq, ...
    fixedFeasible,sValues,pwmList,chosenTHD,chosenFreq,yLabelText,titleText,yScale)
hold(ax,'on');
colorOpt = [0.05 0.45 0.75];
colorFixed = [0.80 0.25 0.30];

handles = gobjects(0);
names = {};

okOpt = isfinite(optTHD) & isfinite(optFreq);
lineIdx = okOpt & optFeasible;
if any(lineIdx)
    h = plot(ax,optTHD(lineIdx),optFreq(lineIdx),'-o','Color',colorOpt, ...
        'MarkerFaceColor',colorOpt,'MarkerSize',4.5,'LineWidth',1.3);
    handles(end+1) = h; names{end+1} = 'IA-OPP (zulaessig)'; %#ok<*AGROW>
end
openIdx = okOpt & ~optFeasible;
if any(openIdx)
    h = plot(ax,optTHD(openIdx),optFreq(openIdx),'o','Color',colorOpt, ...
        'MarkerSize',5,'LineWidth',1.0);
    handles(end+1) = h; names{end+1} = 'IA-OPP (Toleranz verletzt)';
end

okFixed = isfinite(fixedTHD) & isfinite(fixedFreq);
filledIdx = okFixed & fixedFeasible;
if any(filledIdx)
    h = plot(ax,fixedTHD(filledIdx),fixedFreq(filledIdx),'s','Color',colorFixed, ...
        'MarkerFaceColor',colorFixed,'MarkerSize',7,'LineStyle','none');
    handles(end+1) = h; names{end+1} = 'Fixed-S-NLM (zulaessig)';
end
openFixedIdx = okFixed & ~fixedFeasible;
if any(openFixedIdx)
    h = plot(ax,fixedTHD(openFixedIdx),fixedFreq(openFixedIdx),'s', ...
        'Color',colorFixed,'MarkerSize',7,'LineWidth',1.1,'LineStyle','none');
    handles(end+1) = h; names{end+1} = 'Fixed-S-NLM (Toleranz verletzt)';
end
for n = find(okFixed(:)).'
    text(ax,fixedTHD(n),fixedFreq(n),sprintf('  %dS',sValues(n)), ...
        'Color',colorFixed,'FontSize',8,'VerticalAlignment','middle');
end

for c = 1:numel(pwmList)
    pw = pwmList{c};
    okPWM = isfinite(pw.thd) & isfinite(pw.freq);
    lineIdx = okPWM & pw.feasible;
    if any(lineIdx)
        h = plot(ax,pw.thd(lineIdx),pw.freq(lineIdx),['-' pw.marker], ...
            'Color',pw.color,'MarkerFaceColor',pw.color,'MarkerSize',5, ...
            'LineWidth',1.2);
        handles(end+1) = h; names{end+1} = [pw.name ' (zulaessig)'];
    end
    openIdx = okPWM & ~pw.feasible;
    if any(openIdx)
        h = plot(ax,pw.thd(openIdx),pw.freq(openIdx),pw.marker, ...
            'Color',pw.color,'MarkerSize',5.5,'LineWidth',1.0,'LineStyle','none');
        handles(end+1) = h; names{end+1} = [pw.name ' (Toleranz verletzt)'];
    end
    for n = find(okPWM(:)).'
        text(ax,pw.thd(n),pw.freq(n),sprintf('  m_f=%d',pw.mf(n)), ...
            'Color',pw.color,'FontSize',8,'VerticalAlignment','middle');
    end
end

h = plot(ax,chosenTHD,chosenFreq,'p','Color',[0.93 0.55 0.05], ...
    'MarkerFaceColor',[0.93 0.55 0.05],'MarkerSize',13,'LineStyle','none');
handles(end+1) = h; names{end+1} = 'Gewaehlte Loesung';

hold(ax,'off');
set(ax,'XScale','log','YScale',yScale);
grid(ax,'on');
xlabel(ax,'Strom-THD [%]');
ylabel(ax,yLabelText);
title(ax,titleText);
legend(ax,handles,names,'Location','southwest','FontSize',8);
end

function p = defaultParameters()
% Gleiche Standardwerte wie die GUI.
p = struct('moduleCount',5,'smPerModule',12,'cellsPerSM',1, ...
    'cellVoltage',3.7,'voltagePeak',80,'frequency',50,'loadR',2, ...
    'loadL',10e-3,'rBattery',10e-3,'rSM',1e-3,'rCHB',2e-3, ...
    'gridIntervals',360,'searchMaxEvents',60, ...
    'enforceSymmetry',true,'switchingStrategy','strict','targetTHD',5, ...
    'maxEvents',24,'mode','events','maxHarmonic',50, ...
    'optimizationSamples',1024,'outputSamples',4096, ...
    'fundamentalTolerance',0.01,'thdTieTolerance',0.01);
p.benchmarkMaxEvents = 96;
p.pwmCarrierRatios = [1 2 3 5 7 10];
p.pwmModuleCarrierRatios = [1 2 3 5 7 10 15 20];
end
