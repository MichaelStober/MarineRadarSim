function scans = loadScans(src, radar)
%LOADSCANS  Echte Scans im kanonischen Format laden (.mat mit Variable "scan").
%   scans = mrsim.real.loadScans('data/real', radar)        % alle *.mat im Ordner
%   scans = mrsim.real.loadScans({'a.mat','b.mat'}, radar)
%   Rueckgabe: Zellarray validierter Scan-Structs (siehe validateScan).
    if ischar(src) && isfolder(src)
        d = dir(fullfile(src, '*.mat'));
        files = fullfile({d.folder}, {d.name});
    elseif ischar(src)
        files = {src};
    else
        files = src;
    end
    scans = cell(1, numel(files));
    for i = 1:numel(files)
        s = load(files{i}, 'scan');
        if ~isfield(s, 'scan')
            error('mrsim:real:load', '%s enthaelt keine Variable "scan".', files{i});
        end
        sc = s.scan;
        if isempty(sc.source), sc.source = files{i}; end
        scans{i} = mrsim.real.validateScan(sc, radar);
    end
end
