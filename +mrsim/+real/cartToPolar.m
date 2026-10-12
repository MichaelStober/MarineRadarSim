function pol = cartToPolar(img, pxM, center, nS, nB, binM, upBearingDeg)
%CARTTOPOLAR  Kartesisches Radarbild (z. B. Pohang-PNG) in Spokes x Bins umrechnen.
%   pol = mrsim.real.cartToPolar(img, pxM, [cx cy], nS, nB, binM, upBearingDeg)
%   img            Graustufenbild (uint8), Zeile 1 oben
%   pxM            Meter je Pixel
%   center         [Spalte Zeile] der Radarposition im Bild (leer = Bildmitte)
%   upBearingDeg   Winkel, in den "oben" im Bild zeigt, relativ zu Spoke 0 (0 = oben ist Spoke 0)
%   Spoke k zeigt in Richtung (k-1)*360/nS im Uhrzeigersinn; Bin j liegt bei (j-0.5)*binM.
%   Bilineare Interpolation; ausserhalb des Bildes 0.
%   Hinweis: Die Umrechnung interpoliert und ist verlustbehaftet; fuer Datensaetze, die
%   nur kartesisch vorliegen, alternativ beide Bilder kartesisch vergleichen.
    if nargin < 7 || isempty(upBearingDeg), upBearingDeg = 0; end
    if size(img, 3) > 1, img = mean(double(img), 3); end
    [h, w] = size(img);
    if isempty(center), center = [(w + 1) / 2, (h + 1) / 2]; end
    th = ((0:nS-1).' * 360 / nS) - upBearingDeg;
    r = ((1:nB) - 0.5) * binM / pxM;
    X = center(1) + sind(th) * r;
    Y = center(2) - cosd(th) * r;
    pol = interp2(double(img), X, Y, 'linear', 0);
    pol = uint8(round(pol));
end
