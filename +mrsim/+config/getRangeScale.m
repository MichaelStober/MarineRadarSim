function sc = getRangeScale(radar, rangeNm)
%GETRANGESCALE  Parameter der gewaehlten Range-Scale aus quantum2.json.
%   sc.nm, sc.dem_level_m, sc.prf_hz, sc.bandwidth_hz, sc.tx_pulse_s,
%   sc.pulse_width_3db_s plus abgeleitete Groessen:
%     sc.range_m      Radius der Scale [m] (1 NM = 1852 m)
%     sc.bin_m        Laenge eines Bins (= range_m * bin_range_factor / n_bins)
%     sc.res_m        3-dB-Entfernungsaufloesung c*tau/2
%     sc.pc_gain      Pulskompressionsgewinn max(1, tau_tx * B)
%     sc.pulses_per_spoke  PRF / (Umdrehungen/s * n_spokes)
    scales = radar.range_scales;
    if iscell(scales), scales = [scales{:}]; end
    idx = find([scales.nm] == rangeNm, 1);
    if isempty(idx)
        % z. B. echte Aufnahme mit 1.5 NM: Pulsparameter der naechstgelegenen Scale,
        % Geometrie mit der tatsaechlichen Range.
        [~, idx] = min(abs([scales.nm] - rangeNm));
        warning('mrsim:config:rangeScaleNearest', ...
            'Range-Scale %g NM nicht definiert -> Pulsparameter von %g NM verwendet.', rangeNm, scales(idx).nm);
        sc = scales(idx);
        sc.nm = rangeNm;
    else
        sc = scales(idx);
    end
    c = 299792458;
    sc.range_m = rangeNm * 1852;
    sc.bin_m   = sc.range_m * radar.bin_range_factor / radar.n_bins;
    sc.res_m   = c * sc.pulse_width_3db_s / 2;
    sc.pc_gain = max(1, sc.tx_pulse_s * sc.bandwidth_hz);
    rps = radar.rotation_rpm / 60;
    sc.pulses_per_spoke = sc.prf_hz / (rps * radar.n_spokes);
    lim = radar.prf_hz_limits;
    if sc.prf_hz < lim(1) || sc.prf_hz > lim(2)
        warning('mrsim:config:prf', 'PRF %g Hz ausserhalb Datenblattbereich [%g %g] Hz.', sc.prf_hz, lim(1), lim(2));
    end
end
