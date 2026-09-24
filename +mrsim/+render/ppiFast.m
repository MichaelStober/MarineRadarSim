function out = ppiFast(reg, pose, radar, sc, scene, lut)
%PPIFAST  Schnelles PPI per Ray-Casting ueber das DOM (primaeres Backend).
%   out.snr_db     n_spokes x n_bins  SNR [dB] je Spoke/Bin (Rauschen = 0 dB)
%   out.land_frac  n_spokes x n_bins  Anteil Landklassen (Ground Truth, ohne Sichtbarkeit)
%   out.vis_frac   n_spokes x n_bins  Anteil sichtbarer Feinzellen
%
%   Ablauf (IMPLEMENTIERUNGSPLAN.md, AP4/AP5):
%   1) Abtastung h'(theta,r) inkl. Erdkruemmung            (samplePolar)
%   2) Sichtbarkeit: eps(r) >= max eps(r'<r) entlang Strahl (Radarschatten)
%   3) lokaler Grazingwinkel psi = atan(dh/dr) - eps       (Duenen-/Gebaeudefronten)
%   4) sigma0(psi, Klasse) aus LUT, sigma = sigma0 * r*dtheta*dr
%   5) Radargleichung P = Pt G^2 lambda^2 sigma g_el^2 / ((4 pi)^3 r^4 L)
%      SNR = P * G_pc / (k T0 B F)
%   6) Jeder Reflexionspunkt wird als Gauss-Fleck in Azimut (Zweiwege-Antennen-
%      diagramm, 4.9 deg) und Entfernung (komprimierter Puls) verteilt; benachbarte
%      Punkte ueberlagern sich. Kohaerent (Zufallsphase je Punkt) -> Speckle entsteht
%      physikalisch aus der Interferenz; sonst inkohaerent (reine Leistungssumme).
%   7) Mittelung auf Spokes/Bins, Rauschen gemittelt ueber Pulse je Spoke.
    kB = 1.380649e-23; T0 = 290; c0 = 299792458;
    ovA = radar.oversampling.azimuth;  ovR = radar.oversampling.range;
    nS = radar.n_spokes; nB = radar.n_bins;

    g = mrsim.render.samplePolar(reg, pose, radar, sc, scene);
    r = g.r;                                                % 1 x Nr
    hr = pose.h_ant;

    % --- 2) Sichtbarkeit / Abschattung -------------------------------------
    elev = atan2(double(g.h) - hr, repmat(r, size(g.h, 1), 1));     % [rad]
    elev(isnan(elev)) = -Inf;                               % keine Daten: kein Echo, keine Abschattung
    prevMax = [-Inf(size(elev, 1), 1), cummax(elev(:, 1:end-1), 2)];
    vis = elev >= prevMax - 1e-9;

    % --- 3) lokaler Grazingwinkel -------------------------------------------
    hd = double(g.h); hd(isnan(hd)) = 0;
    slope = zeros(size(hd));
    slope(:, 2:end-1) = (hd(:, 3:end) - hd(:, 1:end-2)) / (2 * g.dr);
    slope(:, 1) = (hd(:, 2) - hd(:, 1)) / g.dr;
    slope(:, end) = (hd(:, end) - hd(:, end-1)) / g.dr;
    elevDeg = rad2deg(elev);
    psi = atand(slope) - elevDeg;
    isSea = g.cls == 1;
    psi(isSea) = -elevDeg(isSea);                           % See: mittlere Oberflaeche flach

    % --- 4) sigma0 und Flaechen-RCS ----------------------------------------
    s0 = mrsim.refl.lookupSigma0(lut, psi, g.cls);
    s0(~vis) = 0;
    s0(:, r < radar.min_range_m) = 0;
    area = r * deg2rad(g.dtheta) * g.dr;                    % 1 x Nr  [m^2]

    % --- 5) Radargleichung -> SNR je Feinzelle ------------------------------
    lambda = c0 / radar.fc_hz;
    G = 10^(radar.antenna_gain_db / 10);
    L = 10^(radar.system_loss_db / 10);
    gel = exp(-4*log(2) * (elevDeg / radar.el_beamwidth_deg).^2);   % Elevationsdiagramm (Leistung, einfach)
    gel(~isfinite(gel)) = 0;
    Pr = radar.peak_power_w * G^2 * lambda^2 .* s0 .* area .* gel.^2 ./ ((4*pi)^3 * r.^4 * L);
    Pn = kB * T0 * sc.bandwidth_hz * 10^(radar.noise_figure_db / 10);
    q = Pr * sc.pc_gain / Pn;                               % SNR-Beitrag (linear)

    % --- 6) Gauss-PSF (Azimut x Entfernung) --------------------------------
    [kaz, kaz2] = azKernel(radar, g.dtheta, size(q, 1));
    [krg, krg2] = rgKernel(sc.res_m, g.dr);
    if radar.speckle.enable
        tex = ones(size(q));
        nu = radar.speckle.sea_texture_shape;
        if nu > 0
            nSea = nnz(isSea);
            tex(isSea) = randg(nu, nSea, 1) / nu;           % K-Verteilung: Gamma-Textur x Rayleigh
        end
        a = sqrt(q .* tex) .* exp(1i * 2*pi * rand(size(q)));
        b = convSep(a, kaz, krg);
        P = abs(b).^2;
    else
        P = convSep(q, kaz2, krg2);
    end

    % --- 7) Spokes/Bins, Rauschen -------------------------------------------
    P = blockMean(P, ovA, ovR);
    nP = max(1, round(sc.pulses_per_spoke));
    if radar.speckle.enable
        noise = randg(nP, nS, nB) / nP;                     % |n|^2 gemittelt ueber nP Pulse
    else
        noise = ones(nS, nB);
    end
    out.snr_db    = single(10 * log10(P + noise));
    out.land_frac = single(blockMean(double(g.cls >= 2), ovA, ovR));
    out.vis_frac  = single(blockMean(double(vis & isfinite(elev)), ovA, ovR));
    out.bin_m     = sc.bin_m;
end

% ---------------------------------------------------------------------------
function [ka, ka2] = azKernel(radar, dth, Na)
% Zweiwege-Leistungsdiagramm Gauss mit FWHM theta_az/sqrt(2); Amplitude = Wurzel
% -> Amplituden-FWHM = theta_az. Nebenkeulen: breite Gausskomponente (Pegel sidelobe_db).
    fw  = radar.az_beamwidth_deg;
    sw  = radar.sidelobe_width_deg;
    sl  = 10^(radar.sidelobe_db / 10);
    K   = min(floor((Na-1)/2), ceil(1.5 * max(fw, sw) / dth));
    x   = (-K:K).' * dth;
    ka2 = exp(-4*log(2) * (x / (fw/sqrt(2))).^2) + sl * exp(-4*log(2) * (x / sw).^2);  % Leistung
    ka  = sqrt(ka2);                                                                    % Amplitude
end

function [kr, kr2] = rgKernel(resM, dr)
% Komprimierter Puls: Leistungsantwort Gauss mit FWHM = c*tau_3dB/2.
    K   = max(1, ceil(2 * resM / dr));
    x   = (-K:K) * dr;
    kr2 = exp(-4*log(2) * (x / resM).^2);
    kr  = sqrt(kr2);
end

function B = convSep(A, ka, kr)
% Entfernung: linear ('same'); Azimut: zirkulaer ueber 360 deg.
    B = conv2(1, kr, A, 'same');
    K = (numel(ka) - 1) / 2;
    Bp = [B(end-K+1:end, :); B; B(1:K, :)];
    B = conv2(ka(:), 1, Bp, 'valid');
end

function B = blockMean(A, fa, fr)
    [m, n] = size(A);
    B = reshape(mean(mean(reshape(A, fa, m/fa, fr, n/fr), 1), 3), m/fa, n/fr);
end
