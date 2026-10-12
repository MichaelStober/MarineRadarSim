function scans = importNpzScans(files, mapFile, radar, outDir)
%IMPORTNPZSCANS  Eigene Spoke-Aufnahmen (.npz, 2048 x 1024) in das kanonische Format bringen.
%   scans = mrsim.real.importNpzScans('pfad/zu/npz', 'config/real_npz_mapping.json', radar)
%   scans = mrsim.real.importNpzScans({'a.npz','b.npz'}, map, radar, 'data/real')
%
%   Die Schluesselnamen im Archiv stehen in der Mapping-Datei (vorher mit
%   mrsim.real.inspectNpz pruefen). Fehlende Spokes nach map.missing_rule.
%   Position/Heading: aus dem Archiv (lat_key/lon_key/heading_key) oder per
%   Zeitstempel aus map.gps_csv. Ohne Heading wird der Scan als 'north-up' markiert,
%   falls map.orientation = 'north-up'; bei 'head-up' ohne Heading -> Fehler
%   (dann Heading liefern oder per Kalibrierung/COG schaetzen - Entscheidung offen).
    m = jsondecode(fileread(mapFile));
    if strncmp(m.spokes_key, 'TODO', 4)
        error('mrsim:real:map', 'spokes_key in %s ist noch nicht ausgefuellt.', mapFile);
    end
    if ischar(files) && isfolder(files)
        d = dir(fullfile(files, '*.npz'));
        files = fullfile({d.folder}, {d.name});
    elseif ischar(files)
        files = {files};
    end
    gps = [];
    if isfield(m, 'gps_csv') && ~isempty(m.gps_csv.file)
        gps = readGps(m.gps_csv);
    end
    scans = {};
    for i = 1:numel(files)
        S = mrsim.real.readNpz(files{i});
        A = getKey(S, m.spokes_key);
        if ndims(A) == 2, A = reshape(A, [1 size(A)]); end
        [~, base] = fileparts(files{i});
        for j = 1:size(A, 1)
            pix = squeeze(A(j, :, :));
            if size(pix, 1) ~= radar.n_spokes && size(pix, 2) == radar.n_spokes, pix = pix.'; end
            scan = struct();
            scan.pix = uint8(min(max(double(pix), 0), radar.pixel_max));
            switch m.missing_rule
                case 'valid_key', v = getKey(S, m.valid_key); if ndims(v) == 2 && size(v, 1) == size(A, 1), v = v(j, :); end
                    scan.valid = logical(v(:));
                case 'zero_rows', scan.valid = any(scan.pix > 0, 2);
                case 'none',      scan.valid = true(size(scan.pix, 1), 1);
                otherwise, error('mrsim:real:missing', 'Unbekannte missing_rule "%s".', m.missing_rule);
            end
            t = pick(S, m.time_key, j, NaN);
            scan.time = sprintf('%.3f', t);
            scan.lat = pick(S, m.lat_key, j, NaN);
            scan.lon = pick(S, m.lon_key, j, NaN);
            scan.heading_deg = pick(S, m.heading_key, j, NaN);
            if strcmp(m.heading_units, 'rad'), scan.heading_deg = rad2deg(scan.heading_deg); end
            if (isnan(scan.lat) || isnan(scan.lon)) && ~isempty(gps)
                if isnan(t), error('mrsim:real:time', '%s: time_key noetig, um die GPS-CSV zuzuordnen.', files{i}); end
                [~, k] = min(abs(gps.t - t));
                scan.lat = gps.lat(k); scan.lon = gps.lon(k);
                if isnan(scan.heading_deg) && ~isempty(gps.hdg), scan.heading_deg = gps.hdg(k); end
            end
            if isnan(scan.lat) || isnan(scan.lon)
                error('mrsim:real:pos', '%s: keine Position (lat_key/lon_key oder gps_csv setzen).', files{i});
            end
            rm = pick(S, m.range_m_key, j, NaN);
            if ~isnan(rm)
                scan.range_nm = round(rm / 1852 * 1000) / 1000;
            elseif ~isempty(m.range_nm_default)
                scan.range_nm = m.range_nm_default;
            else
                error('mrsim:real:range', '%s: Range unbekannt (range_m_key oder range_nm_default).', files{i});
            end
            scan.orientation = m.orientation;
            scan.h_ant = m.antenna_height_m;
            scan.env = m.env;
            scan.settings = m.settings;
            scan.id = sprintf('%s_%03d', base, j);
            scan.source = files{i};
            scans{end+1} = mrsim.real.validateScan(scan, radar); %#ok<AGROW>
            if nargin >= 4 && ~isempty(outDir)
                mrsim.real.saveScan(scans{end}, fullfile(outDir, [scan.id '.mat']));
            end
        end
    end
end

function v = getKey(S, key)
    f = matlab.lang.makeValidName(key);
    if ~isfield(S, f), error('mrsim:real:key', 'Schluessel "%s" nicht im Archiv (vorhanden: %s).', key, strjoin(S.keys_, ', ')); end
    v = S.(f);
end

function v = pick(S, key, j, def)
    if isempty(key), v = def; return; end
    a = double(getKey(S, key));
    if isempty(a), v = def; elseif numel(a) >= j && numel(a) > 1, v = a(j); else, v = a(1); end
end

function g = readGps(c)
    lines = regexp(fileread(c.file), '\r?\n', 'split');
    lines = lines(~cellfun(@(s) isempty(strtrim(s)), lines));
    names = lower(strtrim(strsplit(lines{1}, ',', 'CollapseDelimiters', false)));
    M = cellfun(@(l) str2double(strsplit(l, ',', 'CollapseDelimiters', false)), lines(2:end), 'UniformOutput', false);
    M = vertcat(M{:});
    col = @(nm) M(:, find(strcmp(names, lower(nm)), 1));
    g.t = col(c.time_col); g.lat = col(c.lat_col); g.lon = col(c.lon_col);
    if ~isempty(c.heading_col), g.hdg = col(c.heading_col); else, g.hdg = []; end
end
