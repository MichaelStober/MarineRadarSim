function gam = gridConvergence(lat, lon, crs)
%GRIDCONVERGENCE  Meridiankonvergenz gamma [deg] (Gitternord relativ zu geogr. Nord).
%   gam = mrsim.geo.gridConvergence(lat, lon, scene)   % oder UTM-Zone als Zahl
%   Gitter-Azimut = geographischer Azimut - gamma.
%   Westlich des Mittelmeridians ist gamma < 0 (Rostock in UTM 33 ~ -2.3 deg,
%   Sesimbra in PT-TM06 ~ -0.6 deg).
%   Numerisch aus einem kleinen Nordschritt (exakt bzgl. mrsim.geo.project).
    d = 1e-5;                                           % ~1.1 m nach Norden
    [E1, N1] = mrsim.geo.project(lat,     lon, crs);
    [E2, N2] = mrsim.geo.project(lat + d, lon, crs);
    gam = -atan2d(E2 - E1, N2 - N1);
end
