function [C, usedDgm] = classifySurface(Z, cls, G)
%CLASSIFYSURFACE  Oberflaechenklassen aus DOM (1 m), optional mit DGM (1 m).
%   C = classifySurface(Z, cls)       nur DOM (Heuristik)
%   C = classifySurface(Z, cls, G)    mit DGM: nDOM = DOM - DGM (Objekthoehe)
%   Klassen: 1 See/Wasser, 2 flaches Land/Strand, 3 Vegetation/Wald, 4 Bebauung
%   (0 = unbekannt wird erst beim Mosaik fuer fehlende Kacheln vergeben).
%
%   Vorgehen:
%   1) Objekthoehe nDOM:
%        mit DGM : nDOM = DOM - DGM (Pixel mit DGM = NaN -> Heuristik unten)
%        ohne DGM: Boden per morphologischer Oeffnung (min-, dann max-Filter,
%                  Fenster cls.ground_window_m) -> nDOM = DOM - Boden
%   2) Objekt: nDOM > object_min_h.
%      Gebaeude vs. Vegetation ueber Ebenheit: Dachflaechen sind (bis auf Kanten/First)
%      planar, Baumkronen ueberall gekruemmt. Im Objektinneren (um edge_px erodiert)
%      wird |Laplace(DOM)| < roof_curv_max_m als "planar" gezaehlt; ist der Anteil
%      planarer Pixel im Fenster roof_window_px >= roof_frac_min -> Gebaeude
%      (Maske anschliessend um edge_px zurueckgewachsen), sonst Wald/Vegetation.
%   3) Wasser: DOM < water_h_max UND glatt (Std-Abw. im Fenster rough_window_px)
%      UND kein Objekt.
    Zd = double(Z);
    usedDgm = nargin >= 3 && ~isempty(G);
    if usedDgm
        nd = Zd - double(G);
        miss = isnan(nd);
        if any(miss(:))                                  % Luecken im DGM -> Heuristik
            ndH = Zd - openingGround(Zd, cls.ground_window_m);
            nd(miss) = ndH(miss);
        end
        nd = max(nd, 0);                                 % DOM < DGM (Rauschen) -> 0
    else
        nd = Zd - openingGround(Zd, cls.ground_window_m);
    end

    k  = ones(cls.rough_window_px);
    nk = conv2(ones(size(Zd)), k, 'same');
    m1 = conv2(nd, k, 'same') ./ nk;
    m2 = conv2(nd.^2, k, 'same') ./ nk;
    rough = sqrt(max(m2 - m1.^2, 0));

    C = uint8(2 * ones(size(Zd)));
    obj = nd > cls.object_min_h_m;

    e = 2 * cls.edge_px + 1;
    core = movmin(movmin(double(obj), e, 1), e, 2) > 0.5;          % Erosion (ohne IPT)
    lap = conv2(Zd, [0 1 0; 1 -4 1; 0 1 0], 'same');
    planar = abs(lap) < cls.roof_curv_max_m & core;
    kw = ones(cls.roof_window_px);
    num = conv2(double(planar), kw, 'same');
    den = conv2(double(core), kw, 'same');
    pf = zeros(size(Zd));
    okd = den > 0;
    pf(okd) = num(okd) ./ den(okd);
    seed = core & pf >= cls.roof_frac_min;
    urban = movmax(movmax(double(seed), e, 1), e, 2) > 0.5 & obj;  % Dilatation
    woods = obj & ~urban;
    water = Zd < cls.water_h_max_m & rough < cls.water_rough_max_m & ~obj;
    C(woods) = 3;
    C(urban) = 4;
    C(water) = 1;
end

function ground = openingGround(Zd, w)
    ground = movmax(movmax(movmin(movmin(Zd, w, 1), w, 2), w, 1), w, 2);
end
