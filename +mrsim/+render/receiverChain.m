function pix = receiverChain(snrDb, binM, radar)
%RECEIVERCHAIN  SNR [dB] -> Pixelwerte 0..pixel_max (uint8), Anzeigekette nach Quantum-Art.
%
%   Modell (docs/MODELL.md, Abschnitt Empfaengerkette; Herleitung in
%   docs/RECHERCHE_ENTFERNUNGSABFALL.md, Kap. 3.3):
%
%     x(r)  = SNR_dB(r) - A_sea(r) + G(r)                         [dB]
%     A_sea = min(sea_max_db, 10*sea_exponent*log10(sea_range_m/r))   fuer r < sea_range_m, sonst 0
%     G(r)  = min(max(range_gain_db_per_decade*log10(r/range_gain_r0_m), 0), range_gain_max_db)
%     pix   = pixel_max * clip( (x - threshold_db) / dynamic_range_db, 0, 1 )
%
%   SNR ist auf die mittlere Rauschleistung bezogen (Rauschen = 0 dB). threshold_db ist damit
%   die Gain-Schwelle relativ zum Rauschen ("Gain sets the detection threshold", Raymarine),
%   dynamic_range_db der Abstand Schwelle -> Weiss (Log-Abbildung mit frueher Saettigung).
%   A_sea entspricht der Sea-Clutter-Kurve (Daempfung nahe am Schiff), G(r) dem STC-Preset
%   ("equalize targets across the image"). Alle Parameter in quantum2.json/receiver sind
%   Annahmen und werden kalibriert (config/calibration.json).
    rc = radar.receiver;
    nB = size(snrDb, 2);
    r = ((1:nB) - 0.5) * binM;

    aSea = zeros(1, nB);
    if rc.sea_max_db > 0 && rc.sea_range_m > 0
        near = r < rc.sea_range_m;
        aSea(near) = min(rc.sea_max_db, 10 * rc.sea_exponent * log10(rc.sea_range_m ./ r(near)));
    end
    gR = zeros(1, nB);
    if rc.range_gain_db_per_decade ~= 0 && rc.range_gain_max_db > 0
        gR = min(max(rc.range_gain_db_per_decade * log10(r / rc.range_gain_r0_m), 0), rc.range_gain_max_db);
    end

    x = double(snrDb) - aSea + gR;
    v = (x - rc.threshold_db) / max(rc.dynamic_range_db, eps);
    pix = uint8(round(min(max(v, 0), 1) * radar.pixel_max));
end
