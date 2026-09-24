function index = simulatePpiFromCsv(csvPath, outDir, varargin)
%SIMULATEPPIFROMCSV  Raymarine-Quantum-2-PPIs entlang einer Trajektorie simulieren.
%
%   simulatePpiFromCsv('examples/track_warnemuende.csv', 'out')
%   simulatePpiFromCsv(csv, out, 'RangeScaleNM', 3, 'HeadingMode', 'cog')
%   simulatePpiFromCsv(csv, out, 'HeadingDeg', 45)          % konstantes Heading, Head-up
%   simulatePpiFromCsv(csv, out, 'Backend', 'iq', 'Frames', 1)  % IQ-Referenz fuer Frame 1
%
%   CSV: Kopfzeile, Spalten lat, lon (Pflicht); optional heading_deg, antenna_height_m, id, time.
%
%   Optionen (Name/Wert):
%     'RangeScaleNM'  1 | 2 | 3 | 4 | 7 | 8 | 10          (Default 2)
%     'HeadingMode'   'auto' | 'north' | 'csv' | 'cog'     (Default 'auto')
%                       auto : heading_deg aus CSV falls vorhanden (Head-up), sonst North-up
%     'HeadingDeg'    [] oder Skalar: konstantes Heading (ueberschreibt HeadingMode)
%     'Backend'       'fast' (Default) | 'iq'
%     'Radar'         Pfad zu quantum2.json          (Default config/quantum2.json)
%     'Scene'         Pfad zu scene_*.json           (Default config/scene_rostock.json)
%     'UseParallel'   false (Default) | true  -> parfor (Parallel Computing Toolbox)
%     'Seed'          Basis-Zufallsseed (Default 1; Frame i nutzt Seed + i)
%     'CartSizePx'    Kantenlaenge kartesisches Bild (Default 1024)
%     'Frames'        [] = alle, sonst Vektor von Zeilenindizes
%     'SaveMat'       true (Default): <frame>.mat mit SNR [dB] und Metadaten
%     'BuildCache'    true (Default): DOM-Cache bei Bedarf anlegen
%
%   Ausgabe in outDir: frame_XXXXXX_{polar,cart,landmask_polar,landmask_cart}.png,
%   frame_XXXXXX.mat, index.csv, run_config.json. Rueckgabe: Index-Struct.
    root = fileparts(mfilename('fullpath'));
    p = inputParser;
    addRequired(p, 'csvPath');
    addRequired(p, 'outDir');
    addParameter(p, 'RangeScaleNM', 2);
    addParameter(p, 'HeadingMode', 'auto');
    addParameter(p, 'HeadingDeg', []);
    addParameter(p, 'Backend', 'fast');
    addParameter(p, 'Radar', fullfile(root, 'config', 'quantum2.json'));
    addParameter(p, 'Scene', fullfile(root, 'config', 'scene_rostock.json'));
    addParameter(p, 'UseParallel', false);
    addParameter(p, 'Seed', 1);
    addParameter(p, 'CartSizePx', 1024);
    addParameter(p, 'Frames', []);
    addParameter(p, 'SaveMat', true);
    addParameter(p, 'BuildCache', true);
    parse(p, csvPath, outDir, varargin{:});
    o = p.Results;
    csvPath = char(csvPath); outDir = char(outDir);
    backend = lower(char(o.Backend));
    if ~any(strcmp(backend, {'fast', 'iq'}))
        error('mrsim:backend', 'Backend muss "fast" oder "iq" sein.');
    end

    % ---------- Konfiguration --------------------------------------------------
    radar = mrsim.config.loadJson(char(o.Radar));
    scene = mrsim.config.loadJson(char(o.Scene));
    scene.cache_dir = mrsim.config.resolvePath(scene.cache_dir, root);
    scene.dom_dir   = mrsim.config.resolvePath(scene.dom_dir, root);
    sc = mrsim.config.getRangeScale(radar, o.RangeScaleNM);
    level = sc.dem_level_m;
    fprintf('Range %g NM: Radius %.0f m, Bin %.2f m, Aufloesung %.1f m, DOM-Stufe %g m, %.1f Pulse/Spoke\n', ...
        sc.nm, sc.range_m, sc.bin_m, sc.res_m, level, sc.pulses_per_spoke);

    % ---------- DOM-Cache -------------------------------------------------------
    cacheLevelDir = fullfile(scene.cache_dir, sprintf('L%gm', level));
    if o.BuildCache && (~isfolder(cacheLevelDir) || isempty(dir(fullfile(cacheLevelDir, 't_*.mat'))))
        fprintf('DOM-Cache fuer %g m fehlt -> wird aus %s gebaut (einmalig) ...\n', level, scene.dom_dir);
        mrsim.dem.buildTileCache(scene);
    end

    % ---------- Trajektorie & Heading ------------------------------------------
    trk = mrsim.geo.readTrajectoryCsv(csvPath);
    [E, N] = mrsim.geo.wgs2utm(trk.lat, trk.lon, scene.utm_zone);
    gam = mrsim.geo.gridConvergence(trk.lat, trk.lon, scene.utm_zone);
    hAnt = trk.antenna_height; hAnt(isnan(hAnt)) = radar.antenna_height_m;
    [hdg, headUp, hsrc] = mrsim.geo.resolveHeading(trk, E, N, gam, char(o.HeadingMode), o.HeadingDeg);

    frames = o.Frames;
    if isempty(frames), frames = 1:numel(E); end
    frames = frames(:).';

    % ---------- Reflektivitaet -------------------------------------------------
    lut = mrsim.refl.buildReflectivityTable(scene.reflectivity, radar.fc_hz);
    fprintf('sigma0-Quellen: %s\n', strjoin(lut.source(2:end), ' | '));

    if ~isfolder(outDir), mkdir(outDir); end
    writeRunConfig(outDir, radar, scene, sc, o, csvPath, lut);

    % ---------- Frames ----------------------------------------------------------
    nF = numel(frames);
    rowsC = cell(1, nF);
    usePar = o.UseParallel && license('test', 'Distrib_Computing_Toolbox');
    if o.UseParallel && ~usePar
        warning('mrsim:parallel', 'Parallel Computing Toolbox nicht verfuegbar -> sequentiell.');
    end
    t0 = tic;
    if usePar
        parfor ii = 1:nF
            rowsC{ii} = renderOne(frames(ii), trk, E, N, gam, hAnt, hdg, headUp, hsrc, ...
                radar, sc, scene, lut, backend, outDir, o);
        end
    else
        for ii = 1:nF
            rowsC{ii} = renderOne(frames(ii), trk, E, N, gam, hAnt, hdg, headUp, hsrc, ...
                radar, sc, scene, lut, backend, outDir, o);
            fprintf('  Frame %d/%d fertig (%.1f s)\n', ii, nF, toc(t0));
        end
    end
    index = [rowsC{:}];
    mrsim.io.writeIndex(outDir, index);
    fprintf('%d Frames in %.1f s -> %s\n', nF, toc(t0), outDir);
end

% =============================================================================
function row = renderOne(i, trk, E, N, gam, hAnt, hdg, headUp, hsrc, radar, sc, scene, lut, backend, outDir, o)
    rng(o.Seed + i);
    pose.E = E(i); pose.N = N(i); pose.gamma = gam(i);
    pose.h_ant = hAnt(i); pose.hdg0 = hdg(i);
    Rmax = sc.range_m * radar.bin_range_factor;
    reg = mrsim.dem.loadRegion(scene, sc.dem_level_m, pose.E, pose.N, Rmax + 2 * sc.dem_level_m);

    switch backend
        case 'fast'
            out = mrsim.render.ppiFast(reg, pose, radar, sc, scene, lut);
            landFrac = out.land_frac;
        case 'iq'
            out = mrsim.render.ppiIQ(reg, pose, radar, sc, scene, lut);
            g = mrsim.render.samplePolar(reg, pose, radar, sc, scene);
            ovA = radar.oversampling.azimuth; ovR = radar.oversampling.range;
            lf = double(g.cls >= 2); [m, n] = size(lf);
            landFrac = reshape(mean(mean(reshape(lf, ovA, m/ovA, ovR, n/ovR), 1), 3), m/ovA, n/ovR);
    end

    pixPolar  = mrsim.render.receiverChain(out.snr_db, sc.bin_m, radar);
    pixCart   = mrsim.render.polarToCart(pixPolar, sc.bin_m, Rmax, o.CartSizePx);
    maskPolar = landFrac >= 0.5;
    maskCart  = mrsim.render.cartLandMask(reg, pose, Rmax, o.CartSizePx);

    name = sprintf('frame_%06d', i);
    if headUp(i), orient = 'head-up'; else, orient = 'north-up'; end
    meta = struct('frame', i, 'id', trk.id(i), 'lat', trk.lat(i), 'lon', trk.lon(i), ...
        'E', pose.E, 'N', pose.N, 'gamma_deg', pose.gamma, 'heading_deg', pose.hdg0, ...
        'orientation', orient, 'heading_source', hsrc{i}, 'antenna_height_m', pose.h_ant, ...
        'range_nm', sc.nm, 'bin_m', sc.bin_m, 'backend', backend, ...
        'spoke0_azimuth_deg', pose.hdg0, 'spokes_clockwise', true);
    files = mrsim.io.writeFrame(outDir, name, pixPolar, pixCart, maskPolar, maskCart, ...
        out.snr_db, meta, o.SaveMat);

    row = struct('frame', i, 'id', trk.id(i), 'lat', trk.lat(i), 'lon', trk.lon(i), ...
        'E', pose.E, 'N', pose.N, 'gamma', pose.gamma, 'heading', pose.hdg0, ...
        'orientation', orient, 'heading_source', hsrc{i}, 'h_ant', pose.h_ant, ...
        'range_nm', sc.nm, 'bin_m', sc.bin_m, 'missing_frac', reg.missing_frac, ...
        'time', trk.time{i}, 'polar_png', files.polar, 'cart_png', files.cart);
end

function writeRunConfig(outDir, radar, scene, sc, o, csvPath, lut)
    rc.created = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    rc.csv = csvPath;
    rc.backend = o.Backend;
    rc.range_scale = sc;
    rc.heading_mode = o.HeadingMode;
    rc.heading_deg_override = o.HeadingDeg;
    rc.seed = o.Seed;
    rc.sigma0_sources = lut.source;
    rc.radar = radar;
    rc.scene = scene;
    try
        txt = jsonencode(rc, 'PrettyPrint', true);
    catch
        txt = jsonencode(rc);
    end
    fid = fopen(fullfile(outDir, 'run_config.json'), 'w');
    fprintf(fid, '%s', txt);
    fclose(fid);
end
