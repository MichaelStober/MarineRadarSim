function prm = crsParams(crs)
%CRSPARAMS  Projektionsparameter (transversale Mercator) aus Szene, crs-Struct oder UTM-Zone.
    if isnumeric(crs)
        prm = utm(crs); return;
    end
    if isfield(crs, 'crs')                    % ganze Szene uebergeben
        c = crs.crs;
    elseif isfield(crs, 'utm_zone')
        prm = utm(crs.utm_zone); return;
    else
        c = crs;
    end
    switch lower(c.type)
        case 'utm'
            prm = utm(c.zone);
        case 'tm'
            prm = struct('lat0', c.lat0, 'lon0', c.lon0, 'k0', c.k0, ...
                         'false_easting', c.false_easting, 'false_northing', c.false_northing);
        otherwise
            error('mrsim:geo:crs', 'Unbekannter crs.type "%s" (erlaubt: utm, tm).', c.type);
    end
end

function prm = utm(zone)
    prm = struct('lat0', 0, 'lon0', -183 + 6*zone, 'k0', 0.9996, ...
                 'false_easting', 500000, 'false_northing', 0);
end
