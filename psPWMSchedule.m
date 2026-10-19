function schedule = psPWMSchedule(p,mf,blockSize)
%PSPWMSCHEDULE Phasenversetzte Traeger-PWM mit waehlbarer Blockgroesse.
% blockSize Submodule bilden einen gemeinsam geschalteten Block mit
% eigenem Dreieckstraeger: blockSize = 1 ist SM-Level-PWM (1S-Schritte),
% blockSize = smPerModule die klassische Modul-Level-PS-PWM (ein Traeger
% je H-Bruecke). Alle N = totalSM/blockSize Bloecke vergleichen die
% normierte Referenzamplitude |m(t)| mit je einem Dreieckstraeger der
% Frequenz fc = mf*f0; die Traeger sind um jeweils 1/N der Traegerperiode
% versetzt. Die Zahl der eingeschalteten Bloecke bildet die Stufenfolge,
% das Vorzeichen folgt der Referenz. Die Schaltzeitpunkte werden auf
% einem feinen Zeitraster (2^18 Punkte pro Periode) bestimmt.
if nargin < 3 || isempty(blockSize)
    blockSize = 1;
end
totalSM = p.moduleCount*p.smPerModule;
if mod(totalSM,blockSize) ~= 0
    error('chb:InvalidBlockSize', ...
        'blockSize (%d) must divide the total SM count (%d).',blockSize,totalSM);
end
N = totalSM/blockSize;
T = 1/p.frequency;
fc = mf*p.frequency;
nGrid = 2^18;
tMid = ((1:nGrid).'-0.5)*(T/nGrid);
m = p.voltagePeak*sin(2*pi*p.frequency*tMid)/(totalSM*p.cellVoltage*p.cellsPerSM);
mAbs = abs(m);
level = zeros(nGrid,1);
for k = 1:N
    u = fc*tMid + (k-1)/N;
    carrier = 2*abs(u-floor(u+0.5));
    level = level + (mAbs > carrier);
end
level = blockSize*sign(m).*level;
changes = find(diff(level) ~= 0);
gridEdges = (0:nGrid).'*(T/nGrid);
schedule = struct('edges',[0; gridEdges(changes+1); T], ...
    'levels',level([1; changes+1]));
end
