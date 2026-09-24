function [E, N] = wgs2utm(lat, lon, zone)
%WGS2UTM  Geographisch (ETRS89/WGS84) -> UTM (ETRS89/UTM, z. B. EPSG:25833).
%   [E,N] = mrsim.geo.wgs2utm(lat, lon, 33)
%   Krueger-Reihe 4. Ordnung auf GRS80, Genauigkeit << 1 mm innerhalb der Zone.
%   Referenz: C.F.F. Karney, "Transverse Mercator with an accuracy of a few
%   nanometers", J. Geodesy 85 (2011), Gl. (7)-(11), (35).
%   Ohne Mapping Toolbox lauffaehig; Test gegen PROJ in tests/runAllTests.m.
    a  = 6378137.0;            % GRS80
    f  = 1/298.257222101;
    k0 = 0.9996;
    E0 = 500000; N0 = 0;
    lon0 = deg2rad(-183 + 6*zone);

    n  = f/(2-f);
    A  = a/(1+n) * (1 + n^2/4 + n^4/64);
    al = [ n/2 - 2*n^2/3 + 5*n^3/16 + 41*n^4/180, ...
           13*n^2/48 - 3*n^3/5 + 557*n^4/1440, ...
           61*n^3/240 - 103*n^4/140, ...
           49561*n^4/161280 ];

    phi = deg2rad(lat);
    dl  = deg2rad(lon) - lon0;
    e   = 2*sqrt(n)/(1+n);                         % erste Exzentrizitaet
    t   = sinh(atanh(sin(phi)) - e .* atanh(e .* sin(phi)));
    xi_ = atan2(t, cos(dl));
    et_ = atanh(sin(dl) ./ sqrt(1 + t.^2));

    xi = xi_; et = et_;
    for j = 1:4
        xi = xi + al(j) * sin(2*j*xi_) .* cosh(2*j*et_);
        et = et + al(j) * cos(2*j*xi_) .* sinh(2*j*et_);
    end
    E = E0 + k0 * A * et;
    N = N0 + k0 * A * xi;
end
