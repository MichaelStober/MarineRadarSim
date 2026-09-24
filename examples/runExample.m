%RUNEXAMPLE  Beispiel: Track 2 km vor der Kueste (Warnemuende -> Markgrafenheide).
%   Beim ersten Lauf wird der DOM-Cache gebaut (alle Kacheln, 2/5/10 m; einige Minuten).
root = fileparts(fileparts(mfilename('fullpath')));
cd(root);

% 1) North-up (CSV ohne Heading), 2 NM
simulatePpiFromCsv('examples/track_warnemuende.csv', 'out/warnemuende_2nm', ...
    'RangeScaleNM', 2);

% 2) Head-up mit Heading aus der CSV, 1 NM
simulatePpiFromCsv('examples/track_warnemuende_heading.csv', 'out/warnemuende_1nm_headup', ...
    'RangeScaleNM', 1);

% 3) Head-up mit Kurs ueber Grund, 4 NM, parallel
simulatePpiFromCsv('examples/track_warnemuende.csv', 'out/warnemuende_4nm_cog', ...
    'RangeScaleNM', 4, 'HeadingMode', 'cog', 'UseParallel', true);

% 4) C-Track vor Warnemuende (Endpunkte 250 m N-S auseinander, Oeffnung nach Osten)
simulatePpiFromCsv('examples/track_c_warnemuende_heading.csv', 'out/c_track_2nm', ...
    'RangeScaleNM', 2);

% 5) IQ-Referenz (langsam!) fuer einen Frame, nur die ersten 200 Pulse zum Testen
% radar = jsondecode(fileread('config/quantum2.json'));  % max_pulses dort setzen
% simulatePpiFromCsv('examples/track_warnemuende.csv', 'out/iq_ref', ...
%     'RangeScaleNM', 1, 'Backend', 'iq', 'Frames', 1);

% Anzeige eines Frames
img = imread('out/warnemuende_2nm/frame_000001_cart.png');
msk = imread('out/warnemuende_2nm/frame_000001_landmask_cart.png');
figure; imagesc(img, [0 252]); colormap(gray); axis image; hold on;
contour(double(msk > 0), [0.5 0.5], 'r'); title('Simulation (grau) mit Landmaske (rot)');
