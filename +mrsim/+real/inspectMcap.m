function info = inspectMcap(bagPath, maxDepth)
%INSPECTMCAP  Topics, Nachrichtentypen und Feldstruktur einer ROS-2-Aufnahme (MCAP) anzeigen.
%   info = mrsim.real.inspectMcap('C:\...\aufnahme_ordner')
%   Benoetigt ROS Toolbox ab R2024a (MCAP-Unterstuetzung in ros2bagreader); ab R2025a
%   werden auch nicht registrierte (eigene) Nachrichtentypen gelesen.
%   Hilft beim Ausfuellen von config/real_mcap_mapping.json.
    if nargin < 2, maxDepth = 4; end
    if exist('ros2bagreader') == 0
        error('mrsim:real:ros', 'ros2bagreader nicht gefunden (ROS Toolbox >= R2024a noetig).');
    end
    bag = ros2bagreader(bagPath);
    t = bag.AvailableTopics;
    fprintf('Aufnahme: %s\nZeit: %.3f .. %.3f s (%.1f s)\n\n', bagPath, bag.StartTime, bag.EndTime, bag.EndTime - bag.StartTime);
    disp(t(:, intersect({'NumMessages', 'MessageType'}, t.Properties.VariableNames, 'stable')));
    topics = t.Properties.RowNames;
    info = struct('topic', topics, 'type', '', 'fields', '');
    for i = 1:numel(topics)
        sel = select(bag, 'Topic', topics{i});
        if sel.NumMessages == 0, continue; end
        m = readMessages(sel, 1);
        info(i).type = char(string(t.MessageType(i)));
        fprintf('\n=== %s  [%s]\n', topics{i}, info(i).type);
        info(i).fields = printTree(m{1}, '  ', maxDepth);
    end
end

function lines = printTree(s, ind, depth)
    lines = {};
    if ~isstruct(s) || depth == 0, return; end
    f = fieldnames(s);
    for k = 1:numel(f)
        v = s(1).(f{k});
        if isstruct(v)
            fprintf('%s%s (struct)\n', ind, f{k});
            lines = [lines, printTree(v, [ind '  '], depth - 1)]; %#ok<AGROW>
        else
            if ischar(v) || isstring(v)
                val = char(v); if numel(val) > 40, val = [val(1:40) '...']; end
                fprintf('%s%s = "%s"\n', ind, f{k}, val);
            elseif isnumeric(v) || islogical(v)
                if numel(v) <= 4
                    fprintf('%s%s = %s  (%s)\n', ind, f{k}, mat2str(double(v(:).'), 6), class(v));
                else
                    fprintf('%s%s: %s %s, min %g max %g\n', ind, f{k}, mat2str(size(v)), class(v), double(min(v(:))), double(max(v(:))));
                end
            else
                fprintf('%s%s (%s)\n', ind, f{k}, class(v));
            end
            lines{end+1} = f{k}; %#ok<AGROW>
        end
    end
end
