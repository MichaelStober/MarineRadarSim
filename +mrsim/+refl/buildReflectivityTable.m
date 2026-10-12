function lut = buildReflectivityTable(rcfg, fc)
%BUILDREFLECTIVITYTABLE  sigma0(Grazingwinkel, Klasse) als Lookup-Tabelle (linear, m^2/m^2).
%   lut.psi    1 x Q   Grazingwinkel-Gitter [deg] (0 ... 90, Schritt 0.05)
%   lut.table  Q x 5   Spalte k+1 = Klasse k (0 unbekannt -> 0, 1 See, 2 flach, 3 Wald, 4 Bebauung)
%   lut.source 1 x 5   Herkunft je Klasse (Toolbox-Modell oder Fallback)
%
%   Radar Toolbox (falls vorhanden):
%     See : seareflectivity(SS, psi, fc, Polarization="H", Model=rcfg.sea_model)
%           NRL gueltig 0.1-60 deg, SS 0-6  (MathWorks-Doku seareflectivity)
%     Land: landreflectivity(landType, psi, fc, Model=rcfg.land_model)
%           Nathanson gueltig 0-60 deg, Typen Desert/Farm/Woods/Jungle/RollingHills/Urban
%           (MathWorks-Doku landreflectivity). Barton waere erst ab 20 deg gueltig.
%   Ausserhalb [grazing_min, grazing_max]: unten constant-gamma-Extrapolation
%   sigma0 ~ sin(psi), oben Wert halten.
%   Fallback ohne Toolbox: constant gamma, sigma0 = gamma * sin(psi) (gamma_db aus der Szene).
    lut.psi = 0:0.05:90;
    Q = numel(lut.psi);
    lut.table = zeros(Q, 5);
    lut.source = repmat({''}, 1, 5);
    lut.source{1} = 'unknown->0';
    gmin = rcfg.grazing_min_deg; gmax = rcfg.grazing_max_deg;
    psiC = min(max(lut.psi, gmin), gmax);
    psiValid = unique(psiC);

    classes = rcfg.classes;
    if ~iscell(classes), classes = num2cell(classes); end

    for k = 1:numel(classes)
        c = classes{k};
        id = c.id;
        s = [];
        if strcmpi(c.name, 'sea')
            if exist('seareflectivity') ~= 0
                try
                    s = seareflectivity(rcfg.sea_state, psiValid(:), fc, ...
                        'Polarization', 'H', 'Model', rcfg.sea_model);
                    lut.source{id+1} = sprintf('seareflectivity %s SS%g', rcfg.sea_model, rcfg.sea_state);
                catch err
                    warning('mrsim:refl:sea', 'seareflectivity fehlgeschlagen (%s) -> constant gamma.', err.message);
                    s = [];
                end
            end
            gdb = rcfg.sea_gamma_db;
        else
            if exist('landreflectivity') ~= 0
                try
                    s = landreflectivity(c.land_type, psiValid(:), fc, 'Model', rcfg.land_model);
                    lut.source{id+1} = sprintf('landreflectivity %s %s', rcfg.land_model, c.land_type);
                catch err
                    warning('mrsim:refl:land', 'landreflectivity(%s) fehlgeschlagen (%s) -> constant gamma.', c.land_type, err.message);
                    s = [];
                end
            end
            gdb = c.gamma_db;
        end
        if ~isempty(s)
            s = s(:); okv = isfinite(s) & s >= 0;
            if nnz(okv) >= 2 && any(~okv)            % einzelne Luecken (Tabellenrand) interpolieren
                s(~okv) = interp1(psiValid(okv), s(okv), psiValid(~okv), 'nearest', 'extrap');
            elseif nnz(okv) < 2
                s = [];
            end
        end
        if isempty(s)
            s = 10^(gdb/10) * sind(psiValid(:));
            lut.source{id+1} = sprintf('constant gamma %g dB', gdb);
        end
        col = interp1(psiValid(:), s(:), psiC(:), 'linear', 'extrap');
        low = lut.psi < gmin;
        col(low) = col(low) .* sind(lut.psi(low)).' ./ sind(gmin);
        lut.table(:, id+1) = max(col, 0);
    end
end
