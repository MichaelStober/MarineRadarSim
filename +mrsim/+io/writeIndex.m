function writeIndex(outDir, rows)
%WRITEINDEX  index.csv: eine Zeile je Frame (Pose, Heading, Dateien).
    f = fullfile(outDir, 'index.csv');
    fid = fopen(f, 'w');
    if fid < 0, error('mrsim:io:index', 'Kann %s nicht schreiben.', f); end
    c = onCleanup(@() fclose(fid));
    fprintf(fid, ['frame,id,lat,lon,easting,northing,gamma_deg,heading_deg,orientation,' ...
                  'heading_source,antenna_height_m,range_nm,bin_m,missing_frac,time,polar_png,cart_png\n']);
    for i = 1:numel(rows)
        r = rows(i);
        fprintf(fid, '%d,%g,%.8f,%.8f,%.3f,%.3f,%.4f,%.3f,%s,%s,%.2f,%g,%.4f,%.4f,%s,%s,%s\n', ...
            r.frame, r.id, r.lat, r.lon, r.E, r.N, r.gamma, r.heading, r.orientation, ...
            r.heading_source, r.h_ant, r.range_nm, r.bin_m, r.missing_frac, r.time, r.polar_png, r.cart_png);
    end
end
