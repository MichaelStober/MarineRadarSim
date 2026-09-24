function trk = readTrajectoryCsv(csvPath)
%READTRAJECTORYCSV  Trajektorie aus CSV lesen.
%   Pflichtspalten : lat, lon            (Aliase: latitude, lng, longitude)
%   Optional       : heading_deg         (Aliase: heading, hdg) - geographisch, Grad
%                    antenna_height_m, id, time (als Text uebernommen)
%   Trennzeichen ',' oder ';' (Dezimalpunkt). Kopfzeile erforderlich.
%   Rueckgabe: struct mit Spaltenvektoren (fehlende optionale Spalten = NaN / leer).
    if ~isfile(csvPath)
        error('mrsim:csv:notFound', 'CSV nicht gefunden: %s', csvPath);
    end
    lines = regexp(fileread(csvPath), '\r?\n', 'split');
    lines = lines(~cellfun(@(s) isempty(strtrim(s)), lines));
    if numel(lines) < 2
        error('mrsim:csv:empty', 'CSV %s enthaelt keine Datenzeilen.', csvPath);
    end
    header = lines{1};
    if numel(strfind(header, ';')) > numel(strfind(header, ','))
        delim = ';';
    else
        delim = ',';
    end
    names = lower(strtrim(strsplit(header, delim)));
    names{1} = strrep(names{1}, char(65279), '');           % UTF-8-BOM (MATLAB dekodiert)
    names = regexprep(names, '^\xEF\xBB\xBF', '');          % UTF-8-BOM (Octave: Rohbytes)
    names = regexprep(names, '^"|"$', '');

    nRows = numel(lines) - 1;
    cells = cell(nRows, numel(names));
    for i = 1:nRows
        parts = strsplit(lines{i+1}, delim);
        parts(end+1:numel(names)) = {''};
        cells(i, :) = strtrim(regexprep(parts(1:numel(names)), '^"|"$', ''));
    end

    col = @(aliases) find(ismember(names, aliases), 1);
    iLat = col({'lat', 'latitude'});
    iLon = col({'lon', 'lng', 'longitude'});
    if isempty(iLat) || isempty(iLon)
        error('mrsim:csv:columns', 'CSV braucht Spalten "lat" und "lon" (gefunden: %s).', strjoin(names, ', '));
    end
    num = @(i) str2double(cells(:, i));

    trk.lat = num(iLat);
    trk.lon = num(iLon);
    bad = isnan(trk.lat) | isnan(trk.lon);
    if any(bad)
        error('mrsim:csv:nan', 'Ungueltige lat/lon in Zeile(n): %s', mat2str(find(bad).' + 1));
    end
    n = numel(trk.lat);

    iH = col({'heading_deg', 'heading', 'hdg'});
    if isempty(iH), trk.heading = nan(n, 1); else, trk.heading = num(iH); end
    trk.has_heading = ~isempty(iH);

    iA = col({'antenna_height_m', 'antenna_height'});
    if isempty(iA), trk.antenna_height = nan(n, 1); else, trk.antenna_height = num(iA); end

    iId = col({'id', 'frame'});
    if isempty(iId), trk.id = (1:n).'; else, trk.id = num(iId); end

    iT = col({'time', 't', 'timestamp'});
    if isempty(iT), trk.time = repmat({''}, n, 1); else, trk.time = cells(:, iT); end
end
