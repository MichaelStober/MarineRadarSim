function img = comparisonImage(entry, radarA, sceneA, radarB, sceneB, seed, nPx)
%COMPARISONIMAGE  Kartesisches Vergleichsbild [echt | Simulation A | Simulation B] (uint8).
%   Fehlende Spokes erscheinen in allen drei Teilbildern schwarz.
    if nargin < 7, nPx = 600; end
    R = entry.sc.range_m * radarA.bin_range_factor;
    simA = mrsim.calib.renderCached(entry, radarA, sceneA, seed);
    simB = mrsim.calib.renderCached(entry, radarB, sceneB, seed);
    toC = @(p) mrsim.render.polarToCart(p, entry.sc.bin_m, R, nPx);
    sep = 255 * ones(nPx, 4, 'uint8');
    img = [toC(entry.scan.pix), sep, toC(simA), sep, toC(simB)];
end
