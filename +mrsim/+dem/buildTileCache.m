function report = buildTileCache(scene, varargin)
%BUILDTILECACHE  DOM1-Kacheln (1 m) einmalig in Aufloesungspyramide umrechnen.
%   report = mrsim.dem.buildTileCache(scene)                 % scene = geladene scene_*.json
%   report = mrsim.dem.buildTileCache(scene, 'Force', true)  % alles neu rechnen
%
%   Je Kachel und Stufe L (scene.levels_m, z. B. 2/5/10 m) entsteht
%   <cache_dir>/L<L>m/t_<E>_<N>.mat mit
%     H  single  Hoehe je Block = MAXIMUM der 1-m-Werte (erhaelt Duenenkamm,
%                Gebaeudekanten -> korrekte Abschattung beim Ray-Casting)
%     C  uint8   Klasse je Block = Mehrheit der 1-m-Klassen (classifySurface)
%   Zeile 1 = Nordrand. Unvollstaendige/defekte Kacheln werden gemeldet und uebersprungen.
    p = inputParser;
    addParameter(p, 'Force', false);
    addParameter(p, 'Levels', []);
    parse(p, varargin{:});
    levels = p.Results.Levels;
    if isempty(levels), levels = scene.levels_m(:).'; end

    tileN = scene.tile_size_m;
    files = dir(fullfile(scene.dom_dir, '*.tif'));
    if isempty(files)
        error('mrsim:dem:noTiles', 'Keine .tif-Dateien in %s.', scene.dom_dir);
    end
    for L = levels
        if mod(tileN, L) ~= 0
            error('mrsim:dem:level', 'Stufe %g m teilt die Kachelgroesse %g m nicht.', L, tileN);
        end
        d = fullfile(scene.cache_dir, sprintf('L%gm', L));
        if ~isfolder(d), mkdir(d); end
    end

    report = struct('file', {}, 'status', {}, 'message', {});
    t0 = tic;
    for i = 1:numel(files)
        fn = files(i).name;
        [zone, Ekm, Nkm, ok] = mrsim.dem.parseTileName(fn, scene.dom_pattern);
        if ~ok || zone ~= scene.utm_zone
            report(end+1) = struct('file', fn, 'status', 'skipped', 'message', 'Name passt nicht zum Muster/Zone'); %#ok<AGROW>
            continue;
        end
        outs = arrayfun(@(L) fullfile(scene.cache_dir, sprintf('L%gm', L), ...
                        sprintf('t_%d_%d.mat', Ekm, Nkm)), levels, 'UniformOutput', false);
        if ~p.Results.Force && all(cellfun(@isfile, outs))
            report(end+1) = struct('file', fn, 'status', 'cached', 'message', ''); %#ok<AGROW>
            continue;
        end
        try
            Z = mrsim.dem.readDomTile(fullfile(files(i).folder, fn));
            if ~isequal(size(Z), [tileN tileN])
                error('Groesse %s statt %dx%d (Download unvollstaendig?)', mat2str(size(Z)), tileN, tileN);
            end
            bad = ~isfinite(Z) | Z < -1000;           % evtl. NoData-Werte
            if any(bad(:))
                Z(bad) = NaN;
            end
            Zf = Z; Zf(bad) = 0;
            C1 = mrsim.scene.classifySurface(Zf, scene.classification);
            C1(bad) = 0;
            for k = 1:numel(levels)
                L = levels(k);
                H = blockReduce(Z, L, 'max');
                C = blockMajority(C1, L, 4);
                E0 = Ekm * 1000; N0 = Nkm * 1000; res = L; %#ok<NASGU>
                save(outs{k}, 'H', 'C', 'E0', 'N0', 'res', '-v7');
            end
            report(end+1) = struct('file', fn, 'status', 'ok', 'message', ''); %#ok<AGROW>
        catch err
            report(end+1) = struct('file', fn, 'status', 'error', 'message', err.message); %#ok<AGROW>
            warning('mrsim:dem:tile', '%s: %s', fn, err.message);
        end
        if mod(i, 10) == 0 || i == numel(files)
            fprintf('  Cache %d/%d Kacheln (%.0f s)\n', i, numel(files), toc(t0));
        end
    end
    st = {report.status};
    fprintf('DOM-Cache: %d neu, %d vorhanden, %d Fehler, %d uebersprungen.\n', ...
        nnz(strcmp(st, 'ok')), nnz(strcmp(st, 'cached')), nnz(strcmp(st, 'error')), nnz(strcmp(st, 'skipped')));
end

function B = blockReduce(A, f, op)
    [m, n] = size(A);
    R = reshape(A, f, m/f, f, n/f);
    switch op
        case 'max'
            B = squeeze(max(max(R, [], 1), [], 3));   % NaN werden ignoriert
        case 'mean'
            B = squeeze(mean(mean(R, 1), 3));
    end
    B = reshape(B, m/f, n/f);
end

function B = blockMajority(C, f, nCls)
    [m, n] = size(C);
    best = zeros(m/f, n/f); B = zeros(m/f, n/f, 'uint8');
    for c = 0:nCls
        cnt = blockReduce(double(C == c), f, 'mean');
        sel = cnt > best;
        B(sel) = c; best(sel) = cnt(sel);
    end
end
