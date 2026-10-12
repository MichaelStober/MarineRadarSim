function [Dmean, Dk] = evaluate(cache, radar, scene, cfg)
%EVALUATE  Mittlere Abweichung D(theta) ueber alle Scans im Cache (Kalibrierziel).
%   Dmean = (1/K) sum_k D_k(theta),  D_k siehe mrsim.calib.discrepancy
    K = numel(cache);
    Dk = cell(1, K);
    tot = zeros(1, K);
    for k = 1:K
        e = cache{k};
        sim = mrsim.calib.renderCached(e, radar, scene, cfg.optimizer.seed + 1000 + k);
        Dk{k} = mrsim.calib.discrepancy(e.scan.pix, sim, e.scan.valid, e.land, e.sc.bin_m, ...
                                        cfg.metric, radar.pixel_max);
        tot(k) = Dk{k}.total;
    end
    Dmean = mean(tot);
end
