function runAllTests()
%RUNALLTESTS  Selbsttests ohne DOM-Daten und ohne Toolboxen (MATLAB und GNU Octave).
%   >> cd MarineRadar; addpath tests; runAllTests
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root);
    t = {@testUtmAgainstProj, @testConvergence, @testCsvReader, @testHeadingModes, ...
         @testRangeScale, @testPolarToCartOrientation, @testReceiverChain, ...
         @testFastWallAndShadow, @testFastHeadUpRotation};
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
