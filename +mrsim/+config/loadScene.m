function scene = loadScene(scenePath, root)
%LOADSCENE  Szenenkonfiguration laden, maschinenspezifische Pfade aus config/local.json
%   ueberlagern und relative Pfade gegen den Projektordner aufloesen.
%
%   config/local.json (NICHT eingecheckt, Vorlage: config/local.example.json):
%     { "scene_rostock": { "dom_dir": "/home/<user>/data/rostock_dom",
%                          "dgm_dir": "/home/<user>/data/rostock_dem" } }
%   Schluessel = Dateiname der Szene ohne Endung. So laeuft dasselbe Repo unter
%   Windows und Linux, ohne dass Pfade im Repo geaendert werden muessen.
    if nargin < 2, root = fileparts(fileparts(fileparts(mfilename('fullpath')))); end
    scene = mrsim.config.loadJson(scenePath);
    [~, key] = fileparts(scenePath);
    localFile = fullfile(root, 'config', 'local.json');
    if isfile(localFile)
        loc = jsondecode(fileread(localFile));
        k = matlab.lang.makeValidName(key);
        if isfield(loc, k)
            ov = loc.(k);
            f = fieldnames(ov);
            for i = 1:numel(f)
                scene.(f{i}) = ov.(f{i});
            end
        end
    end
    for f = {'dom_dir', 'dgm_dir', 'cache_dir'}
        if isfield(scene, f{1})
            scene.(f{1}) = mrsim.config.resolvePath(scene.(f{1}), root);
        end
    end
    % Punktziele (Tonnen/Baken) einmalig laden
    if isfield(scene, 'targets') && isfield(scene.targets, 'file') && ~isempty(scene.targets.file)
        f = mrsim.config.resolvePath(scene.targets.file, root);
        if isfile(f)
            scene.targets_data = mrsim.scene.loadTargets(f, scene, scene.targets);
        else
            warning('mrsim:targets:missing', 'Zieldatei %s nicht gefunden -> keine Punktziele.', f);
        end
    end
end
