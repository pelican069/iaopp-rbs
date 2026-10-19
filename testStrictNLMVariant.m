function testStrictNLMVariant
%TESTSTRICTNLMVARIANT Reproducible numerical regression tests.

p = baseParameters();
p.mode = 'events';
p.maxEvents = 24;
[r,d] = strictNLMOptimizeSchedule(p);
assert(d.strictNLM && d.symmetryEnforced);
assert(all(diff(r.schedule.quarterLevels) > 0));
assert(isequal(d.testedBudgets(:),(4:4:24).'));
assert(r.stepChanges <= p.maxEvents);
assert(d.operatingPointMet);
curve = d.bestTHDByBudget(isfinite(d.bestTHDByBudget));
assert(all(diff(curve) <= 1e-12));
assertQuarterWaveSymmetry(r.schedule,1/p.frequency);
% RL metrics are closed-form: independent of the sample count, available
% without waveform sampling, and consistent with an FFT of the current.
rCoarse = strictNLMEvaluateSchedule(p,r.schedule,512);
assert(abs(rCoarse.thdCurrent-r.thdCurrent) < 1e-9);
assert(abs(rCoarse.P-r.P) < 1e-9 && abs(rCoarse.S-r.S) < 1e-9);
rMetrics = strictNLMEvaluateSchedule(p,r.schedule,0);
assert(isempty(rMetrics.t) && abs(rMetrics.thdCurrent-r.thdCurrent) < 1e-12);
x = r.i-mean(r.i);
N = numel(x);
X = fft(x);
fundRms = sqrt(2)*abs(X(2))/N;
harmonicRms = sqrt(2)*abs(X(3:p.maxHarmonic+1))/N;
thdFFT = 100*sqrt(sum(harmonicRms.^2))/fundRms;
assert(abs(thdFFT-r.thdCurrent) < 0.2);

p.mode = 'target';
p.targetTHD = 5;
[r,d] = strictNLMOptimizeSchedule(p);
assert(d.targetMet && r.thdCurrent <= p.targetTHD);
assert(d.testedBudgets(end) == r.stepChanges);

p = baseParameters();
p.cellsPerSM = 12;
p.voltagePeak = 200;
p.frequency = 100;
p.loadL = 0;
p.mode = 'events';
p.maxEvents = 100;
p.searchMaxEvents = 100;
[r,d] = strictNLMOptimizeSchedule(p);
assert(r.periodicClosureError == 0 && all(isfinite(r.i)));
assert(d.evaluatedMaxEvents == 100);
assert(all(diff(r.schedule.quarterLevels) > 0));
% L=0 metrics are closed-form: independent of the sample count and
% consistent with an FFT of the sampled current.
rCoarse = strictNLMEvaluateSchedule(p,r.schedule,512);
assert(abs(rCoarse.thdCurrent-r.thdCurrent) < 1e-12);
assert(abs(rCoarse.P-r.P) < 1e-12 && abs(rCoarse.S-r.S) < 1e-12);
x = r.i-mean(r.i);
N = numel(x);
X = fft(x);
fundRms = sqrt(2)*abs(X(2))/N;
harmonicRms = sqrt(2)*abs(X(3:p.maxHarmonic+1))/N;
thdFFT = 100*sqrt(sum(harmonicRms.^2))/fundRms;
assert(abs(thdFFT-r.thdCurrent) < 0.2);

p = baseParameters();
p.moduleCount = 3;
p.smPerModule = 4;
p.voltagePeak = 30;
p.gridIntervals = 100;
p.maxEvents = 8;
p.mode = 'events';
p.switchingStrategy = 'free';
p.enforceSymmetry = false;
[r,d] = strictNLMOptimizeSchedule(p);
assert(~d.strictNLM && r.stepChanges <= p.maxEvents);

fprintf('ALL STRICT-NLM CORE TESTS PASSED\n');
end

function p = baseParameters()
p = struct('moduleCount',5,'smPerModule',6,'cellsPerSM',1, ...
    'cellVoltage',3.7,'voltagePeak',80,'frequency',50,'loadR',2, ...
    'loadL',10e-3,'rBattery',10e-3,'rSM',1e-3,'rCHB',2e-3, ...
    'gridIntervals',360,'searchMaxEvents',60, ...
    'enforceSymmetry',true,'switchingStrategy','strict','targetTHD',5, ...
    'maxEvents',24,'mode','target','maxHarmonic',50, ...
    'optimizationSamples',1024,'outputSamples',4096, ...
    'fundamentalTolerance',0.01,'thdTieTolerance',0.01);
end

function assertQuarterWaveSymmetry(schedule,T)
t = ((0:999).'+0.5)*(T/4000);
first = discretize(t,schedule.edges);
mirror = discretize(T/2-t,schedule.edges);
negative = discretize(t+T/2,schedule.edges);
levels = schedule.levels;
assert(max(abs(levels(first)-levels(mirror))) == 0);
assert(max(abs(levels(first)+levels(negative))) == 0);
end
