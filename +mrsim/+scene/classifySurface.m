function C = classifySurface(Z, cls)
%CLASSIFYSURFACE  Oberflaechenklassen aus DOM (1 m) ohne DGM.
%   Klassen: 1 See/Wasser, 2 flaches Land/Strand, 3 Vegetation/Wald, 4 Bebauung
%   (0 = unbekannt wird erst beim Mosaik fuer fehlende Kacheln vergeben).
%
%   Vorgehen:
%   1) Bodenschaetzung per morphologischer Oeffnung (min- dann max-Filter,
%      Fenster cls.ground_window_m) -> genaehertes nDOM = DOM - Boden.
%   2) lokale Rauhigkeit = Std-Abw. des nDOM im Fenster cls.rough_window_px.
%   3) Wasser: DOM < water_h_max UND glatt UND kein Objekt.
%      Objekt: nDOM > object_min_h; rau -> Wald, glatt -> Gebaeude.
%   Heuristik; mit DGM1 (nDOM = DOM - DGM) waere die Trennung sauberer.
    w  = cls.ground_window_m;
    Zd = double(Z);
    ground = movmax(movmax(movmin(movmin(Zd, w, 1), w, 2), w, 1), w, 2);
    nd = Zd - ground;

    k  = ones(cls.rough_window_px);
    nk = conv2(ones(size(Zd)), k, 'same');
    m1 = conv2(nd, k, 'same') ./ nk;
    m2 = conv2(nd.^2, k, 'same') ./ nk;
    rough = sqrt(max(m2 - m1.^2, 0));

    % Anteil rauer Pixel in groesserer Nachbarschaft: Baumkronen haben auch glatte
    % Einzelpixel, Daecher sind grossflaechig glatt.
    kv = ones(cls.veg_frac_window_px);
    roughFrac = conv2(double(rough >= cls.veg_rough_min_m), kv, 'same') ./ conv2(ones(size(Zd)), kv, 'same');

    C = uint8(2 * ones(size(Zd)));
    obj   = nd > cls.object_min_h_m;
    woods = obj & roughFrac >= cls.veg_frac_min;
    urban = obj & ~woods;
    water = Zd < cls.water_h_max_m & rough < cls.water_rough_max_m & ~obj;
    C(woods) = 3;
    C(urban) = 4;
    C(water) = 1;
end
