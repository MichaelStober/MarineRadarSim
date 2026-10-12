function cache = prepare(scans, radar, scene, lut, cfg)
%PREPARE  Szenenantwort (teurer Geometrieteil) je echtem Scan einmalig berechnen.
%   cache{k}.scan, .pose, .sc, .resp, .land (n_spokes x n_bins logical)
%   Danach kostet jede Parameterauswertung nur noch sensorModel + receiverChain.
%   Die Zufallsphasen/Texturen sind je Scan fest (Seed cfg.optimizer.seed + k):
%   "common random numbers" -> das Kalibrierziel ist deterministisch in theta.
    if isfield(cfg, 'oversampling_override') && cfg.oversampling_override > 0
        radar.oversampling.azimuth = cfg.oversampling_override;
        radar.oversampling.range = cfg.oversampling_override;
    end
    cache = cell(1, numel(scans));
    for k = 1:numel(scans)
        s = scans{k};
        headUp = strcmp(s.orientation, 'head-up');
        pose = mrsim.geo.makePose(s.lat, s.lon, s.heading_deg, headUp, s.h_ant, scene);
        sc = mrsim.config.getRangeScale(radar, s.range_nm);
        R = sc.range_m * radar.bin_range_factor;
        reg = mrsim.dem.loadRegion(scene, sc.dem_level_m, pose.E, pose.N, R + 2 * sc.dem_level_m);
        rng(cfg.optimizer.seed + k);
        resp = mrsim.render.sceneResponse(reg, pose, radar, sc, scene, lut);
        ovA = resp.ovA; ovR = resp.ovR;
        lf = double(resp.cls >= 2); [m, n] = size(lf);
        land = reshape(mean(mean(reshape(lf, ovA, m/ovA, ovR, n/ovR), 1), 3), m/ovA, n/ovR) >= 0.5;
        cache{k} = struct('scan', s, 'pose', pose, 'sc', sc, 'resp', resp, 'land', land, ...
                          'missing_frac', reg.missing_frac);
        fprintf('  vorbereitet: %s (%s, %.2f NM, %d/%d Spokes gueltig)\n', s.id, s.env, s.range_nm, nnz(s.valid), numel(s.valid));
    end
end
