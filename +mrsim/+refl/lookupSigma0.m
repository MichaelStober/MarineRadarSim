function s0 = lookupSigma0(lut, psiDeg, cls)
%LOOKUPSIGMA0  sigma0 [m^2/m^2] fuer Grazingwinkel psiDeg [deg] und Klasse cls (0..4).
%   psi <= 0 (abgewandte Flaeche) -> 0.
    dpsi = lut.psi(2) - lut.psi(1);
    iq = round(min(max(psiDeg, 0), 90) / dpsi) + 1;
    ic = double(cls) + 1;
    s0 = lut.table(sub2ind(size(lut.table), iq, ic));
    s0(psiDeg <= 0) = 0;
end
