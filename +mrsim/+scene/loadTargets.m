function tg = loadTargets(csvPath, crs, defaults)
%LOADTARGETS  Diskrete Punktziele (Tonnen, Baken, ... aus ENC/OSM-Seezeichen) laden.
%   CSV mit Kopfzeile, Spalten:
%     lat, lon          Pflicht (WGS84)
%     rcs_dbsm          Radarquerschnitt [dBsm]; leer -> Default nach reflector
%     height_m          Hoehe des Streuzentrums ueber Wasser [m]; leer -> Default
%     reflector         1/0 (Radarreflektor vorhanden); leer -> 0
%     type, name        frei (z. B. buoy_lateral, "Tonne 12")
%     shape             Form (OSM seamark:<typ>:shape, z. B. spar, can, pillar); leer erlaubt
%   defaults (scene.targets):
%     categories.<kat>.rcs_dbsm / .height_m   Mittlerer RCS und Hoehe je Kategorie (Option B):
%        beacon          type beginnt mit beacon_
%        buoy_reflector  type beginnt mit buoy_ und reflector = 1
%        spar            type beginnt mit buoy_, ohne Reflektor, shape = spar
%        buoy            alle uebrigen (auch unbekannter Typ)
%     Fehlt categories: rcs_reflector_dbsm, rcs_plain_dbsm, height_m (altes Schema).
%   Explizite Werte in rcs_dbsm/height_m der CSV haben Vorrang.
%   Rueckgabe: struct mit Spaltenvektoren E, N (Kartenkoordinaten der Szene), h, rcs (linear, m^2), type, name.
%
%   Erzeugen der CSV z. B. mit mrsim.scene.seamarksFromOverpass (OpenSeaMap/OSM) oder
%   aus ENC-Objekten (S-57: BOYLAT, BOYCAR, BOYSAW, BOYSPP, BCNLAT, ...; Reflektor
%   ueber Attribut CONRAD = 3 bzw. Objekt RADRFL).
    tg = struct('E', [], 'N', [], 'h', [], 'rcs', [], 'type', {{}}, 'name', {{}}, 'category', {{}});
    if isempty(csvPath) || ~isfile(csvPath), return; end
    lines = regexp(fileread(csvPath), '\r?\n', 'split');
    lines = lines(~cellfun(@(s) isempty(strtrim(s)), lines));
    if numel(lines) < 2, return; end
    names = lower(strtrim(strsplit(lines{1}, ',', 'CollapseDelimiters', false)));
    n = numel(lines) - 1;
    C = cell(n, numel(names));
    for i = 1:n
        parts = strsplit(lines{i+1}, ',', 'CollapseDelimiters', false);
        parts(end+1:numel(names)) = {''};
        C(i, :) = strtrim(parts(1:numel(names)));
    end
    col = @(nm) find(strcmp(names, nm), 1);
    num = @(nm) getNum(C, col(nm), n);
    lat = num('lat'); lon = num('lon');
    if any(isnan(lat)) || any(isnan(lon))
        error('mrsim:targets:latlon', 'Zieldatei %s: lat/lon fehlen oder sind ungueltig.', csvPath);
    end
    [tg.E, tg.N] = mrsim.geo.project(lat, lon, crs);              % crs: Szene oder UTM-Zone
    refl = num('reflector'); refl(isnan(refl)) = 0;
    tg.type = getStr(C, col('type'), n);
    tg.name = getStr(C, col('name'), n);
    shape = getStr(C, col('shape'), n);
    rcsDb = num('rcs_dbsm');
    h = num('height_m');
    if isfield(defaults, 'categories') && ~isempty(defaults.categories)
        tg.category = cell(n, 1);
        for i = 1:n
            k = categorize(tg.type{i}, shape{i}, refl(i));
            tg.category{i} = k;
            cat = defaults.categories.(k);
            if isnan(rcsDb(i)), rcsDb(i) = cat.rcs_dbsm; end
            if isnan(h(i)), h(i) = cat.height_m; end
        end
    else
        d = isnan(rcsDb);
        rcsDb(d & refl > 0)  = defaults.rcs_reflector_dbsm;
        rcsDb(d & refl == 0) = defaults.rcs_plain_dbsm;
        h(isnan(h)) = defaults.height_m;
        tg.category = repmat({''}, n, 1);
    end
    tg.rcs = 10.^(rcsDb / 10);
    tg.h = h;
end

function k = categorize(type, shape, refl)
    type = lower(strtrim(type)); shape = lower(strtrim(shape));
    if strncmp(type, 'beacon_', 7)
        k = 'beacon';
    elseif refl > 0
        k = 'buoy_reflector';
    elseif strcmp(shape, 'spar')
        k = 'spar';
    else
        k = 'buoy';
    end
end

function v = getNum(C, i, n)
    if isempty(i), v = nan(n, 1); else, v = str2double(C(:, i)); end
end

function v = getStr(C, i, n)
    if isempty(i), v = repmat({''}, n, 1); else, v = C(:, i); end
end
