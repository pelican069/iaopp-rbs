function out = analyzeOperatingPoints(p)
%ANALYZEOPERATINGPOINTS THD-Vergleich ueber den Modulationsgrad.
%   Wiederholt den Kernvergleich (optimierte Schaltmuster gegen 1S-/2S-NLM
%   und PS-PWM auf SM-Ebene) fuer mehrere Sollamplituden, also
%   Modulationsgrade m_a = voltagePeak/(maxLevel*vStep). Je Betriebspunkt
%   laeuft der Optimierer im Budget-Modus bis 96 Stufenwechsel; berichtet
%   werden die optimierte THD bei n = 48 und n = 96 sowie die Baselines
%   mit ihren (teils deutlich hoeheren) Ereignisbudgets. Ergebnisse werden
%   in Strict_NLM_Betriebspunkte.mat zwischengespeichert und als
%   Vektor-PDF (Strict_NLM_Betriebspunkte.pdf) geplottet.
%   Ohne Argument werden die Parameter aus Strict_NLM_Benchmark.mat
%   uebernommen. Achtung: Laufzeit mehrere Minuten pro Betriebspunkt.

close all

thisDir = fileparts(mfilename('fullpath'));
if nargin < 1 || isempty(p)
    matFile = fullfile(thisDir,'Strict_NLM_Benchmark.mat');
    if ~isfile(matFile)
        error('chb:MissingBenchmark', ...
            'Strict_NLM_Benchmark.mat fehlt - zuerst benchmarkStrictNLM ausfuehren.');
    end
    s = load(matFile,'parameters');
    p = s.parameters;
end

vPeaks = [45 80 120 160 200];
maxLevel = p.moduleCount*p.smPerModule;
vStep = p.cellVoltage*p.cellsPerSM;
mfSM = 2;
mfModule = 10;
tol = p.fundamentalTolerance + 1e-12;

count = numel(vPeaks);
ma = vPeaks(:)/(maxLevel*vStep);
opt48 = nan(count,1); opt96 = nan(count,1);
optBest = nan(count,1); optBestBudget = nan(count,1);
sweep = struct('voltagePeak',cell(count,1),'diagnostics',cell(count,1));
nlm1 = nan(count,1); nlm1Budget = nan(count,1); nlm1Ok = false(count,1);
nlm2 = nan(count,1); nlm2Budget = nan(count,1); nlm2Ok = false(count,1);
pwm = nan(count,1); pwmBudget = nan(count,1); pwmOk = false(count,1);
pwmMod = nan(count,1); pwmModBudget = nan(count,1); pwmModOk = false(count,1);

for n = 1:count
    po = p;
    po.voltagePeak = vPeaks(n);
    po.mode = 'events';
    po.maxEvents = 96;
    po.searchMaxEvents = 96;
    fprintf('Betriebspunkt %g V (m_a = %.2f) ...\n',vPeaks(n),ma(n));
    [~,diag] = strictNLMOptimizeSchedule(po, ...
        @(f,msg)fprintf('  %3.0f %%  %s\n',100*f,msg));
    sweep(n).voltagePeak = vPeaks(n);
    sweep(n).diagnostics = diag;
    feasible = diag.candidateFundamentalError <= tol;
    if numel(feasible) >= 48 && feasible(48)
        opt48(n) = diag.candidateTHD(48);
    end
    if numel(feasible) >= 96 && feasible(96)
        opt96(n) = diag.candidateTHD(96);
    end
    feasibleIdx = find(feasible);
    if ~isempty(feasibleIdx)
        [optBest(n),bestPos] = min(diag.candidateTHD(feasibleIdx));
        optBestBudget(n) = feasibleIdx(bestPos);
    end

    r = strictNLMEvaluateSchedule(po,fixedStepNLMSchedule(po,1),0);
    nlm1(n) = r.thdCurrent; nlm1Budget(n) = r.stepChanges;
    nlm1Ok(n) = r.fundamentalAmplitudeError <= tol;
    schedule2 = fixedStepNLMSchedule(po,2);
    if ~isempty(schedule2)
        r = strictNLMEvaluateSchedule(po,schedule2,0);
        nlm2(n) = r.thdCurrent; nlm2Budget(n) = r.stepChanges;
        nlm2Ok(n) = r.fundamentalAmplitudeError <= tol;
    end
    r = strictNLMEvaluateSchedule(po,psPWMSchedule(po,mfSM),0);
    pwm(n) = r.thdCurrent; pwmBudget(n) = r.stepChanges;
    pwmOk(n) = r.fundamentalAmplitudeError <= tol;
    r = strictNLMEvaluateSchedule(po,psPWMSchedule(po,mfModule,po.smPerModule),0);
    pwmMod(n) = r.thdCurrent; pwmModBudget(n) = r.stepChanges;
    pwmModOk(n) = r.fundamentalAmplitudeError <= tol;
end

resultTable = table(vPeaks(:),ma,opt48,optBest,optBestBudget,opt96, ...
    nlm1,nlm1Budget,nlm1Ok,nlm2,nlm2Budget,nlm2Ok,pwm,pwmBudget,pwmOk, ...
    pwmMod,pwmModBudget,pwmModOk, ...
    'VariableNames',{'Vpeak_V','ma','Opt48_THD','OptBest_THD','OptBest_n', ...
    'Opt96_THD','NLM1S_THD','NLM1S_Budget','NLM1S_ok','NLM2S_THD', ...
    'NLM2S_Budget','NLM2S_ok','PWMSM2_THD','PWMSM2_Budget','PWMSM2_ok', ...
    'PWMMod10_THD','PWMMod10_Budget','PWMMod10_ok'});
fprintf('\nErgebnisse ueber den Modulationsgrad:\n');
disp(resultTable);

matOut = fullfile(thisDir,'Strict_NLM_Betriebspunkte.mat');
save(matOut,'resultTable','vPeaks','ma','p','sweep');
fprintf('Ergebnisse gespeichert: %s\n',matOut);

%% Abbildung aus dem gerade gespeicherten Cache rendern
plotResult = plotOperatingPoints();

out = struct();
out.table = resultTable;
out.figure = plotResult.figure;
out.pdfFile = plotResult.pdfFile;
out.matFile = matOut;
end
