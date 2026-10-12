function scan = validateScan(scan, radar)
%VALIDATESCAN  Echten Scan pruefen und Standardwerte setzen (kanonisches Format).
%
%   Kanonisches Format eines echten Scans (eine Umdrehung), Pflichtfelder fett:
%     **pix**          n_spokes x n_bins uint8 (0..252), Zeile = Spoke, Spalte = Bin
%     **valid**        n_spokes x 1 logical, false = Spoke fehlt (nicht empfangen)
%     **lat, lon**     Antennenposition WGS84 [deg] zur Scanmitte
%     **range_nm**     eingestellte Range-Scale [NM]
%     heading_deg      geographisches Heading [deg]; NaN = unbekannt
%     orientation      'head-up' (Spoke 0 = Bug) | 'north-up' (Spoke 0 = Nord)
%     h_ant            Antennenhoehe [m]; NaN -> radar.antenna_height_m
%     time             Zeitstempel Scanmitte (Text, ISO 8601)
%     settings         struct mit Radareinstellungen (mode, gain_auto, gain, sea_auto,
%                      sea, sea_curve, rain, interference_rejection, target_expansion, ...)
%     env              Umgebungslabel, z. B. 'rostock_offshore', 'rostock_hafen'
%     id, source       Kennung, Herkunftsdatei
    req = {'pix', 'valid', 'lat', 'lon', 'range_nm'};
    for i = 1:numel(req)
        if ~isfield(scan, req{i}) || isempty(scan.(req{i}))
            error('mrsim:real:field', 'Scan ohne Pflichtfeld "%s".', req{i});
        end
    end
    [nS, nB] = size(scan.pix);
    if nS ~= radar.n_spokes || nB ~= radar.n_bins
        error('mrsim:real:size', 'Scan hat %dx%d statt %dx%d (Spokes x Bins).', nS, nB, radar.n_spokes, radar.n_bins);
    end
    scan.pix = uint8(min(scan.pix, radar.pixel_max));
    scan.valid = logical(scan.valid(:));
    if numel(scan.valid) ~= nS
        error('mrsim:real:valid', 'valid muss %d Eintraege haben.', nS);
    end
    scan.pix(~scan.valid, :) = 0;
    d = struct('heading_deg', NaN, 'orientation', '', 'h_ant', NaN, 'time', '', ...
               'settings', struct(), 'env', 'unbekannt', 'id', '', 'source', '');
    f = fieldnames(d);
    for i = 1:numel(f)
        if ~isfield(scan, f{i}) || isempty(scan.(f{i}))
            scan.(f{i}) = d.(f{i});
        end
    end
    if isempty(scan.orientation)
        if isnan(scan.heading_deg), scan.orientation = 'north-up'; else, scan.orientation = 'head-up'; end
    end
    if strcmp(scan.orientation, 'head-up') && isnan(scan.heading_deg)
        error('mrsim:real:heading', 'Scan %s ist head-up, aber ohne heading_deg.', scan.id);
    end
    if isnan(scan.h_ant), scan.h_ant = radar.antenna_height_m; end
end
