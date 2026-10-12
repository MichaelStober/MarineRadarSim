function scans = readScansMcap(bagPath, mapFile, startTimes, radar, outDir)
%READSCANSMCAP  Echte Quantum-Scans (je eine Umdrehung) aus einer MCAP-Aufnahme extrahieren.
%   scans = mrsim.real.readScansMcap(bag, 'config/real_mcap_mapping.json', t0, radar)
%   scans = mrsim.real.readScansMcap(bag, map, t0, radar, 'data/real')   % zusaetzlich speichern
%
%   startTimes  Vektor von Startzeiten [s] in Aufnahmezeit (bag.StartTime..EndTime);
%               je Startzeit wird die erste vollstaendige Umdrehung danach genommen.
%   Pose zur Scanmitte: lat/lon linear, Heading zirkulaer interpoliert.
%   Settings: letzte Settings-Nachricht vor Scanbeginn.
%   Benoetigt ROS Toolbox >= R2024a (MCAP); UNGETESTET ohne echte Aufnahme -
%   Feldnamen kommen aus config/real_mcap_mapping.json (vorher mrsim.real.inspectMcap).
    m = jsondecode(fileread(mapFile));
    if exist('ros2bagreader') == 0
        error('mrsim:real:ros', 'ros2bagreader nicht gefunden (ROS Toolbox >= R2024a noetig).');
    end
    chk = {'spoke_topic', 'spoke_angle_field', 'spoke_data_field', 'gnss_topic'};
    for i = 1:numel(chk)
        if strncmp(m.(chk{i}), 'TODO', 4)
            error('mrsim:real:map', 'Mapping-Feld "%s" ist noch nicht ausgefuellt (%s).', chk{i}, mapFile);
        end
    end
    bag = ros2bagreader(bagPath);
    T = m.rotation_period_s;
    scans = cell(1, numel(startTimes));
    for i = 1:numel(startTimes)
        t0 = startTimes(i);
        [tS, msgS] = readTopic(bag, m.spoke_topic, t0, t0 + 2.2 * T);
        if isempty(msgS)
            warning('mrsim:real:noSpokes', 'Keine Spokes ab t = %.2f s.', t0); continue;
        end
        ang = cellfun(@(x) double(getPath(x, m.spoke_angle_field)), msgS);
        dat = cellfun(@(x) getPath(x, m.spoke_data_field), msgS, 'UniformOutput', false);
        [pix, valid, tSpan] = mrsim.real.assembleRotation(tS, ang, dat, radar.n_spokes, radar.n_bins, m.angle_units_per_rev);
        tMid = mean(tSpan);

        scan = struct();
        scan.pix = pix; scan.valid = valid;
        scan.time = sprintf('%.3f', tMid);
        scan.source = sprintf('%s @ %.3f s', bagPath, tMid);
        scan.env = m.env;
        scan.id = sprintf('%s_%010.3f', m.env, tMid);
        scan.h_ant = m.antenna_height_m;

        % --- Settings (vor Pose, liefert ggf. die Range) --------------------
        scan.settings = struct();
        if isfield(m, 'settings_topic') && ~strncmp(m.settings_topic, 'TODO', 4)
            [~, msgC] = readTopic(bag, m.settings_topic, bag.StartTime, tSpan(1));
            if ~isempty(msgC)
                last = msgC{end};
                f = fieldnames(m.settings_fields);
                for k = 1:numel(f)
                    p = m.settings_fields.(f{k});
                    if ~strncmp(p, 'TODO', 4)
                        try, scan.settings.(f{k}) = getPath(last, p); catch, end
                    end
                end
            end
        end
        % --- Range ----------------------------------------------------------
        rng_m = NaN;
        if isfield(m, 'spoke_range_field') && ~isempty(m.spoke_range_field) && ~strncmp(m.spoke_range_field, 'TODO', 4)
            rng_m = double(getPath(msgS{end}, m.spoke_range_field));
        elseif isfield(scan.settings, 'range_m')
            rng_m = double(scan.settings.range_m);
        end
        if isnan(rng_m)
            error('mrsim:real:range', 'Range unbekannt: spoke_range_field oder settings_fields.range_m setzen.');
        end
        scan.range_nm = round(rng_m / 1852 * 1000) / 1000;

        % --- Position --------------------------------------------------------
        [tG, msgG] = readTopic(bag, m.gnss_topic, tMid - 3, tMid + 3);
        if isempty(msgG), error('mrsim:real:gnss', 'Keine GNSS-Nachricht um t = %.2f s.', tMid); end
        la = cellfun(@(x) double(getPath(x, m.lat_field)), msgG);
        lo = cellfun(@(x) double(getPath(x, m.lon_field)), msgG);
        scan.lat = interpOrNearest(tG, la, tMid);
        scan.lon = interpOrNearest(tG, lo, tMid);

        % --- Heading ---------------------------------------------------------
        scan.heading_deg = NaN;
        if isfield(m, 'heading_topic') && ~strncmp(m.heading_topic, 'TODO', 4)
            [tH, msgH] = readTopic(bag, m.heading_topic, tMid - 2, tMid + 2);
            if ~isempty(msgH)
                h = cellfun(@(x) double(getPath(x, m.heading_field)), msgH);
                switch m.heading_units
                    case 'rad',         h = rad2deg(h);
                    case 'enu_yaw_rad', h = 90 - rad2deg(h);   % ENU-Yaw (ab Ost, math. positiv) -> Kurs ab Nord
                end
                c = interpOrNearest(tH, cosd(h), tMid); s = interpOrNearest(tH, sind(h), tMid);
                scan.heading_deg = mod(atan2d(s, c), 360);
            end
        end
        if strcmp(m.angle_reference, 'bow'), scan.orientation = 'head-up'; else, scan.orientation = 'north-up'; end

        scans{i} = mrsim.real.validateScan(scan, radar);
        if nargin >= 5 && ~isempty(outDir)
            mrsim.real.saveScan(scans{i}, fullfile(outDir, [scans{i}.id '.mat']));
        end
        fprintf('Scan %s: %d/%d Spokes, %.3f NM, HDG %.1f\n', scans{i}.id, nnz(valid), numel(valid), scan.range_nm, scan.heading_deg);
    end
    scans = scans(~cellfun(@isempty, scans));
end

function [t, msgs] = readTopic(bag, topic, t0, t1)
    sel = select(bag, 'Topic', topic, 'Time', [t0 t1]);
    if sel.NumMessages == 0, t = []; msgs = {}; return; end
    msgs = readMessages(sel);
    t = sel.MessageList.Time;
end

function v = getPath(s, p)
    parts = strsplit(p, '.');
    v = s;
    for k = 1:numel(parts)
        v = v.(parts{k});
    end
end

function y = interpOrNearest(t, v, tq)
    if numel(t) >= 2 && tq >= min(t) && tq <= max(t)
        [tu, iu] = unique(t);
        y = interp1(tu, v(iu), tq, 'linear');
    else
        [~, k] = min(abs(t - tq)); y = v(k);
    end
end
