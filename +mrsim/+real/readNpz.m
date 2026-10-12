function S = readNpz(file)
%READNPZ  NumPy-.npz-Archiv lesen (ohne Python): struct mit einem Feld je Array.
%   .npz = ZIP aus .npy-Dateien (auch savez_compressed). Feldnamen werden zu
%   gueltigen MATLAB-Namen gemacht; S.keys_ enthaelt die Originalnamen.
    tmp = tempname();
    mkdir(tmp);
    c = onCleanup(@() rmdir(tmp, 's'));
    unzip(file, tmp);
    d = dir(fullfile(tmp, '*.npy'));
    S = struct(); keys = cell(1, numel(d));
    for i = 1:numel(d)
        [~, key] = fileparts(d(i).name);
        keys{i} = key;
        S.(matlab.lang.makeValidName(key)) = mrsim.real.readNpy(fullfile(tmp, d(i).name));
    end
    S.keys_ = keys;
end
