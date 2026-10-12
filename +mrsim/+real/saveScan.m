function saveScan(scan, file)
%SAVESCAN  Echten Scan im kanonischen Format speichern (Variable "scan", -v7).
%   Felder siehe mrsim.real.validateScan. Zusaetzlich eine PNG-Vorschau des Polarbilds.
    [d, ~] = fileparts(file);
    if ~isempty(d) && ~isfolder(d), mkdir(d); end
    save(file, 'scan', '-v7');
    [p, n] = fileparts(file);
    imwrite(scan.pix, fullfile(p, [n '_polar.png']));
end
