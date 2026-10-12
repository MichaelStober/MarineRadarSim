function [E, N] = tmForward(lat, lon, prm)
%TMFORWARD  Transversale Mercatorprojektion (GRS80) mit beliebigem Ursprung.
%   [E,N] = mrsim.geo.tmForward(lat, lon, prm)
%   prm.lat0, prm.lon0 [deg]  Ursprung (Breite, Mittelmeridian)
%   prm.k0                     Massstabsfaktor
%   prm.false_easting, prm.false_northing [m]
%   Beispiele:
%     UTM Zone 33 (EPSG:25833): lat0 0, lon0 15, k0 0.9996, FE 500000, FN 0
%     PT-TM06 (EPSG:3763):      lat0 39.66825833, lon0 -8.13310833, k0 1, FE 0, FN 0
%   Krueger-Reihe 4. Ordnung (Karney, J. Geodesy 85, 2011, Gl. 7-11, 35); fuer
%   lat0 ~= 0 wird die Nordwert-Konstante des Ursprungs (Meridianbogen) abgezogen.
%   Test gegen PROJ: tests/runAllTests.m (testProjectionsAgainstProj).
    a = 6378137.0; f = 1/298.257222101;          % GRS80
    n = f/(2-f);
    A = a/(1+n) * (1 + n^2/4 + n^4/64);
    al = [ n/2 - 2*n^2/3 + 5*n^3/16 + 41*n^4/180, ...
           13*n^2/48 - 3*n^3/5 + 557*n^4/1440, ...
           61*n^3/240 - 103*n^4/140, ...
           49561*n^4/161280 ];
    e = 2*sqrt(n)/(1+n);
    lon0 = deg2rad(prm.lon0);

    [xi, et] = kruger(deg2rad(lat), deg2rad(lon) - lon0, e, al);
    [xi0, ~] = kruger(deg2rad(prm.lat0), 0, e, al);
    E = prm.false_easting  + prm.k0 * A * et;
    N = prm.false_northing + prm.k0 * A * (xi - xi0);
end

function [xi, et] = kruger(phi, dl, e, al)
    t   = sinh(atanh(sin(phi)) - e .* atanh(e .* sin(phi)));
    xi_ = atan2(t, cos(dl));
    et_ = atanh(sin(dl) ./ sqrt(1 + t.^2));
    xi = xi_; et = et_;
    for j = 1:4
        xi = xi + al(j) * sin(2*j*xi_) .* cosh(2*j*et_);
        et = et + al(j) * cos(2*j*xi_) .* sinh(2*j*et_);
    end
end
