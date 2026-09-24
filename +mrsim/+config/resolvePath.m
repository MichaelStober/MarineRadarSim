function p = resolvePath(p, root)
%RESOLVEPATH  Relativen Pfad aus der Konfiguration gegen den Projektordner aufloesen.
    if isempty(p), return; end
    isAbs = (numel(p) >= 2 && p(2) == ':') || p(1) == '/' || p(1) == '\';
    if ~isAbs
        p = fullfile(root, p);
    end
end
