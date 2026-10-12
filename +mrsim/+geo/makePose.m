function pose = makePose(lat, lon, headingDeg, headUp, hAnt, scene)
%MAKEPOSE  Radarpose fuer die Renderer aus WGS84-Position und Heading.
%   pose.E, pose.N  Kartenkoordinaten [m] (scene.crs bzw. scene.utm_zone), pose.gamma Meridiankonvergenz [deg],
%   pose.hdg0       Azimut von Spoke 0 (Heading bei Head-up, 0 bei North-up),
%   pose.h_ant      Antennenhoehe [m]
    [pose.E, pose.N] = mrsim.geo.project(lat, lon, scene);
    pose.gamma = mrsim.geo.gridConvergence(lat, lon, scene);
    if headUp
        pose.hdg0 = mod(headingDeg, 360);
    else
        pose.hdg0 = 0;
    end
    pose.h_ant = hAnt;
end
