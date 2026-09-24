function gam = gridConvergence(lat, lon, zone)
%GRIDCONVERGENCE  Meridiankonvergenz gamma [deg] (Gitternord relativ zu geogr. Nord).
%   Gitter-Azimut = geographischer Azimut - gamma.
%   Westlich des Mittelmeridians (Rostock, 12 E in Zone 33) ist gamma < 0 (~ -2.4 deg).
%   Numerisch aus einem kleinen Nordschritt bestimmt (exakt bzgl. wgs2utm).
    d = 1e-5;                                           % ~1.1 m nach Norden
    [E1, N1] = mrsim.geo.wgs2utm(lat,     lon, zone);
    [E2, N2] = mrsim.geo.wgs2utm(lat + d, lon, zone);
    % Richtung des geogr. Nordens im Gitter, gemessen von Gitternord im Uhrzeigersinn
    gridBearingOfTrueNorth = atan2d(E2 - E1, N2 - N1);
    gam = -gridBearingOfTrueNorth;
end
