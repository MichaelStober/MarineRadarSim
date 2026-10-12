function S = inspectNpz(file)
%INSPECTNPZ  Inhalt einer .npz-Datei auflisten (Schluessel, Groesse, Typ, Wertebereich).
%   Hilft beim Ausfuellen von config/real_npz_mapping.json.
    S = mrsim.real.readNpz(file);
    fprintf('%s\n', file);
    for i = 1:numel(S.keys_)
        v = S.(matlab.lang.makeValidName(S.keys_{i}));
        if isempty(v)
            fprintf('  %-20s (leer oder nicht unterstuetzter Typ)\n', S.keys_{i});
        else
            fprintf('  %-20s %-14s %-8s min %g  max %g\n', S.keys_{i}, mat2str(size(v)), class(v), ...
                double(min(v(:))), double(max(v(:))));
        end
    end
    k = find(cellfun(@(key) ndims(S.(matlab.lang.makeValidName(key))) == 2 && ...
             all(size(S.(matlab.lang.makeValidName(key))) > 100), S.keys_), 1);
    if ~isempty(k)
        v = S.(matlab.lang.makeValidName(S.keys_{k}));
        z = all(v == 0, 2);
        fprintf('  -> "%s": %d von %d Zeilen komplett 0 (moegliche fehlende Spokes)\n', S.keys_{k}, nnz(z), size(v, 1));
    end
end
