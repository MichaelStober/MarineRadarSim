function s = getTileFile(f, maxTiles)
%GETTILEFILE  Gecachte Kachel (GeoTIFF-Schema) laden, mit prozesslokalem LRU-Speicher.
%   s.H, s.C, s.x0, s.y0, s.res. mrsim.dem.getTileFile('clear') leert den Speicher.
    persistent store order
    if strcmp(f, 'clear'), store = []; order = {}; s = []; return; end
    if isempty(store)
        store = containers.Map('KeyType', 'char', 'ValueType', 'any');
        order = {};
    end
    if isKey(store, f)
        s = store(f);
        order(strcmp(order, f)) = [];
        order{end+1} = f;
        return;
    end
    s = load(f, 'H', 'C', 'x0', 'y0', 'res');
    store(f) = s;
    order{end+1} = f;
    while numel(order) > maxTiles
        remove(store, order{1});
        order(1) = [];
    end
end
