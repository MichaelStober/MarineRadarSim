function img = polarToCart(polar, binM, rangeM, nPx)
%POLARTOCART  Polares Bild (Spokes x Bins) -> kartesisches Bild nPx x nPx.
%   Spoke 1 zeigt nach oben (Bug bei Head-up, Nord bei North-up), Spokes im
%   Uhrzeigersinn. Bildmitte = Radar, Bildkante = rangeM. Ausserhalb des Kreises 0.
%   Bilineare Interpolation, zirkulaer in Azimut.
    [nS, nB] = size(polar);
    pxm = 2 * rangeM / nPx;
    u = ((1:nPx) - (nPx+1)/2) * pxm;               % x nach rechts
    v = ((nPx+1)/2 - (1:nPx).') * pxm;             % y nach oben
    X = repmat(u, nPx, 1); Y = repmat(v, 1, nPx);
    R = hypot(X, Y);
    A = mod(atan2d(X, Y), 360);                    % im Uhrzeigersinn ab oben
    sIdx = A / (360 / nS) + 1;                     % Spoke k hat Zentrum (k-1)*360/nS
    bIdx = R / binM + 0.5;                         % Bin k hat Zentrum (k-0.5)*binM
    P = double([polar; polar(1, :)]);              % Wrap fuer Spoke nS -> 1
    img = interp2(P, min(max(bIdx, 1), nB), sIdx, 'linear');
    img(R > rangeM | isnan(img)) = 0;
    if isa(polar, 'uint8')
        img = uint8(round(img));
    elseif islogical(polar)
        img = img >= 0.5;
    end
end
