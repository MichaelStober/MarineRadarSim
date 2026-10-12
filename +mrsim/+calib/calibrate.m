function res = calibrate(cache, radar, scene, cfg)
%CALIBRATE  Gestufte Systemidentifikation der Simulationsparameter an echten Scans.
%
%   theta* = argmin_theta (1/K) sum_k D_k(theta)        (D_k: mrsim.calib.discrepancy)
%
%   Stufen (cfg.stages, Reihenfolge wie angegeben):
%     geometry   : Azimut-Offset per Kreuzkorrelation (estimateAzimuthOffset)
%     radiometry : Klassen-Offsets sigma0, STC, floor/sat
%     psf        : Keulenbreite, Nebenkeulen, Entfernungsaufloesung
%     texture    : Formparameter der K-Verteilung (See)
%     joint      : alle Optimierungsparameter gemeinsam, Start bei den Stufenwerten
%   In jeder Stufe werden nur deren Parameter variiert, alle anderen bleiben fest.
%   Grenzen [lb, ub] ueber logistische Transformation theta = lb + (ub-lb)/(1+exp(-x)).
%
%   res.radar, res.scene   kalibrierte Konfiguration
%   res.theta              Tabelle name/path/init/value/lb/ub/stage
%   res.D_init, res.D_final, res.history (D je Stufe), res.az_offset_per_scan,
%   res.cfg (inkl. Normierung; fuer vergleichbare Auswertung weiterer Scans)
    P = cfg.params;
    if ~iscell(P), P = num2cell(P); end
    names = cellfun(@(p) p.name, P, 'UniformOutput', false);
    paths = cellfun(@(p) p.path, P, 'UniformOutput', false);
    lb = cellfun(@(p) p.lb, P); ub = cellfun(@(p) p.ub, P);
    stg = cellfun(@(p) p.stage, P, 'UniformOutput', false);
    init = zeros(size(lb));
    for i = 1:numel(P), init(i) = mrsim.calib.getParam(radar, scene, paths{i}); end

    % Normierung der Terme auf ihre Werte bei theta_0 (siehe discrepancy.m)
    [~, Dk0] = mrsim.calib.evaluate(cache, radar, scene, cfg);
    nd = mean(cellfun(@(d) d.dist, Dk0)); ne = mean(cellfun(@(d) d.edge, Dk0));
    cfg.metric.norm_dist = max(nd, eps); cfg.metric.norm_edge = max(ne, eps);
    res.cfg = cfg;
    res.D_init = mrsim.calib.evaluate(cache, radar, scene, cfg);
    res.history = struct('stage', 'init', 'D', res.D_init);
    res.az_offset_per_scan = [];
    fprintf('Kalibrierung: %d Scans, D_init = %.4f\n', numel(cache), res.D_init);

    stages = cfg.stages; if ischar(stages), stages = {stages}; end
    for s = 1:numel(stages)
        st = stages{s};
        t0 = tic;
        if strcmp(st, 'geometry')
            if cfg.geometry.estimate_azimuth_offset
                [off, per] = mrsim.calib.estimateAzimuthOffset(cache, radar, scene, cfg);
                radar.azimuth_offset_deg = off;
                res.az_offset_per_scan = per;
                fprintf('  geometry: Azimut-Offset %.2f deg (je Scan: %s)\n', off, mat2str(per, 3));
            end
        else
            if strcmp(st, 'joint')
                sel = find(~strcmp(stg, 'geometry'));
                maxEv = cfg.optimizer.max_evals_joint;
            else
                sel = find(strcmp(stg, st));
                maxEv = cfg.optimizer.max_evals_per_stage;
            end
            if isempty(sel), continue; end
            x0 = zeros(numel(sel), 1);
            for i = 1:numel(sel)
                v = mrsim.calib.getParam(radar, scene, paths{sel(i)});
                x0(i) = toX(v, lb(sel(i)), ub(sel(i)));
            end
            f = @(x) objective(x, sel, paths, lb, ub, cache, radar, scene, cfg);
            xBest = runOptimizer(f, x0, lb(sel), ub(sel), names(sel), maxEv, cfg.optimizer.method, strcmp(st, 'joint'));
            for i = 1:numel(sel)
                [radar, scene] = mrsim.calib.setParam(radar, scene, paths{sel(i)}, toTheta(xBest(i), lb(sel(i)), ub(sel(i))));
            end
        end
        D = mrsim.calib.evaluate(cache, radar, scene, cfg);
        res.history(end+1) = struct('stage', st, 'D', D);
        fprintf('  %-10s D = %.4f  (%.0f s)\n', st, D, toc(t0));
    end

    val = zeros(size(init));
    for i = 1:numel(P), val(i) = mrsim.calib.getParam(radar, scene, paths{i}); end
    res.theta = struct('name', names, 'path', paths, 'init', num2cell(init), 'value', num2cell(val), ...
                       'lb', num2cell(lb), 'ub', num2cell(ub), 'stage', stg);
    res.D_final = res.history(end).D;
    res.radar = radar; res.scene = scene;
end

% ---------------------------------------------------------------------------
function D = objective(x, sel, paths, lb, ub, cache, radar, scene, cfg)
    for i = 1:numel(sel)
        [radar, scene] = mrsim.calib.setParam(radar, scene, paths{sel(i)}, toTheta(x(i), lb(sel(i)), ub(sel(i))));
    end
    D = mrsim.calib.evaluate(cache, radar, scene, cfg);
end

function th = toTheta(x, lb, ub)
    th = lb + (ub - lb) ./ (1 + exp(-x));
end

function x = toX(th, lb, ub)
    u = min(max((th - lb) / (ub - lb), 1e-4), 1 - 1e-4);
    x = log(u / (1 - u));
end

function xBest = runOptimizer(f, x0, lb, ub, names, maxEv, method, polish)
    useBayes = strcmpi(method, 'bayesopt') || ...
        (strcmpi(method, 'auto') && exist('bayesopt') ~= 0 && numel(x0) <= 10 && ~polish);
    if useBayes
        vars = [];
        for i = 1:numel(x0)
            v = optimizableVariable(matlab.lang.makeValidName(names{i}), [lb(i) ub(i)]);
            vars = [vars, v]; %#ok<AGROW>
        end
        th0 = lb(:).' + (ub(:).' - lb(:).') ./ (1 + exp(-x0(:).'));
        init = array2table(th0, 'VariableNames', {vars.Name});
        fb = @(T) f(arrayfun(@(i) toX(T{1, i}, lb(i), ub(i)), 1:numel(x0)).');
        r = bayesopt(fb, vars, 'MaxObjectiveEvaluations', maxEv, 'IsObjectiveDeterministic', true, ...
                     'InitialX', init, 'Verbose', 0, 'PlotFcn', []);
        thB = table2array(r.XAtMinObjective);
        xBest = arrayfun(@(i) toX(thB(i), lb(i), ub(i)), 1:numel(x0)).';
        % lokale Nachoptimierung
        opts = optimset('MaxFunEvals', round(maxEv / 2), 'Display', 'off', 'TolX', 1e-3, 'TolFun', 1e-5);
        xBest = fminsearch(f, xBest, opts);
    else
        opts = optimset('MaxFunEvals', maxEv, 'MaxIter', maxEv, 'Display', 'off', 'TolX', 1e-3, 'TolFun', 1e-5);
        xBest = fminsearch(f, x0, opts);
    end
end
