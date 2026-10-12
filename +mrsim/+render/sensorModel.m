function out = sensorModel(resp, radar, sc, scene)
%SENSORMODEL  Billiger, parametrierter Sensorteil: Szenenantwort -> SNR [dB] je Spoke/Bin.
%
%   b(theta,r) = (h_az (x) h_r) * [ sqrt(g_c) * amp0 * exp(1i*phi) ]   (Faltung, zirkulaer in theta)
%   P          = blockMean(|b|^2)  auf n_spokes x n_bins
%   SNR        = P + n,   n ~ Gamma(N_p, 1/N_p)  (Rauschleistung gemittelt ueber N_p Pulse/Spoke)
%
%   Parameter (alle in den JSON-Konfigurationen, Default in Klammern):
%     scene.reflectivity.class_offset_db  [See flach Wald Bebauung Punktziel] dB-Offset ([0 0 0 0 0])
%     radar.az_beamwidth_deg              Einweg-HPBW; Zweiwege-Leistungs-FWHM = HPBW/sqrt(2)
%     radar.sidelobe_db, sidelobe_width_deg  breite Gauss-Komponente des Diagramms
%     radar.range_res_scale               Faktor auf c*tau_3dB/2 (1)
%     radar.azimuth_offset_deg            Montage-Offset Spoke 0 gegen Bug, im Uhrzeigersinn (0)
%     radar.speckle.enable                kohaerent (Speckle) oder inkohaerent (Erwartungswert)
%     scene.scatterers.C_db, n_exp, quay_bonus_db   Dihedral-Streuer (resp.scat, s. u.)
%     radar.short_pulse.enable, tx_pulse_s           Kurzpuls im Nahbereich (s. u.)
%   Ohne Speckle wird inkohaerent gerechnet: P = (h_az^2 (x) h_r^2) * (g_c * amp0^2).
%
%   Dihedral-Streuer (Option C, Kandidaten aus sceneResponse):
%     sigma_d = 10^(C_db/10) * a*b * cos(dAlpha)^n_exp * (Kaimauer ? 10^(quay_bonus_db/10) : 1)
%     q_d     = q1 * sigma_d   (q1 = Radargleichung je m^2 inkl. g_el^2, Pulskompression)
%   kohaerent mit eigener Zufallsphase zur Feinzelle addiert. Billig variierbar -> Kalibrierung.
%
%   Kurzpuls im Nahbereich (Option A, HYPOTHESE fuer das Quantum 2):
%     r < r_sp = c*tau_lang/2 :  P <- P * G_pc,kurz / G_pc,lang,   G_pc = max(1, tau*B)
%   (waehrend des langen Chirps ist der Empfaenger taub; den Nahbereich deckt ein kurzer Puls ab).
%   Die geaenderte Entfernungsaufloesung des kurzen Pulses ist nicht modelliert.
    ovA = resp.ovA; ovR = resp.ovR; nS = resp.nS; nB = resp.nB;

    off = getf(getf(scene, 'reflectivity', struct()), 'class_offset_db', [0 0 0 0]);
    off = off(:).'; off(end+1:5) = 0;                    % [See flach Wald Bebauung Punktziel]
    gC = [0, 10.^(off / 10)];                            % Index = Klasse + 1 (0 unbekannt -> 0)
    gcell = gC(double(resp.cls) + 1);

    azOff = getf(radar, 'azimuth_offset_deg', 0);
    sh = round(azOff / resp.dtheta);

    [ka, ka2] = azKernel(radar, resp.dtheta, size(resp.amp0, 1));
    resM = sc.res_m * getf(radar, 'range_res_scale', 1);
    [kr, kr2] = rgKernel(resM, resp.dr);

    qd = scattererPower(resp, scene);                   % [] oder Spaltenvektor je Kandidat
    if radar.speckle.enable
        a = double(resp.amp0) .* sqrt(gcell) .* exp(1i * double(resp.phase));
        if ~isempty(qd)
            a(resp.scat.idx) = a(resp.scat.idx) + sqrt(qd) .* exp(1i * double(resp.scat.phase));
        end
        if sh ~= 0, a = circshift(a, -sh, 1); end
        b = convSep(a, ka, kr);
        P = abs(b).^2;
    else
        p = double(resp.amp0).^2 .* gcell;
        if ~isempty(qd)
            p(resp.scat.idx) = p(resp.scat.idx) + qd;
        end
        if sh ~= 0, p = circshift(p, -sh, 1); end
        P = convSep(p, ka2, kr2);
    end
    P = shortPulse(P, resp, radar, sc);
    P = blockMean(P, ovA, ovR);

    nP = max(1, round(sc.pulses_per_spoke));
    if radar.speckle.enable
        noise = randg(nP, nS, nB) / nP;
    else
        noise = ones(nS, nB);
    end
    out.snr_db = single(10 * log10(P + noise));
    out.bin_m  = resp.bin_m;
end

% ---------------------------------------------------------------------------
function v = getf(s, f, d)
    if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end

function qd = scattererPower(resp, scene)
% Dihedral-Streuer (Option C): Leistung je Kandidat aus den kalibrierbaren Parametern.
    qd = [];
    if ~isfield(resp, 'scat') || isempty(resp.scat.idx), return; end
    sp = getf(scene, 'scatterers', struct());
    if ~getf(sp, 'enable', false), return; end
    C  = getf(sp, 'C_db', 8);
    n  = getf(sp, 'n_exp', 4);
    qb = getf(sp, 'quay_bonus_db', 6);
    sig = 10^(C/10) * double(resp.scat.ab) .* double(resp.scat.cosA).^n;
    sig(resp.scat.water) = sig(resp.scat.water) * 10^(qb/10);
    qd = double(resp.scat.q1) .* sig;
end

function P = shortPulse(P, resp, radar, sc)
% Kurzpuls im Nahbereich (Option A): Energie unterhalb r_sp = c*tau_lang/2 reduzieren.
    sp = getf(radar, 'short_pulse', struct());
    if ~getf(sp, 'enable', false), return; end
    tauS = getf(sc, 'short_pulse_s', []);
    if isempty(tauS), tauS = getf(sp, 'tx_pulse_s', 1e-6); end
    if sc.tx_pulse_s <= tauS, return; end
    rsp = 299792458 * sc.tx_pulse_s / 2;
    fac = max(1, tauS * sc.bandwidth_hz) / sc.pc_gain;
    near = resp.r < rsp;
    P(:, near) = P(:, near) * fac;
end

function [ka, ka2] = azKernel(radar, dth, Na)
% Zweiwege-Leistungsdiagramm Gauss mit FWHM theta_az/sqrt(2); Amplitude = Wurzel
% -> Amplituden-FWHM = theta_az. Nebenkeulen: breite Gausskomponente (Pegel sidelobe_db).
    fw  = radar.az_beamwidth_deg;
    sw  = radar.sidelobe_width_deg;
    sl  = 10^(radar.sidelobe_db / 10);
    K   = min(floor((Na-1)/2), ceil(1.5 * max(fw, sw) / dth));
    x   = (-K:K).' * dth;
    ka2 = exp(-4*log(2) * (x / (fw/sqrt(2))).^2) + sl * exp(-4*log(2) * (x / sw).^2);
    ka  = sqrt(ka2);
end

function [kr, kr2] = rgKernel(resM, dr)
% Komprimierter Puls: Leistungsantwort Gauss mit FWHM = c*tau_3dB/2.
    K   = max(1, ceil(2 * resM / dr));
    x   = (-K:K) * dr;
    kr2 = exp(-4*log(2) * (x / resM).^2);
    kr  = sqrt(kr2);
end

function B = convSep(A, ka, kr)
% Entfernung: linear ('same', kurzer Kern); Azimut: zirkulaer ueber 360 deg per FFT
% (Kern mit Nebenkeulen kann mehrere hundert Abtastwerte breit sein).
    B = conv2(1, kr, A, 'same');
    Na = size(B, 1);
    K = (numel(ka) - 1) / 2;
    h = zeros(Na, 1);
    h(1:K+1) = ka(K+1:end);                 % Offsets 0..K
    h(end-K+1:end) = ka(1:K);               % Offsets -K..-1
    B = ifft(fft(B, [], 1) .* fft(h), [], 1);
    if isreal(A), B = real(B); end
end

function B = blockMean(A, fa, fr)
    [m, n] = size(A);
    B = reshape(mean(mean(reshape(A, fa, m/fa, fr, n/fr), 1), 3), m/fa, n/fr);
end
