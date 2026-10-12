function report = buildTileCacheGeneric(scene, levels, force)
%BUILDTILECACHEGENERIC  Cache fuer beliebige georeferenzierte GeoTIFF-Kacheln
%   (scene.tile_scheme = "geotiff"; z. B. DGT MDS 50 cm Portugal, EPSG:3763).
%   Aufruf ueber mrsim.dem.buildTileCache.
%
%   Unterschiede zum MV-Schema:
%   - Lage, Groesse, Aufloesung und NoData kommen aus dem Dateikopf (readTileInfo),
%     Kacheln duerfen unterschiedlich gross sein (Rand des Befliegungsgebiets).
%   - Jede Kachel wird mit NaN auf das Raster der groessten Stufe Lmax ausgerichtet
%     (Ecken auf Vielfachen von Lmax), damit alle Stufen ganzzahlig passen.
%   - Klassifikation auf 1-m-Raster (Hoehe = Blockmittel), wenn die Kachel feiner ist;
%     die Fenstergroessen in scene.classification gelten damit wie bei MV in Metern.
%   - Hoehe je Stufe = Block-MAXIMUM der Originalwerte (wie MV).
%   Ausgabe: <cache_dir>/L<L>m/g_<Name>.mat (H, C, x0, y0, res, dgm) und index.mat.
    files = dir(fullfile(scene.dom_dir, getf(scene, 'dom_glob', '*.tif')));
    if isempty(files)
        error('mrsim:dem:noTiles', 'Keine Kacheln (%s) in %s.', getf(scene, 'dom_glob', '*.tif'), scene.dom_dir);
    end
    Lmax = max(levels);
    if any(mod(Lmax, levels) ~= 0)
        error('mrsim:dem:levels', 'Alle Stufen muessen die groesste Stufe (%g m) teilen.', Lmax);
    end
    nodataBelow = getf(scene, 'nodata_below_m', -1000);
    for L = levels
        d = fullfile(scene.cache_dir, sprintf('L%gm', L));
        if ~isfolder(d), mkdir(d); end
    end

    report = struct('file', {}, 'status', {}, 'message', {});
    nNew = 0; t0 = tic;
    for i = 1:numel(files)
        fn = files(i).name;
        [~, stem] = fileparts(fn);
        key = regexprep(stem, '[^A-Za-z0-9_\-]', '_');
        outs = arrayfun(@(L) fullfile(scene.cache_dir, sprintf('L%gm', L), ['g_' key '.mat']), ...
                        levels, 'UniformOutput', false);
        if ~force && all(cellfun(@isfile, outs))
            report(end+1) = struct('file', fn, 'status', 'cached', 'message', ''); %#ok<AGROW>
            continue;
        end
        try
            src = fullfile(files(i).folder, fn);
            t = mrsim.dem.readTileInfo(src);
            Z = mrsim.dem.readDomTile(src);
            if ~isequal(size(Z), [t.nr t.nc]), error('Pixelgroesse passt nicht zum Dateikopf'); end
            if t.flip, Z = flipud(Z); end
            bad = ~isfinite(Z) | Z < nodataBelow;
            if ~isempty(t.nodata), bad = bad | Z == t.nodata; end
            Z(bad) = NaN;

            % --- auf Lmax-Raster ausrichten ---------------------------------
            r = t.res;
            xa0 = floor(t.x0 / Lmax) * Lmax;
            ya1 = ceil(t.y1 / Lmax) * Lmax;
            xa1 = ceil((t.x0 + t.nc * r) / Lmax) * Lmax;
            ya0 = floor((t.y1 - t.nr * r) / Lmax) * Lmax;
            pc = round((t.x0 - xa0) / r); pr = round((ya1 - t.y1) / r);
            Zp = nan(round((ya1 - ya0) / r), round((xa1 - xa0) / r), 'single');
            Zp(pr + (1:t.nr), pc + (1:t.nc)) = Z;
            badp = isnan(Zp);

            % --- Klassifikation auf 1-m-Raster (bzw. nativ, wenn groeber) -------
            if r < 1
                f1 = round(1 / r);
                if abs(f1 * r - 1) > 1e-9, error('Aufloesung %g m teilt 1 m nicht', r); end
                Zc = blockReduce(fillNan(Zp), f1, 'mean');
                badc = blockReduce(double(badp), f1, 'mean') > 0.5;
                rc = 1;
            else
                Zc = fillNan(Zp); badc = badp; rc = r;
            end
            C1 = mrsim.scene.classifySurface(Zc, scene.classification);
            C1(badc) = 0;

            for k = 1:numel(levels)
                L = levels(k);
                fH = round(L / r); fC = round(L / rc);
                H = blockReduce(Zp, fH, 'max');                 %#ok<NASGU>
                C = blockMajority(C1, fC, 4);                    %#ok<NASGU>
                x0 = xa0; y0 = ya1; res = L; dgm = false;        %#ok<NASGU>
                save(outs{k}, 'H', 'C', 'x0', 'y0', 'res', 'dgm', '-v7');
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
    for L = levels
        writeIndex(fullfile(scene.cache_dir, sprintf('L%gm', L)));
    end
    st = {report.status};
    if nNew > 0 || any(strcmp(st, 'error'))
        fprintf('Hoehen-Cache: %d neu, %d vorhanden, %d Fehler.\n', nNew, nnz(strcmp(st, 'cached')), nnz(strcmp(st, 'error')));
    end
end

% ---------------------------------------------------------------------------
function writeIndex(d)
% Ausdehnung aller gecachten Kacheln einer Stufe -> index.mat (fuer loadRegionGeneric)
    f = dir(fullfile(d, 'g_*.mat'));
    n = numel(f);
    x0 = zeros(n, 1); x1 = x0; y0 = x0; y1 = x0; files = cell(n, 1);
    for i = 1:n
        s = load(fullfile(d, f(i).name), 'x0', 'y0', 'res', 'H');
        files{i} = f(i).name;
        x0(i) = s.x0; y1(i) = s.y0;
        x1(i) = s.x0 + size(s.H, 2) * s.res;
        y0(i) = s.y0 - size(s.H, 1) * s.res;
    end
    save(fullfile(d, 'index.mat'), 'x0', 'x1', 'y0', 'y1', 'files', '-v7');
end

function v = getf(s, f, d)
    if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end

function Z = fillNan(Z)
    Z = double(Z); Z(isnan(Z)) = 0;
end

function B = blockReduce(A, f, op)
    [m, n] = size(A);
    R = reshape(A, f, m/f, f, n/f);
    switch op
        case 'max'
            B = squeeze(max(max(R, [], 1), [], 3));
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
