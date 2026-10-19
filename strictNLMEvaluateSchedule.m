function result = strictNLMEvaluateSchedule(p, schedule, sampleCount)
%STRICTNLMEVALUATESCHEDULE Evaluate one periodic CHB switching schedule.
% THD, fundamental and power metrics are computed in closed form from the
% switching instants for both R and RL loads: the source voltage is
% piecewise constant and the periodic RL current is piecewise
% constant-plus-exponential, so every Fourier coefficient and RMS integral
% has an exact segment expression. The quality metrics are therefore
% smooth in the edge times and independent of the sample count. Sampling
% is only used to export waveforms for plotting; sampleCount = 0 skips the
% waveform export entirely (metric-only evaluation for the optimizer).

if nargin < 3 || isempty(sampleCount)
    sampleCount = 4096;
end

edges = schedule.edges(:);
levels = schedule.levels(:);
T = 1 / p.frequency;
if numel(edges) ~= numel(levels) + 1 || abs(edges(1)) > 1e-12 || ...
        abs(edges(end) - T) > max(1e-12, 1e-9*T)
    error('chb:InvalidSchedule', 'Schedule edges must span one period.');
end

[rTotalSeg, rConvSeg, activeSeg] = levelResistance(levels, p);
vStep = p.cellVoltage * p.cellsPerSM;
vSeg = levels * vStep;
dtSeg = diff(edges);
w = 2*pi*p.frequency;
maxH = p.maxHarmonic;

if p.loadL == 0
    % Pure R load: all signals are piecewise constant.
    iSeg = vSeg ./ rTotalSeg;
    vLoadSeg = vSeg - rConvSeg.*iSeg;
    [thdI, iFundRms, iFund, iHarmonicRms] = segmentTHD(edges, iSeg, T, maxH);
    [thdV, vFundRms, vFund, vHarmonicRms] = segmentTHD(edges, vSeg, T, maxH);
    [~, ~, vLoadFund] = segmentTHD(edges, vLoadSeg, T, maxH);
    wSeg = dtSeg / T;
    P = sum(wSeg.*vLoadSeg.*iSeg);
    S = sqrt(sum(wSeg.*vLoadSeg.^2))*sqrt(sum(wSeg.*iSeg.^2));
    converterLoss = sum(wSeg.*rConvSeg.*iSeg.^2);
    iEdge = [];
    periodicClosureError = 0;
else
    % Periodic solution: compose i_next = a*i + b over the complete period.
    aSeg = exp(-rTotalSeg .* dtSeg / p.loadL);
    bSeg = (vSeg ./ rTotalSeg) .* (1 - aSeg);
    A = 1;
    B = 0;
    for n = 1:numel(levels)
        B = aSeg(n) * B + bSeg(n);
        A = aSeg(n) * A;
    end
    if abs(1-A) < 1e-12
        i0 = 0;
    else
        i0 = B / (1-A);
    end
    iEdge = zeros(numel(edges),1);
    iEdge(1) = i0;
    for n = 1:numel(levels)
        iEdge(n+1) = aSeg(n)*iEdge(n) + bSeg(n);
    end
    periodicClosureError = iEdge(end)-iEdge(1);

    % Segment n: i(t) = cSteady + cExp*exp(-(t-t_n)/tau); exact metrics.
    tauSeg = p.loadL ./ rTotalSeg;
    cSteady = vSeg ./ rTotalSeg;
    cExp = iEdge(1:end-1) - cSteady;
    [thdI, iFundRms, iFund, iHarmonicRms] = expSegmentTHD(edges, cSteady, cExp, tauSeg, aSeg, T, maxH);
    [thdV, vFundRms, vFund, vHarmonicRms] = segmentTHD(edges, vSeg, T, maxH);
    [~, ~, vLoadFund] = expSegmentTHD(edges, vSeg - rConvSeg.*cSteady, ...
        -rConvSeg.*cExp, tauSeg, aSeg, T, maxH);

    % Exact time-domain averages over the exponential segments.
    intExp = tauSeg.*(1-aSeg);          % integral of exp term per segment
    intExp2 = (tauSeg/2).*(1-aSeg.^2);  % integral of squared exp term
    iSquared = cSteady.^2.*dtSeg + 2*cSteady.*cExp.*intExp + cExp.^2.*intExp2;
    alphaSeg = vSeg - rConvSeg.*cSteady;
    betaSeg = -rConvSeg.*cExp;
    vLoadSquared = alphaSeg.^2.*dtSeg + 2*alphaSeg.*betaSeg.*intExp + ...
        betaSeg.^2.*intExp2;
    P = sum(alphaSeg.*cSteady.*dtSeg + (alphaSeg.*cExp + betaSeg.*cSteady).*intExp + ...
        betaSeg.*cExp.*intExp2)/T;
    S = sqrt(sum(vLoadSquared)/T)*sqrt(sum(iSquared)/T);
    converterLoss = sum(rConvSeg.*iSquared)/T;
end

% Optional: Tripel-Ordnungen (h = 3, 9, 15, ...) aus der Strom-THD
% ausblenden — im 3-Leiter-Sternverbund fliessen sie nicht als
% Leiterstroeme (dreiphasenbewusste Bewertung/Optimierung).
if isfield(p,'excludeTriplenTHD') && p.excludeTriplenTHD
    hOrders = (1:maxH).';
    nonTriplen = hOrders >= 2 & mod(hOrders,3) ~= 0;
    thdI = sqrt(sum(iHarmonicRms(nonTriplen).^2))/max(iHarmonicRms(1),1e-12);
end

vCos = sqrt(2)*real(vFund);
vSin = -sqrt(2)*imag(vFund);
fundamentalError = hypot(vSin-p.voltagePeak, vCos)/max(p.voltagePeak, eps);
fundamentalAmplitudeError = abs(hypot(vSin,vCos)-p.voltagePeak)/max(p.voltagePeak,eps);
Q = imag(vLoadFund*conj(iFund));
powerFactor = P/max(S, eps);

% Sampled waveforms are only needed for display purposes.
if sampleCount > 0
    t = (0:sampleCount-1).' * (T/sampleCount);
    segIdx = discretize(t, edges);
    segIdx(isnan(segIdx)) = numel(levels);
    vSource = vSeg(segIdx);
    if p.loadL == 0
        i = vSource ./ rTotalSeg(segIdx);
    else
        tau = t - edges(segIdx);
        aSample = exp(-rTotalSeg(segIdx).*tau/p.loadL);
        i = aSample.*iEdge(segIdx) + (vSeg(segIdx)./rTotalSeg(segIdx)).*(1-aSample);
    end
    vLoad = vSource - rConvSeg(segIdx).*i;
    zLoad = hypot(p.loadR, w*p.loadL);
    phi = atan2(w*p.loadL, p.loadR);
    vIdeal = p.voltagePeak*sin(w*t);
    iIdeal = (p.voltagePeak/zLoad)*sin(w*t-phi);
else
    t = zeros(0,1);
    vSource = t; vLoad = t; i = t; vIdeal = t; iIdeal = t;
end

nextLevels = [levels(2:end); levels(1)];
stepChanges = sum(nextLevels ~= levels);
smChangesPerEvent = abs(abs(nextLevels)-abs(levels));
smChanges = sum(smChangesPerEvent);
positiveSMEvents = smChangesPerEvent(smChangesPerEvent > 0);
if isempty(positiveSMEvents)
    histSMCounts = 0;
    histEventCounts = 0;
else
    histSMCounts = (1:max(positiveSMEvents)).';
    histEventCounts = arrayfun(@(n) sum(positiveSMEvents == n),histSMCounts);
end

result = struct();
result.t = t;
result.vIdeal = vIdeal;
result.iIdeal = iIdeal;
result.vSource = vSource;
result.vLoad = vLoad;
result.i = i;
result.currentError = i-iIdeal;
result.voltageError = vSource-vIdeal;
result.thdCurrent = 100*thdI;
result.thdVoltage = 100*thdV;
result.currentFundRms = iFundRms;
result.voltageFundRms = vFundRms;
result.harmonicOrders = (1:maxH).';
result.currentHarmonicRms = iHarmonicRms;
result.voltageHarmonicRms = vHarmonicRms;
result.fundamentalVoltagePeak = hypot(vSin,vCos);
result.fundamentalError = fundamentalError;
result.fundamentalAmplitudeError = fundamentalAmplitudeError;
result.P = P;
result.Q = Q;
result.S = S;
result.powerFactor = powerFactor;
result.converterLoss = converterLoss;
result.stepChanges = stepChanges;
result.smChanges = smChanges;
result.reconfigurationFrequency = stepChanges*p.frequency;
result.smChangesPerEvent = smChangesPerEvent;
result.histSMCounts = histSMCounts;
result.histEventCounts = histEventCounts;
result.segmentResistance = rTotalSeg;
result.segmentConverterResistance = rConvSeg;
result.segmentActiveModules = activeSeg;
result.periodicClosureError = periodicClosureError;
result.schedule = schedule;
end

function [rTotal, rConverter, activeModules] = levelResistance(level, p)
activeModules = zeros(size(level));
nz = level ~= 0;
activeModules(nz) = ceil(abs(level(nz))/p.smPerModule);
rBridge = 2*p.moduleCount*p.rCHB;
rSM = activeModules*p.smPerModule*p.rSM;
rBattery = abs(level)*p.cellsPerSM*p.rBattery;
rConverter = rBridge + rSM + rBattery;
rTotal = p.loadR + rConverter;
end

function [thdValue, fundamentalRms, fundamentalPhasor, harmonicRms] = segmentTHD(edges, xSeg, T, maxH)
%SEGMENTTHD Exact Fourier metrics of a piecewise constant periodic signal.
% C_h = (1/T) * integral of x(t)*exp(-1i*h*w*t) over one period, evaluated
% segment by segment in closed form. Uses the RMS phasor convention with
% cosine reference. harmonicRms contains the RMS magnitudes for h=1..maxH.
h = 1:maxH;
E = exp((-2i*pi/T)*edges*h);                    % (numSeg+1) x maxH
C = (xSeg.' * (E(1:end-1,:) - E(2:end,:))) ./ (2i*pi*h);
[thdValue, fundamentalRms, fundamentalPhasor, harmonicRms] = thdFromCoefficients(C);
end

function [thdValue, fundamentalRms, fundamentalPhasor, harmonicRms] = expSegmentTHD( ...
    edges, cSteady, cExp, tauSeg, aSeg, T, maxH)
%EXPSEGMENTTHD Exact Fourier metrics of a piecewise const-plus-exp signal.
% Segment n on [t_n, t_(n+1)]: x(t) = cSteady(n) + cExp(n)*exp(-(t-t_n)/tau(n))
% with aSeg(n) = exp(-dt(n)/tau(n)). The exponential part integrates to
% (E_n - a_n*E_(n+1)) / (1/tau_n + 1i*h*w) with E_n = exp(-1i*h*w*t_n), so
% the coefficients are exact for arbitrary edge times.
h = 1:maxH;
wh = (2*pi/T)*h;
E = exp(-1i*edges*wh);                          % (numSeg+1) x maxH
Ea = E(1:end-1,:);
Eb = E(2:end,:);
constPart = (cSteady.' * (Ea - Eb)) ./ (1i*wh*T);
expPart = sum((cExp.*(Ea - aSeg.*Eb)) ./ (1./tauSeg + 1i*wh), 1) / T;
[thdValue, fundamentalRms, fundamentalPhasor, harmonicRms] = ...
    thdFromCoefficients(constPart + expPart);
end

function [thdValue, fundamentalRms, fundamentalPhasor, harmonicRms] = thdFromCoefficients(C)
fundamentalPhasor = sqrt(2)*C(1);
fundamentalRms = abs(fundamentalPhasor);
harmonicRms = sqrt(2)*abs(C(:));
if fundamentalRms < 1e-12
    thdValue = inf;
    return
end
thdValue = sqrt(sum(harmonicRms(2:end).^2))/fundamentalRms;
end
