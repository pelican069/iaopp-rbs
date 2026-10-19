function [best, diagnostics] = strictNLMOptimizeSchedule(p, progressFcn)
%STRICTNLMOPTIMIZESCHEDULE Event-budgeted strict/free level optimization.

if nargin < 2
    progressFcn = [];
end
if ~isfield(p,'enforceSymmetry')
    p.enforceSymmetry = false;
end
if ~isfield(p,'switchingStrategy')
    p.switchingStrategy = 'strict';
end
if ~isfield(p,'thdTieTolerance')
    p.thdTieTolerance = 0.01; % percentage points
end
if ~isfield(p,'fundamentalWeight')
    p.fundamentalWeight = 0.01; % tie-break weight in the refinement score
end
strictMode = strcmpi(p.switchingStrategy,'strict');
if strictMode
    p.enforceSymmetry = true;
end
validateParameters(p);
T = 1/p.frequency;
maxLevel = p.moduleCount*p.smPerModule;
if p.enforceSymmetry
    allLevels = (0:maxLevel).';
    intervalCount = max(20,ceil(p.gridIntervals/4));
    optimizationSpan = T/4;
else
    allLevels = (-maxLevel:maxLevel).';
    intervalCount = p.gridIntervals;
    optimizationSpan = T;
end
levelCount = numel(allLevels);
zeroIdx = find(allLevels == 0,1);

if strcmpi(p.mode,'events')
    maxEvents = p.maxEvents;
else
    maxEvents = p.searchMaxEvents;
end
maxEvents = min(round(maxEvents),p.gridIntervals-1);
if maxEvents < 1
    maxEvents = 1;
end

% More candidate boundaries are placed where the sinusoid is steep.
fineX = linspace(0,1,20001);
density = 0.30 + 0.70*abs(cos(2*pi*p.frequency*optimizationSpan*fineX));
cdf = cumtrapz(fineX,density);
cdf = cdf/cdf(end);
uEdges = linspace(0,1,intervalCount+1);
gridEdges = interp1(cdf,fineX,uEdges,'linear');
gridEdges([1 end]) = [0 1];
gridEdges = gridEdges*optimizationSpan;
tMid = (gridEdges(1:end-1)+gridEdges(2:end))/2;
dt = diff(gridEdges);

w = 2*pi*p.frequency;
z = hypot(p.loadR,w*p.loadL);
phi = atan2(w*p.loadL,p.loadR);
iIdeal = (p.voltagePeak/z)*sin(w*tMid-phi);
vIdeal = p.voltagePeak*sin(w*tMid);

active = zeros(size(allLevels));
nz = allLevels ~= 0;
active(nz) = ceil(abs(allLevels(nz))/p.smPerModule);
rConv = 2*p.moduleCount*p.rCHB + active*p.smPerModule*p.rSM + ...
    abs(allLevels)*p.cellsPerSM*p.rBattery;
vAvailable = allLevels*(p.cellVoltage*p.cellsPerSM);

cost = zeros(intervalCount,levelCount);
for n = 1:intervalCount
    requiredSource = vIdeal(n) + rConv*iIdeal(n);
    cost(n,:) = (dt(n)/T)*((vAvailable-requiredSource)/max(p.voltagePeak,eps)).^2;
end

% DP state: voltage level and exact number of internal level transitions.
if p.enforceSymmetry
    K = floor(maxEvents/4);
    if strictMode
        K = min(K,maxLevel);
    end
    if K < 1
        error('chb:SymmetricBudgetTooSmall', ...
            'Strict quarter-wave symmetry requires at least four level changes per period.');
    end
else
    K = maxEvents;
end
infCost = inf(levelCount,K+1);
dp = infCost;
dp(zeroIdx,1) = cost(1,zeroIdx);
pred = zeros(levelCount,K+1,intervalCount,'uint16');

for n = 2:intervalCount
    next = infCost;
    maxKHere = min(K,n-1);
    for k = 0:maxKHere
        same = dp(:,k+1);
        chosen = same;
        chosenPred = uint16((1:levelCount).');
        if k > 0
            previous = dp(:,k);
            if strictMode
                % A transition may only move to a strictly higher level.
                different = inf(levelCount,1);
                differentPred = zeros(levelCount,1,'uint16');
                for targetIdx = 2:levelCount
                    [different(targetIdx),sourceIdx] = min(previous(1:targetIdx-1));
                    differentPred(targetIdx) = uint16(sourceIdx);
                end
            else
                [m1,idx1] = min(previous);
                tmp = previous;
                tmp(idx1) = inf;
                [m2,idx2] = min(tmp);
                different = repmat(m1,levelCount,1);
                differentPred = repmat(uint16(idx1),levelCount,1);
                different(idx1) = m2;
                differentPred(idx1) = uint16(idx2);
            end
            useDifferent = different < chosen;
            chosen(useDifferent) = different(useDifferent);
            chosenPred(useDifferent) = differentPred(useDifferent);
        end
        next(:,k+1) = chosen + cost(n,:).';
        pred(:,k+1,n) = chosenPred;
    end
    dp = next;
end

if ~isempty(progressFcn)
    progressFcn(0.45,'Bewerte Rekonstruktionskandidaten ...');
end

candidates = repmat(struct('schedule',[],'result',[],'score',inf),maxEvents,1);
if p.enforceSymmetry
    for quarterEvents = 1:K
        [~,endIdx] = min(dp(:,quarterEvents+1));
        if ~isfinite(dp(endIdx,quarterEvents+1))
            continue
        end
        path = reconstructPath(pred,allLevels,endIdx,quarterEvents,intervalCount);
        quarterSchedule = compressPath(gridEdges,path);
        schedule = expandQuarterWaveSchedule(quarterSchedule,T);
        r = strictNLMEvaluateSchedule(p,schedule,0);
        budget = r.stepChanges;
        if budget > maxEvents
            continue
        end
        score = qualityScore(r,p);
        candidates(budget).schedule = schedule;
        candidates(budget).result = r;
        candidates(budget).score = score;
    end
else
    for budget = 1:maxEvents
        % A possible last-to-first transition at the period boundary also counts.
        endpointCost = inf(levelCount,1);
        endpointK = -ones(levelCount,1);
        for endIdx = 1:levelCount
            boundaryEvent = endIdx ~= zeroIdx;
            internalK = budget-boundaryEvent;
            if internalK >= 0
                endpointCost(endIdx) = dp(endIdx,internalK+1);
                endpointK(endIdx) = internalK;
            end
        end
        [~,endIdx] = min(endpointCost);
        if ~isfinite(endpointCost(endIdx))
            continue
        end
        path = reconstructPath(pred,allLevels,endIdx,endpointK(endIdx),intervalCount);
        schedule = compressPath(gridEdges,path);
        r = strictNLMEvaluateSchedule(p,schedule,0);
        candidates(budget).schedule = schedule;
        candidates(budget).result = r;
        candidates(budget).score = qualityScore(r,p);
    end
end

valid = find(arrayfun(@(x) ~isempty(x.result),candidates));
if isempty(valid)
    error('chb:OptimizationFailed','No feasible switching schedule was found.');
end

% Every exact event count is timing-refined before it can be selected.
exactTHD = nan(maxEvents,1);
exactFundamentalError = nan(maxEvents,1);
exactVoltagePeak = nan(maxEvents,1);
exactSMChanges = nan(maxEvents,1);
exactConverterLoss = nan(maxEvents,1);
exactSchedules = cell(maxEvents,1);
tested = false(maxEvents,1);
targetMet = false;
for position = 1:numel(valid)
    k = valid(position);
    if ~isempty(progressFcn)
        progressFcn(0.45 + 0.48*position/numel(valid), ...
            sprintf('Verfeinere %d Stufenwechsel ...',k));
    end
    refinedSchedule = refineCandidate(p,candidates(k).schedule);
    refinedResult = strictNLMEvaluateSchedule(p,refinedSchedule,p.outputSamples);
    candidates(k).schedule = refinedSchedule;
    candidates(k).result = refinedResult;
    candidates(k).score = qualityScore(refinedResult,p);
    exactTHD(k) = refinedResult.thdCurrent;
    exactFundamentalError(k) = refinedResult.fundamentalAmplitudeError;
    exactVoltagePeak(k) = refinedResult.fundamentalVoltagePeak;
    exactSMChanges(k) = refinedResult.smChanges;
    exactConverterLoss(k) = refinedResult.converterLoss;
    exactSchedules{k} = refinedSchedule;
    tested(k) = true;
    if strcmpi(p.mode,'target') && isOperatingPointValid(refinedResult,p) && ...
            refinedResult.thdCurrent <= p.targetTHD
        targetMet = true;
        break
    end
end

testedBudgets = find(tested);
operatingValid = tested & exactFundamentalError <= p.fundamentalTolerance;
validBudgets = find(operatingValid);
if targetMet
    chosen = testedBudgets(end);
elseif ~isempty(validBudgets)
    chosen = chooseLowestTHD(validBudgets,exactTHD,p.thdTieTolerance);
else
    testedScores = arrayfun(@(k)candidates(k).score,testedBudgets);
    [~,bestIndex] = min(testedScores);
    chosen = testedBudgets(bestIndex);
end
best = candidates(chosen).result;

bestTHDByBudget = nan(maxEvents,1);
runningBest = inf;
for budget = 1:max(testedBudgets)
    if operatingValid(budget)
        runningBest = min(runningBest,exactTHD(budget));
    end
    if isfinite(runningBest)
        bestTHDByBudget(budget) = runningBest;
    end
end

diagnostics = struct();
diagnostics.targetMet = targetMet;
diagnostics.operatingPointMet = isOperatingPointValid(best,p);
diagnostics.chosenBudget = chosen;
diagnostics.gridIntervals = p.gridIntervals;
diagnostics.symmetryEnforced = p.enforceSymmetry;
diagnostics.strictNLM = strictMode;
diagnostics.searchMaxEvents = maxEvents;
diagnostics.evaluatedMaxEvents = max(testedBudgets);
diagnostics.candidateTHD = exactTHD;
diagnostics.candidateFundamentalError = exactFundamentalError;
diagnostics.candidateVoltagePeak = exactVoltagePeak;
diagnostics.candidateSMChanges = exactSMChanges;
diagnostics.candidateConverterLoss = exactConverterLoss;
diagnostics.candidateSchedules = exactSchedules;
diagnostics.budgetAxis = (1:maxEvents).';
diagnostics.bestTHDByBudget = bestTHDByBudget;
diagnostics.testedBudgets = testedBudgets;
if ~isempty(progressFcn)
    progressFcn(1,'Fertig');
end
end

function chosen = chooseLowestTHD(budgets,exactTHD,tieTolerance)
chosen = budgets(1);
bestTHD = exactTHD(chosen);
for k = budgets(2:end).'
    if exactTHD(k) < bestTHD-tieTolerance
        chosen = k;
        bestTHD = exactTHD(k);
    end
end
end

function valid = isOperatingPointValid(result,p)
valid = result.fundamentalAmplitudeError <= p.fundamentalTolerance + 1e-12;
end

function schedule = compressPath(gridEdges,path)
gridEdges = gridEdges(:);
changes = find(diff(path) ~= 0);
schedule.edges = [gridEdges(1); gridEdges(changes+1); gridEdges(end)];
schedule.levels = path([1; changes+1]);
schedule.edges = schedule.edges(:);
schedule.levels = schedule.levels(:);
end

function path = reconstructPath(pred,allLevels,endIdx,k,intervalCount)
path = zeros(intervalCount,1);
idx = endIdx;
path(end) = allLevels(idx);
for n = intervalCount:-1:2
    previousIdx = double(pred(idx,k+1,n));
    if previousIdx == 0
        error('chb:ReconstructionFailed','Could not reconstruct the DP path.');
    end
    if previousIdx ~= idx
        k = k-1;
    end
    idx = previousIdx;
    path(n-1) = allLevels(idx);
end
end

function schedule = expandQuarterWaveSchedule(quarterSchedule,T)
% Mirror rising and falling edges, then apply half-wave antisymmetry.
qdt = diff(quarterSchedule.edges);
qlevels = quarterSchedule.levels;
fullDt = [qdt; flipud(qdt); qdt; flipud(qdt)];
fullLevels = [qlevels; flipud(qlevels); -qlevels; -flipud(qlevels)];
fullEdges = [0; cumsum(fullDt)];
fullEdges(end) = T;
schedule = compressPath(fullEdges,fullLevels);
schedule.quarterEdges = quarterSchedule.edges;
schedule.quarterLevels = quarterSchedule.levels;
end

function score = qualityScore(r,p)
% THD objective with a barrier at the amplitude tolerance. Inside the
% tolerance the amplitude error is almost free (matching the selection
% rule, which only requires tolerance compliance), so the refinement may
% trade amplitude margin for THD. The tiny amplitude term only breaks ties
% in directions where the THD is flat. The constant offset for any
% violation keeps the refinement from trading feasibility against THD.
violation = max(0,r.fundamentalAmplitudeError-p.fundamentalTolerance);
score = r.thdCurrent + p.fundamentalWeight*r.fundamentalAmplitudeError + 1e7*violation^2;
if violation > 0
    score = score + 100;
end
end

function schedule = refineCandidate(p,schedule)
if numel(schedule.levels) <= 1
    return
end
if p.enforceSymmetry
    schedule = refineSymmetricSchedule(p,schedule);
else
    schedule = refineSchedule(p,schedule);
end
end

function schedule = refineSchedule(p,schedule)
% Coordinate descent over the interior edge times, iterated until converged.
% The level sequence and the event count remain unchanged, and an edge only
% moves when the candidate strictly improves the current schedule score.
if numel(schedule.edges) <= 2
    return
end
edges = schedule.edges;
T = 1/p.frequency;
minGap = T/max(20*p.gridIntervals,1000);
options = optimset('TolX',T/2e5,'MaxFunEvals',18,'Display','off');
currentScore = timingObjective(edges(2),2,edges,schedule.levels,p);
for pass = 1:8
    passStartScore = currentScore;
    for n = 2:numel(edges)-1
        lo = edges(n-1)+minGap;
        hi = edges(n+1)-minGap;
        if hi <= lo
            continue
        end
        objective = @(x) timingObjective(x,n,edges,schedule.levels,p);
        [candidateX,candidateValue] = fminbnd(objective,lo,hi,options);
        if candidateValue < currentScore
            edges(n) = candidateX;
            currentScore = candidateValue;
        end
    end
    if passStartScore-currentScore < 1e-3
        break
    end
end
schedule.edges = edges;
end

function schedule = refineSymmetricSchedule(p,schedule)
% Refine only the first-quarter boundaries and mirror every modification.
% Iterated coordinate descent; a boundary only moves on strict improvement.
quarterEdges = schedule.quarterEdges;
quarterLevels = schedule.quarterLevels;
T = 1/p.frequency;
minGap = T/max(20*p.gridIntervals,1000);
options = optimset('TolX',T/2e5,'MaxFunEvals',18,'Display','off');
currentScore = symmetricTimingObjective(quarterEdges(2),2,quarterEdges, ...
    quarterLevels,p,T);
for pass = 1:8
    passStartScore = currentScore;
    for n = 2:numel(quarterEdges)-1
        lo = quarterEdges(n-1)+minGap;
        hi = quarterEdges(n+1)-minGap;
        if hi <= lo
            continue
        end
        objective = @(x) symmetricTimingObjective(x,n,quarterEdges,quarterLevels,p,T);
        [candidateX,candidateValue] = fminbnd(objective,lo,hi,options);
        if candidateValue < currentScore
            quarterEdges(n) = candidateX;
            currentScore = candidateValue;
        end
    end
    if passStartScore-currentScore < 1e-3
        break
    end
end
quarterSchedule = struct('edges',quarterEdges,'levels',quarterLevels);
schedule = expandQuarterWaveSchedule(quarterSchedule,T);
end

function value = timingObjective(x,index,edges,levels,p)
edges(index) = x;
s = struct('edges',edges,'levels',levels);
r = strictNLMEvaluateSchedule(p,s,0);
value = qualityScore(r,p);
end

function value = symmetricTimingObjective(x,index,edges,levels,p,T)
edges(index) = x;
quarterSchedule = struct('edges',edges,'levels',levels);
s = expandQuarterWaveSchedule(quarterSchedule,T);
r = strictNLMEvaluateSchedule(p,s,0);
value = qualityScore(r,p);
end

function validateParameters(p)
positive = {'moduleCount','smPerModule','cellsPerSM','cellVoltage','frequency', ...
    'voltagePeak','loadR','gridIntervals','optimizationSamples','outputSamples'};
for n = 1:numel(positive)
    if ~isfinite(p.(positive{n})) || p.(positive{n}) <= 0
        error('chb:InvalidParameter','%s must be positive.',positive{n});
    end
end
if ~isfinite(p.loadL) || p.loadL < 0
    error('chb:InvalidParameter','loadL must be zero or positive.');
end
if ~any(strcmpi(p.switchingStrategy,{'strict','free'}))
    error('chb:InvalidParameter','switchingStrategy must be strict or free.');
end
if ~isfinite(p.fundamentalTolerance) || p.fundamentalTolerance < 0
    error('chb:InvalidParameter','fundamentalTolerance must be zero or positive.');
end
if ~isfinite(p.thdTieTolerance) || p.thdTieTolerance < 0
    error('chb:InvalidParameter','thdTieTolerance must be zero or positive.');
end
maxVoltage = p.moduleCount*p.smPerModule*p.cellsPerSM*p.cellVoltage;
if p.voltagePeak > maxVoltage
    error('chb:VoltageInfeasible', ...
        'Peak voltage %.3g V exceeds the available %.3g V.',p.voltagePeak,maxVoltage);
end
end
