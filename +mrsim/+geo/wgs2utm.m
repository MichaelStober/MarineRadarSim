function [E, N] = wgs2utm(lat, lon, zone)
%WGS2UTM  Geographisch (ETRS89/WGS84) -> UTM der angegebenen Zone (z. B. EPSG:25833).
%   Duenne Huelle um mrsim.geo.tmForward (Krueger-Reihe, Karney 2011);
%   fuer andere Koordinatensysteme mrsim.geo.project verwenden.
    [E, N] = mrsim.geo.tmForward(lat, lon, mrsim.geo.crsParams(zone));
end
