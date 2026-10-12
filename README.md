# MarineRadar – Quantum-2-PPI-Simulation aus DOM-Daten

Simuliert Raymarine-Quantum-2-Radarbilder (2048 Spokes × 1024 Bins, Werte 0–252) entlang einer Trajektorie aus einer CSV-Datei. Die Küste kommt aus dem DOM1 (LAiV-MV, 1 m, EPSG:25833). Details zu Modell und Annahmen: `IMPLEMENTIERUNGSPLAN.md`.

## Schnellstart

```matlab
% DOM-Kacheln nach <repo>/rostock_dom, DGM (optional) nach <repo>/rostock_dem legen;
% liegen sie woanders: config/local.example.json nach config/local.json kopieren, Pfade eintragen
addpath tests; runAllTests                 % 16 Selbsttests, ohne Daten, ~30 s
simulatePpiFromCsv('examples/track_warnemuende.csv', 'out/test', 'RangeScaleNM', 2)
```

Das Repo läuft unter Windows und Linux. Maschinenspezifische Pfade stehen nur in `config/local.json` (nicht eingecheckt). Weiterarbeit mit KI-Assistenten: `AGENTS.md`; Kontext, Formeln, Entscheidungen und Roadmap in `docs/`.

Beim ersten Aufruf wird `cache/` gebaut: alle DOM-Kacheln in 2, 5 und 10 m (einige Minuten, etwa 0,7 GB). Ändern sich die Klassifikationsparameter oder der DGM-Ordner, baut sich der Cache automatisch neu (`cache/cache_stamp.json`).

Das Raycasting nutzt nur das DOM. Das DGM ist optional und dient der Klassifikation (Objekthöhe = DOM − DGM); Kacheln ohne DGM nutzen eine Schätzung aus dem DOM.

## Kalibrierung an echten Scans

```matlab
radar = mrsim.config.loadJson('config/quantum2.json');
mrsim.real.inspectNpz('aufnahme.npz')                          % Schluessel ansehen
scans = mrsim.real.importNpzScans('ordner', 'config/real_npz_mapping.json', radar, 'data/real');
result = runCalibration('data/real', 'out/calib');             % Report + kalibrierte JSONs
```
Ohne echte Daten prüft `runCalibrationRecovery` das Verfahren an synthetischer Wahrheit. Formate in `docs/DATENFORMATE.md`, Verfahren in `docs/MODELL.md`.

## Weitere Gebiete (Portugal)

```matlab
% Pfad zu den DSM-Kacheln in config/local.json:  "scene_portugal": {"dom_dir": "C:/.../Portugal_DSM_50cm"}
simulatePpiFromCsv('examples/probe_sesimbra.csv', 'out/sesimbra', 'Scene', 'config/scene_portugal.json', 'RangeScaleNM', 2)
```
Neue Gebiete brauchen nur eine Szenendatei: `tile_scheme: "geotiff"` und das passende `crs`. Der Cache liegt je Szene in einem eigenen Ordner (`cache_dir`).

## Tonnen und Baken

```matlab
mrsim.scene.downloadSeamarks([54.05 11.90 54.35 12.40], 'data/targets_rostock.csv')
% danach in config/scene_rostock.json: "targets": { "file": "data/targets_rostock.csv", ... }
```

## CSV-Format

```
id,lat,lon[,heading_deg][,antenna_height_m][,time]
1,54.2134366,12.1232843
```
Trennzeichen `,` oder `;`. Pflicht sind nur `lat` und `lon` (WGS84/ETRS89).

## Optionen

| Option | Werte | Default |
|---|---|---|
| `RangeScaleNM` | 1, 2, 3, 4, 7, 8, 10 | 2 |
| `HeadingMode` | `auto` (Heading-Spalte → Head-up, sonst North-up), `north`, `csv`, `cog` | `auto` |
| `HeadingDeg` | fester Kurs (überschreibt `HeadingMode`) | `[]` |
| `Backend` | `fast` (Ray-Casting), `iq` (radarScenario-Referenz, langsam) | `fast` |
| `UseParallel` | `parfor` über Frames | `false` |
| `Frames` | Teilmenge der CSV-Zeilen | alle |
| `Seed`, `CartSizePx`, `SaveMat`, `Radar`, `Scene`, `BuildCache` | siehe `help simulatePpiFromCsv` | |

## Ausgabe (je Frame)

| Datei | Inhalt |
|---|---|
| `frame_XXXXXX_polar.png` | 2048 × 1024 uint8, Zeile = Spoke (im Uhrzeigersinn, Spoke 1 = Bug bzw. Nord), Spalte = Bin |
| `frame_XXXXXX_cart.png` | kartesisch, Bildkante = Range-Scale, oben = Bug/Nord |
| `frame_XXXXXX_landmask_{polar,cart}.png` | Ground Truth Land (255) / Wasser (0) aus dem DOM, ohne Abschattung |
| `frame_XXXXXX.mat` | `snr_db` (polar, vor Empfängerkette) + `meta` |
| `index.csv` | Pose, UTM, Meridiankonvergenz, Heading, Ausrichtung je Frame |
| `run_config.json` | eingefrorene Konfiguration des Laufs |

## Struktur

```
simulatePpiFromCsv.m        CSV -> simulierte Scans
runCalibration.m            echte Scans -> kalibrierte Konfiguration + Report
config/                     quantum2.json, scene_rostock.json, calibration.json, real_*_mapping.json
+mrsim/+dem                 Kachel lesen, Cache (max-Aggregation), Mosaik
+mrsim/+scene               Klassifikation, Punktziele (Tonnen)
+mrsim/+geo                 UTM (Krüger), Meridiankonvergenz, CSV, Heading, Pose
+mrsim/+refl                sigma0-Tabelle (Radar Toolbox: seareflectivity NRL / landreflectivity Nathanson)
+mrsim/+render              sceneResponse, sensorModel, receiverChain, ppiFast, ppiIQ
+mrsim/+real                echte Scans: NPZ, MCAP, kartesische PNG, fehlende Spokes
+mrsim/+calib               Abweichungsmaß, Kalibrierung, Leave-one-out
+mrsim/+io                  PNG/MAT/index.csv
tests/                      runAllTests, runCalibrationRecovery
docs/                       KONTEXT, MODELL, ENTSCHEIDUNGEN, ROADMAP, DATENFORMATE
```

## Offene Annahmen

Mit `_assumed` oder `_`-Kommentar in den JSON-Dateien markiert; vollständige Liste in `docs/ENTSCHEIDUNGEN.md`.
