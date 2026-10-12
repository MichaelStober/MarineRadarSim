function [pix, valid] = spokeDropout(pix, st, varargin)
%SPOKEDROPOUT  Fehlende Spokes auf ein (simuliertes) Polarbild uebertragen (Augmentierung).
%   [pix, valid] = mrsim.real.spokeDropout(pix, st)               % st aus mrsim.real.spokeStats
%   [pix, valid] = mrsim.real.spokeDropout(pix, [], 'NumRuns', 3, 'MeanRun', 20)
%
%   Mit st: Anzahl Ausfallsektoren und deren Laengen werden aus der empirischen
%   Verteilung der echten Scans gezogen; Startpositionen gewichtet mit
%   st.per_spoke_freq (systematische Bearings) plus gleichverteilter Anteil
%   'Uniform' (Default 0.5), damit das Netz nicht nur feste Sektoren lernt.
%   Ohne st: Poisson-Anzahl (NumRuns) mit geometrisch verteilten Laengen (MeanRun).
    p = inputParser;
    addParameter(p, 'NumRuns', 2);
    addParameter(p, 'MeanRun', 10);
    addParameter(p, 'Uniform', 0.5);
    parse(p, varargin{:});
    o = p.Results;
    nS = size(pix, 1);
    valid = true(nS, 1);

    if ~isempty(st) && ~isempty(st.run_lengths)
        nRuns = st.runs_per_scan(randi(numel(st.runs_per_scan)));
        lens = st.run_lengths(randi(numel(st.run_lengths), 1, nRuns));
        w = st.per_spoke_freq(:);
        if sum(w) > 0, w = w / sum(w); else, w = ones(nS, 1) / nS; end
        w = (1 - o.Uniform) * w + o.Uniform / nS;
    else
        nRuns = poissrnd_(o.NumRuns);
        lens = max(1, ceil(-log(rand(1, nRuns)) * o.MeanRun));
        w = ones(nS, 1) / nS;
    end
    cw = cumsum(w);
    for k = 1:nRuns
        s0 = find(cw >= rand * cw(end), 1);
        idx = mod(s0 - 1 + (0:lens(k)-1), nS) + 1;
        valid(idx) = false;
    end
    pix(~valid, :) = 0;
end

function k = poissrnd_(lam)
% Poisson ohne Statistics Toolbox (Knuth)
    L = exp(-lam); k = 0; p = 1;
    while true
        p = p * rand;
        if p <= L, break; end
        k = k + 1;
    end
end
