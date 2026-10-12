function n = downloadSeamarks(bbox, outCsv, jsonFile)
%DOWNLOADSEAMARKS  Tonnen/Baken (OpenSeaMap-Daten in OSM) per Overpass-API laden und als
%   Punktziel-CSV schreiben. Gleiche Quelle wie bei der Dagdilelis-Reimplementierung.
%
%   n = mrsim.scene.downloadSeamarks([54.05 11.90 54.35 12.40], 'data/targets_rostock.csv')
%   bbox = [lat_sued lon_west lat_nord lon_ost]
%   Zwischenergebnis (Overpass-JSON) wird neben der CSV abgelegt bzw. unter jsonFile.
%   Braucht Internetzugang auf dem ausfuehrenden Rechner. UNGETESTET in der
%   Entwicklungsumgebung (Overpass dort gesperrt); die Umwandlung JSON -> CSV
%   (seamarksFromOverpass) ist getestet.
    if nargin < 3 || isempty(jsonFile)
        [p, b] = fileparts(outCsv);
        jsonFile = fullfile(p, [b '_overpass.json']);
    end
    q = sprintf('[out:json][timeout:60];node["seamark:type"~"^(buoy_|beacon_)"](%.5f,%.5f,%.5f,%.5f);out;', ...
        bbox(1), bbox(2), bbox(3), bbox(4));
    url = ['https://overpass-api.de/api/interpreter?data=' urlencode(q)];
    [p, ~] = fileparts(jsonFile);
    if ~isempty(p) && ~isfolder(p), mkdir(p); end
    websave(jsonFile, url);
    n = mrsim.scene.seamarksFromOverpass(jsonFile, outCsv);
    fprintf('%d Seezeichen nach %s geschrieben.\n', n, outCsv);
end
