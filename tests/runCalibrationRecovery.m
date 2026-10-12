function rep = runCalibrationRecovery(scenePath, varargin)
%RUNCALIBRATIONRECOVERY  Parameter-Wiederfindungsexperiment fuer die Kalibrierung.
%
%   rep = runCalibrationRecovery()                          % config/scene_rostock.json
%   rep = runCalibrationRecovery(scenePath, 'Stages', {'geometry','radiometry'})
%
%   Erzeugt "pseudo-echte" Scans mit bekannten Parametern theta_true (andere
%   Zufallsrealisierung als in der Kalibrierung, zufaellig fehlende Spokes) und
%   kalibriert ausgehend von den Standardwerten. Prueft, welche Parameter
%   identifizierbar sind und wie genau sie wiedergefunden werden.
%   -> Validierung des Verfahrens, bevor echte Scans vorliegen (benoetigt DOM-Cache).
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root);
    if nargin < 1 || isempty(scenePath), scenePath = fullfile(root, 'config', 'scene_rostock.json'); end
    p = inputParser;
    addParameter(p, 'Stages', {'geometry', 'radiometry', 'psf'});
    addParameter(p, 'MaxEvals', 80);
    addParameter(p, 'RangeNM', 2);
    parse(p, varargin{:});
    o = p.Results;

    radar = mrsim.config.loadJson(fullfile(root, 'config', 'quantum2.json'));
    scene = mrsim.config.loadScene(scenePath, root);
    cfg   = mrsim.config.loadJson(fullfile(root, 'config', 'calibration.json'));
    cfg.stages = o.Stages;
    cfg.optimizer.max_evals_per_stage = o.MaxEvals;
    cfg.optimizer.method = 'fminsearch';
    lut = mrsim.refl.buildReflectivityTable(scene.reflectivity, radar.fc_hz);
    mrsim.dem.buildTileCache(scene);

    % --- wahre Parameter ------------------------------------------------------
    truth = { 'scene.reflectivity.class_offset_db(1)',  4; ...
              'scene.reflectivity.class_offset_db(2)', -5; ...
              'scene.reflectivity.class_offset_db(3)',  3; ...
              'scene.reflectivity.class_offset_db(4)',  2; ...
              'radar.receiver.floor_db',                6; ...
              'radar.receiver.sat_db',                 42; ...
              'radar.receiver.stc_max_db',             38; ...
              'radar.azimuth_offset_deg',             2.0; ...
              'radar.az_beamwidth_deg',               5.6 };
    rT = radar; sT = scene;
    for i = 1:size(truth, 1)
        [rT, sT] = mrsim.calib.setParam(rT, sT, truth{i, 1}, truth{i, 2});
    end

    % --- pseudo-echte Scans: Kuestenposen vor Warnemuende/Markgrafenheide ------
    poses = [54.2134366 12.1232843 30.6; 54.2211607 12.1311120 30.6; ...
             54.2050419 12.0480997 312.6; 54.2027980 12.0482598 43.0];
    scans = cell(1, size(poses, 1));
    for k = 1:size(poses, 1)
        s = struct('lat', poses(k,1), 'lon', poses(k,2), 'heading_deg', poses(k,3), ...
                   'orientation', 'head-up', 'range_nm', o.RangeNM, 'h_ant', radar.antenna_height_m, ...
                   'env', 'synthetisch', 'id', sprintf('pseudo_%d', k), ...
                   'pix', zeros(radar.n_spokes, radar.n_bins, 'uint8'), 'valid', true(radar.n_spokes, 1));
        s = mrsim.real.validateScan(s, radar);
        cfgT = cfg; cfgT.optimizer.seed = 500 + 10 * k;          % andere Speckle-Realisierung
        e = mrsim.calib.prepare({s}, rT, sT, lut, cfgT);
        pix = mrsim.calib.renderCached(e{1}, rT, sT, 900 + k);
        rng(77 + k);
        [pix, valid] = mrsim.real.spokeDropout(pix, [], 'NumRuns', 2, 'MeanRun', 40);
        s.pix = pix; s.valid = valid;
        scans{k} = mrsim.real.validateScan(s, radar);
    end

    % --- Kalibrierung ab Standardwerten ------------------------------------------
    cache = mrsim.calib.prepare(scans, radar, scene, lut, cfg);
    r = mrsim.calib.calibrate(cache, radar, scene, cfg);

    rep = struct('path', truth(:, 1), 'true', truth(:, 2), 'init', [], 'estimate', [], 'error', []);
    fprintf('\n%-42s %8s %8s %8s %8s\n', 'Parameter', 'wahr', 'start', 'geschaetzt', 'Fehler');
    for i = 1:size(truth, 1)
        rep(i).init = mrsim.calib.getParam(radar, scene, truth{i, 1});
        rep(i).estimate = mrsim.calib.getParam(r.radar, r.scene, truth{i, 1});
        rep(i).error = rep(i).estimate - truth{i, 2};
        fprintf('%-42s %8.2f %8.2f %8.2f %8.2f\n', truth{i, 1}, truth{i, 2}, rep(i).init, rep(i).estimate, rep(i).error);
    end
    Dtrue = mrsim.calib.evaluate(cache, rT, sT, r.cfg);
    fprintf('\nD_init = %.4f, D_final = %.4f, D(theta_true) = %.4f (Untergrenze durch Speckle/Rauschen)\n', ...
        r.D_init, r.D_final, Dtrue);
end
