function [pix, snr] = renderCached(entry, radar, scene, seed)
%RENDERCACHED  Simuliertes Polarbild aus vorbereiteter Szenenantwort (billig).
%   Rauschen mit festem Seed (common random numbers), Ausgabe wie die echte Aufnahme
%   inkl. ausgeblendeter fehlender Spokes.
    rng(seed);
    out = mrsim.render.sensorModel(entry.resp, radar, entry.sc, scene);
    snr = out.snr_db;
    pix = mrsim.render.receiverChain(snr, entry.sc.bin_m, radar);
    pix(~entry.scan.valid, :) = 0;
end
