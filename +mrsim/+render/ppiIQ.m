function out = ppiIQ(reg, pose, radar, sc, scene, lut)
%PPIIQ  Referenz-Backend auf IQ-Ebene (Radar Toolbox), angelehnt an das MathWorks-
%   Beispiel "Simulate Maritime Radar PPI". Sehr rechenintensiv - nur fuer einzelne
%   Validierungsframes gedacht (radar.iq.max_pulses begrenzt die Pulszahl).
%
%   Szene : radarScenario (kartesisch, flach), Radar im Ursprung (x = Ost, y = Nord).
%   Umwelt: EIN landSurface mit DOM-Terrain (See ~0 m) + ReflectivityMap (Klassen 1..4)
%           + surfaceReflectivityCustom aus derselben sigma0-LUT wie ppiFast.
%           Muster: MathWorks "Simulated Land Scenes for SAR Image Formation";
%           Terrain-Orientierung flipud(Z).' wie in "Simulating Site-Specific
%           Bistatic Land Clutter". Erdkruemmung per Hoehenkorrektur (wie ppiFast).
%   Radar : radarTransceiver, MechanicalScanMode "Circular" (24 U/min),
%           Antenne = phased.CustomAntennaElement mit Gauss-Diagramm 4.9 x 20 deg,
%           Antennengewinn (2x, Hin- und Rueckweg) im Sendeverstaerker abgebildet.
%   Clutter: clutterGenerator(UseBeam, Resolution = res * clutter_resolution_factor).
%   Auswertung: phased.RangeResponse (Matched Filter) -> |.|^2 / Rauschreferenz = SNR,
%           Pulse den Spokes zugeordnet und gemittelt; Ausgabe wie ppiFast.
%   UNGETESTET in dieser Umgebung (keine MATLAB-Lizenz) - beim ersten Lauf pruefen.
    c0 = 299792458; kB = 1.380649e-23; T0 = 290;
    nS = radar.n_spokes; nB = radar.n_bins;
    iqc = radar.iq;
    Rmax = sc.range_m * radar.bin_range_factor;

    % ---------- Terrain (lokal, Kruemmungskorrektur) ----------------------
    [nr, nc] = size(reg.H);
    xc = reg.x0 + ((1:nc) - 0.5) * reg.res - pose.E;          % Zellzentren rel. Radar
    yc = reg.y0 - ((1:nr).' - 0.5) * reg.res - pose.N;        % Zeile 1 = Nord
    keepC = abs(xc) <= Rmax + reg.res;  keepR = abs(yc) <= Rmax + reg.res;
    st = max(1, round(iqc.terrain_res_m / reg.res));          % Terrain ausduennen (Rechenzeit)
    iR = find(keepR); iR = iR(1:st:end); iC = find(keepC); iC = iC(1:st:end);
    Z = double(reg.H(iR, iC)); Cm = double(reg.C(iR, iC));
    xs = xc(iC); ys = yc(iR);
    [XX, YY] = meshgrid(xs, ys);
    Re = 6371000;
    Z = Z - scene.water_level_m - (XX.^2 + YY.^2) / (2 * scene.earth_k * Re);
    Z(isnan(Z)) = 0;  Cm(Cm == 0) = 1;                         % unbekannt -> See
    terrain = flipud(Z).';                                     % Zeilen = x aufsteigend, Spalten = y aufsteigend
    reflMap = flipud(Cm).';
    bdry = [min(xs) max(xs); min(ys) max(ys)];

    tbl = lut.table(:, 2:5);                                   % Klassen 1..4
    tbl = permute(repmat(tbl, [1 1 2]), [1 3 2]);              % Q x 2 (Frequenz) x 4 (Typ)
    refl = surfaceReflectivityCustom('Reflectivity', tbl, 'GrazingAngle', lut.psi, ...
        'Frequency', radar.fc_hz * [0.9 1.1], 'Speckle', 'Rayleigh');

    % ---------- Wellenform / Hardware ---------------------------------------
    B = sc.bandwidth_hz;
    fs = 2 * B;
    prf = fs / round(fs / iqc.prf_hz);
    if sc.tx_pulse_s * B > 1.5
        wav = phased.LinearFMWaveform('SampleRate', fs, 'PulseWidth', sc.tx_pulse_s, ...
            'PRF', prf, 'SweepBandwidth', B, 'NumPulses', 1);
    else
        wav = phased.RectangularWaveform('SampleRate', fs, 'PulseWidth', 1/B, ...
            'PRF', prf, 'NumPulses', 1);
    end
    az = -180:180; el = -90:90;
    [AZ, EL] = meshgrid(az, el);
    patDb = -12 * ((AZ / radar.az_beamwidth_deg).^2 + (EL / radar.el_beamwidth_deg).^2);
    patDb(abs(AZ) > 90) = -60;                                 % Rueckseite abgeschirmt (Patch-Array)
    patDb = max(patDb, radar.sidelobe_db - 15);
    ant = phased.CustomAntennaElement('FrequencyVector', radar.fc_hz * [0.9 1.1], ...
        'AzimuthAngles', az, 'ElevationAngles', el, ...
        'MagnitudePattern', patDb, 'PhasePattern', zeros(size(patDb)));
    txr = phased.Transmitter('PeakPower', radar.peak_power_w, ...
        'Gain', 2 * radar.antenna_gain_db - radar.system_loss_db);
    rcv = phased.ReceiverPreamp('Gain', 0, 'NoiseFigure', radar.noise_figure_db, 'SampleRate', fs);
    rotRate = radar.rotation_rpm * 6;                          % deg/s
    rdr = radarTransceiver('Waveform', wav, 'Transmitter', txr, ...
        'TransmitAntenna', phased.Radiator('Sensor', ant, 'OperatingFrequency', radar.fc_hz), ...
        'ReceiveAntenna', phased.Collector('Sensor', ant, 'OperatingFrequency', radar.fc_hz), ...
        'Receiver', rcv, 'MechanicalScanMode', 'Circular', 'MechanicalScanRate', rotRate, ...
        'RangeLimits', [0 Rmax]);

    % ---------- Szenario ----------------------------------------------------
    Tstop = 360 / rotRate;
    scn = radarScenario('UpdateRate', 0, 'IsEarthCentered', false, 'StopTime', Tstop);
    landSurface(scn, 'Terrain', terrain, 'Boundary', bdry, ...
        'RadarReflectivity', refl, 'ReflectivityMap', reflMap);
    platform(scn, 'Position', [0 0 pose.h_ant], 'Sensors', rdr);
    clutterGenerator(scn, rdr, 'Resolution', sc.res_m * iqc.clutter_resolution_factor, ...
        'UseBeam', logical(iqc.use_beam), 'RangeLimit', Rmax);

    mf = getMatchedFilter(wav);
    rr = phased.RangeResponse('RangeMethod', 'Matched filter', 'PropagationSpeed', c0, 'SampleRate', fs);
    Pn = kB * T0 * fs * 10^(radar.noise_figure_db / 10) * sum(abs(mf).^2);   % Rauschleistung nach MF

    % ---------- Pulsschleife -------------------------------------------------
    binC = ((1:nB) - 0.5) * sc.bin_m;
    acc = zeros(nS, nB); cnt = zeros(nS, 1);
    nMax = round(Tstop * prf);
    if iqc.max_pulses > 0, nMax = min(nMax, iqc.max_pulses); end
    p = 0; tic0 = tic;
    while advance(scn) && p < nMax
        p = p + 1;
        t = scn.SimulationTime;
        sig = receive(scn);
        x = sig{1};
        [resp, rg] = rr(x(:, 1), mf);
        pw = interp1(rg, abs(resp).^2, binC, 'linear', 0) / Pn;
        azScan = mod(rotRate * t, 360);                        % mech. Azimut, math. positiv ab x (Ost)
        brgTrue = mod(90 - azScan + pose.gamma, 360);          % -> geogr. Azimut (Uhrzeigersinn ab Nord)
        k = mod(round(mod(brgTrue - pose.hdg0, 360) / (360/nS)), nS) + 1;
        acc(k, :) = acc(k, :) + pw(:).'; cnt(k) = cnt(k) + 1;
        if p == 1 || mod(p, 100) == 0
            fprintf('    IQ Puls %d/%d (%.1f s, ~%.0f s gesamt)\n', p, nMax, toc(tic0), toc(tic0) / p * nMax);
        end
    end

    % ---------- leere Spokes zirkulaer interpolieren -------------------------
    have = find(cnt > 0);
    P = nan(nS, nB);
    P(have, :) = acc(have, :) ./ cnt(have);
    if numel(have) >= 2 && numel(have) < nS
        xi = [have - nS; have; have + nS];
        P = interp1(xi, [P(have, :); P(have, :); P(have, :)], (1:nS).', 'nearest');
    end
    P(isnan(P)) = 0;
    out.snr_db = single(10 * log10(max(P, 1e-3)));            % P enthaelt Empfaengerrauschen bereits
    out.land_frac = [];
    out.vis_frac = [];
    out.bin_m = sc.bin_m;
    out.iq_pulses = p;
end
