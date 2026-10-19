function s = germanNumber(fmt,varargin)
%GERMANNUMBER sprintf mit Dezimalkomma (deutsche Konvention).
%   s = germanNumber(fmt,...) formatiert wie sprintf und ersetzt
%   anschliessend Dezimalpunkte durch Kommas — nur zwischen Ziffern,
%   damit Abkuerzungspunkte im Text (z. B. "klass. OPP") erhalten bleiben.
s = regexprep(sprintf(fmt,varargin{:}),'(?<=\d)\.(?=\d)',',');
end
