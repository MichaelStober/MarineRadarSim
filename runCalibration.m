function result = runCalibration(scanSource, outDir, varargin)
%RUNCALIBRATION  Simulation an echten Scans kalibrieren (Systemidentifikation) und berichten.
%
%   result = runCalibration('data/real', 'out/calib')
%   result = runCalibration(scans, 'out/calib', 'LeaveOneOut', true)
%
%   scanSource : Ordner mit kanonischen Scan-.mat (mrsim.real.saveScan) oder Zellarray von Scans
%   Optionen   : 'Radar', 'Scene', 'Calib' (JSON-Pfade), 'LeaveOneOut' (true),
%                'WriteConfigs' (true: kalibrierte JSONs nach outDir schreiben)
%
%   Ablauf:
%   1) Scans laden und nach cfg.group_by (z. B. Radar-Mode) gruppieren
%   2) je Gruppe: Szenenantwort je Scan vorbereiten (teuer, einmalig)
%   3) optional Leave-one-out (Generalisierung), dann Kalibrierung auf allen Scans der Gruppe
%   4) Report: calibration_report.json, Vergleichsbilder [echt | vorher | nachher],
%      kalibrierte Konfigurationen quantum2_calibrated_<gruppe>.json / scene_..._<gruppe>.json
    root = fileparts(mfilename('fullpath'));
    p = inputParser;
    addParameter(p, 'Radar', fullfile(root, 'config', 'quantum2.json'));
    addParameter(p, 'Scene', fullfile(root, 'config', 'scene_rostock.json'));
    addParameter(p, 'Calib', fullfile(root, 'config', 'calibration.json'));
    addParameter(p, 'LeaveOneOut', true);
    addParameter(p, 'WriteConfigs', true);
    parse(p, varargin{:});
    o = p.Results;

    radar = mrsim.config.loadJson(char(o.Radar));
    scene = mrsim.config.loadScene(char(o.Scene), root);
    cfg   = mrsim.config.loadJson(char(o.Calib));
    lut   = mrsim.refl.buildReflectivityTable(scene.reflectivity, radar.fc_hz);
    mrsim.dem.buildTileCache(scene);

    if iscell(scanSource), scans = scanSource; else, scans = mrsim.real.loadScans(char(scanSource), radar); end
    if ~isfolder(outDir), mkdir(outDir); end

    keys = cellfun(@(s) groupKey(s, cfg.group_by), scans, 'UniformOutput', false);
    groups = unique(keys);
    result = struct('group', {}, 'n_scans', {}, 'D_init', {}, 'D_final', {}, 'theta', {}, ...
                    'az_offset_per_scan', {}, 'history', {}, 'loo', {}, 'scan_ids', {});
    st = mrsim.real.spokeStats(scans);
    fprintf('Fehlende Spokes: Mittel %.1f %%, %d Ausfallsektoren gesamt\n', 100 * mean(st.missing_frac), numel(st.run_lengths));

    for g = 1:numel(groups)
        idx = find(strcmp(keys, groups{g}));
        fprintf('\n=== Gruppe "%s": %d Scans ===\n', groups{g}, numel(idx));
        cache = mrsim.calib.prepare(scans(idx), radar, scene, lut, cfg);
        loo = [];
        if o.LeaveOneOut && numel(idx) >= 2
            loo = mrsim.calib.leaveOneOut(cache, radar, scene, cfg);
        end
        r = mrsim.calib.calibrate(cache, radar, scene, cfg);
        tag = matlab_safe(groups{g});
        for k = 1:numel(cache)
            img = mrsim.calib.comparisonImage(cache{k}, radar, scene, r.radar, r.scene, cfg.optimizer.seed);
            imwrite(img, fullfile(outDir, sprintf('vergleich_%s_%s.png', tag, matlab_safe(cache{k}.scan.id))));
        end
        if o.WriteConfigs
            writeJson(fullfile(outDir, sprintf('quantum2_calibrated_%s.json', tag)), stripMeta(r.radar));
            writeJson(fullfile(outDir, sprintf('scene_calibrated_%s.json', tag)), stripMeta(r.scene));
        end
        result(end+1) = struct('group', groups{g}, 'n_scans', numel(idx), 'D_init', r.D_init, ...
            'D_final', r.D_final, 'theta', r.theta, 'az_offset_per_scan', r.az_offset_per_scan, ...
            'history', r.history, 'loo', loo, 'scan_ids', {cellfun(@(s) s.id, scans(idx), 'UniformOutput', false)}); %#ok<AGROW>
    end
    rep.created = datestr(now, 'yyyy-mm-dd HH:MM:SS');
    rep.spoke_stats = st;
    rep.groups = result;
    rep.calibration_config = cfg;
    writeJson(fullfile(outDir, 'calibration_report.json'), rep);
    fprintf('\nReport: %s\n', fullfile(outDir, 'calibration_report.json'));
end

function k = groupKey(s, fields)
    if isempty(fields), k = 'alle'; return; end
    if ischar(fields), fields = {fields}; end
    parts = cell(1, numel(fields));
    for i = 1:numel(fields)
        if isfield(s.settings, fields{i}), v = s.settings.(fields{i}); else, v = 'na'; end
        if isnumeric(v) || islogical(v), v = num2str(v); end
        parts{i} = sprintf('%s=%s', fields{i}, char(v));
    end
    k = strjoin(parts, '_');
end

function s = matlab_safe(s)
    s = regexprep(s, '[^A-Za-z0-9_\-]', '_');
end

function s = stripMeta(s)
    if isfield(s, 'source_file'), s = rmfield(s, 'source_file'); end
end

function writeJson(f, s)
    try, txt = jsonencode(s, 'PrettyPrint', true); catch, txt = jsonencode(s); end
    fid = fopen(f, 'w'); fprintf(fid, '%s', txt); fclose(fid);
end
