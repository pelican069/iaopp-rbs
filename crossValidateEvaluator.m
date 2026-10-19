function crossValidateEvaluator
%CROSSVALIDATEEVALUATOR Kreuzvalidierung der geschlossenen Auswertung.
%   Vergleicht die geschlossene Bewertung (strictNLMEvaluateSchedule)
%   gegen eine UNABHAENGIGE Zeitschritt-Simulation: klassisches
%   Runge-Kutta-4 auf der stueckweisen RL-DGL di/dt = (v - R*i)/L
%   (keine Exponentialloesung, kein expSegmentTHD), Einschwingen aus
%   i(0) = 0 ueber 8 Perioden statt analytischer Periodizitaets-
%   bedingung, THD per FFT der letzten Periode. Identisch bleibt nur
%   das MODELL (Stufe -> Pfadwiderstand); das ist Definitionssache,
%   nicht Loeserwahl. Kandidaten: IA-OPP (n = 48), 1S-NLM,
%   PS-PWM Submodulebene (m_f = 2), Nominalfall.
%   Ergebnis (2026-10-19): Uebereinstimmung an der Grenze doppelter
%   Genauigkeit (dTHD <= 1e-7 pp, max. Stromabweichung <= 3e-13 A).

thisDir = fileparts(mfilename('fullpath'));
s = load(fullfile(thisDir,'Strict_NLM_Benchmark.mat'));
p = s.parameters;
T = 1/p.frequency;
Nfft = 2^14;
hmax = 0.5e-6;          % max. RK4-Schrittweite [s]
settlePeriods = 8;

cands = { ...
    'IA-OPP (n=48)',    s.bestResult.schedule; ...
    '1S-NLM',           fixedStepNLMSchedule(p,1); ...
    'PS-PWM SM (mf=2)', psPWMSchedule(p,2)};

for k = 1:size(cands,1)
    sched = cands{k,2};
    r = strictNLMEvaluateSchedule(p,sched,Nfft);        % geschlossene Form

    % Stufen->Widerstand (Modelldefinition, hier unabhaengig implementiert)
    lvl = sched.levels;
    act = zeros(size(lvl)); nz = lvl ~= 0;
    act(nz) = ceil(abs(lvl(nz))/p.smPerModule);
    Rseg = p.loadR + 2*p.moduleCount*p.rCHB + act*p.smPerModule*p.rSM + ...
        abs(lvl)*p.cellsPerSM*p.rBattery;
    Vseg = lvl*p.cellVoltage*p.cellsPerSM;

    % RK4-Simulation: Einschwingen + letzte Periode auf dem FFT-Raster
    i0 = 0;
    drift = inf;
    for per = 1:settlePeriods
        iPrev = i0;
        i0 = integratePeriod(i0,sched.edges,Vseg,Rseg,p.loadL,hmax,[],[]);
        drift = abs(i0-iPrev);
    end
    tU = (0:Nfft-1).'*(T/Nfft);
    [~,iU,iEdges] = integratePeriod(i0,sched.edges,Vseg,Rseg,p.loadL,hmax, ...
        tU,numel(lvl));

    % THD der Simulation (FFT, identische Definition h <= maxHarmonic)
    x = iU - mean(iU);
    X = fft(x)/Nfft;
    fund = sqrt(2)*abs(X(2));
    harm = sqrt(2)*abs(X(3:p.maxHarmonic+1));
    thdSim = 100*sqrt(sum(harm.^2))/fund;

    fprintf(['%-18s  THDcf %.6f %%  THDsim %.6f %%  dTHD %.2e pp  ', ...
        'dRMS %.2e A  max|di| %.2e A  Drift %.2e A  <|i|>Ereignis %5.2f A\n'], ...
        cands{k,1},r.thdCurrent,thdSim,thdSim-r.thdCurrent, ...
        sqrt(mean(iU.^2))-sqrt(mean(r.i.^2)),max(abs(iU-r.i)),drift, ...
        mean(abs(iEdges)));
end
fprintf(['RK4: Schrittweite <= %.2g us, segmentweise an Kanten ', ...
    'ausgerichtet; Drift = Aenderung von i(T) der letzten ', ...
    'Einschwingperiode.\n'],1e6*hmax);
end

function [iEnd,iOut,iEdges] = integratePeriod(i0,edges,Vseg,Rseg,L,hmax,tU,nSeg)
% Klassisches RK4 ueber eine Periode; optional Werte an den uniformen
% Zeiten tU sowie an den Segmentkanten zurueckgeben.
collect = ~isempty(tU);
if collect
    iOut = zeros(size(tU));
    nextU = 1;
    iEdges = zeros(nSeg,1);
else
    iOut = []; iEdges = [];
end
i = i0;
for n = 1:numel(Vseg)
    v = Vseg(n); R = Rseg(n);
    t0 = edges(n); t1 = edges(n+1);
    if collect
        iEdges(n) = i;
    end
    segTargets = [];
    if collect
        while nextU <= numel(tU) && tU(nextU) < t1 - 1e-15
            segTargets(end+1,1) = tU(nextU); %#ok<AGROW>
            nextU = nextU + 1;
        end
    end
    pts = [t0; segTargets; t1];
    for q = 1:numel(pts)-1
        dt = pts(q+1)-pts(q);
        if dt > 0
            nSub = max(1,ceil(dt/hmax));
            h = dt/nSub;
            for m = 1:nSub
                k1 = (v - R*i)/L;
                k2 = (v - R*(i+0.5*h*k1))/L;
                k3 = (v - R*(i+0.5*h*k2))/L;
                k4 = (v - R*(i+h*k3))/L;
                i = i + (h/6)*(k1+2*k2+2*k3+k4);
            end
        end
        if collect && q <= numel(segTargets)
            iOut(nextU-numel(segTargets)+q-1) = i;
        end
    end
end
iEnd = i;
end
