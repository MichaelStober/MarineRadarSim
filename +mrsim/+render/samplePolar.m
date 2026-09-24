function g = samplePolar(reg, pose, radar, sc, scene)
%SAMPLEPOLAR  Hoehe/Klasse auf dem feinen Polargitter um die Radarposition abtasten.
%   Feingitter: Na = n_spokes*ovA Strahlen x Nr = n_bins*ovR Entfernungen.
%   Strahl i hat den geographischen Azimut
%       theta_i = hdg0 + ((i-1) - (ovA-1)/2) * 360/Na      (im Uhrzeigersinn)
%   mit hdg0 = Heading (Head-up) bzw. 0 (North-up); Spoke k = Strahlen (k-1)*ovA+(1:ovA).
%   Entfernung r_j = (j-0.5)*dr, dr = bin_m/ovR; Bin k = Feinzellen (k-1)*ovR+(1:ovR).
%   Gitterazimut = geogr. Azimut - gamma (Meridiankonvergenz, UTM).
%
%   g.h      Hoehe relativ Wasserspiegel inkl. Erdkruemmung h' = h - wl - r^2/(2 k R_E)  [m]
%   g.cls    Klasse (uint8), g.r (1 x Nr), g.theta (Na x 1), g.dtheta, g.dr
    ovA = radar.oversampling.azimuth;  ovR = radar.oversampling.range;
    Na = radar.n_spokes * ovA;         Nr = radar.n_bins * ovR;
    dth = 360 / Na;
    g.theta  = pose.hdg0 + ((0:Na-1).' - (ovA-1)/2) * dth;
    g.dtheta = dth;
    g.dr     = sc.bin_m / ovR;
    g.r      = ((1:Nr) - 0.5) * g.dr;

    beta = g.theta - pose.gamma;                 % Gitterazimut
    sb = sind(beta); cb = cosd(beta);
    col = (pose.E - reg.x0) / reg.res + 0.5 + (sb * g.r) / reg.res;
    row = (reg.y0 - pose.N) / reg.res + 0.5 - (cb * g.r) / reg.res;

    h = interp2(double(reg.H), col, row, 'linear');   % NaN ausserhalb / ohne Daten
    [nr, nc] = size(reg.C);
    ri = min(max(round(row), 1), nr); ci = min(max(round(col), 1), nc);
    cls = reg.C(sub2ind([nr nc], ri, ci));
    outside = row < 0.5 | row > nr + 0.5 | col < 0.5 | col > nc + 0.5;
    if strcmpi(scene.missing_data, 'sea')
        h(outside | isnan(h)) = 0; cls(outside) = 1;
    else
        h(outside) = NaN; cls(outside) = 0;
    end
    Re = 6371000;
    g.h = single(h - scene.water_level_m - (g.r.^2) / (2 * scene.earth_k * Re));
    g.cls = cls;
end
