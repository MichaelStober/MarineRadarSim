function mask = cartLandMask(reg, pose, rangeM, nPx)
%CARTLANDMASK  Ground-Truth-Landmaske im kartesischen Ausgabebild (gleiche Ausrichtung
%   wie polarToCart: oben = hdg0). Direkt aus dem Klassenraster abgetastet (keine
%   Radargeometrie, keine Abschattung). Land = Klassen 2..4.
    pxm = 2 * rangeM / nPx;
    u = ((1:nPx) - (nPx+1)/2) * pxm;
    v = ((nPx+1)/2 - (1:nPx).') * pxm;
    X = repmat(u, nPx, 1); Y = repmat(v, 1, nPx);
    R = hypot(X, Y);
    A = atan2d(X, Y) + pose.hdg0 - pose.gamma;     % Gitterazimut
    dE = R .* sind(A); dN = R .* cosd(A);
    col = round((pose.E + dE - reg.x0) / reg.res + 0.5);
    row = round((reg.y0 - (pose.N + dN)) / reg.res + 0.5);
    [nr, nc] = size(reg.C);
    ok = row >= 1 & row <= nr & col >= 1 & col <= nc & R <= rangeM;
    mask = false(nPx);
    mask(ok) = reg.C(sub2ind([nr nc], row(ok), col(ok))) >= 2;
end
