function [hdg, headUp, source] = resolveHeading(trk, E, N, gam, mode, fixedDeg)
%RESOLVEHEADING  Heading je Frame bestimmen (geographisch, Grad, im Uhrzeigersinn).
%   mode:
%     'auto'  : Spalte heading_deg vorhanden -> Head-up, sonst North-up
%     'north' : immer North-up (Spoke 0 = geographisch Nord)
%     'csv'   : Spalte heading_deg Pflicht
%     'cog'   : Kurs ueber Grund aus aufeinanderfolgenden Positionen
%   fixedDeg (nicht leer) ueberschreibt alles: konstantes Heading, Head-up.
%   Rueckgabe: hdg (n x 1, 0 bei North-up), headUp (logical n x 1), source (Text je Frame)
    n = numel(E);
    hdg = zeros(n, 1); headUp = false(n, 1); source = repmat({'north'}, n, 1);

    if ~isempty(fixedDeg)
        hdg(:) = mod(fixedDeg, 360); headUp(:) = true; source(:) = {'fixed'};
        return;
    end

    switch lower(mode)
        case 'north'
            % Defaults
        case {'auto', 'csv'}
            if trk.has_heading
                ok = ~isnan(trk.heading);
                hdg(ok) = mod(trk.heading(ok), 360);
                headUp(ok) = true; source(ok) = {'csv'};
                if any(~ok)
                    warning('mrsim:heading:nan', '%d Zeilen ohne Heading -> North-up.', nnz(~ok));
                end
            elseif strcmpi(mode, 'csv')
                error('mrsim:heading:missing', 'HeadingMode "csv", aber keine Spalte heading_deg in der CSV.');
            end
        case 'cog'
            if n < 2
                error('mrsim:heading:cog', 'HeadingMode "cog" braucht mindestens 2 Positionen.');
            end
            minMove = 1.0;                          % [m] darunter Kurs halten
            last = NaN;
            for i = 1:n
                if i < n, j0 = i; j1 = i + 1; else, j0 = i - 1; j1 = i; end
                dE = E(j1) - E(j0); dN = N(j1) - N(j0);
                if hypot(dE, dN) >= minMove
                    gridBrg = atan2d(dE, dN);
                    last = mod(gridBrg + gam(i), 360);  % Gitter -> geographisch
                end
                if ~isnan(last)
                    hdg(i) = last; headUp(i) = true; source{i} = 'cog';
                end
            end
        otherwise
            error('mrsim:heading:mode', 'Unbekannter HeadingMode "%s".', mode);
    end
end
