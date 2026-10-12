function n = seamarksFromOverpass(jsonFile, outCsv)
%SEAMARKSFROMOVERPASS  Tonnen/Baken aus einem Overpass-JSON-Export (OpenSeaMap/OSM) in die
%   Punktziel-CSV fuer mrsim.scene.loadTargets schreiben.
%
%   Overpass-Abfrage (Beispiel, Bounding Box anpassen, Ausgabe als JSON speichern):
%     [out:json]; node["seamark:type"~"^(buoy_|beacon_)"](54.05,11.90,54.35,12.40); out;
%
%   Uebernommen: lat, lon, type (seamark:type), name (seamark:name),
%   reflector = 1, wenn seamark:radar_reflector = yes. rcs_dbsm und height_m bleiben
%   leer -> Defaults aus scene.targets (Annahmen, siehe docs/ENTSCHEIDUNGEN.md).
%   Rueckgabe: Anzahl geschriebener Ziele.
    d = jsondecode(fileread(jsonFile));
    el = d.elements;
    if ~iscell(el), el = num2cell(el); end
    fid = fopen(outCsv, 'w');
    if fid < 0, error('mrsim:targets:write', 'Kann %s nicht schreiben.', outCsv); end
    c = onCleanup(@() fclose(fid));
    fprintf(fid, 'lat,lon,rcs_dbsm,height_m,reflector,type,name\n');
    n = 0;
    for i = 1:numel(el)
        e = el{i};
        if ~isfield(e, 'lat') || ~isfield(e, 'tags'), continue; end
        ty = tag(e.tags, 'seamark:type');
        if isempty(regexp(ty, '^(buoy_|beacon_)', 'once')), continue; end
        refl = strcmpi(tag(e.tags, 'seamark:radar_reflector'), 'yes');
        nm = strrep(tag(e.tags, 'seamark:name'), ',', ' ');
        fprintf(fid, '%.7f,%.7f,,,%d,%s,%s\n', e.lat, e.lon, refl, ty, nm);
        n = n + 1;
    end
end

function v = tag(tags, key)
% jsondecode ersetzt ':' in Feldnamen (MATLAB: seamark_type); beide Varianten pruefen
    v = '';
    cands = {matlab.lang.makeValidName(key), strrep(key, ':', '_'), strrep(key, ':', '')};
    for k = 1:numel(cands)
        if isfield(tags, cands{k}), v = char(tags.(cands{k})); return; end
    end
end
