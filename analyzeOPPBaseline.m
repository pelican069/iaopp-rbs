function out = analyzeOPPBaseline()
%ANALYZEOPPBASELINE Klassische OPP-Baseline mit linearem Streckenmodell.
%   Rechnet die Budget-Front mit stufenUNabhängigem Umrichterwiderstand im
%   Gütemaß (rBattery = rSM = 0, d. h. das klassische OPP-Kriterium einer
%   linearen Strecke) und wertet die entstandenen Schaltmuster anschließend
%   auf der realen Strecke (stufenabhängige Widerstände) aus. Die Differenz
%   quantifiziert den Wert der Streckenmodellierung im Gütemaß.
%   Ergebnisse werden als oppTable in Strict_NLM_Benchmark.mat ergänzt und
%   von plotBenchmarkTHDPlane als zusätzliche Kurve gerendert.
%   Hinweis: Ein erneuter benchmarkStrictNLM-Lauf überschreibt die .mat —
%   danach analyzeOPPBaseline erneut ausführen.

thisDir = fileparts(mfilename('fullpath'));
matFile = fullfile(thisDir,'Strict_NLM_Benchmark.mat');
if ~isfile(matFile)
    error('chb:MissingBenchmark', ...
        'Strict_NLM_Benchmark.mat fehlt - zuerst benchmarkStrictNLM ausfuehren.');
end
s = load(matFile);
p = s.parameters;
tol = p.fundamentalTolerance + 1e-12;

pLin = p;
pLin.rBattery = 0;
pLin.rSM = 0;
pLin.mode = 'events';
if isfield(p,'benchmarkMaxEvents')
    pLin.maxEvents = p.benchmarkMaxEvents;
else
    pLin.maxEvents = 96;
end
pLin.searchMaxEvents = pLin.maxEvents;

fprintf('OPP-Baseline: Optimierung mit linearem Streckenmodell bis %d Stufenwechsel ...\n', ...
    pLin.maxEvents);
progress = @(fraction,message) fprintf('  %3.0f %%  %s\n',100*fraction,message);
[~,diag] = strictNLMOptimizeSchedule(pLin,progress);

tested = diag.testedBudgets;
count = numel(tested);
thdLin = diag.candidateTHD(tested);
thdReal = nan(count,1);
fundError = nan(count,1);
for n = 1:count
    schedule = diag.candidateSchedules{tested(n)};
    r = strictNLMEvaluateSchedule(p,schedule,0);
    thdReal(n) = r.thdCurrent;
    fundError(n) = r.fundamentalAmplitudeError;
end
feasible = fundError <= tol;

oppTable = table(tested,p.frequency*tested,thdLin,thdReal,100*fundError, ...
    feasible,'VariableNames',{'Stufenwechsel','fRekonf_Hz', ...
    'THD_linModell_pct','THD_real_pct','FundFehler_pct','zulaessig'});
fprintf('\nOPP-Baseline (Optimierung linear, Bewertung real):\n');
disp(oppTable);
bestIdx = find(feasible);
[bestReal,pos] = min(thdReal(bestIdx));
fprintf(['Beste OPP-Loesung auf realer Strecke: %.3f %% THD bei %d ', ...
    'Stufenwechseln (lineares Modell versprach %.3f %%).\n'], ...
    bestReal,tested(bestIdx(pos)),thdLin(bestIdx(pos)));

s.oppTable = oppTable;
s.oppSchedules = diag.candidateSchedules;
save(matFile,'-struct','s');
fprintf('oppTable und oppSchedules in %s ergaenzt.\n',matFile);

out = struct();
out.table = oppTable;
out.diagnostics = diag;
end
