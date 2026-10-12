function [pix, valid, tSpan] = assembleRotation(t, ang, data, nS, nB, unitsPerRev)
%ASSEMBLEROTATION  Einzelne Spoke-Nachrichten zu genau einer Umdrehung zusammensetzen.
%   t      Zeitstempel je Spoke [s] (aufsteigend)
%   ang    Winkel je Spoke in Einheiten 0..unitsPerRev-1
%   data   Zellarray der Amplitudenvektoren (uint8)
%   Ausgabe: pix (nS x nB uint8), valid (nS x 1), tSpan [t_start t_end] der Umdrehung.
%
%   Die Umdrehung beginnt beim ersten Ueberlauf des Winkels (ang faellt um mehr als
%   eine halbe Umdrehung) und endet beim naechsten. Gibt es keinen Ueberlauf, werden
%   alle Spokes verwendet. Doppelt belegte Spokes: der spaeteste gewinnt.
%   Nicht empfangene Spokes bleiben 0 und valid = false (fehlende Bearings).
    ang = double(ang(:)); t = double(t(:));
    wraps = find(diff(ang) < -unitsPerRev / 2) + 1;
    if numel(wraps) >= 2
        sel = wraps(1):(wraps(2) - 1);
    elseif numel(wraps) == 1 && wraps(1) > 1
        % nur ein Ueberlauf: den laengeren Teil nehmen
        if wraps(1) - 1 >= numel(ang) - wraps(1) + 1
            sel = 1:(wraps(1) - 1);
        else
            sel = wraps(1):numel(ang);
        end
    else
        sel = 1:numel(ang);
    end
    pix = zeros(nS, nB, 'uint8');
    valid = false(nS, 1);
    for j = sel
        k = mod(floor(ang(j) / unitsPerRev * nS), nS) + 1;
        v = uint8(data{j}(:).');
        n = min(numel(v), nB);
        row = zeros(1, nB, 'uint8');
        row(1:n) = v(1:n);
        pix(k, :) = row;
        valid(k) = true;
    end
    tSpan = [t(sel(1)) t(sel(end))];
end
