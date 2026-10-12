function resp = sceneResponse(reg, pose, radar, sc, scene, lut)
%SCENERESPONSE  Geometrieabhaengiger (teurer) Teil der Simulation, OHNE Sensormodell.
%   Liefert je Feinzelle (Strahl i, Entfernung j) die komplexe Streuamplitude vor
%   Antennen-/Pulsfaltung, aufgeteilt in Betrag, Phase und Klasse:
%
%       a_ij = amp0_ij * exp(1i*phi_ij),   amp0_ij = sqrt( q_ij * tau_ij )
%
%   q_ij   SNR-Beitrag der Zelle (Radargleichung, s. u.), linear
%   tau_ij Textur (See: Gamma(nu,1/nu), sonst 1)  -> K-verteiltes Seeclutter
%   phi_ij Zufallsphase U(0,2pi)                  -> Speckle durch Interferenz
%
%   Alles, was danach kommt (Klassen-Offsets, Antennendiagramm, Entfernungsantwort,
%   Rauschen, Empfaengerkette, Azimut-Offset), ist in mrsim.render.sensorModel und
%   damit billig variierbar -> Grundlage fuer die Kalibrierung (Systemidentifikation).
%
%   Geometrie/Radiometrie (IMPLEMENTIERUNGSPLAN.md, AP4/AP5):
%   1) h'(theta,r) inkl. Erdkruemmung                         (samplePolar)
%   2) Sichtbarkeit: eps(r) >= max_{r'<r} eps(r')             (Radarschatten)
%   3) lokaler Grazingwinkel psi = atan(dh/dr) - eps (See: psi = -eps)
%   4) sigma0(psi, Klasse) aus LUT; Flaeche A = r*dtheta*dr
%   5) q = Pt G^2 lambda^2 sigma0 A g_el^2 / ((4pi)^3 r^4 L) * G_pc / (k T0 B F)
%
%   6) Dihedral-Kandidaten an Wandkanten (scene.scatterers, Option C) -> resp.scat
%      (nur Geometrie; Staerke im Sensormodell, kalibrierbar)
%   7) optionale Punktziele (scene.targets_data, Klasse 5) mit Swerling-1-Fluktuation und
%      Zweiwege-Mehrweg (scene.targets.fluctuation / .multipath, Option B), s. u.
%
%   resp.scat  struct idx, q1, ab, cosA, water, phase (Spalten je Kandidat)
%   resp.amp0 (single Na x Nr), resp.phase (single), resp.cls (uint8, 0..5),
%   resp.vis (logical), resp.dtheta, resp.dr, resp.r, plus Kopien von nS/nB/ov.
    kB = 1.380649e-23; T0 = 290; c0 = 299792458;

    g = mrsim.render.samplePolar(reg, pose, radar, sc, scene);
    r = g.r;
    hr = pose.h_ant;

    % --- Sichtbarkeit -------------------------------------------------------
    elev = atan2(double(g.h) - hr, repmat(r, size(g.h, 1), 1));
    elev(isnan(elev)) = -Inf;
    prevMax = [-Inf(size(elev, 1), 1), cummax(elev(:, 1:end-1), 2)];
    vis = elev >= prevMax - 1e-9;
    clear prevMax

    % --- lokaler Grazingwinkel -------------------------------------------------
    hd = double(g.h); hd(isnan(hd)) = 0;
    slope = zeros(size(hd));
    slope(:, 2:end-1) = (hd(:, 3:end) - hd(:, 1:end-2)) / (2 * g.dr);
    slope(:, 1) = (hd(:, 2) - hd(:, 1)) / g.dr;
    slope(:, end) = (hd(:, end) - hd(:, end-1)) / g.dr;
    clear hd
    elevDeg = rad2deg(elev);
    psi = atand(slope) - elevDeg;
    clear slope
    isSea = g.cls == 1;
    psi(isSea) = -elevDeg(isSea);

    % --- sigma0, Radargleichung --------------------------------------------------
    s0 = mrsim.refl.lookupSigma0(lut, psi, g.cls);
    clear psi
    s0(~vis) = 0;
    s0(:, r < radar.min_range_m) = 0;
    area = r * deg2rad(g.dtheta) * g.dr;
    lambda = c0 / radar.fc_hz;
    G = 10^(radar.antenna_gain_db / 10);
    L = 10^(radar.system_loss_db / 10);
    gel = exp(-4*log(2) * (elevDeg / radar.el_beamwidth_deg).^2);
    gel(~isfinite(gel)) = 0;
    clear elevDeg
    Pn = kB * T0 * sc.bandwidth_hz * 10^(radar.noise_figure_db / 10);
    q = radar.peak_power_w * G^2 * lambda^2 .* s0 .* area .* gel.^2 ./ ((4*pi)^3 * r.^4 * L) ...
        * sc.pc_gain / Pn;
    clear s0 gel

    % --- Dihedral-Streuer (Option C): Kandidaten aus Wandkanten im DSM -------------------
    %   Nur Geometrie hier; Staerke (C_db, n_exp, quay_bonus_db) im Sensormodell.
    cls = g.cls;
    resp.scat = findScatterers(g, vis, elev, gel0(elev, radar), radar, sc, scene, G, lambda, L, Pn);

    % --- Diskrete Punktziele (Tonnen, Baken aus ENC/OSM; Option B) ---------------------
    %   q_t = Pt G^2 lambda^2 sigma_t F^4 g_el^2 / ((4pi)^3 r^4 L) * G_pc / (k T0 B F)
    %   in die naechste Feinzelle; sichtbar, wenn der Elevationswinkel zum Ziel den
    %   bisherigen Horizont auf dem Strahl uebersteigt. Klasse 5 = Punktziel.
    %   sigma_t: mittlerer RCS je Ziel (loadTargets), optional Swerling-1-Fluktuation
    %   je Frame: sigma ~ Exp(mittel). F^4: Zweiwege-Mehrweg ueber die See (multipathFactor).
    nT = 0;
    if isfield(scene, 'targets_data') && ~isempty(scene.targets_data.E)
        tg = scene.targets_data;
        tcfg = getf(scene, 'targets', struct());
        dE = tg.E - pose.E; dN = tg.N - pose.N;
        rt = hypot(dE, dN);
        thT = atan2d(dE, dN) + pose.gamma;                     % geogr. Azimut
        Na = size(q, 1); Nr = size(q, 2);
        ii = mod(round(mod(thT - g.theta(1), 360) / g.dtheta), Na) + 1;
        jj = round(rt / g.dr + 0.5);
        Re = 6371000;
        fluct = strcmpi(getf(tcfg, 'fluctuation', 'none'), 'swerling1');
        mp = getf(tcfg, 'multipath', struct());
        for t = find(rt(:).' >= radar.min_range_m & jj(:).' <= Nr & jj(:).' >= 1)
            ht = tg.h(t) - scene.water_level_m - rt(t)^2 / (2 * scene.earth_k * Re);
            eT = atan2(ht - hr, rt(t));
            if jj(t) > 1 && eT < max(elev(ii(t), 1:jj(t)-1)), continue; end   % abgeschattet
            gT = exp(-4*log(2) * (rad2deg(eT) / radar.el_beamwidth_deg)^2);
            sig = tg.rcs(t);
            if fluct, sig = sig * (-log(rand())); end          % Exp-verteilt, Mittel = sig
            F4 = 1;
            if getf(mp, 'enable', false)
                F4 = mrsim.render.multipathFactor(hr, tg.h(t) - scene.water_level_m, rt(t), lambda, ...
                        getf(mp, 'reflection_coeff', -1), ...
                        getf(mp, 'use_roughness', true) * seaStateSigmaH(getf(scene.reflectivity, 'sea_state', 3)));
            end
            qT = radar.peak_power_w * G^2 * lambda^2 * sig * F4 * gT^2 / ((4*pi)^3 * rt(t)^4 * L) ...
                 * sc.pc_gain / Pn;
            q(ii(t), jj(t)) = q(ii(t), jj(t)) + qT;
            cls(ii(t), jj(t)) = 5;
            nT = nT + 1;
        end
    end
    isSea = isSea & cls ~= 5;

    % --- Textur + Phase ---------------------------------------------------------
    tex = ones(size(q));
    nu = radar.speckle.sea_texture_shape;
    if radar.speckle.enable && nu > 0
        tex(isSea) = randg(nu, nnz(isSea), 1) / nu;
    end
    resp.amp0  = single(sqrt(q .* tex));
    resp.phase = single(2*pi * rand(size(q)));
    resp.cls   = cls;
    resp.n_targets = nT;
    resp.vis   = vis & isfinite(elev);
    resp.dtheta = g.dtheta;  resp.dr = g.dr;  resp.r = g.r;
    resp.nS = radar.n_spokes; resp.nB = radar.n_bins;
    resp.ovA = radar.oversampling.azimuth; resp.ovR = radar.oversampling.range;
    resp.bin_m = sc.bin_m;
end

% ---------------------------------------------------------------------------
function v = getf(s, f, d)
    if isstruct(s) && isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end

function gel = gel0(elev, radar)
% Elevationsdiagramm (Einweg-Leistung, Gauss) wie oben, fuer die Streuerkandidaten.
    gel = exp(-4*log(2) * (rad2deg(elev) / radar.el_beamwidth_deg).^2);
    gel(~isfinite(gel)) = 0;
end

function sh = seaStateSigmaH(ss)
% RMS-Hoehe der Seeoberflaeche [m] aus dem Seegang (WMO-Code, signifikante Wellenhoehe
% H_1/3 = Klassenmitte, sigma_h = H_1/3 / 4). Fuer den Rauigkeitsfaktor im Mehrwegmodell.
    H = [0, 0.05, 0.3, 0.875, 1.875, 3.25, 5.0, 7.5, 11.5, 14];
    ss = min(max(round(ss), 0), numel(H) - 1);
    sh = H(ss + 1) / 4;
end

function sc_ = findScatterers(g, vis, elev, gel, radar, sc, scene, G, lambda, L, Pn)
%FINDSCATTERERS  Dihedral-Kandidaten (Wand + Boden/Wasser davor) auf dem feinen Polargitter.
%   Kandidat in Feinzelle (i,j), wenn
%     - dh_j = h(i,j) - h(i,j-1) > 0 (Anstieg zum Radar hin gesehen) und
%     - der Anstieg ueber ein Fenster von w Zellen (w = ceil(dem_level/dr)+1, fuer die
%       interpolationsbedingte Rampe) >= min_wall_m ist,
%     - Zelle j und der Fuss (tiefste Zelle im Fenster) sichtbar sind.
%   Wandhoehenanteil a = min(dh_j, max_wall_m), Breite b = r * dtheta (Zellbreite),
%   Orientierung cos(dAlpha) = max(g_r,0)/sqrt(g_r^2 + g_theta^2) aus dem Hoehengradienten
%   (g_r = dh/dr, g_theta = dh/(r dtheta)), Kaimauer = Fuss ist See (Klasse 1).
%   q1 = Pt G^2 lambda^2 g_el^2 / ((4pi)^3 r^4 L) * G_pc / Pn  (je m^2 RCS).
    sp = getf(scene, 'scatterers', struct());
    sc_ = struct('idx', zeros(0, 1), 'q1', zeros(0, 1, 'single'), 'ab', zeros(0, 1, 'single'), ...
                 'cosA', zeros(0, 1, 'single'), 'water', false(0, 1), 'phase', zeros(0, 1, 'single'));
    if ~getf(sp, 'enable', false), return; end
    minW = getf(sp, 'min_wall_m', 2.5);
    maxW = getf(sp, 'max_wall_m', 30);
    h = double(g.h); h(isnan(h)) = 0;
    [Na, Nr] = size(h);
    w = max(1, ceil(sc.dem_level_m / g.dr) + 1);
    dh = [zeros(Na, 1), diff(h, 1, 2)];
    hmin = h; jmin = repmat(1:Nr, Na, 1);
    for k = 1:w
        hk = [inf(Na, k), h(:, 1:end-k)];
        better = hk < hmin;
        hmin(better) = hk(better);
        jk = repmat((1:Nr) - k, Na, 1);
        jmin(better) = jk(better);
    end
    jmin = max(jmin, 1);
    footIdx = sub2ind([Na Nr], repmat((1:Na).', 1, Nr), jmin);
    cand = dh > 0 & (h - hmin) >= minW & vis & vis(footIdx);
    cand(:, g.r < radar.min_range_m) = false;
    idx = find(cand);
    if isempty(idx), return; end
    [ii, jj] = ind2sub([Na Nr], idx);
    r = g.r(jj); r = r(:);
    gr = zeros(size(idx));
    jp = min(jj + 1, Nr); jm = max(jj - 1, 1);
    gr(:) = (h(sub2ind([Na Nr], ii, jp)) - h(sub2ind([Na Nr], ii, jm))) ./ ((jp - jm) * g.dr);
    ip = mod(ii, Na) + 1; im = mod(ii - 2, Na) + 1;
    dthR = deg2rad(g.dtheta);
    gt = (h(sub2ind([Na Nr], ip, jj)) - h(sub2ind([Na Nr], im, jj))) ./ (2 * r * dthR);
    cosA = max(gr, 0) ./ max(sqrt(gr.^2 + gt.^2), eps);
    a = min(dh(idx), maxW);
    b = r * dthR;
    q1 = radar.peak_power_w * G^2 * lambda^2 * gel(idx).^2 ./ ((4*pi)^3 * r.^4 * L) * sc.pc_gain / Pn;
    sc_.idx = idx;
    sc_.q1 = single(q1);
    sc_.ab = single(a .* b);
    sc_.cosA = single(cosA);
    sc_.water = g.cls(footIdx(idx)) == 1;
    sc_.phase = single(2*pi * rand(numel(idx), 1));
end
