function report = buildTileCache(scene, varargin)
%BUILDTILECACHE  Hoehenkacheln einmalig in Aufloesungspyramide umrechnen.
%   scene.tile_scheme = "mv_named" (Default; DOM1 MV, Lage aus dem Dateinamen) oder
%   "geotiff" (Lage aus dem Dateikopf, beliebige Kachelgroesse/Aufloesung/CRS,
%   siehe mrsim.dem.buildTileCacheGeneric).
%   report = mrsim.dem.buildTileCache(scene)                 % scene = geladene scene_*.json
%   report = mrsim.dem.buildTileCache(scene, 'Force', true)  % alles neu rechnen
%
%   Je Kachel und Stufe L (scene.levels_m, z. B. 2/5/10 m) entsteht
%   <cache_dir>/L<L>m/t_<E>_<N>.mat mit
%     H  single  Hoehe je Block = MAXIMUM der 1-m-Werte (erhaelt Duenenkamm,
%                Gebaeudekanten -> korrekte Abschattung beim Ray-Casting)
%     C  uint8   Klasse je Block = Mehrheit der 1-m-Klassen (classifySurface)
%     dgm logical  true, wenn die Klassifikation das DGM genutzt hat
%   Zeile 1 = Nordrand. Unvollstaendige/defekte Kacheln werden gemeldet und uebersprungen.
%
%   DGM (optional, scene.dgm_dir / scene.dgm_pattern): gleiche Kachelung wie das DOM;
%   fehlt eine DGM-Kachel, wird fuer diese Kachel die DOM-Heuristik verwendet.
%   <cache_dir>/cache_stamp.json haelt Klassifikationsparameter + DGM-Ordner fest;
%   aendert sich etwas davon, wird der Cache automatisch neu gebaut.
    p = inputParser;
    addParameter(p, 'Force', false);
    addParameter(p, 'Levels', []);
    parse(p, varargin{:});
    levels = p.Results.Levels;
    if isempty(levels), levels = scene.levels_m(:).'; end

    % --- allgemeines GeoTIFF-Schema (Lage aus dem Dateikopf, z. B. Portugal) ----
    if isfield(scene, 'tile_scheme') && strcmpi(scene.tile_scheme, 'geotiff')
        stamp = jsonencode(struct('version', 3, 'scheme', 'geotiff', 'classification', scene.classification, ...
            'dom_dir', scene.dom_dir, 'levels', levels, 'nodata_below_m', scene.nodata_below_m));
        stampFile = fullfile(scene.cache_dir, 'cache_stamp.json');
        force = p.Results.Force;
        old = '';
        if isfile(stampFile), old = strtrim(fileread(stampFile)); end
        if ~force && ~strcmp(old, stamp) && ~isempty(dir(fullfile(scene.cache_dir, 'L*m', 'g_*.mat')))
            fprintf('Hoehen-Cache veraltet (Parameter geaendert) -> wird neu gebaut.\n');
            force = true;
        end
        if ~isfolder(scene.cache_dir), mkdir(scene.cache_dir); end
        report = mrsim.dem.buildTileCacheGeneric(scene, levels, force);
        fid = fopen(stampFile, 'w'); fprintf(fid, '%s', stamp); fclose(fid);
        return;
    end

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

    % --- DGM-Index und Stempel ----------------------------------------------
    dgmMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
    dgmDir = '';
    if isfield(scene, 'dgm_dir') && ~isempty(scene.dgm_dir) && isfolder(scene.dgm_dir)
        dgmDir = scene.dgm_dir;
        gf = dir(fullfile(dgmDir, '*.tif'));
        for j = 1:numel(gf)
            [zg, Eg, Ng, okg] = mrsim.dem.parseTileName(gf(j).name, scene.dgm_pattern);
            if okg && zg == scene.utm_zone
                dgmMap(sprintf('%d_%d', Eg, Ng)) = fullfile(gf(j).folder, gf(j).name);
            end
        end
    elseif isfield(scene, 'dgm_dir') && ~isempty(scene.dgm_dir)
        warning('mrsim:dem:noDgm', 'DGM-Ordner %s nicht gefunden -> nur DOM-Heuristik.', scene.dgm_dir);
    end
    stamp = jsonencode(struct('version', 2, 'classification', scene.classification, ...
                              'dgm_dir', dgmDir, 'n_dgm', dgmMap.Count));
    stampFile = fullfile(scene.cache_dir, 'cache_stamp.json');
    force = p.Results.Force;
    if ~force
        old = '';
        if isfile(stampFile), old = strtrim(fileread(stampFile)); end
        if ~strcmp(old, stamp) && ~isempty(dir(fullfile(scene.cache_dir, 'L*m', 't_*.mat')))
            fprintf('DOM-Cache veraltet (Klassifikation/DGM geaendert) -> wird neu gebaut.\n');
            force = true;
        end
    end

    report = struct('file', {}, 'status', {}, 'message', {});
    nNew = 0; nDgm = 0;
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
        if ~force && all(cellfun(@isfile, outs))
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
            G = [];
            key = sprintf('%d_%d', Ekm, Nkm);
            if isKey(dgmMap, key)
                try
                    G = mrsim.dem.readDomTile(dgmMap(key));
                    if ~isequal(size(G), [tileN tileN]), error('Groesse %s', mat2str(size(G))); end
                    G(~isfinite(G) | G < -1000) = NaN;     % NoData (z. B. -32767)
                catch errG
                    warning('mrsim:dem:dgmTile', 'DGM %s unbrauchbar (%s) -> Heuristik.', key, errG.message);
                    G = [];
                end
            end
            [C1, dgm] = mrsim.scene.classifySurface(Zf, scene.classification, G);
            C1(bad) = 0;
            nDgm = nDgm + dgm;
            for k = 1:numel(levels)
                L = levels(k);
                H = blockReduce(Z, L, 'max');
                C = blockMajority(C1, L, 4);
                E0 = Ekm * 1000; N0 = Nkm * 1000; res = L; %#ok<NASGU>
                save(outs{k}, 'H', 'C', 'E0', 'N0', 'res', 'dgm', '-v7');
            end
            report(end+1) = struct('file', fn, 'status', 'ok', 'message', ''); %#ok<AGROW>
            nNew = nNew + 1;
        catch err
            report(end+1) = struct('file', fn, 'status', 'error', 'message', err.message); %#ok<AGROW>
            warning('mrsim:dem:tile', '%s: %s', fn, err.message);
        end
        if nNew > 0 && (mod(i, 10) == 0 || i == numel(files))
            fprintf('  Cache %d/%d Kacheln (%.0f s)\n', i, numel(files), toc(t0));
        end
    end
    fid = fopen(stampFile, 'w'); fprintf(fid, '%s', stamp); fclose(fid);
    st = {report.status};
    if nNew > 0 || any(strcmp(st, 'error'))
        fprintf('DOM-Cache: %d neu (%d mit DGM), %d vorhanden, %d Fehler, %d uebersprungen.\n', ...
            nNew, nDgm, nnz(strcmp(st, 'cached')), nnz(strcmp(st, 'error')), nnz(strcmp(st, 'skipped')));
    end
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
