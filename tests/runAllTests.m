function runAllTests()
%RUNALLTESTS  Selbsttests ohne DOM-Daten und ohne Toolboxen (MATLAB und GNU Octave).
%   >> cd MarineRadar; addpath tests; runAllTests
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root);
    t = {@testUtmAgainstProj, @testConvergence, @testCsvReader, @testHeadingModes, ...
         @testRangeScale, @testPolarToCartOrientation, @testReceiverChain, ...
         @testFastWallAndShadow, @testFastHeadUpRotation, @testClassifyWithDgm, @testPointTarget, ...
         @testAssembleRotation, @testSpokeStats, @testDiscrepancyZero, @testProjectionPtTm06, @testLoadRegionGeneric};
    nFail = 0;
    for i = 1:numel(t)
        name = func2str(t{i});
        try
            t{i}(root);
            fprintf('  [OK]   %s\n', name);
        catch err
            nFail = nFail + 1;
            fprintf('  [FAIL] %s: %s\n', name, err.message);
        end
    end
    if nFail > 0
        error('%d von %d Tests fehlgeschlagen.', nFail, numel(t));
    end
    fprintf('Alle %d Tests bestanden.\n', numel(t));
end

% -----------------------------------------------------------------------------
function testUtmAgainstProj(~)
    % Referenz: PROJ/pyproj EPSG:4326 -> EPSG:25833
    lat = [54.2134366; 54.1817; 53.9; 54.5];
    lon = [12.1232843; 12.087; 11.2; 13.9];
    Eref = [312423.3901; 309912.4370; 250371.0709; 428763.7378];
    Nref = [6011090.3960; 6007657.7152; 5979088.4245; 6039710.9627];
    [E, N] = mrsim.geo.wgs2utm(lat, lon, 33);
    assert(max(abs(E - Eref)) < 1e-3 && max(abs(N - Nref)) < 1e-3, 'UTM weicht > 1 mm von PROJ ab');
end

function testConvergence(~)
    % Referenz: pyproj Proj(25833).get_factors().meridian_convergence
    g = mrsim.geo.gridConvergence([54.2134366; 54.5], [12.1232843; 13.9], 33);
    assert(max(abs(g - [-2.334270; -0.895564])) < 1e-4, 'Meridiankonvergenz falsch');
end

function testCsvReader(~)
    f = [tempname() '.csv'];
    fid = fopen(f, 'w');
    fprintf(fid, 'Latitude;Longitude;HDG;time\n54.2;12.1;45;t0\n54.21;12.11;50;t1\n');
    fclose(fid);
    trk = mrsim.geo.readTrajectoryCsv(f);
    delete(f);
    assert(isequal(size(trk.lat), [2 1]) && trk.has_heading && trk.heading(2) == 50, 'CSV-Parser');
    assert(strcmp(trk.time{2}, 't1') && all(isnan(trk.antenna_height)), 'CSV optionale Spalten');
end

function testHeadingModes(~)
    trk.has_heading = false; trk.heading = nan(3, 1);
    E = [0; 100; 200]; N = [0; 0; 0]; gam = [-2; -2; -2];     % Fahrt nach Gitter-Ost
    [h, hu] = mrsim.geo.resolveHeading(trk, E, N, gam, 'auto', []);
    assert(all(h == 0) && ~any(hu), 'auto ohne Heading -> North-up');
    [h, hu] = mrsim.geo.resolveHeading(trk, E, N, gam, 'cog', []);
    assert(all(abs(h - 88) < 1e-9) && all(hu), 'COG = Gitterkurs + gamma');
    [h, hu] = mrsim.geo.resolveHeading(trk, E, N, gam, 'north', 123);
    assert(all(h == 123) && all(hu), 'HeadingDeg-Override');
    threw = false;
    try, mrsim.geo.resolveHeading(trk, E, N, gam, 'csv', []); catch, threw = true; end
    assert(threw, 'csv ohne Spalte muss Fehler werfen');
end

function testRangeScale(root)
    radar = mrsim.config.loadJson(fullfile(root, 'config', 'quantum2.json'));
    sc = mrsim.config.getRangeScale(radar, 3);
    assert(abs(sc.bin_m - 3*1852/1024) < 1e-9, 'Bin-Laenge');
    assert(abs(sc.res_m - 299792458*4e-8/2) < 1e-6, 'Entfernungsaufloesung');
end

function testPolarToCartOrientation(~)
    P = zeros(2048, 1024, 'uint8');
    P(1, 500) = 200;                                        % Spoke 1 = oben
    P(513, 500) = 100;                                      % Spoke 513 = 90 deg = rechts
    img = mrsim.render.polarToCart(P, 1, 1024, 2049);
    c = 1025;                                               % Bildmitte
    assert(img(c - 500, c) > 50, 'Spoke 1 muss nach oben zeigen');
    assert(img(c, c + 500) > 25, 'Spoke 513 muss nach rechts zeigen (Uhrzeigersinn)');
end

function testReceiverChain(root)
    radar = mrsim.config.loadJson(fullfile(root, 'config', 'quantum2.json'));
    snr = repmat(single([-10 0 20 200]), 4, 1);
    pix = mrsim.render.receiverChain([zeros(4, 1020, 'single') snr], 10, radar);
    assert(isa(pix, 'uint8') && max(pix(:)) == radar.pixel_max && min(pix(:)) == 0, 'Pixelbereich 0..252');
end

function [radar, scene, lut, sc] = synthSetup(root)
    radar = mrsim.config.loadJson(fullfile(root, 'config', 'quantum2.json'));
    radar.speckle.enable = false;
    radar.receiver.stc_max_db = 0;
    scene.missing_data = 'sea'; scene.water_level_m = 0; scene.earth_k = 4/3;
    rc.sea_state = 3; rc.sea_model = 'NRL'; rc.land_model = 'none-for-test';
    rc.grazing_min_deg = 0.1; rc.grazing_max_deg = 60; rc.sea_gamma_db = -45;
    rc.classes = {struct('id', 1, 'name', 'sea'), ...
                  struct('id', 2, 'name', 'flat', 'land_type', 'x', 'gamma_db', -18), ...
                  struct('id', 3, 'name', 'woods', 'land_type', 'x', 'gamma_db', -12), ...
                  struct('id', 4, 'name', 'urban', 'land_type', 'x', 'gamma_db', -6)};
    % Toolbox-unabhaengig: constant gamma erzwingen
    lut = buildConstGamma(rc);
    sc = mrsim.config.getRangeScale(radar, 1);
end

function lut = buildConstGamma(rc)
    lut.psi = 0:0.05:90;
    g = [0, rc.sea_gamma_db, -18, -12, -6];
    lut.table = zeros(numel(lut.psi), 5);
    for k = 2:5, lut.table(:, k) = 10^(g(k)/10) * sind(lut.psi(:)); end
    lut.source = {};
end

function reg = synthRegion()
    % 4 km x 4 km, 2 m, See 0 m; Mauer 20 m hoch, 10 m tief, 400 m breit, 1000 m noerdlich
    res = 2; n = 2000;
    reg.H = zeros(n, 'single'); reg.C = ones(n, 'uint8');
    reg.x0 = -2000; reg.y0 = 2000; reg.res = res;
    xc = reg.x0 + ((1:n) - 0.5) * res;  yc = reg.y0 - ((1:n) - 0.5) * res;
    rows = yc >= 1000 & yc <= 1010;  cols = abs(xc) <= 200;
    reg.H(rows, cols) = 20; reg.C(rows, cols) = 4;
    reg.missing_frac = 0;
end

function testFastWallAndShadow(root)
    [radar, scene, lut, sc] = synthSetup(root);
    reg = synthRegion();
    pose = struct('E', 0, 'N', 0, 'gamma', 0, 'h_ant', 3, 'hdg0', 0);
    out = mrsim.render.ppiFast(reg, pose, radar, sc, scene, lut);
    bWall = round(1000 / sc.bin_m) + 1;
    [~, kMax] = max(max(out.snr_db(:, bWall-5:bWall+5), [], 2));
    kMax = mod(kMax - 1 + 1024, 2048) - 1024;               % Spoke-Offset um 0
    assert(abs(kMax) <= 3, sprintf('Mauer-Echo bei Spoke-Offset %d statt ~0', kMax));
    assert(max(out.snr_db(1, bWall-5:bWall+5)) > 20, 'Mauer-Echo zu schwach');
    behind = round(1100 / sc.bin_m):round(1500 / sc.bin_m);
    assert(all(out.vis_frac(1, behind) == 0), 'Radarschatten hinter der Mauer fehlt');
    assert(any(out.vis_frac(1025, behind) > 0), 'Suedrichtung darf nicht abgeschattet sein');
end

function testFastHeadUpRotation(root)
    [radar, scene, lut, sc] = synthSetup(root);
    reg = synthRegion();
    pose = struct('E', 0, 'N', 0, 'gamma', 0, 'h_ant', 3, 'hdg0', 90);   % Kurs Ost -> Mauer links (270 deg rel.)
    out = mrsim.render.ppiFast(reg, pose, radar, sc, scene, lut);
    bWall = round(1000 / sc.bin_m) + 1;
    [~, k] = max(max(out.snr_db(:, bWall-5:bWall+5), [], 2));
    assert(abs((k - 1) * 360/2048 - 270) < 2, sprintf('Head-up: Mauer bei %.1f deg statt 270', (k-1)*360/2048));
end

function testClassifyWithDgm(root)
    % Synthetisch: Boden 5 m (Huegel), Flachdach 10 m hoch, "Baumkronen" (zufaellig),
    % Wasser 0 m. Mit DGM muessen Dach -> 4, Kronen -> 3, Huegel -> 2 (nicht Objekt).
    scene = mrsim.config.loadJson(fullfile(root, 'config', 'scene_rostock.json'));
    cls = scene.classification;
    n = 200; [X, Y] = meshgrid(1:n);
    G = 5 + 3 * sin(X / 30);                       % welliger Boden
    G(:, 1:40) = 0;                                % Wasser links
    Z = G;
    Z(60:100, 60:100) = G(60:100, 60:100) + 10;    % Flachdach 40 x 40 m
    rng(3);
    tree = 12 + 4 * rand(n);
    Z(120:180, 120:180) = G(120:180, 120:180) + tree(120:180, 120:180);
    C = mrsim.scene.classifySurface(Z, cls, G);
    assert(mode(reshape(double(C(70:90, 70:90)), [], 1)) == 4, 'Flachdach nicht als Bebauung erkannt');
    assert(mode(reshape(double(C(130:170, 130:170)), [], 1)) == 3, 'Baumkronen nicht als Vegetation erkannt');
    assert(mode(reshape(double(C(5:195, 45:55)), [], 1)) == 2, 'Boden faelschlich als Objekt');
    assert(mode(reshape(double(C(5:195, 5:30)), [], 1)) == 1, 'Wasser nicht erkannt');
end

function testPointTarget(root)
    % Tonne mit 10 dBsm, 1500 m oestlich ueber freier See -> heller Punkt bei 90 deg
    [radar, scene, lut, sc] = synthSetup(root);
    reg.H = zeros(2000, 'single'); reg.C = ones(2000, 'uint8');
    reg.x0 = -2000; reg.y0 = 2000; reg.res = 2; reg.missing_frac = 0;
    scene.targets_data = struct('E', 1500, 'N', 0, 'h', 3, 'rcs', 10, 'type', {{''}}, 'name', {{''}});
    pose = struct('E', 0, 'N', 0, 'gamma', 0, 'h_ant', 3, 'hdg0', 0);
    out = mrsim.render.ppiFast(reg, pose, radar, sc, scene, lut);
    b = round(1500 / sc.bin_m) + 1;
    [v, k] = max(max(out.snr_db(:, b-3:b+3), [], 2));
    assert(abs((k - 1) * 360/2048 - 90) < 1, 'Punktziel nicht bei 90 deg');
    assert(v > 10, sprintf('Punktziel zu schwach (%.1f dB)', v));   % erwartet ~14 dB (Radargleichung)
    assert(out.resp.n_targets == 1, 'Punktziel nicht gezaehlt');
end

function testAssembleRotation(~)
    % 1.5 Umdrehungen mit 8 Spokes; Spoke 3 fehlt -> valid(3) = false
    ang = [5 6 7 0 1 3 4 5 6 7 0 1];
    t = (1:numel(ang)) * 0.1;
    dat = arrayfun(@(a) uint8(a * ones(1, 4)), ang, 'UniformOutput', false);
    [pix, valid, tSpan] = mrsim.real.assembleRotation(t, ang, dat, 8, 4, 8);
    assert(isequal(valid.', logical([1 1 0 1 1 1 1 1])), 'valid-Maske falsch');
    assert(pix(8, 1) == 7 && pix(1, 1) == 0 && all(pix(3, :) == 0), 'Spoke-Zuordnung falsch');
    assert(abs(tSpan(1) - 0.4) < 1e-9 && abs(tSpan(2) - 1.0) < 1e-9, 'Zeitspanne falsch');
end

function testSpokeStats(~)
    v = true(16, 1); v([1 2 16 8]) = false;                 % zirkulaerer Sektor 16-1-2 und Einzelspoke 8
    st = mrsim.real.spokeStats({struct('valid', v)});
    assert(isequal(sort(st.run_lengths), [1 3]), 'Sektorlaengen (zirkulaer) falsch');
    assert(abs(st.missing_frac - 0.25) < 1e-12, 'Ausfallanteil falsch');
    rng(1);
    [p, vv] = mrsim.real.spokeDropout(uint8(ones(16, 4)), st);
    assert(all(all(p(~vv, :) == 0)) && all(all(p(vv, :) == 1)), 'Dropout-Maske inkonsistent');
end

function testDiscrepancyZero(root)
    cfg = mrsim.config.loadJson(fullfile(root, 'config', 'calibration.json'));
    rng(2);
    A = uint8(randi(252, 64, 128) .* (rand(64, 128) > 0.7));
    land = false(64, 128); land(:, 60:end) = true;
    m = cfg.metric; m.min_pixels = 10;
    D = mrsim.calib.discrepancy(A, A, true(64, 1), land, 3.6, m, 252);
    assert(D.total == 0, 'Abweichung identischer Bilder muss 0 sein');
    B = A; B(:, 60:end) = min(252, B(:, 60:end) + 40);
    D2 = mrsim.calib.discrepancy(A, B, true(64, 1), land, 3.6, m, 252);
    assert(D2.dist > 0, 'Helligkeitsunterschied muss erkannt werden');
end

function testProjectionPtTm06(~)
    % Referenz: PROJ/pyproj EPSG:4326 -> EPSG:3763 (ETRS89 / PT-TM06) und Meridiankonvergenz
    sc.crs = struct('type', 'tm', 'lat0', 39.66825833333333, 'lon0', -8.133108333333333, ...
                    'k0', 1, 'false_easting', 0, 'false_northing', 0);
    [E, N] = mrsim.geo.project([38.42924229693182; 41.15], [-9.102020741698434; -8.61], sc);
    assert(max(abs(E - [-84604.4577; -40032.3304])) < 1e-3 && ...
           max(abs(N - [-137106.4711; 164645.9523])) < 1e-3, 'PT-TM06 weicht > 1 mm von PROJ ab');
    g = mrsim.geo.gridConvergence(38.42924229693182, -9.102020741698434, sc);
    assert(abs(g - (-0.602261)) < 1e-4, 'Meridiankonvergenz PT-TM06 falsch');
end

function testLoadRegionGeneric(~)
    % Zwei ausgerichtete Kacheln (10 m Raster, 2 m Stufe) mit NaN-Rand und Ueberlappung
    d = [tempname() '_cache'];
    mkdir(fullfile(d, 'L2m'));
    H = nan(50, 50, 'single'); H(:, 1:40) = 5; C = zeros(50, 'uint8'); C(:, 1:40) = 2;
    x0 = 1000; y0 = 2100; res = 2;                                      %#ok<NASGU>
    save(fullfile(d, 'L2m', 'g_a.mat'), 'H', 'C', 'x0', 'y0', 'res', '-v7');
    H = 7 * ones(50, 50, 'single'); C = 4 * ones(50, 'uint8');
    x0 = 1080; y0 = 2100;                                                %#ok<NASGU>
    save(fullfile(d, 'L2m', 'g_b.mat'), 'H', 'C', 'x0', 'y0', 'res', '-v7');
    x0 = [1000; 1080]; x1 = [1100; 1180]; y0 = [2000; 2000]; y1 = [2100; 2100];
    files = {'g_a.mat'; 'g_b.mat'};                                      %#ok<NASGU>
    save(fullfile(d, 'L2m', 'index.mat'), 'x0', 'x1', 'y0', 'y1', 'files', '-v7');
    scene = struct('cache_dir', d, 'tile_cache_max', 10, 'missing_data', 'sea');
    mrsim.dem.getTileFile('clear');
    reg = mrsim.dem.loadRegionGeneric(scene, 2, 1090, 2050, 90);
    rmdir(d, 's');
    % Zelle bei E = 1050 (nur Kachel a), E = 1095 (Ueberlappung: a = NaN, b = 7)
    col = @(E) round((E - reg.x0) / reg.res + 0.5);
    row = round((reg.y0 - 2050) / reg.res + 0.5);
    assert(reg.H(row, col(1051)) == 5 && reg.C(row, col(1051)) == 2, 'Kachel a falsch eingesetzt');
    assert(reg.H(row, col(1095)) == 7 && reg.C(row, col(1095)) == 4, 'Ueberlappung/NaN-Rand falsch');
    assert(reg.H(row, col(1170)) == 7, 'Kachel b falsch eingesetzt');
    assert(reg.C(1, 1) == 1 && reg.missing_frac > 0, 'Fehlende Bereiche nicht als See');
end
