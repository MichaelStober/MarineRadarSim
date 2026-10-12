function [radar, scene] = setParam(radar, scene, path, value)
%SETPARAM  Parameter per Pfad setzen, z. B. 'radar.receiver.stc_max_db' oder
%   'scene.reflectivity.class_offset_db(2)'.
    [root, fields, idx] = parsePath(path);
    switch root
        case 'radar', radar = setIn(radar, fields, idx, value);
        case 'scene', scene = setIn(scene, fields, idx, value);
        otherwise, error('mrsim:calib:path', 'Pfad muss mit radar. oder scene. beginnen: %s', path);
    end
end

function s = setIn(s, fields, idx, value)
    if numel(fields) == 1
        if isempty(idx)
            s.(fields{1}) = value;
        else
            v = s.(fields{1}); v(idx) = value; s.(fields{1}) = v;
        end
    else
        if ~isfield(s, fields{1}), s.(fields{1}) = struct(); end
        s.(fields{1}) = setIn(s.(fields{1}), fields(2:end), idx, value);
    end
end

function [root, fields, idx] = parsePath(path)
    tok = regexp(path, '^(.*)\((\d+)\)$', 'tokens', 'once');
    if isempty(tok), p = path; idx = []; else, p = tok{1}; idx = str2double(tok{2}); end
    parts = strsplit(p, '.');
    root = parts{1}; fields = parts(2:end);
end
