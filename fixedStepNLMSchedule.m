function schedule = fixedStepNLMSchedule(p,s)
%FIXEDSTEPNLMSCHEDULE Nearest-Level-Schedule mit fester Granularitaet s.
% Die Stufen sind Vielfache von s Submodulen; Umschaltzeitpunkte liegen
% exakt an den Nearest-Level-Schwellen (m-0.5)*s*vStep der Viertelwelle,
% Rest der Periode per Viertelwellensymmetrie. Liefert [] wenn s so grob
% ist, dass keine Stufe erreicht wird.
vStep = p.cellVoltage*p.cellsPerSM;
maxLevel = p.moduleCount*p.smPerModule;
T = 1/p.frequency;
w = 2*pi*p.frequency;
M = floor(p.voltagePeak/(s*vStep) + 0.5);
M = min(M,floor(maxLevel/s));
if M < 1
    schedule = [];
    return
end
m = (1:M).';
tRise = asin(min(1,(m-0.5)*s*vStep/p.voltagePeak))/w;
quarterEdges = [0; tRise; T/4];
quarterLevels = s*(0:M).';

qdt = diff(quarterEdges);
fullDt = [qdt; flipud(qdt); qdt; flipud(qdt)];
fullLevels = [quarterLevels; flipud(quarterLevels); -quarterLevels; -flipud(quarterLevels)];
fullEdges = [0; cumsum(fullDt)];
fullEdges(end) = T;
changes = find(diff(fullLevels) ~= 0);
schedule = struct();
schedule.edges = [fullEdges(1); fullEdges(changes+1); fullEdges(end)];
schedule.levels = fullLevels([1; changes+1]);
end
