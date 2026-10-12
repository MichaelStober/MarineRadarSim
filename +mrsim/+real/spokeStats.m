function st = spokeStats(scans)
%SPOKESTATS  Statistik fehlender Spokes ueber echte Scans.
%   st.missing_frac       Anteil fehlender Spokes je Scan
%   st.per_spoke_freq     n_spokes x 1: Haeufigkeit, mit der Spoke k fehlt (systematische Bearings)
%   st.run_lengths        Laengen aller zusammenhaengenden Ausfallsektoren [Spokes] (zirkulaer)
%   st.runs_per_scan      Anzahl Ausfallsektoren je Scan
%   Grundlage fuer (a) Maskierung in der Kalibrierung und (b) mrsim.real.spokeDropout.
    n = numel(scans);
    nS = numel(scans{1}.valid);
    st.missing_frac = zeros(1, n);
    st.per_spoke_freq = zeros(nS, 1);
    st.run_lengths = [];
    st.runs_per_scan = zeros(1, n);
    for i = 1:n
        m = ~scans{i}.valid(:);
        st.missing_frac(i) = mean(m);
        st.per_spoke_freq = st.per_spoke_freq + m / n;
        rl = runLengths(m);
        st.run_lengths = [st.run_lengths, rl]; %#ok<AGROW>
        st.runs_per_scan(i) = numel(rl);
    end
    st.n_scans = n;
end

function rl = runLengths(m)
% zusammenhaengende true-Folgen, zirkulaer ueber Spoke nS -> 1
    rl = [];
    if ~any(m), return; end
    if all(m), rl = numel(m); return; end
    k = find(~m, 1);                       % bei einem gueltigen Spoke beginnen
    m = circshift(m, -(k-1));
    d = diff([0; m; 0]);
    s = find(d == 1); e = find(d == -1);
    rl = (e - s).';
end
