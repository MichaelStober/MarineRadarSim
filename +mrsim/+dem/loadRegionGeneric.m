function reg = loadRegionGeneric(scene, level, E, N, radius)
%LOADREGIONGENERIC  Mosaik um (E,N) aus dem GeoTIFF-Cache (tile_scheme "geotiff").
%   Gleiche Ausgabe wie mrsim.dem.loadRegion: reg.H, reg.C, reg.x0 (West),
%   reg.y0 (Nord), reg.res, reg.missing_frac. Ueberlappende Kacheln: Hoehe =
%   Maximum der gueltigen Werte, Klasse aus der Kachel mit gueltigem Wert.
    d = fullfile(scene.cache_dir, sprintf('L%gm', level));
    idx = loadIndex(fullfile(d, 'index.mat'));
    L = level;
    x0m = floor((E - radius) / L) * L;  x1m = ceil((E + radius) / L) * L;
    y0m = floor((N - radius) / L) * L;  y1m = ceil((N + radius) / L) * L;
    nr = round((y1m - y0m) / L); nc = round((x1m - x0m) / L);
    H = nan(nr, nc, 'single'); C = zeros(nr, nc, 'uint8');

    hit = find(idx.x1 > x0m & idx.x0 < x1m & idx.y1 > y0m & idx.y0 < y1m);
    for k = hit(:).'
        s = mrsim.dem.getTileFile(fullfile(d, idx.files{k}), scene.tile_cache_max);
        c0 = round((s.x0 - x0m) / L);  r0 = round((y1m - s.y0) / L);
        [th, tw] = size(s.H);
        rr = (1:th) + r0; cc = (1:tw) + c0;
        okr = rr >= 1 & rr <= nr; okc = cc >= 1 & cc <= nc;
        if ~any(okr) || ~any(okc), continue; end
        Ht = s.H(okr, okc); Ct = s.C(okr, okc);
        Hm = H(rr(okr), cc(okc)); Cm = C(rr(okr), cc(okc));
        take = ~isnan(Ht) & (isnan(Hm) | Ht > Hm);
        Hm(take) = Ht(take); Cm(take) = Ct(take);
        H(rr(okr), cc(okc)) = Hm; C(rr(okr), cc(okc)) = Cm;
    end

    miss = isnan(H);
    reg.missing_frac = mean(miss(:));
    switch lower(scene.missing_data)
        case 'sea',  H(miss) = 0; C(miss) = 1;
        case 'none', C(miss) = 0;
        otherwise, error('mrsim:dem:missing', 'missing_data muss "sea" oder "none" sein.');
    end
    reg.H = H; reg.C = C; reg.x0 = x0m; reg.y0 = y1m; reg.res = L;
end

function idx = loadIndex(f)
    persistent cacheFile cacheTime cacheIdx
    if ~isfile(f), error('mrsim:dem:index', 'Index %s fehlt - mrsim.dem.buildTileCache(scene) ausfuehren.', f); end
    di = dir(f);
    if isequal(cacheFile, f) && isequal(cacheTime, di.datenum)
        idx = cacheIdx; return;
    end
    idx = load(f);
    cacheFile = f; cacheTime = di.datenum; cacheIdx = idx;
end
