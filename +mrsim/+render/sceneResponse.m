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
%   6) optionale Punktziele (scene.targets_data, Klasse 5), s. u.
%
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

    % --- Diskrete Punktziele (Tonnen, Baken aus ENC/OSM) ----------------------------
    %   q_t = Pt G^2 lambda^2 sigma_t g_el^2 / ((4pi)^3 r^4 L) * G_pc / (k T0 B F)
    %   in die naechste Feinzelle; sichtbar, wenn der Elevationswinkel zum Ziel den
    %   bisherigen Horizont auf dem Strahl uebersteigt. Klasse 5 = Punktziel.
    cls = g.cls;
    nT = 0;
    if isfield(scene, 'targets_data') && ~isempty(scene.targets_data.E)
        tg = scene.targets_data;
        dE = tg.E - pose.E; dN = tg.N - pose.N;
        rt = hypot(dE, dN);
        thT = atan2d(dE, dN) + pose.gamma;                     % geogr. Azimut
        Na = size(q, 1); Nr = size(q, 2);
        ii = mod(round(mod(thT - g.theta(1), 360) / g.dtheta), Na) + 1;
        jj = round(rt / g.dr + 0.5);
        Re = 6371000;
        for t = find(rt(:).' >= radar.min_range_m & jj(:).' <= Nr & jj(:).' >= 1)
            ht = tg.h(t) - scene.water_level_m - rt(t)^2 / (2 * scene.earth_k * Re);
            eT = atan2(ht - hr, rt(t));
            if jj(t) > 1 && eT < max(elev(ii(t), 1:jj(t)-1)), continue; end   % abgeschattet
            gT = exp(-4*log(2) * (rad2deg(eT) / radar.el_beamwidth_deg)^2);
            qT = radar.peak_power_w * G^2 * lambda^2 * tg.rcs(t) * gT^2 / ((4*pi)^3 * rt(t)^4 * L) ...
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
