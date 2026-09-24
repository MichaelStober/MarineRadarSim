function cfg = loadJson(jsonPath)
%LOADJSON  JSON-Konfiguration lesen (jsondecode, MATLAB >= R2016b).
%   Felder, die mit '_' beginnen, sind Kommentare. MATLAB benennt solche
%   Felder beim Dekodieren um (z. B. 'x_comment'); sie werden ignoriert.
    if ~isfile(jsonPath)
        error('mrsim:config:notFound', 'Konfigurationsdatei nicht gefunden: %s', jsonPath);
    end
    txt = fileread(jsonPath);
    cfg = jsondecode(txt);
    cfg.source_file = jsonPath;
end
