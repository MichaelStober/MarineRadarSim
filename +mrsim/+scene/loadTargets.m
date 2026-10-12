function tg = loadTargets(csvPath, crs, defaults)
%LOADTARGETS  Diskrete Punktziele (Tonnen, Baken, ... aus ENC/OSM-Seezeichen) laden.
%   CSV mit Kopfzeile, Spalten:
%     lat, lon          Pflicht (WGS84)
%     rcs_dbsm          Radarquerschnitt [dBsm]; leer -> Default nach reflector
%     height_m          Hoehe des Streuzentrums ueber Wasser [m]; leer -> Default
%     reflector         1/0 (Radarreflektor vorhanden); leer -> 0
%     type, name        frei (z. B. buoy_lateral, "Tonne 12")
%   defaults (scene.targets): rcs_reflector_dbsm, rcs_plain_dbsm, height_m
%   Rueckgabe: struct mit Spaltenvektoren E, N (Kartenkoordinaten der Szene), h, rcs (linear, m^2), type, name.
%
%   Erzeugen der CSV z. B. mit mrsim.scene.seamarksFromOverpass (OpenSeaMap/OSM) oder
%   aus ENC-Objekten (S-57: BOYLAT, BOYCAR, BOYSAW, BOYSPP, BCNLAT, ...; Reflektor
%   ueber Attribut CONRAD = 3 bzw. Objekt RADRFL).
    tg = struct('E', [], 'N', [], 'h', [], 'rcs', [], 'type', {{}}, 'name', {{}});
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
    rcsDb = num('rcs_dbsm');
    d = isnan(rcsDb);
    rcsDb(d & refl > 0)  = defaults.rcs_reflector_dbsm;
    rcsDb(d & refl == 0) = defaults.rcs_plain_dbsm;
    tg.rcs = 10.^(rcsDb / 10);
    tg.h = num('height_m'); tg.h(isnan(tg.h)) = defaults.height_m;
    tg.type = getStr(C, col('type'), n);
    tg.name = getStr(C, col('name'), n);
end

function v = getNum(C, i, n)
    if isempty(i), v = nan(n, 1); else, v = str2double(C(:, i)); end
end

function v = getStr(C, i, n)
    if isempty(i), v = repmat({''}, n, 1); else, v = C(:, i); end
end
