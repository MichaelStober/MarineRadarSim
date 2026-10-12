function [offDeg, perScan] = estimateAzimuthOffset(cache, radar, scene, cfg)
%ESTIMATEAZIMUTHOFFSET  Montage-Offset der Antenne (Spoke 0 gegen Bug) per Kreuzkorrelation.
%
%   Deskriptor je Spoke (wie LodeStar, Jang et al. 2024): d(k) = mean_r log(1 + I(k,r)),
%   r >= descriptor_min_range_m, mittelwertfrei und normiert, nur gueltige Spokes.
%   rho(s) = sum_{k gueltig} d_real(k) * d_sim(k + s) / |gueltig|,  s = -S..S
%   s* = argmax rho, parabolisch verfeinert; Offset = s* * 360/n_spokes.
%   Gesamtwert = Maximum der ueber alle Scans SUMMIERTEN Korrelation (Scans mit
%   scharfem Maximum dominieren, Scans mit kuestenparalleler Geometrie und flachem
%   Maximum verfaelschen nicht - im Recovery-Test robuster als der Median der
%   Einzelwerte). Die Einzelwerte je Scan enthalten auch Heading-Fehler und stehen im Report.
    nS = radar.n_spokes;
    radar.azimuth_offset_deg = 0;
    S = round(cfg.geometry.max_offset_deg / (360 / nS));
    perScan = zeros(1, numel(cache));
    rhoSum = zeros(2*S + 1, 1);
    for k = 1:numel(cache)
        e = cache{k};
        sim = mrsim.calib.renderCached(e, radar, scene, cfg.optimizer.seed);
        j0 = max(1, ceil(cfg.geometry.descriptor_min_range_m / e.sc.bin_m));
        v = e.scan.valid;
        dr = mean(log1p(double(e.scan.pix(:, j0:end))), 2);
        ds = mean(log1p(double(sim(:, j0:end))), 2);
        dr = norm0(dr, v); ds = norm0(ds, true(nS, 1));
        rho = zeros(2*S + 1, 1);
        for s = -S:S
            dsh = circshift(ds, -s);              % dsh(k) = ds(k + s)
            rho(s + S + 1) = sum(dr(v) .* dsh(v)) / nnz(v);
        end
        rhoSum = rhoSum + rho;
        perScan(k) = peak(rho, S) * 360 / nS;
    end
    offDeg = peak(rhoSum, S) * 360 / nS;
end

function sStar = peak(rho, S)
    [~, i] = max(rho);
    sStar = i - S - 1;
    if i > 1 && i < numel(rho)                    % parabolische Verfeinerung
        y = rho(i-1:i+1);
        den = y(1) - 2*y(2) + y(3);
        if den ~= 0, sStar = sStar + 0.5 * (y(1) - y(3)) / den; end
    end
end

function d = norm0(d, v)
    mu = mean(d(v)); sd = std(d(v));
    if sd == 0, sd = 1; end
    d = (d - mu) / sd;
    d(~v) = 0;
end
