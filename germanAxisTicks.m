function germanAxisTicks(varargin)
%GERMANAXISTICKS Dezimalpunkte der Achsenbeschriftung durch Kommas ersetzen.
%   germanAxisTicks(ax1,ax2,...) friert die aktuellen Ticklabels der
%   uebergebenen Achsen ein und ersetzt Dezimalpunkte durch Kommas
%   (deutsche Konvention). Unmittelbar vor dem Export aufrufen, da die
%   Labels danach nicht mehr automatisch aktualisiert werden.
drawnow
for n = 1:nargin
    for ax = varargin{n}(:).'
        xticklabels(ax,strrep(xticklabels(ax),'.',','));
        yticklabels(ax,strrep(yticklabels(ax),'.',','));
    end
end
end
