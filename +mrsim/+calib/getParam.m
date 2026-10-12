function v = getParam(radar, scene, path)
%GETPARAM  Parameter per Pfad lesen (Gegenstueck zu mrsim.calib.setParam).
    tok = regexp(path, '^(.*)\((\d+)\)$', 'tokens', 'once');
    if isempty(tok), p = path; idx = []; else, p = tok{1}; idx = str2double(tok{2}); end
    parts = strsplit(p, '.');
    switch parts{1}
        case 'radar', v = radar;
        case 'scene', v = scene;
        otherwise, error('mrsim:calib:path', 'Pfad muss mit radar. oder scene. beginnen: %s', path);
    end
    for k = 2:numel(parts), v = v.(parts{k}); end
    if ~isempty(idx), v = v(idx); end
end
