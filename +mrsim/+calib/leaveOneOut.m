function T = leaveOneOut(cache, radar, scene, cfg)
%LEAVEONEOUT  Kreuzvalidierung der Kalibrierung: je Scan auf den uebrigen kalibrieren,
%   auf dem ausgelassenen Scan auswerten (Generalisierung statt Anpassung).
%   T(k): id, env, D_default (unkalibriert), D_holdout (theta aus den anderen Scans),
%         D_train (mittlere Abweichung auf den Trainingsscans).
%   Bei K < 2 Scans nicht moeglich.
    K = numel(cache);
    if K < 2, error('mrsim:calib:loo', 'Leave-one-out braucht mindestens 2 Scans.'); end
    T = struct('id', {}, 'env', {}, 'D_default', {}, 'D_holdout', {}, 'D_train', {});
    for k = 1:K
        tr = cache(setdiff(1:K, k));
        fprintf('LOO %d/%d: Test = %s\n', k, K, cache{k}.scan.id);
        r = mrsim.calib.calibrate(tr, radar, scene, cfg);
        D0 = mrsim.calib.evaluate(cache(k), radar, scene, r.cfg);      % gleiche Normierung
        Dh = mrsim.calib.evaluate(cache(k), r.radar, r.scene, r.cfg);
        T(end+1) = struct('id', cache{k}.scan.id, 'env', cache{k}.scan.env, ...
                          'D_default', D0, 'D_holdout', Dh, 'D_train', r.D_final); %#ok<AGROW>
    end
end
