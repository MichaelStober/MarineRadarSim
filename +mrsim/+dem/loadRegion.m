function reg = loadRegion(scene, level, E, N, radius)
%LOADREGION  Hoehen-/Klassenmosaik um (E,N) mit Radius [m] aus dem Cache bauen.
%   reg.H     single  Hoehe [m], NaN = keine Daten (nach missing_data-Regel ersetzt)
%   reg.C     uint8   Klasse (0 unbekannt, 1 See, 2 flach, 3 Wald, 4 Bebauung)
%   reg.x0    Westkante [m E], reg.y0 Nordkante [m N], reg.res Zellgroesse [m]
%   reg.missing_frac  Anteil fehlender Zellen (vor Ersetzung)
%   Zelle (r,c) hat ihr Zentrum bei E = x0 + (c-0.5)*res, N = y0 - (r-0.5)*res.
    if isfield(scene, 'tile_scheme') && strcmpi(scene.tile_scheme, 'geotiff')
        reg = mrsim.dem.loadRegionGeneric(scene, level, E, N, radius);
        return;
    end
    T  = scene.tile_size_m;
    tk = T / 1000;
    nT = T / level;
    eMin = floor((E - radius) / T) * tk;  eMax = floor((E + radius) / T) * tk;
    nMin = floor((N - radius) / T) * tk;  nMax = floor((N + radius) / T) * tk;
    eList = eMin:tk:eMax;
    nList = nMax:-tk:nMin;                                 % Nord -> Sued (Zeilen)

    H = nan(numel(nList) * nT, numel(eList) * nT, 'single');
    C = zeros(size(H), 'uint8');
    for a = 1:numel(nList)
        for b = 1:numel(eList)
            [h, c, found] = mrsim.dem.getTile(scene.cache_dir, level, eList(b), nList(a), scene.tile_cache_max);
            if found
                rr = (a-1)*nT + (1:nT); cc = (b-1)*nT + (1:nT);
                H(rr, cc) = h; C(rr, cc) = c;
            end
        end
    end

    miss = isnan(H);
    reg.missing_frac = mean(miss(:));
    switch lower(scene.missing_data)
        case 'sea'
            H(miss) = 0; C(miss) = 1;
        case 'none'
            C(miss) = 0;                                  % NaN bleibt -> kein Echo, keine Abschattung
        otherwise
            error('mrsim:dem:missing', 'missing_data muss "sea" oder "none" sein.');
    end
    reg.H = H; reg.C = C;
    reg.x0 = eMin * 1000;
    reg.y0 = (nMax + tk) * 1000;
    reg.res = level;
end
