function [zone, Ekm, Nkm, ok] = parseTileName(fileName, pattern)
%PARSETILENAME  'dom1_33_314_6010_2_gtiff.tif' -> zone 33, E 314 km, N 6010 km.
%   Die Kachel deckt E = [Ekm, Ekm+2]*1000, N = [Nkm, Nkm+2]*1000 ab
%   (untere linke Ecke, 2 km Kantenlaenge; geprueft gegen Geotransform).
    tok = regexp(fileName, pattern, 'tokens', 'once');
    ok = numel(tok) == 3;
    if ok
        zone = str2double(tok{1}); Ekm = str2double(tok{2}); Nkm = str2double(tok{3});
    else
        zone = NaN; Ekm = NaN; Nkm = NaN;
    end
end
