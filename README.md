# MarineRadar – Quantum-2-PPI-Simulation aus DOM-Daten

Simuliert Raymarine-Quantum-2-Radarbilder (2048 Spokes × 1024 Bins, Werte 0–252) entlang einer Trajektorie aus einer CSV-Datei. Die Küste kommt aus dem DOM1 (LAiV-MV, 1 m, EPSG:25833). Details zu Modell und Annahmen: `IMPLEMENTIERUNGSPLAN.md`.

## Schnellstart

```matlab
cd path\to\MarineRadar
addpath tests; runAllTests                 % Selbsttest (ohne DOM, ~20 s)
simulatePpiFromCsv('examples/track_warnemuende.csv', 'out/test', 'RangeScaleNM', 2)
```

Beim ersten Aufruf wird `cache/` aus dem in der Szenen-Konfiguration eingetragenen DOM-Ordner und `rostock_dem/` (DGM, optional) gebaut: alle Kacheln in 2, 5 und 10 m. Das dauert einmalig einige Minuten und belegt etwa 0,7 GB. Ändern sich die Klassifikationsparameter oder der DGM-Ordner, baut sich der Cache beim nächsten Lauf automatisch neu (`cache/cache_stamp.json`); erzwingen mit `mrsim.dem.buildTileCache(scene, 'Force', true)`.

Mit DGM wird die Objekthöhe direkt als nDOM = DOM − DGM bestimmt; Kacheln ohne DGM (z. B. die südlichste Reihe) fallen automatisch auf die DOM-Heuristik zurück. Gebäude vs. Vegetation: Ebenheit der Dachflächen (|Laplace(DOM)| im Objektinneren).

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
simulatePpiFromCsv.m        Einstiegspunkt
config/quantum2.json        Radar (Datenblatt + Annahmen je Range-Scale, Empfängerkette)
config/scene_rostock.json   DOM-Pfad, Cache, Klassifikation, Reflektivitätsmodelle
+mrsim/+dem                 Kachel lesen, Cache (max-Aggregation), Mosaik, LRU
+mrsim/+scene               Klassifikation See/flach/Wald/Bebauung (nDOM aus DGM, sonst Heuristik)
+mrsim/+geo                 UTM (Krüger), Meridiankonvergenz, CSV, Heading
+mrsim/+refl                sigma0-LUT (Radar Toolbox: seareflectivity NRL / landreflectivity Nathanson)
+mrsim/+render              ppiFast, ppiIQ, Gauss-PSF, Empfängerkette, polar→kartesisch
+mrsim/+io                  PNG/MAT/index.csv
tests/runAllTests.m         Selbsttests (UTM vs. PROJ, Heading, Schatten, Orientierung, Klassifikation)
```

## Kalibrierung (offen)

Folgende Werte sind Annahmen und sollten an echten Quantum-2-Aufnahmen mit GNSS-Pose angepasst werden:

- `receiver.*`: STC, Gain, floor/sat in dB
- `range_scales[].*`: PRF, Bandbreite, Pulslänge
- `antenna_gain_db`, `sidelobe_*`, `bin_range_factor`
- Klassen-Schwellen in `scene_rostock.json`
