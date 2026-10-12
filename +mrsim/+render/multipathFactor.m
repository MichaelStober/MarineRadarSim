function F4 = multipathFactor(h1, h2, r, lambda, gamma0, sigmaH)
%MULTIPATHFACTOR  Zweiwege-Mehrweg (Spiegelung an der Seeoberflaeche), Leistungsfaktor F^4.
%
%   F   = | 1 + Gamma * rho_s * exp(-1i*dPhi) |
%   dPhi = 4*pi*h1*h2 / (lambda*r)                  (Wegunterschied 2*h1*h2/r, flache Erde)
%   rho_s = exp(-2*(2*pi*sigmaH*sin(psi)/lambda)^2)  (Rauigkeitsfaktor nach Ament)
%   psi  = atan((h1+h2)/r)                           (Grazingwinkel am Spiegelpunkt)
%   F4  = F^4                                        (Hin- und Rueckweg)
%
%   h1, h2  Antennen- bzw. Zielhoehe ueber Wasser [m]; r horizontale Entfernung [m]
%   gamma0  Fresnel-Reflexionsfaktor der glatten See (H-Pol., kleiner Grazingwinkel: ~ -1)
%   sigmaH  RMS-Wellenhoehe [m] (0 = glatte See)
%
%   Grenzen: flache Erde (kein Divergenzfaktor), keine Abschattung des Spiegelpunkts,
%   gleiche Antennengewinne fuer direkten und reflektierten Strahl (20 deg Elevationskeule).
%   Fuer glatte See und Gamma = -1 gilt F^4 = (2*sin(2*pi*h1*h2/(lambda*r)))^4; jenseits
%   r_c ~ 4*h1*h2/lambda faellt die Leistung dann mit r^-8.
%   Quellen: Skolnik, Radar Handbook (Kap. Propagation); Bole et al., Radar and ARPA Manual.
    if nargin < 5 || isempty(gamma0), gamma0 = -1; end
    if nargin < 6 || isempty(sigmaH), sigmaH = 0; end
    h2 = max(h2, 0);
    dPhi = 4 * pi * h1 .* h2 ./ (lambda .* r);
    psi = atan((h1 + h2) ./ r);
    rho = exp(-2 * (2 * pi * sigmaH .* sin(psi) ./ lambda).^2);
    F = abs(1 + gamma0 .* rho .* exp(-1i * dPhi));
    F4 = F.^4;
end
