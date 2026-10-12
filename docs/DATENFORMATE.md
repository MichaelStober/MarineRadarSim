# Datenformate

## 1. Kanonischer echter Scan (eine Umdrehung)

Alle Quellen werden in dieses Format gebracht (`mrsim.real.validateScan`). Gespeichert als `.mat` mit der Variablen `scan` (`mrsim.real.saveScan`), geladen mit `mrsim.real.loadScans`. Ablageort: `data/real/` (nicht eingecheckt).

| Feld | Typ | Bedeutung |
|---|---|---|
| `pix` | n_spokes × n_bins `uint8` | Zeile = Spoke (im Uhrzeigersinn), Spalte = Bin, Werte 0–252 |
| `valid` | n_spokes × 1 `logical` | `false` = Spoke fehlt in der Aufnahme |
| `lat`, `lon` | double | Antennenposition WGS84 zur Scanmitte |
| `range_nm` | double | eingestellte Range-Scale |
| `heading_deg` | double | geographisches Heading; `NaN` = unbekannt |
| `orientation` | `'head-up'` / `'north-up'` | Spoke 0 zeigt zum Bug bzw. nach Nord |
| `h_ant` | double | Antennenhöhe in m |
| `settings` | struct | `mode`, `gain_auto`, `gain`, `sea_auto`, `sea`, `sea_curve`, `rain`, `interference_rejection`, `target_expansion` |
| `env`, `id`, `time`, `source` | char | Umgebungslabel, Kennung, Zeit, Herkunft |

## 2. Quellen und Adapter

| Quelle | Adapter | Stand |
|---|---|---|
| Eigene Aufnahmen als `.npz` (2048 × 1024 Spokes) | `mrsim.real.importNpzScans` mit `config/real_npz_mapping.json`; Inhalt prüfen mit `mrsim.real.inspectNpz` | Leser in Octave getestet; die Schlüsselnamen der echten Dateien fehlen noch |
| MCAP (ROS 2), Topic mit den Roh-Spokes | `mrsim.real.readScansMcap` mit `config/real_mcap_mapping.json`; Topics prüfen mit `mrsim.real.inspectMcap` | ungetestet; braucht ROS Toolbox ab R2024a, eigene Nachrichtentypen ab R2025a |
| Kartesische PNG (z. B. Pohang) | `mrsim.real.cartToPolar` | Umrechnung getestet; Importer mit Pose und Radarprofil fehlt noch |

Die PPI-Bilder aus dem PPI-Node enthalten eingezeichnete Grafiken und werden nicht verwendet.

**NPZ lesen ohne Python:** `mrsim.real.readNpz` entpackt das Archiv und liest die `.npy`-Dateien direkt (numerische und boolesche Typen).

**Fehlende Spokes:** In der Kalibrierung werden sie über `valid` ausgeblendet. `mrsim.real.spokeStats` misst Häufigkeit und Sektorlängen, `mrsim.real.spokeDropout` überträgt diese Statistik als Augmentierung auf simulierte Scans.

## 3. Trajektorie für die Simulation (CSV)

```
id,lat,lon[,heading_deg][,antenna_height_m][,time]
```
Trennzeichen `,` oder `;`. Pflicht: `lat`, `lon`.

## 4. Punktziele (Tonnen, Baken) als CSV

```
lat,lon,rcs_dbsm,height_m,reflector,type,name
54.2000000,12.1000000,,,1,buoy_lateral,Tonne 5
```
Leere Felder nehmen die Standardwerte aus `scene.targets`. Erzeugen aus einem Overpass-Export mit `mrsim.scene.seamarksFromOverpass`. Einbinden über `targets.file` in der Szenendatei.

## 5. Höhenmodelle

Das Raycasting nutzt immer das Oberflächenmodell (DOM/DSM). Zwei Kachelschemata (`tile_scheme` in der Szene):

| Szene | Daten | Schema | Koordinatensystem |
|---|---|---|---|
| `scene_rostock.json` | DOM1 LAiV-MV, 1 m, Kacheln 2 × 2 km; DGM optional | `mv_named`: Lage aus dem Dateinamen (die Dateien haben keine CRS-Angabe) | EPSG:25833 (UTM 33) |
| `scene_portugal.json` | DGT MDS 50 cm (2024), Kacheln 1 × 1 km, am Rand schmaler, NoData −999 | `geotiff`: Lage, Größe, Auflösung und NoData aus dem Dateikopf (`georasterinfo`) | EPSG:3763 (PT-TM06) |

Das Schema `geotiff` funktioniert für beliebige georeferenzierte GeoTIFF-Kacheln. Das Koordinatensystem wird in der Szene als `crs` (transversale Mercator: `lat0`, `lon0`, `k0`, `false_easting`, `false_northing`) oder als `utm_zone` angegeben. Es muss zu den Kacheln passen; geprüft gegen PROJ für EPSG:25833 und EPSG:3763.

Standardorte im Repo-Ordner: `rostock_dom/`, `rostock_dem/`, `portugal_dsm/` (nicht eingecheckt). Abweichende Pfade in `config/local.json`.

## 6. Ausgabe der Simulation (je Frame)

`frame_XXXXXX_polar.png`, `_cart.png`, `_landmask_polar.png`, `_landmask_cart.png`, `frame_XXXXXX.mat` (SNR in dB plus Metadaten), `index.csv`, `run_config.json`. Details in `README.md`.

## 7. Ausgabe der Kalibrierung

`calibration_report.json` (Parameter, Abweichung vorher/nachher, Leave-one-out, Spoke-Statistik), `vergleich_<gruppe>_<scan>.png` (echt | vorher | nachher), `quantum2_calibrated_<gruppe>.json`, `scene_calibrated_<gruppe>.json`.
