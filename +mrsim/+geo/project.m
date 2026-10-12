function [E, N] = project(lat, lon, crs)
%PROJECT  WGS84/ETRS89 -> Kartenkoordinaten der Szene.
%   [E,N] = mrsim.geo.project(lat, lon, scene)   % nutzt scene.crs bzw. scene.utm_zone
%   [E,N] = mrsim.geo.project(lat, lon, 33)      % UTM-Zone direkt
%   scene.crs (optional), z. B. fuer Portugal (EPSG:3763, PT-TM06):
%     "crs": {"type": "tm", "epsg": 3763, "lat0": 39.66825833333333,
%             "lon0": -8.133108333333333, "k0": 1.0,
%             "false_easting": 0, "false_northing": 0}
%   Ohne scene.crs: UTM mit scene.utm_zone (Rostock, EPSG:25833).
%   Alle Rechnungen der Simulation laufen in diesen ebenen Koordinaten; deshalb
%   muessen sie zum Koordinatensystem der Hoehenkacheln passen.
    prm = mrsim.geo.crsParams(crs);
    [E, N] = mrsim.geo.tmForward(lat, lon, prm);
end
