# Implementierungsplan – Quantum-2-PPI-Simulation aus DOM-Daten (MATLAB R2025b)

Stand: 2026-09-24 · Workspace: Projektordner · DOM: in der Szenen-Konfiguration festgelegt

**Ziel:** `simulatePpiFromCsv("track.csv", "out\")` → pro CSV-Zeile (lat, lon[, heading, …]) ein simuliertes Raymarine-Quantum-2-PPI (polar + kartesisch) plus Metadaten und Ground-Truth-Landmaske.

## Umsetzungsstand (2026-09-24)

| AP | Status | Umsetzung |
|---|---|---|
| AP0 | erledigt | CRS EPSG:25833 bestätigt; eigene UTM-Umrechnung (Krüger), Test gegen PROJ < 1 mm |
| AP1 | erledigt | `mrsim.dem.buildTileCache` (2/5/10 m, Höhe = Block-Maximum), `loadRegion`, LRU-Cache je Worker |
| AP2 | erledigt | nDOM = DOM − DGM1 (`rostock_dem/`, 445 Kacheln; 56 DOM-Kacheln ohne DGM → Heuristik per morphologischer Öffnung); Gebäude/Vegetation über Dach-Ebenheit (Laplace); Cache-Stempel baut bei Änderungen neu; OSM-Maske nicht eingebunden |
| AP3 | erledigt | CSV-Parser, `HeadingMode` auto/north/csv/cog + `HeadingDeg`, Meridiankonvergenz berücksichtigt |
| AP4/5 | erledigt | `ppiFast`: Ray-Casting, Abschattung, lokaler Grazingwinkel, sigma0-LUT, Radargleichung, Gauss-Fleck je Reflexionspunkt (kohärent → Speckle), Rauschen, STC |
| AP6 | implementiert, **ungetestet** | `ppiIQ` (radarScenario/landSurface/clutterGenerator); in der Entwicklungsumgebung keine MATLAB-Lizenz |
| AP7 | erledigt | PNG polar/kartesisch, Landmasken, `.mat`, `index.csv`, `run_config.json`, `parfor` |
| AP8 | teilweise | 10 Selbsttests (`tests/runAllTests.m`); Kalibrierung an echten Aufnahmen offen |
| – | nicht umgesetzt | Mehrwege-Ausbreitungsfaktor F⁴ (optional) |

---

## 1. Befunde vorab (geprüft)

| Punkt | Befund | Konsequenz |
|---|---|---|
| DOM-Kacheln | 2000×2000 px, 1 m, float32, unkomprimiert (16 MB), Bounds = Dateiname × 1000 (z. B. `33_314_6010` → E 314000–316000, N 6010000–6012000) | Georeferenz aus Dateiname ableitbar |
| CRS | **EPSG:25833 (ETRS89/UTM 33N) – laut Portal-Metadaten bestätigt**; das GeoTIFF selbst enthält aber keine CRS-GeoKeys (rasterio: `crs=None`), nur Geotransform | CRS beim Einlesen explizit setzen |
| NoData | keins gesetzt; **Wasserflächen ≈ 0 m** (Median See ≈ −0,003 m), Minima bis −5 m | Wasser nicht über NoData, sondern über Höhe/Maske klassifizieren |
| Inhalt | DOM = Oberflächenmodell inkl. Wald (~25–30 m) und Gebäuden; Beispielkachel 314_6010 zeigt Düne + tiefes Hinterland (~1–2 m) | Genau das, was ein Radar „sieht“ – aber Strand/Hinterland liegen nur 0,5–2 m über Wasser → Land/Wasser-Schwelle kritisch |
| Download-Stand | 169 von 339 Kacheln vorhanden, 1 Datei noch unvollständig | Mosaik-Builder muss fehlende Kacheln erkennen und melden |
| MATLAB-Workspace | leer | Neues Projekt aufsetzen |

**Quantum 2 (Q24D) – Herstellerdaten** ([Raymarine](https://www.raymarine.com/en-us/our-products/marine-radar/quantum/quantum-2-q24d-radome)):
9354–9446 MHz (X-Band), 20 W Peak, horizontale Keule **4,9°**, vertikal 20°, H-Polarisation, Patch-Array, 24 U/min, Chirp 400 ns–22 µs, Pulsbreite (3 dB) 40 ns–14,7 µs, Chirp-Bandbreite bis 32 MHz (→ Δr = c/2B ≈ 4,7 m), min. Reichweite 6 m, Range-Scales 1/16 … 24 NM.

**Ergänzend laut Datenblatt (vom Nutzer geliefert):** Rauschmaß **< 4 dB**, PRF **920–5900 Hz**, ZF 26 MHz, Duplexer Circulator. Kürzeste 3-dB-Pulsbreite 40 ns ⇒ Δr ≈ c·τ/2 ≈ 6 m (etwas gröber als c/2B).

**Pulse pro Spoke:** 24 U/min = 0,4 U/s ⇒ 2300–14 750 Pulse/Umdrehung ⇒ **≈ 1,1–7,2 Pulse je Spoke** (bei 2048 Spokes). Ein Spoke ist also eine nicht-kohärente Mittelung weniger Pulse → Speckle wird nur schwach geglättet (Multi-Look mit N ≈ 1–7). Eindeutige Reichweite bei 5900 Hz ≈ 25 km > 10 NM → keine Mehrdeutigkeit.

**Vom Nutzer festgelegt (echtes Gerät / Testboot):** 2048 Spokes/Umdrehung (0,176°/Spoke) × 1024 Samples/Spoke, Pixelwerte **0–252**, Antennenhöhe **3 m**, Range-Scales **1, 2, 3, 4, 7, 8, 10 NM** (einstellbar).

**Noch offen** (→ `config`-Parameter, aus Aufnahmen kalibrieren): PRF je Range-Scale (innerhalb 920–5900 Hz), Bandbreite/Pulslänge je Range-Scale, Kurzpuls/Chirp-Umschaltung im Nahbereich, Nebenkeulenpegel, STC-/Gain-Kurve, Abbildung Range-Scale → Länge der 1024 Bins (exakt = Scale oder mit Überhang?).

Hinweis: 7 und 10 NM stehen nicht in der Range-Scale-Liste des Herstellers (… 6, 8, 12 …) – werden trotzdem unterstützt, da frei konfigurierbar.

> Hinweis: 4,9° Keulenbreite ⇒ Azimutzelle ≈ 256 m bei 3 km (≈ 28 Spokes). Diese Verschmierung dominiert das Radarbild – das muss die Simulation zwingend abbilden.

**Abgeleitete Geometrie je Range-Scale** (Bin = Scale/1024; Radarhorizont bei 3 m Antennenhöhe, k = 4/3: ≈ 7,1 km ≈ 3,8 NM für Ziele auf Meereshöhe, ≈ 27 km für 25 m hohen Wald):

| Scale | Radius | Bin-Länge | DOM-Stufe | Bemerkung |
|---|---|---|---|---|
| 1 NM | 1,85 km | 1,8 m | 2 m | Bin < Δr (≈ 4,7–6 m) → PSF-Faltung entscheidend |
| 2 NM | 3,70 km | 3,6 m | 2 m | |
| 3 NM | 5,56 km | 5,4 m | 5 m | |
| 4 NM | 7,41 km | 7,2 m | 5 m | Rand ≈ Radarhorizont für Strand |
| 7 NM | 12,96 km | 12,7 m | 10 m | nur erhöhte Strukturen sichtbar |
| 8 NM | 14,82 km | 14,5 m | 10 m | |
| 10 NM | 18,52 km | 18,1 m | 10 m | Radius kann über DOM-Abdeckung hinausragen |

---

## 2. Architekturentscheidung: zwei Backends

Das [MathWorks-Beispiel „Simulate Maritime Radar PPI“](https://de.mathworks.com/help/radar/ug/simulate-maritime-radar-ppi.html) arbeitet auf IQ-Ebene (`radarScenario` + `radarTransceiver` + `clutterGenerator`, Pulse-by-Pulse, `phased.RangeResponse`). Das ist physikalisch sauber, aber teuer: Das [Bistatic-Land-Clutter-Beispiel](https://www.mathworks.com/help/radar/ug/Simulating-Site-Specific-Bistatic-Land-Clutter.html) nennt 127 s für 128 Pulse mit ~1 200 Patches. Ein Quantum-PPI braucht ~10³ Spokes und bei 3 km Reichweite deutlich mehr Patches pro Puls → Minuten bis Stunden pro Frame.

| Backend | Zweck | Laufzeit (Schätzung) |
|---|---|---|
| **`fast`** (primär) | Eigener Raster-Renderer: Ray-Casting über DOM, Abschattung, σ⁰ aus Radar-Toolbox-Modellen, Radargleichung, Faltung mit Antennen-/Range-PSF, Speckle, Rauschen, STC | Sekunden/Frame, `parfor`-fähig |
| **`iq`** (Referenz) | 1:1 nach MathWorks-Beispiel, Terrain = DOM-Ausschnitt | Minuten–Stunden/Frame; nur für Validierung einzelner Frames |

Beide nutzen dieselbe Szenen-Aufbereitung (DOM-Crop, Klassen, Erdkrümmung) und denselben Ausgabe-Writer. `fast` wird gegen `iq` und gegen echte Quantum-2-Aufnahmen kalibriert.

### Land + See in einem Surface (für `iq`)
Statt `landSurface` und `seaSurface` zu überlagern: **ein** `landSurface` mit DOM-Terrain über den ganzen Ausschnitt (See ≈ 0 m), `ReflectivityMap` mit Klassenindex je Vertex und `surfaceReflectivityCustom` mit σ⁰-Tabelle (Grazing × Frequenz × Klasse). Klasse „See“ wird aus `seareflectivity` (NRL, Sea State, H-Pol) befüllt, Landklassen aus `landreflectivity`. Muster laut [SAR-Land-Scenes-Beispiel](https://www.mathworks.com/help/radar/ug/simulated-land-scenes-for-synthetic-aperture-radar-image-formation.html) und [surfaceReflectivityCustom](https://www.mathworks.com/help/radar/ref/surfacereflectivitycustom-system-object.html). Terrain-Orientierung wie im Bistatic-Beispiel: `Terrain=flipud(Z).'`, `Boundary=[xmin xmax; ymin ymax]` ([LandSurface](https://au.mathworks.com/help/radar/ref/landsurface.html)).

---

## 3. Projektstruktur

```
MarineRadar/
├─ simulatePpiFromCsv.m          % Einstiegspunkt
├─ config/
│  ├─ quantum2.json              % Radarparameter (Herstellerdaten + Kalibrierwerte)
│  └─ scene_rostock.json         % DOM-Pfad, CRS, Cache, Klassenschwellen, Sea State
├─ +mrsim/
│  ├─ +dem/   buildTileCache.m, loadRegion.m, tileIndex.m
│  ├─ +geo/   readTrajectoryCsv.m, wgs2utm.m, earthCurvature.m
│  ├─ +scene/ classifySurface.m, cropLocal.m
│  ├─ +refl/  buildReflectivityTable.m        % landreflectivity/seareflectivity → LUT
│  ├─ +render/ ppiFast.m, ppiIQ.m, antennaPattern.m, rangePsf.m, receiverChain.m
│  └─ +io/    writeFrame.m, writeIndex.m
├─ tests/     % matlab.unittest
└─ cache/     % vorverarbeitete DOM-Kacheln
```

Parameter ausschließlich über JSON (`jsondecode`); im Code Kommentare mit Verweis auf Doku-Seite/Formel.

---

## 4. Arbeitspakete

### AP0 – Setup & Datencheck (0,5 d)
- Toolboxen prüfen: Radar, Phased Array, **Mapping** (`readgeoraster`, `projcrs`, `projfwd`). Ohne Mapping Toolbox: UTM-Formeln selbst implementieren.
- CRS: EPSG:25833 bestätigt. Offen nur noch der Höhenbezug (vermutlich DHHN2016 ≈ NHN; Ostsee-MW ≈ 0 m NHN) – für die Simulation unkritisch, solange Wasser ≈ 0 m bleibt.
- `readgeoraster` auf Kachel testen; falls `R` ohne CRS: `R = maprefcells([E E+2000],[N N+2000],[2000 2000]); R.ProjectedCRS = projcrs(25833)` aus dem Dateinamen bauen.

### AP1 – DOM-Cache (1 d) · `mrsim.dem.buildTileCache`
- Einmalig je Kachel: 1 m → Pyramide **2 m, 5 m und 10 m** als `.mat` (single); Stufe je Range-Scale laut Tabelle in Abschnitt 1.
  - Aggregation **max** für Höhen (erhält Dünenkamm, Gebäudekanten → korrekte Abschattung).
  - zusätzlich Rauhigkeit (Std-Abw. im Block) als Klassifikationsmerkmal.
- `tileIndex`: Tabelle Kachel ↔ Bounds ↔ vorhanden/fehlend.
- Speicher: Gesamtgebiet 54×40 km bei 2 m ≈ 2,2 GB → **nicht** global laden; pro Frame nur Kacheln im Radius R_max (`loadRegion`).
- Fehlende Kacheln: `NaN` + Warnung; im Renderer als „unbekannt“ (nicht als Wasser!) behandeln. Ausnahme: Bereiche außerhalb der DOM-Abdeckung, die laut OSM-Maske See sind (relevant ab 7 NM) → See bei 0 m.

### AP2 – Oberflächenklassen (1 d) · `mrsim.scene.classifySurface`
Klassen (Index für ReflectivityMap/LUT): 1 See, 2 Strand/flaches Land, 3 Vegetation/Wald, 4 Bebauung.
- **Wasser:** Höhe < h_w (z. B. 0,3 m) **und** Zusammenhang mit offener See (Flood-Fill ab bekanntem Seepunkt; Hafenbecken/Warnow separat). Besser/robuster: OSM-Landpolygone aus dem shoreline-viewer-Projekt als Maske verwenden, DOM nur für Höhe.
- **Wald vs. Gebäude:** nur mit Objekthöhe (nDSM = DOM − DGM) sauber trennbar → Option: **DGM1** vom selben Portal nachladen. Ohne DGM: Heuristik über Höhe + Rauhigkeit (Wald: hohe Textur, Gebäude: flache Dächer, steile Kanten).
- Ergebnis zusätzlich als Ground-Truth-Landmaske exportieren.

### AP3 – Trajektorie & lokale Szene (0,5 d)
- `readTrajectoryCsv`: Pflicht `lat, lon`; optional `heading_deg`, `time`, `antenna_height_m` (Default 3 m), `id`.
- **Heading optional** über `opts.HeadingMode`:
  - `"auto"` (Default): Spalte `heading_deg` vorhanden → verwenden (Head-up), sonst **North-up**
  - `"north"`: immer North-up (Spoke 0 = geografisch Nord), Heading wird ignoriert
  - `"csv"`: Spalte `heading_deg` Pflicht, Fehler wenn sie fehlt
  - `"cog"`: Kurs über Grund aus aufeinanderfolgenden Positionen
  - zusätzlich `opts.HeadingDeg` (Skalar) als konstanter Override
- Heading wirkt nur als Rotation der Spokes (Spoke-Offset = heading/360·2048); die Szene selbst ändert sich nicht. Das verwendete Heading und der Modus stehen in `index.csv`, damit North-up-Frames später noch gedreht werden können.
- `wgs2utm`: `projfwd(projcrs(25833), lat, lon)`.
- `cropLocal`: Ausschnitt im Radius R_max um das Schiff, Pyramidenstufe nach Range-Scale.
- **Erdkrümmung** (flacher Szenario-Modus): h' = h − d²/(2·k·R_E), k = 4/3. Relevant: bei 3 km ≈ 0,53 m (gleiche Größenordnung wie Strandhöhe), bei 10 NM ≈ 20 m.

### AP4 – `fast`-Renderer, Geometrie (1 d) · `mrsim.render.ppiFast`
1. Polares Abtastgitter direkt im Zielformat: 2048 Spokes (optional 2× überabgetastet) × 1024 Bins (optional 2× überabgetastet, dann zurückmitteln).
2. `interp2` der Höhe entlang jedes Strahls.
3. Elevationswinkel ε(r) = atan((h' − h_ant)/r); **sichtbar**, wenn ε(r) ≥ `cummax` von ε entlang des Strahls → Radarschatten.
4. Lokaler Grazing-/Inzidenzwinkel aus Terrain-Gradient in Strahlrichtung (Dünen-/Gebäudefronten → starke Rückstreuung).
5. Zwischenergebnis: binäres Sichtbarkeits-PPI → Plausibilitätscheck gegen OSM-Küstenlinie.

### AP5 – `fast`-Renderer, Radiometrie (1–2 d)
1. σ⁰(ψ, Klasse) aus LUT (`landreflectivity`, `seareflectivity` NRL, H-Pol, f = 9,4 GHz, Sea State aus Config).
2. Patch-RCS σ = σ⁰ · r·Δθ·Δr (Grazing-korrigiert).
3. Radargleichung P_r = P_t G² λ² σ / ((4π)³ r⁴ L); optional Ausbreitungsfaktor F⁴ (Zweiwege-Mehrweg über See).
4. **Azimut-Faltung** mit Zweiwege-Antennendiagramm (4,9° HPBW, Nebenkeulen aus Config), zirkulär über 360°.
5. **Range-Faltung** mit komprimierter Puls-PSF (3-dB-Breite je Range-Scale, min. 40 ns ≈ 6 m; Fensterung → Nebenzipfel).
6. Speckle: Rayleigh (Land), Weibull/K (See), anschließend **Multi-Look-Mittelung über N = PRF/(0,4 Hz·2048) Pulse** je Spoke; thermisches Rauschen kTBF mit F = 4 dB (bei B = 32 MHz ≈ −95 dBm).
7. Empfängerkette: STC, Log-Kompression, Gain, Quantisierung auf **0–252** (uint8, Clipping bei 252), Ausgabe 2048 × 1024.

### AP6 – `iq`-Backend (1–2 d, optional) · `mrsim.render.ppiIQ`
- Wie MathWorks-Beispiel, angepasst: `radarScenario(UpdateRate=0)`, Plattform mit `kinematicTrajectory` in 3 m Höhe (AngularVelocity = 144 °/s; PRF im Datenblattbereich 920–5900 Hz, z. B. 2 Pulse je Spoke → 1638 Hz, Spoke = Mittel der Pulse; ZF 26 MHz wird nicht modelliert, Simulation im Basisband), Antenne `phased.ULA` mit N so, dass HPBW ≈ 4,9°, `BackBaffled=true`, `radarTransceiver` (LFM, 32 MHz, f₀ 9,4 GHz, 20 W), `clutterGenerator(Resolution=Δr/2, UseBeam=false)` + `ringClutterRegion`.
- Terrain = Crop aus AP3 (inkl. Krümmungskorrektur), Klassen aus AP2 als `ReflectivityMap`.
- Nur für einige Referenzframes; Ausgabe über denselben Writer → direkter Vergleich mit `fast`.

### AP7 – Ausgabe & Batch (0,5 d) · `mrsim.io`
Pro Frame im Zielordner:
- `frame_000123_polar.png` (2048 × 1024, uint8, Werte 0–252) – Format wie echte Aufnahme
- `frame_000123_cart.png` (kartesisch, Pixel/m aus Config)
- `frame_000123_landmask_polar.png` / `_cart.png` (Ground Truth)
- `frame_000123.mat` (Rohdaten double, Pose, Parameter)

Zusätzlich `index.csv` (Frame ↔ lat/lon/E/N/Heading/Zeit) und `run_config.json` (eingefrorene Konfiguration, Git-Hash). Batch über `parfor`, Cache-Kacheln per Worker lazy laden.

### AP8 – Validierung & Kalibrierung (laufend)
- Unit-Tests: Kachel-Georeferenz, Punktziel (Range/Azimut korrekt), flache See ohne Land → nur Clutter + Rauschen, Abschattung hinter künstlicher Wand.
- `fast` vs. `iq` auf 3–5 Frames: Range-Profile, Azimut-Verschmierung.
- **Gegen echte Quantum-2-Aufnahmen** (Testboot, GNSS-Pose): IoU der schwellwertbinarisierten Landechos, Küstenkanten-Abstand, Histogramm-Matching der Amplituden → STC/Gain/Nebenkeulen fitten.

---

## 5. Einstiegs-API (Skizze)

```matlab
function simulatePpiFromCsv(csvPath, outDir, opts)
arguments
    csvPath (1,1) string
    outDir  (1,1) string
    opts.Radar   (1,1) string = "config/quantum2.json"
    opts.Scene   (1,1) string = "config/scene_rostock.json"
    opts.Backend (1,1) string {mustBeMember(opts.Backend,["fast","iq"])} = "fast"
    opts.RangeScaleNM (1,1) double {mustBeMember(opts.RangeScaleNM,[1 2 3 4 7 8 10])} = 2
    opts.HeadingMode (1,1) string {mustBeMember(opts.HeadingMode,["auto","north","csv","cog"])} = "auto"
    opts.HeadingDeg  double = []        % optionaler konstanter Override
    opts.UseParallel (1,1) logical = true
end
```

`config/quantum2.json` (Auszug):
```json
{
  "fc_hz": 9.4e9, "peak_power_w": 20, "az_beamwidth_deg": 4.9, "el_beamwidth_deg": 20,
  "polarization": "H", "rotation_rpm": 24, "bandwidth_hz": 32e6,
  "antenna_height_m": 3.0,
  "n_spokes": 2048, "n_bins": 1024, "pixel_max": 252,
  "range_scales_nm": [1, 2, 3, 4, 7, 8, 10],
  "dem_level_m": {"1": 2, "2": 2, "3": 5, "4": 5, "7": 10, "8": 10, "10": 10},
  "bandwidth_hz_per_scale": null, "bin_range_factor": 1.0,
  "noise_figure_db": 4, "prf_hz_limits": [920, 5900], "prf_hz_per_scale": null,
  "pulse_width_3db_s_per_scale": null,
  "sidelobe_db": null, "stc": null
}
```
`null` = aus Aufnahmen/SDK zu bestimmen.

---

## 6. Offene Punkte / Entscheidungen

1. ~~Antennenhöhe~~ → 3 m · ~~Range-Scales~~ → 1/2/3/4/7/8/10 NM · ~~Spoke-Format~~ → 2048 × 1024, 0–252 · ~~Heading~~ → optional (`HeadingMode`)
2. Deckt Bin 1024 exakt die Range-Scale ab? (an echter Aufnahme mit bekanntem Ziel prüfen → `bin_range_factor`)
3. Chirp-Bandbreite/Pulslänge und PRF je Range-Scale (bestimmt Range-PSF und Pulse/Spoke) – Datenblatt liefert nur Grenzen
4. Land/Wasser-Maske: DOM-Schwelle, OSM-Polygone (shoreline-viewer) oder beides?
5. DGM1 zusätzlich laden (Wald/Gebäude-Trennung)?

## 7. Risiken

- **Flacher Strand:** Echo hängt an 0,5–2 m Höhenunterschied und flachem Grazing → σ⁰-Modelle bei ψ < 1° unsicher; Kalibrierung an echten Daten unverzichtbar.
- **Keine CRS-Tags in den Dateien:** EPSG:25833 ist bestätigt, muss aber im Code explizit gesetzt werden (nicht auf `readgeoraster`-CRS verlassen).
- **Statische Szene:** DOM-Zeitpunkt ≠ Messzeit (Schiffe im Hafen, Baustellen, Vegetation).
- **Wasserstand:** DOM-Wasser ≈ 0 m NHN; realer Pegel (Wind-Stau Ostsee ±1 m) verschiebt die Strandlinie → optional Pegel-Offset als Parameter.

## Quellen
- MathWorks: [Simulate Maritime Radar PPI](https://de.mathworks.com/help/radar/ug/simulate-maritime-radar-ppi.html), [Simulating Site-Specific Bistatic Land Clutter](https://www.mathworks.com/help/radar/ug/Simulating-Site-Specific-Bistatic-Land-Clutter.html), [Simulated Land Scenes for SAR](https://www.mathworks.com/help/radar/ug/simulated-land-scenes-for-synthetic-aperture-radar-image-formation.html), [LandSurface](https://au.mathworks.com/help/radar/ref/landsurface.html), [surfaceReflectivityCustom](https://www.mathworks.com/help/radar/ref/surfacereflectivitycustom-system-object.html), [Simulate a Coastal Surveillance Radar](https://www.mathworks.com/help/radar/ug/simulate-a-coastal-surveillance-radar.html)
- Raymarine: [Quantum 2 Q24D – Spezifikationen](https://www.raymarine.com/en-us/our-products/marine-radar/quantum/quantum-2-q24d-radome)
