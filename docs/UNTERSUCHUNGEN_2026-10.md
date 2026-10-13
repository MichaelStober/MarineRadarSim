# Untersuchungen und Erkenntnisse: Echointensität, Optionen A/B/C, Tests (Oktober 2026)

Stand: 2026-10-13. Protokoll der Claude-Sitzungen vom 12. und 13.10.2026 mit Mike.
Gilt für das **Raymarine Quantum 2**. Andere Radare kommen erst später für Vergleiche dazu.

Ergänzende Dokumente im Repo:
- `docs/RECHERCHE_ENTFERNUNGSABFALL.md`: Recherche im Detail, mit Quellen und Rechenskript
- `docs/MODELL.md`: Formeln
- `docs/ENTSCHEIDUNGEN.md`: Entscheidungen und offene Punkte

**Kennzeichnung der Aussagen:**
- **[belegt]**: Quelle angegeben
- **[gerechnet]**: Radargleichung
- **[Sim]**: in der Simulation gemessen
- **[Mike]**: Beobachtung an echten Aufnahmen
- **[Hypothese]**: plausibel, nicht belegt

---

## 1. Ausgangsfrage

**[Mike]**
- Simulierte Quantum-2-Scans werden bei 8 NM mit der Entfernung deutlich dunkler, echte Quantum-2-Aufnahmen nicht.
- In echten Rostock-Scans sind die Fahrwassertonnen und die See sehr deutlich.
- Das Gesamtbild unterscheidet sich stark von der Simulation.
- Bei Pohang und MOANA (ca. 1 NM) fiel das nicht auf.

**Fragen:**
- Gibt es einen entfernungsabhängigen Gain?
- Warum sind echte Bilder so intensiv?
- Gibt es Literatur oder fertige Werkzeuge?
- Wo wurden die Vergleichsdaten `km_data` aufgenommen?

---

## 2. Untersuchung des Datensatzes `km_data` (Flemmen et al. 2023)

### 2.1 Was der Datensatz ist [belegt]

- Begleitdaten zum Repo `hflemmen/radar_odometry`, Paper „Maritime radar odometry inspired by visual odometry“ (NTNU, Daten von Kongsberg Maritime).
- Ordner `b` = Sequenz b des Papers.

**Radar:**

| Eigenschaft | Wert |
|---|---|
| Band | S-Band |
| Antennenhöhe | 21 m über See |
| Keulenbreite | 3,1° |
| Range im Paper | 19 km |

**Format:**
- 200 Umdrehungen als BMP, 4096 Spokes × 2000 Bins, 8 bit.
- Zu jeder BMP eine TXT mit einer Zeile je Spoke: Zeit, Azimut [rad, gegen den Uhrzeigersinn relativ zum Bug], Heading [rad], Lat/Lon [rad], m/Bin.
- Die freigegebene Version ist reduziert: 6,8134 m/Bin, also 13,6 km statt 3,4 m/Bin und 19 km.

**Aufnahme:**
- 2018-06-25, 08:16:58–08:24:59 UTC.
- Ort: Meløy, Nordland, Norwegen.
- Fahrt von 66,9514 N / 13,4820 E nach 66,9661 N / 13,5536 E.

**DEM für einen Vergleich:**
- Bereich ca. 66,83–67,09 N und 13,17–13,86 E.
- Quelle: Kartverket, hoydedata.no, DOM 1 m.

### 2.2 Messung: Pixelwerte über die Entfernung [gemessen]

Mittel über 50 Umdrehungen, Statistik je Bin über alle Spokes. Bild: `Downloads/km_data/_analyse/`.

| Entfernung | Median | p90 | p99 |
|---|---|---|---|
| 0,7 km | 81 | 140 | 181 |
| 1,7 km | 68 | 159 | 210 |
| 2,0 km | 53 | 98 | 181 |
| 3,1 km | 36 | 83 | 141 |
| 4,1 km | 35 | 87 | 170 |
| 7–13,6 km | 27–28 | 45–55 | 100–145 |

**Erkenntnisse:**
- Das Rauschen ist sichtbar (Median ca. 28/255) und bleibt bis 13,6 km gleich hoch.
- Land bei 12 km ist praktisch so hell wie bei 2 km, also gesättigt.
- Seeclutter ist stark bis ca. 2 km.
- Bei einigen Peilungen gibt es eine Stufe bei ca. 1,9 km. Das könnte ein Pulswechsel sein [Hypothese, nicht gesichert].
- **Einschränkung:** anderes Radar (S-Band, 21 m, unbekannte Leistung). Das stützt die Erklärung in Kap. 4 nur qualitativ und ist kein Beleg für das Quantum 2.

---

## 3. Physik: was die Radargleichung erwartet [gerechnet]

### 3.1 Parameter

Werte aus `config/quantum2.json`, Range-Scale 8 NM:

| Parameter | Wert | Herkunft |
|---|---|---|
| Sendeleistung Pt | 20 W | Datenblatt |
| Antennengewinn G | 24 dBi | Annahme |
| Wellenlänge λ | 3,19 cm | |
| Verluste L | 3 dB | Annahme |
| Rauschzahl NF | 4 dB | Datenblatt |
| Bandbreite B | 20 MHz | Annahme |
| Pulslänge τ | 16 µs | Annahme |
| Pulskompressionsgewinn G_pc | 25 dB | aus τ und B |
| Keulenbreite θ_az | 4,9° | Datenblatt |
| Entfernungsauflösung ΔR | 10,5 m | Annahme |

### 3.2 Abhängigkeit von der Entfernung

| Zieltyp | Abhängigkeit | Grund |
|---|---|---|
| Fläche (Land, See) | SNR ∝ σ⁰(ψ)/r³ | bestrahlte Fläche r·θ·ΔR wächst mit r |
| Punktziel (Tonne, Schiff) | SNR ∝ 1/r⁴ | |
| See | etwa r⁻⁴ bis r⁻⁵ | Grazingwinkel ψ ≈ h/r sinkt, σ⁰ fällt mit |
| Tonne mit Spiegelung über die See | r⁻⁸ ab r_c ≈ 4·h_a·h_t/λ | ab ca. 1,3 km bei Tonnenhöhe 3,5 m |

### 3.3 Zahlen

SNR vor STC, Freiraum ohne Abschattung:

| Entfernung | See NRL SS3 | steile Front σ⁰ = −10 dB | Tonne 10 dBsm | Tonne mit Spiegelung |
|---|---|---|---|---|
| 0,5 km | 18,0 dB | 55,9 dB | 49,4 dB | 59,0 dB |
| 1 km | 4,6 dB | 46,6 dB | 37,0 dB | 46,9 dB |
| 2 km | −9,1 dB | 37,7 dB | 25,2 dB | 34,6 dB |
| 4 km | −23,8 dB | 28,6 dB | 13,0 dB | 12,8 dB |
| 8 km | −38,6 dB | 19,6 dB | 1,0 dB | −10,6 dB |
| 14 km | −50,8 dB | 12,3 dB | −8,7 dB | −29,9 dB |

**Radarhorizont** bei 3 m Antennenhöhe:
- ca. 7,1 km.
- Am Rand der 8-NM-Scale (14,8 km) muss ein Ziel mindestens ca. 3,5 m hoch sein.
- Bis ca. 10 km ist der Horizont nicht die Hauptursache für den Abfall.

**Die Physik fällt also deutlich ab:** Eine steile Front verliert von 2 auf 8 km etwa 18 dB, eine Tonne etwa 24 dB.

---

## 4. Warum echte Radarbilder trotzdem kaum dunkler werden

1. **Gain ist eine Schwelle über dem Rauschen** [belegt, Raymarine: „The manual Gain control sets the detection threshold“].
   - Das Rauschen ist in jeder Entfernung gleich.
   - Der Hintergrund ist deshalb überall gleich hell.
2. **Logarithmische Abbildung mit früher Sättigung** [Hypothese, gestützt durch `km_data` und Olofsson 2020].
   - Zwischen Schwelle und Weiß liegen grob 20 dB.
   - Eine Front bei 2 km (ca. 38 dB) und bei 8 km (ca. 20 dB) ist beide Male nahezu weiß.
3. **Der Nahbereich wird gezielt gedämpft.**
   - Sea-Clutter-Kurve und STC-Preset [belegt, Raymarine: „equalize targets across the image“; Sea wirkt bis zu 5 NM].
   - Dazu vermutlich ein kurzer Puls im Nahbereich [Hypothese]. Während des langen Chirps ist der Empfänger taub: bei 16 µs bis 2,4 km, bei 22 µs bis 3,3 km.
4. **Flächenziele fallen nur mit r⁻³.**
5. **Bei großer Range-Scale längerer Puls**, also mehr Energie [belegt für Furuno: „pulse lengths are pre-set for each range“].
6. **Expanded Returns** vergrößert kleine Ziele [belegt: Funktion vorhanden].

**Weitere Belege zum Quantum 2** [belegt]:
- Das SDK liefert „processed radar data“. Die aufgezeichneten Spokes sind also bereits verarbeitet.
- Quantum 2 hat keinen Buoy-Modus, nur Harbour, Coastal, Offshore und Weather.

---

## 5. Untersuchung der Simulation vor den Änderungen [Sim]

**Testaufbau:**
- Octave in der Cloud, Ersatz-Reflektivität (constant gamma).
- Rostock, Pose 54,22116 N / 12,13111 E, 8 NM.

**Befunde:**
- **Rauschen wurde schwarz** (Pixel 0). Die alte Abbildung lief von `floor_db` 3 bis `sat_db` 35.
- **Land blieb mittelgrau:** Die stärksten Landechos jenseits von 2 km lagen bei 20–25 dB, das ergab nur Pixel 134–173.
- **Ab 6,5 km nur noch Rauschen.**
- **DOM-Abdeckung im Test unvollständig:** `missing_frac` = 0,87. Nur ca. 13 % der 8-NM-Fläche hatten DOM-Daten (31 Kacheln), der Rest wurde als See gerechnet.
- **Seeclutter fehlte:** Das alte STC dämpfte bis 1,5 km um bis zu 30 dB.
- **Tonnen fehlten**, weil `targets.file` leer war.
- **Voller Pulskompressionsgewinn überall**, auch im blinden Bereich des Chirps.
- **Keine Mehrwegeausbreitung, keine hellen Einzelstreuer.**

**Rechnung geprüft:** In `sceneResponse`/`sensorModel` gab es keinen Fehler. Die SNR-Werte passen zur Handrechnung.

---

## 6. Recherche: Literatur und Werkzeuge [belegt]

Ein fertiges Werkzeug, das DEM in realistische Marineradar-PPIs umsetzt, wurde nicht gefunden.

**Relevant:**
- Olofsson et al., FUSION 2020: GNSS-freie Navigation mit Radar und DEM; Sichtbarkeit, RCS ∝ Fläche, Schwelle.
- Suo et al. 2020: DEM + SAR, Geländeecho.
- Zhang et al. 2016 und Chen 2015: Radarsimulation aus ENC.
- Li et al. 2025: Schiffsecho über RCS.
- RadaRays (RA-L 2025, Open Source): rotierendes FMCW-Radar.
- RadSimReal (CVPR 2024): Anpassung über gemessene Punktantwort und Rauschen.
- Rezvov et al. 2024: synthetisches Seeclutter für das Vortraining.
- MATLAB-Beispiele zu Maritime PPI und Sea Clutter: ohne STC und ohne Anzeigekette.

**Normen und Werte:**
- IMO MSC.192(79), Tab. 2: RCS von Tonnen.
- QinetiQ/MAIB 2007: RCS von Radarreflektoren, stark abhängig vom Aspektwinkel.

**Ausgeschlossen** (Entscheidung Mike): gelernte Sim-to-Real-Ansätze (GAN/CycleGAN). Dafür gibt es zu wenig reale Daten.

Volle Quellenliste: `docs/RECHERCHE_ENTFERNUNGSABFALL.md`, Kap. 9.

---

## 7. Umsetzung (Entscheidungen Mike, 2026-10-12)

### 7.1 Option A: Empfängerkette nach Quantum-Art

Die alte Kette ist **ersetzt**, es gibt keinen Legacy-Pfad (`+render/receiverChain.m`):

```
x(r)  = SNR_dB(r) − A_sea(r) + G(r)
A_sea = min(sea_max_db, 10·sea_exponent·log10(sea_range_m/r))   für r < sea_range_m
G(r)  = clip(range_gain_db_per_decade·log10(r/range_gain_r0_m), 0, range_gain_max_db)
Pixel = 252 · clip((x − threshold_db)/dynamic_range_db, 0, 1)
```

| Parameter | Default (Annahme) |
|---|---|
| `threshold_db` | 2 |
| `dynamic_range_db` | 20 |
| `sea_max_db` / `sea_range_m` / `sea_exponent` | 10 / 1000 / 2 |
| `range_gain_db_per_decade` | 0 (aus) |

**Kurzpuls im Nahbereich** (`radar.short_pulse`, in `sensorModel.m`):
- Unterhalb r_sp = c·τ_lang/2 wird P mit G_pc,kurz/G_pc,lang multipliziert.
- Default 1 µs; bei 8 NM ergibt das −12 dB bis 2,4 km.
- Status: [Hypothese].

### 7.2 Option B: Seezeichen

**Radarquerschnitt je Kategorie** (`scene.targets.categories`, IMO-basiert, `+scene/loadTargets.m`):

| Kategorie | Regel | RCS | Höhe |
|---|---|---|---|
| `buoy_reflector` | Tonne mit `seamark:radar_reflector=yes` | 10 dBsm | 3,5 m |
| `buoy` | übrige Tonnen | 7 dBsm | 3,5 m |
| `spar` | Spiere ohne Reflektor | 0 dBsm | 1 m |
| `beacon` | Baken (`beacon_*`) | 13 dBsm (Annahme) | 5 m |

**Weitere Teile:**
- Swerling-1-Fluktuation je Frame: RCS exponentialverteilt.
- Zweiwege-Mehrweg, nur für Punktziele (`+render/multipathFactor.m`): Γ = −1, Rauigkeit nach Ament aus dem Seegang.
- `seamarksFromOverpass` übernimmt jetzt auch die Form (`shape`).
- `downloadSeamarks`:
  - Timeout 120 s statt 5 s (MATLAB-Default war zu kurz, Fehler bei Mike).
  - Ausweichserver.
  - Octave-tauglich.

**Herkunft der Daten:** Die Seezeichen kommen aus OpenStreetMap. OpenSeaMap stellt diese OSM-Daten (Tags `seamark:*`) nur dar. Overpass ist die Abfrageschnittstelle dafür.

### 7.3 Option C: Dihedral-Streuer aus dem DSM (hybrid)

Kandidaten bestimmt `sceneResponse.m/findScatterers`, die Stärke `sensorModel.m`.

**Kandidat:**
- Anstieg der Höhe zum Radar hin.
- Gesamtanstieg über ein Fenster (fängt die Interpolationsrampe ab) ≥ `min_wall_m` (2,5 m).
- Zelle und Fuß sichtbar.

**Radarquerschnitt:**
- σ = 10^(C/10) · a · b · cosⁿ(Δα).
- Kaimauer (See vor der Wand): zusätzlich +`quay_bonus_db`.

**Defaults (Annahmen):** C = 8 dB, n = 4, Kaimauer-Bonus 6 dB. Alle kalibrierbar.

### 7.4 Kalibrierung

- **Neue Stufen:** `range` (Gain-Kurve, Kurzpuls) und `scatterers` (Punktziel-Offset, C, n, Kaimauer-Bonus).
- **Radiometrie** jetzt mit `threshold_db`, `dynamic_range_db` und der Sea-Kurve.
- **Azimut-Deskriptor:** neue Pixelschwelle `geometry.descriptor_min_px` = 60. Ohne sie verwässerte das jetzt sichtbare Rauschen den Deskriptor, und der Azimut-Offset wurde mit 0,06° statt 1,79° geschätzt. Bestätigung durch Mike steht aus.

### 7.5 Nebenkeulen (Entscheidung Mike, 2026-10-13)

- `sidelobe_db` −25 → **−45 dB** (zweiwegig, breite Gauß-Komponente 30°).
- Kalibriergrenzen −60…−20 dB.
- Grund siehe Kap. 8.4.

---

## 8. Tests und Ergebnisse [Sim]

### 8.1 Selbsttests

- 23 Tests in Octave, alle bestanden (16 alte, 7 neue).
- Die neuen Tests prüfen:
  - Abbildung der Empfängerkette
  - Kurzpuls-Stufe: 12,04 dB
  - Mehrweg gegen die Formel; r⁻⁸ weit draußen
  - Kategorien der Seezeichen
  - Übernahme der Form aus Overpass
  - Mehrweg am Punktziel
  - Dihedral-Kandidaten an einer synthetischen Mauer

### 8.2 Vorher/Nachher 3 und 8 NM

Rostock, ohne Seezeichen. Bild: `Claude outputs/vorher_nachher_A_C.png`.

- Land ist jetzt bis zum Ende der DOM-Abdeckung (ca. 9 km) gesättigt. Rauschen erscheint schwach.
- **Auffällig:** Kurzpuls und Sea-Kurve zusammen machen die ersten ca. 0,7 km schwarz, auch das Seeclutter. Das widerspricht Mikes Beobachtung. In MATLAB mit NRL prüfen (offener Punkt 24).

### 8.3 Test B: Seezeichen im Seekanal

Pose 54,2165 N / 12,0745 E, North-up. Bild: `Claude outputs/test_B_seezeichen.png`.

**Daten:**
- 195 Seezeichen aus OSM.
- Einteilung: 138 Tonnen, 45 Spieren, 11 Baken, **nur 1 mit Reflektor-Tag**.

**Ergebnisse:**
- Die Tonnen erscheinen an den OSM-Positionen als Bögen in Azimutrichtung.
- Die Tonnen in der Unterwarnow liegen hinter Warnemünde im Schatten.

Sichtbarkeit bei 8 NM:

| Entfernung | Tonnen | sichtbar (Pixel ≥ 100) | Median Pixel |
|---|---|---|---|
| 0–2 km | 8 | 75 % | 190–210 |
| 2–4 km | 19 | 79 % | 184 |
| 4–8 km | 78 | 6 % | 59 |
| 8–15 km | 83 | 4 % | 56 |

- Bei 2 NM sind die Tonnen bis ca. 2,5 km gesättigt und bei 3–3,7 km schwach (Pixel 40–70).
- Grund: Bei 2 NM gibt es ca. 7 dB weniger Pulskompressionsgewinn; dazu kommt Mehrweg mit r⁻⁸.

**Offen:** Tragen die Leuchttonnen im Seekanal (Form `pillar`) Reflektoren? Anker dafür: Bis zu welcher Entfernung sieht Mike die Leitbojen in echten 8-NM-Scans? Deutlich über 4 km spräche für Reflektoren.

### 8.4 Test Nebenkeulen

Bild: `Claude outputs/test_nebenkeulen.png`.

- Die Bögen bzw. Schweife entlang der Kreise um starke Echos kamen von der angenommenen Nebenkeule (−25 dB, 30°).
- Sie wurden erst mit der neuen Kette sichtbar: Starke Echos liegen 30–40 dB über dem Rauschen, die Nebenkeule liegt damit noch über der Schwelle.

Anteil heller Pixel im Testausschnitt:

| Nebenkeulen | Pixel ≥ 60 | Pixel ≥ 150 |
|---|---|---|
| −25 dB | 16 % | 6,2 % |
| −45 dB | 8,4 % | 5,6 % |
| −60 dB | 8,4 % | 5,6 % |

**Entscheidung:** −45 dB. Das entspricht etwa −23 dB einwegig, einem typischen Richtwert für Marineradar-Antennen; für das Quantum 2 nicht belegt.

### 8.5 Wiederfindungsexperiment der Kalibrierung (neue Kette)

Stufen geometry/radiometry/psf, `MaxEvals` 120.

| Parameter | wahr | Start | geschätzt |
|---|---|---|---|
| Azimut-Offset | 2,00° | 0 | 1,79° |
| threshold_db | 4,0 | 2,0 | 3,7 |
| dynamic_range_db | 26 | 20 | 25,0 |
| sea_max_db | 15 | 10 | 12,0 |
| Keulenbreite | 5,6° | 4,9° | 6,8° |
| Offset See / flach / Wald / Bebauung | 4 / −5 / 3 / 2 dB | 0 | 3,4 / −1,1 / 2,0 / 5,0 |

- D: 2,00 am Start, 1,21 nach der Kalibrierung, **1,63 bei den wahren Parametern**.
- Die Parameter der Empfängerkette werden gut wiedergefunden.
- Die Kalibrierung landet aber unter D(wahr): Das Maß ist verrauscht, die Parameter passen sich teils an Zufall an.
- Vermutete Ursache: Das sichtbare Rauschen löst die Kantensuche aus (`edge_threshold` 5).
- Ein Prüflauf mit Schwelle 30 wurde abgebrochen; offen.

---

## 9. Offene Punkte (Details in `docs/ENTSCHEIDUNGEN.md`)

| Nr. | Thema | Optionen |
|---|---|---|
| 24 | Nahbereich schwarz durch Kurzpuls und Sea-Kurve | so lassen bis zur Kalibrierung; `sea_max_db` 0–3; Kurzpuls aus; Kurzpuls 4 µs (−6 dB) |
| 25 | Seezeichen-Datei | Rostock erledigt (`data/targets_rostock.csv`); Portugal offen |
| 26 | Streuer-Defaults (C, n, Kaimauer-Bonus), Speicherbedarf bei 8 NM | Kalibrierung |
| 27 | Stufen `range`/`scatterers` | nur mit passenden Scans sinnvoll |
| 28 | Kantenschwelle im Abweichungsmaß | anheben (30); relativ zum Rauschen; nur Pixel ≥ `descriptor_min_px` |
| – | Reflektoren auf Leuchttonnen | 7 dBsm lassen; `pillar` → 10 dBsm; eigene Kategorie |
| – | `descriptor_min_px` = 60 | bestätigen |

**Nicht nachgebildet:**
- Rain/FTC, Interference Rejection, Expanded Returns, Doppler, Presets der Modi.
- Mehrweg für Land.
- Kräne, Masten, Schiffe.

---

## 10. Was echte Quantum-2-Scans liefern müssen

1. Die Settings zum Aufnahmezeitpunkt: Range-Scale, Mode, Gain/Sea/Rain (Auto/Wert), STC-Preset.
2. Mehrere Range-Scales an derselben Stelle, mindestens 2 und 8 NM. Nur so lassen sich G(r), Sea-Kurve und Kurzpuls von der Szene trennen.
3. Einen Sektor mit freier See bis zum Rand, für Rauschsockel und Schwelle.
4. Bekannte Tonnen im Bild, für Punktantwort, Keulenbreite, Nebenkeulen und Reflektor-Frage.
5. Auswertung wie in Kap. 2.2 (Profile über die Entfernung, getrennt nach Land und See), dazu `runCalibration`. Auf eine Stufe bei 1–3,5 km achten: Hinweis auf den Pulswechsel.

---

## 11. Simulation ausführen

```matlab
cd('C:\Users\michi\Documents\MATLAB\MarineRadar'); addpath(pwd)
addpath tests; runAllTests                                   % 23 Selbsttests
simulatePpiFromCsv('examples/track_warnemuende.csv', 'out/test_8nm', 'RangeScaleNM', 8, 'HeadingMode', 'cog')
```

- **Eigene Pose:** CSV mit `id,lat,lon[,heading_deg]`.
- **Andere Szene:** `'Scene','config/scene_portugal.json'`.
- **Radarvariante:** `'Radar','config/<kopie>.json'`.
- **Prüfen:** `missing_frac` in `index.csv`.

---

## 12. Erzeugte Bilder

| Datei | Inhalt |
|---|---|
| `Downloads/km_data/_analyse/km_data_scan_b_000.png` | echter S-Band-Scan, polar und kartesisch |
| `Downloads/km_data/_analyse/vergleich_intensitaet_ueber_entfernung.png` | km_data gegen Simulation (alte Kette) |
| `Downloads/km_data/_analyse/radargleichung_8nm.png` | SNR über die Entfernung je Zieltyp |
| `Claude outputs/vorher_nachher_A_C.png` | 3/8 NM vor und nach A+C |
| `Claude outputs/test_B_seezeichen.png` | Seekanal mit und ohne Seezeichen |
| `Claude outputs/test_nebenkeulen.png` | Nebenkeulen −25/−45/−60 dB |
