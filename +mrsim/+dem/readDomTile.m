function Z = readDomTile(tifPath)
%READDOMTILE  DOM1-Kachel (GeoTIFF float32, 2000x2000, 1 m) als single lesen.
%   Zeile 1 = Nordrand, Spalte 1 = Westrand (GeoTIFF-Standard, geprueft).
%   Die Dateien enthalten KEINE CRS-GeoKeys -> Georeferenz kommt aus dem
%   Dateinamen (mrsim.dem.parseTileName), nicht aus readgeoraster.
    Z = [];
    if exist('readgeoraster') ~= 0
        try
            Z = readgeoraster(tifPath, 'OutputType', 'single');
        catch
            Z = [];                                   % z. B. fehlende GeoKeys -> Tiff-Fallback
        end
    end
    if isempty(Z) && exist('Tiff', 'class') == 8
        t = Tiff(tifPath, 'r');
        c = onCleanup(@() close(t));
        Z = single(read(t));
    end
    if isempty(Z)
        Z = single(imread(tifPath));
    end
    Z = Z(:, :, 1);
end
