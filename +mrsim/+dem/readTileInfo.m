function t = readTileInfo(file)
%READTILEINFO  Georeferenz einer GeoTIFF-Kachel aus dem Dateikopf (ohne Pixel zu lesen).
%   t.x0 Westkante, t.y1 Nordkante [m, Kartenkoordinaten], t.res Zellgroesse [m],
%   t.nr, t.nc Zeilen/Spalten, t.nodata NoData-Wert ([] wenn keiner), t.flip (true,
%   wenn Zeile 1 die Suedkante ist).
%
%   Weg 1 (ohne Toolbox): imfinfo liest die GeoTIFF-Tags
%     ModelPixelScaleTag (33550) = [sx sy sz], ModelTiepointTag (33922) = [I J K X Y Z],
%     GDAL_NODATA (42113, Text), GeoKeyDirectoryTag (34735) -> GTRasterTypeGeoKey (1025).
%     Westkante x0 = X - I*sx, Nordkante y1 = Y + J*sy (Rastertyp "Area");
%     bei "Point" (1025 = 2) liegt der Bezugspunkt in der Zellmitte -> halbe Zelle versetzt.
%     Spezifikation: OGC GeoTIFF 1.1 (ModelTiepoint/ModelPixelScale, RasterPixelIsArea/Point).
%   Weg 2: Tiff-Klasse (getTag) mit denselben Tags.
%   Weg 3: georasterinfo der Mapping Toolbox.
%   NoData ist optional: fehlt er, greift scene.nodata_below_m (-100 m faengt -999 ab).
%   Fuer Kacheln OHNE Georeferenz im Dateikopf (DOM1 MV) bleibt tile_scheme "mv_named".
    t = [];
    try
        t = fromImfinfo(file);
    catch err1
        msg1 = err1.message;
    end
    if isempty(t)
        try
            t = fromTiff(file);
        catch err2
            msg2 = err2.message;
        end
    end
    if isempty(t)
        try
            t = fromGeorasterinfo(file);
        catch err3
            error('mrsim:dem:info', ['%s: keine Georeferenz lesbar.\n  imfinfo: %s\n' ...
                  '  Tiff: %s\n  georasterinfo: %s'], file, msg1, msg2, err3.message);
        end
    end
end

% ---------------------------------------------------------------------------
function t = fromImfinfo(file)
    info = imfinfo(file);
    info = info(1);
    if ~isfield(info, 'ModelPixelScaleTag') || ~isfield(info, 'ModelTiepointTag') || ...
            isempty(info.ModelPixelScaleTag) || isempty(info.ModelTiepointTag)
        error('ModelPixelScaleTag/ModelTiepointTag fehlen (evtl. ModelTransformationTag)');
    end
    sc = double(info.ModelPixelScaleTag(:));
    tp = double(info.ModelTiepointTag(:));
    if abs(sc(1) - sc(2)) > 1e-9, error('Zellen nicht quadratisch (%g x %g m)', sc(1), sc(2)); end
    t.res = sc(1);
    t.x0 = tp(4) - tp(1) * sc(1);
    t.y1 = tp(5) + tp(2) * sc(2);
    if rasterType(info) == 2                         % RasterPixelIsPoint
        t.x0 = t.x0 - t.res / 2;
        t.y1 = t.y1 + t.res / 2;
    end
    t.nr = info.Height; t.nc = info.Width;
    t.nodata = gdalNodata(info);
    t.flip = false;                                  % positive Pixelskala: Zeile 1 = Nord
end

function t = fromTiff(file)
    tf = Tiff(file, 'r');
    c = onCleanup(@() close(tf));
    sc = double(getTag(tf, 'ModelPixelScaleTag'));
    tp = double(getTag(tf, 'ModelTiepointTag'));
    if abs(sc(1) - sc(2)) > 1e-9, error('Zellen nicht quadratisch'); end
    t.res = sc(1);
    t.x0 = tp(4) - tp(1) * sc(1);
    t.y1 = tp(5) + tp(2) * sc(2);
    try
        info.GeoKeyDirectoryTag = getTag(tf, 'GeoKeyDirectoryTag');
        if rasterType(info) == 2
            t.x0 = t.x0 - t.res / 2; t.y1 = t.y1 + t.res / 2;
        end
    catch
    end
    t.nr = getTag(tf, 'ImageLength'); t.nc = getTag(tf, 'ImageWidth');
    t.nodata = [];
    try, t.nodata = str2double(getTag(tf, 'GDAL_NODATA')); catch, end
    t.flip = false;
end

function rt = rasterType(info)
    rt = 1;
    if isfield(info, 'GeoKeyDirectoryTag') && ~isempty(info.GeoKeyDirectoryTag)
        g = double(info.GeoKeyDirectoryTag(:));
        n = g(4);
        for k = 1:n
            e = g(4*k + (1:4));
            if e(1) == 1025 && e(2) == 0, rt = e(4); end
        end
    end
end

function nd = gdalNodata(info)
    nd = [];
    if isfield(info, 'GDAL_NODATA') && ~isempty(info.GDAL_NODATA)
        nd = str2double(info.GDAL_NODATA); return;
    end
    if isfield(info, 'UnknownTags')
        u = info.UnknownTags;
        for k = 1:numel(u)
            if u(k).ID == 42113
                v = u(k).Value;
                if ischar(v), nd = str2double(strtrim(v)); else, nd = double(v(1)); end
            end
        end
    end
end

function t = fromGeorasterinfo(file)
    info = georasterinfo(file);
    R = info.RasterReference;
    if isempty(R), error('keine Georeferenz im Dateikopf'); end
    t.x0 = R.XWorldLimits(1);
    t.y1 = R.YWorldLimits(2);
    t.res = R.CellExtentInWorldX;
    t.nr = R.RasterSize(1); t.nc = R.RasterSize(2);
    t.nodata = info.MissingDataIndicator;
    t.flip = strcmpi(char(R.ColumnsStartFrom), 'south');
end
