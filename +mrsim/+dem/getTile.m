function [H, C, found] = getTile(cacheDir, level, Ekm, Nkm, maxTiles)
%GETTILE  Gecachte Kachel laden, mit prozesslokalem LRU-Speicher.
%   Jeder parfor-Worker haelt seinen eigenen Speicher (persistent).
%   mrsim.dem.getTile('clear') leert den Speicher.
    persistent store order
    if nargin == 1 && ischar(cacheDir) && strcmp(cacheDir, 'clear')
        store = []; order = {}; H = []; C = []; found = false;
        return;
    end
    if isempty(store)
        store = containers.Map('KeyType', 'char', 'ValueType', 'any');
        order = {};
    end
    key = sprintf('%g|%d|%d|%s', level, Ekm, Nkm, cacheDir);
    if isKey(store, key)
        v = store(key);
        H = v.H; C = v.C; found = v.found;
        order(strcmp(order, key)) = [];
        order{end+1} = key;
        return;
    end
    f = fullfile(cacheDir, sprintf('L%gm', level), sprintf('t_%d_%d.mat', Ekm, Nkm));
    if isfile(f)
        s = load(f, 'H', 'C');
        H = s.H; C = s.C; found = true;
    else
        H = []; C = []; found = false;
    end
    store(key) = struct('H', H, 'C', C, 'found', found);
    order{end+1} = key;
    while numel(order) > maxTiles
        remove(store, order{1});
        order(1) = [];
    end
end
