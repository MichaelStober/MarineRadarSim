function n = downloadSeamarks(bbox, outCsv, jsonFile, timeoutS)
%DOWNLOADSEAMARKS  Tonnen/Baken (OpenSeaMap-Daten in OSM) per Overpass-API laden und als
%   Punktziel-CSV schreiben. Gleiche Quelle wie bei der Dagdilelis-Reimplementierung.
%
%   n = mrsim.scene.downloadSeamarks([54.05 11.90 54.35 12.40], 'data/targets_rostock.csv')
%   n = mrsim.scene.downloadSeamarks(bbox, outCsv, jsonFile, timeoutS)
%   bbox = [lat_sued lon_west lat_nord lon_ost]
%   Zwischenergebnis (Overpass-JSON) wird neben der CSV abgelegt bzw. unter jsonFile.
%   timeoutS: Wartezeit je Server [s] (Default 120; websave-Default von 5 s ist fuer
%   Overpass zu kurz). Bei Fehlern werden nacheinander mehrere Overpass-Server versucht.
%   Braucht Internetzugang auf dem ausfuehrenden Rechner.
    if nargin < 3 || isempty(jsonFile)
        [p, b] = fileparts(outCsv);
        jsonFile = fullfile(p, [b '_overpass.json']);
    end
    if nargin < 4 || isempty(timeoutS), timeoutS = 120; end
    q = sprintf('[out:json][timeout:90];node["seamark:type"~"^(buoy_|beacon_)"](%.5f,%.5f,%.5f,%.5f);out;', ...
        bbox(1), bbox(2), bbox(3), bbox(4));
    servers = {'https://overpass-api.de/api/interpreter', ...
               'https://overpass.kumi.systems/api/interpreter', ...
               'https://maps.mail.ru/osm/tools/overpass/api/interpreter'};
    [p, ~] = fileparts(jsonFile);
    if ~isempty(p) && ~isfolder(p), mkdir(p); end
    opts = weboptions('Timeout', timeoutS);
    ok = false; lastErr = '';
    for s = 1:numel(servers)
        url = [servers{s} '?data=' urlencode(q)];
        try
            fprintf('Overpass: %s ...\n', servers{s});
            websave(jsonFile, url, opts);
            ok = true;
            break
        catch err
            lastErr = err.message;
            fprintf('  fehlgeschlagen: %s\n', err.message);
        end
    end
    if ~ok
        error('mrsim:targets:overpass', ['Kein Overpass-Server erreichbar (%s).\n' ...
            'Alternative: Abfrage im Browser auf https://overpass-turbo.eu ausfuehren, ' ...
            'als JSON exportieren und mrsim.scene.seamarksFromOverpass(json, csv) aufrufen.\n' ...
            'Abfrage: %s'], lastErr, q);
    end
    n = mrsim.scene.seamarksFromOverpass(jsonFile, outCsv);
    fprintf('%d Seezeichen nach %s geschrieben.\n', n, outCsv);
end
