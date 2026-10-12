function out = ppiFast(reg, pose, radar, sc, scene, lut)
%PPIFAST  Schnelles PPI per Ray-Casting ueber das DOM (primaeres Backend).
%   = mrsim.render.sensorModel( mrsim.render.sceneResponse(...) )
%   out.snr_db     n_spokes x n_bins  SNR [dB] je Spoke/Bin (Rauschen = 0 dB)
%   out.land_frac  n_spokes x n_bins  Anteil Landklassen (Ground Truth, ohne Sichtbarkeit)
%   out.vis_frac   n_spokes x n_bins  Anteil sichtbarer Feinzellen
%   out.resp       Szenenantwort (fuer Kalibrierung wiederverwendbar)
%   Modell und Formeln: sceneResponse.m (Geometrie, Radargleichung) und
%   sensorModel.m (Faltung mit Antennen-/Pulsantwort, Rauschen).
    resp = mrsim.render.sceneResponse(reg, pose, radar, sc, scene, lut);
    out = mrsim.render.sensorModel(resp, radar, sc, scene);
    ovA = resp.ovA; ovR = resp.ovR;
    out.land_frac = single(blockMean(double(resp.cls >= 2), ovA, ovR));
    out.vis_frac  = single(blockMean(double(resp.vis), ovA, ovR));
    out.resp = resp;
end

function B = blockMean(A, fa, fr)
    [m, n] = size(A);
    B = reshape(mean(mean(reshape(A, fa, m/fa, fr, n/fr), 1), 3), m/fa, n/fr);
end
