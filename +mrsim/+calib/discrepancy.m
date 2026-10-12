function D = discrepancy(realPix, simPix, valid, landMask, binM, mcfg, pixMax)
%DISCREPANCY  Abweichung zwischen echtem und simuliertem Polarbild (Kalibrierziel).
%
%   D = w_dist * D_dist / N_dist + w_edge * D_edge / N_edge
%   N_dist, N_edge (mcfg.norm_dist/norm_edge, Default 1): Werte der Terme bei den
%   Startparametern theta_0 (gesetzt in mrsim.calib.calibrate). Beide Terme starten
%   damit bei 1; die Gewichte w sind relative Wichtigkeiten statt Einheitenkorrekturen.
%
%   D_dist = sum_{c,b} w_cb * W1(F^real_cb, F^sim_cb) / (pixMax * sum_{c,b} w_cb)
%     c in {See, Land} (Klassenmaske aus der Simulationsgeometrie),
%     b = Entfernungsband (mcfg.range_bands gleich breite Baender),
%     F = empirische Verteilungsfunktion der Pixelwerte 0..pixMax,
%     W1 = 1-Wasserstein-Distanz; fuer diskrete Werte exakt sum_v |F_r(v) - F_s(v)|,
%     w_cb = 1 (mcfg.cell_weighting = 'equal', Default) oder Pixelzahl ('pixels').
%     'equal', weil sonst die (ueberwiegend leeren) Seezellen das Mass dominieren und
%     die informativen Land-/Kuestenzellen kaum Gewicht haben.
%     Nur Zellen mit >= mcfg.min_pixels Pixeln.
%     Nur gueltige Spokes (valid) - fehlende Bearings gehen nicht ein.
%   Begruendung: Speckle und Restfehler der Pose machen einen pixelweisen Vergleich
%   unbrauchbar; verglichen werden Intensitaetsverteilungen je Klasse und Entfernung.
%
%   D_edge = mean_k min(|r_k^real - r_k^sim|, cap) / cap
%     r_k = Entfernung des ersten Bins >= mcfg.edge_threshold ab mcfg.edge_min_range_m
%     auf Spoke k im GEGLAETTETEN Bild (gleitender Mittelwert ueber edge_smooth_spokes x
%     edge_smooth_bins), damit einzelne Speckle-Spitzen keine Kante vortaeuschen.
%     Nur Spokes, auf denen die Simulationsgeometrie Land enthaelt (edge_only_land_spokes).
%     Findet nur eines der beiden Bilder eine Kante, zaehlt cap; keines -> Spoke entfaellt.
%
%   Rueckgabe: D.total, D.dist, D.edge, D.cells (Tabelle je Klasse/Band), D.n_edge
    pixMax = double(pixMax);
    nB = size(realPix, 2);
    v = logical(valid(:));
    R = double(realPix(v, :)); S = double(simPix(v, :)); L = landMask(v, :);
    band = min(floor((0:nB-1) / nB * mcfg.range_bands) + 1, mcfg.range_bands);
    B = repmat(band, size(R, 1), 1);

    num = 0; den = 0;
    cells = zeros(0, 4);                      % [Klasse Band n W1]
    for c = 0:1                               % 0 See, 1 Land
        for b = 1:mcfg.range_bands
            sel = (L == c) & (B == b);
            n = nnz(sel);
            if n < mcfg.min_pixels, continue; end
            w1 = wasserstein1(R(sel), S(sel), pixMax);
            if isfield(mcfg, 'cell_weighting') && strcmp(mcfg.cell_weighting, 'pixels'), w = n; else, w = 1; end
            num = num + w * w1; den = den + w;
            cells(end+1, :) = [c b n w1]; %#ok<AGROW>
        end
    end
    if den > 0, D.dist = num / den / pixMax; else, D.dist = NaN; end

    j0 = max(1, ceil(mcfg.edge_min_range_m / binM));
    sa = getf(mcfg, 'edge_smooth_spokes', 5); sb = getf(mcfg, 'edge_smooth_bins', 3);
    Rs = smooth2(double(realPix), sa, sb); Ss = smooth2(double(simPix), sa, sb);
    Rs = Rs(v, :); Ss = Ss(v, :);
    useK = true(size(Rs, 1), 1);
    if getf(mcfg, 'edge_only_land_spokes', true)
        useK = any(L(:, j0:end), 2);
    end
    rr = firstAbove(Rs(useK, j0:end), mcfg.edge_threshold);
    rs = firstAbove(Ss(useK, j0:end), mcfg.edge_threshold);
    cap = mcfg.edge_cap_m;
    both = ~isnan(rr) & ~isnan(rs);
    one  = xor(~isnan(rr), ~isnan(rs));
    e = [min(abs(rr(both) - rs(both)) * binM, cap); cap * ones(nnz(one), 1)];
    D.n_edge = numel(e);
    if isempty(e), D.edge = 0; else, D.edge = mean(e) / cap; end

    D.total = mcfg.w_dist * D.dist / getf(mcfg, 'norm_dist', 1) + ...
              mcfg.w_edge * D.edge / getf(mcfg, 'norm_edge', 1);
    D.cells = cells;
end

function w = wasserstein1(a, b, pixMax)
    ha = accumarray(min(max(round(a(:)), 0), pixMax) + 1, 1, [pixMax + 1, 1]);
    hb = accumarray(min(max(round(b(:)), 0), pixMax) + 1, 1, [pixMax + 1, 1]);
    Fa = cumsum(ha) / numel(a); Fb = cumsum(hb) / numel(b);
    w = sum(abs(Fa - Fb));
end

function v = getf(s, f, d)
    if isfield(s, f), v = s.(f); else, v = d; end
end

function Y = smooth2(X, na, nb)
% gleitender Mittelwert, zirkulaer in Azimut (Zeilen), linear in Entfernung
    ka = ones(na, 1) / na; kb = ones(1, nb) / nb;
    h = floor(na / 2);
    Xp = [X(end-h+1:end, :); X; X(1:h, :)];
    Y = conv2(ka, kb, Xp, 'same');
    Y = Y(h+1:end-h, :);
end

function r = firstAbove(X, thr)
    [m, k] = max(X >= thr, [], 2);
    r = double(k); r(~m) = NaN;
end
