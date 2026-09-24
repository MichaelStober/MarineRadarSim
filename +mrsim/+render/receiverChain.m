function pix = receiverChain(snrDb, binM, radar)
%RECEIVERCHAIN  SNR [dB] -> Pixelwerte 0..pixel_max (uint8), wie Quantum-2-Spokes.
%   1) STC: Daempfung im Nahbereich  A(r) = min(stc_max_db, 10*stc_exponent*log10(stc_range/r))
%   2) Gain-Offset gain_db
%   3) Log-Abbildung: floor_db -> 0, sat_db -> pixel_max, dazwischen linear in dB
%   Alle Parameter in quantum2.json/receiver (Annahmen, an echten Aufnahmen kalibrieren).
    rc = radar.receiver;
    nB = size(snrDb, 2);
    r = ((1:nB) - 0.5) * binM;
    stc = zeros(1, nB);
    near = r < rc.stc_range_m;
    stc(near) = min(rc.stc_max_db, 10 * rc.stc_exponent * log10(rc.stc_range_m ./ r(near)));
    v = double(snrDb) - stc + rc.gain_db;
    v = (v - rc.floor_db) / (rc.sat_db - rc.floor_db) * radar.pixel_max;
    pix = uint8(min(max(round(v), 0), radar.pixel_max));
end
