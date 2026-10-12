# Kontext – Radarsimulation für die Masterarbeit

Stand: 2026-10-01. Dieses Dokument fasst alles zusammen, was ein neuer Bearbeiter (Mensch oder KI) wissen muss, um hier weiterzuarbeiten. Arbeitsregeln stehen in `AGENTS.md`.

## 1. Worum es geht

**Arbeit:** Masterarbeit von Mike (Michael Stober), Hochschule Esslingen, bei Spleenlab. Thema: GNSS-freie Lokalisierung autonomer Wasserfahrzeuge in Küstennähe, Schwerpunkt Marineradar. Die Arbeit wird auf Englisch geschrieben, die Abstimmung läuft auf Deutsch.

**Idee hinter diesem Repo:** Ein neuronaler Feature-Deskriptor (CNN wie ResNet-18/50 oder ein Transformer, noch offen) soll Radarscans gegen eine Referenz abgleichen. Echte Scans mit bekannter Pose gibt es nur wenige. Deshalb werden **synthetische Scans aus Höhenmodellen** erzeugt und zum Training genutzt. Damit das trägt, muss die Lücke zwischen simulierten und echten Scans (Domain Gap) klein und gemessen sein.

**Was das Repo leisten soll:**
1. Aus einer CSV mit Positionen (optional Heading) Radarscans simulieren, wie sie das Radar liefern würde.
2. Die Simulation mit wenigen echten Scans kalibrieren (4 Scans je Umgebung sind geplant) und den verbleibenden Abstand messen.
3. Verschiedene Radare unterstützen: zuerst Raymarine Quantum 2, später das Radar des Pohang-Canal-Datensatzes und weitere.
4. Alles so dokumentieren, dass jede Modellannahme in der Arbeit begründet werden kann.

**Umgebungen:** eigene Aufnahmen vor Rostock (etwa 3 km vor der Küste, flache Küste) und im Rostocker Hafen; Pohang Canal und MOANA als öffentliche Datensätze; eigene Aufnahmen aus Portugal.

## 2. Das Radar

Raymarine Quantum 2 (Q24D), Herstellerangaben: 9354–9446 MHz, 20 W Spitzenleistung, Keule 4,9° horizontal und 20° vertikal, horizontale Polarisation, 24 U/min, Rauschmaß unter 4 dB, PRF 920–5900 Hz, Chirp 400 ns–22 µs, Pulsbreite 40 ns–14,7 µs, Chirp-Bandbreite bis 32 MHz ([Raymarine](https://www.raymarine.com/en-us/our-products/marine-radar/quantum/quantum-2-q24d-radome)).

Von Mike: 2048 Spokes je Umdrehung mit je 1024 Werten, Pixelwerte 0–252, Antennenhöhe am Testboot 3 m, Range-Scales 1, 2, 3, 4, 7, 8, 10 NM. Aufgezeichnet wird über das SDK und ROS-2-Nodes in MCAP-Dateien, zusammen mit GNSS, IMU, ArduPilot-Pose, Heading, Geschwindigkeit und den Radareinstellungen.

Nicht veröffentlicht und deshalb Annahme oder Kalibrierparameter: PRF, Bandbreite und Pulslänge je Range-Scale, Antennengewinn, Nebenkeulen, die gesamte Signalverarbeitung (Gain, Sea, Rain, Interference Rejection, Target Expansion, Modes).

## 3. Architektur

```
simulatePpiFromCsv.m     CSV -> simulierte Scans
runCalibration.m         echte Scans -> kalibrierte Konfiguration + Report
config/                  quantum2.json, scene_rostock.json, calibration.json,
                         real_*_mapping.json, local.json (nicht eingecheckt)
+mrsim/+config           JSON laden, lokale Pfade, Range-Scale
+mrsim/+dem              Kacheln lesen, Cache in 2/5/10 m, Mosaik
+mrsim/+scene            Oberflächenklassen, Punktziele (Tonnen)
+mrsim/+geo              UTM, Meridiankonvergenz, CSV, Heading, Pose
+mrsim/+refl             Rückstreutabelle sigma0(Winkel, Klasse)
+mrsim/+render           sceneResponse (Geometrie, teuer), sensorModel (Sensor, billig),
                         receiverChain, ppiFast, ppiIQ, polar <-> kartesisch
+mrsim/+real             echte Scans: NPZ, MCAP, kartesische PNG, fehlende Spokes
+mrsim/+calib            Abweichungsmaß, Kalibrierung, Leave-one-out
+mrsim/+io               Ausgabe
tests/                   runAllTests (14 Tests), runCalibrationRecovery
docs/                    dieses Dokument, MODELL, ENTSCHEIDUNGEN, ROADMAP, DATENFORMATE
```

**Zentrale Trennung:** `sceneResponse` rechnet die geometrieabhängige Streuantwort einmal je Pose. `sensorModel` und `receiverChain` wenden darauf die Sensorparameter an. Die Kalibrierung variiert nur den zweiten Teil. Formeln in `docs/MODELL.md`.

**Zwei Backends:** `fast` (Raycasting über das DOM, Sekunden pro Frame) ist das Arbeitspferd. `iq` (radarScenario der Radar Toolbox, Stunden pro Frame) ist als Referenz gedacht.

## 4. Was fertig ist und wie es geprüft wurde

Es gab in der Entwicklung keine MATLAB-Lizenz. Getestet wurde in GNU Octave 8.4 mit 31 echten DOM-Kacheln und 5 DGM-Kacheln.

| Teil | Stand |
|---|---|
| Simulation `fast` von CSV bis PNG | in Octave getestet |
| UTM-Umrechnung, Meridiankonvergenz | gegen PROJ geprüft, Abweichung unter 1 mm |
| DOM-Cache, Klassifikation mit DGM | in Octave getestet |
| Punktziele (Tonnen) im Renderer | Selbsttest besteht |
| Empfängerkette nach Quantum-Art, Kurzpuls (Option A, 2026-10-12) | Selbsttests bestehen; 3- und 8-NM-Läufe in Octave |
| Seezeichen je Kategorie, Swerling 1, Mehrweg (Option B) | Selbsttests bestehen (Kategorien, Overpass-Umwandlung mit Form, F⁴ gegen Formel) |
| Dihedral-Streuer aus DSM-Kanten (Option C) | Selbsttest an synthetischer Mauer; 3- und 8-NM-Läufe in Octave |
| Kalibrier-Framework | in Octave getestet, Wiederfindungsexperiment siehe Abschnitt 5 |
| NPZ-Leser, kanonisches Scan-Format, Spoke-Statistik, Dropout | in Octave getestet (synthetische Datei) |
| Umrechnung kartesisch → polar | Rundlauf getestet |
| `ppiIQ` (IQ-Referenz) | geschrieben, **nie ausgeführt** |
| `readScansMcap`, `inspectMcap` | geschrieben, **nie ausgeführt** (braucht ROS Toolbox) |
| `downloadSeamarks` | geschrieben, **nie ausgeführt** (Overpass in der Entwicklungsumgebung gesperrt) |
| Reflektivität aus der Radar Toolbox | Aufruf geschrieben; in Octave lief nur das Ersatzmodell (constant gamma) |
| Kalibrierung mit echten Scans | **noch nicht möglich**, Daten fehlen |
| Szene Portugal (DGT-DSM 50 cm, EPSG:3763, Schema `geotiff`) | in Octave getestet: Cache aus 43 Kacheln, Probescan vor Sesimbra (1 und 2 NM) |
| Allgemeine TM-Projektion (`mrsim.geo.project`) | gegen PROJ geprüft für EPSG:25833 und EPSG:3763 |

Folge für den ersten Lauf in MATLAB: Die Helligkeiten ändern sich gegenüber den Octave-Tests, weil dort die Toolbox-Modelle fehlten.

## 5. Wiederfindungsexperiment der Kalibrierung

**Hinweis:** Die Tabelle stammt aus der Zeit vor dem neuen Empfängermodell (floor/sat/STC, bis 2026-10-12). Zum neuen Modell siehe den Nachtrag unten.

`tests/runCalibrationRecovery.m` erzeugt vier pseudo-echte Scans (2 NM, vor Warnemünde) mit bekannten Parametern, anderer Speckle-Realisierung und zufällig fehlenden Spokes und kalibriert ab den Standardwerten. Ergebnis vom 2026-10-01 (Octave, Ersatz-Reflektivität, 60 Auswertungen je Stufe):

| Parameter | wahr | Start | geschätzt |
|---|---|---|---|
| Azimut-Offset | 2,00° | 0 | 1,79° |
| floor_db | 6,0 | 3,0 | 6,4 |
| sat_db | 42,0 | 35,0 | 41,1 |
| stc_max_db | 38,0 | 30,0 | 35,3 |
| Keulenbreite | 5,60° | 4,90° | 5,31° |
| Offset Wald | 3,0 dB | 0 | 4,1 |
| Offset Bebauung | 2,0 dB | 0 | 3,9 |
| Offset See | 4,0 dB | 0 | 1,1 |
| Offset flaches Land | −5,0 dB | 0 | −11,6 |

Abweichung: 1,99 am Start, 0,54 nach der Kalibrierung, 0,57 bei den wahren Parametern.

**Lesart:**
- Azimut-Offset, floor/sat und Keulenbreite werden gut wiedergefunden.
- Der Offset der See und `stc_max_db` wirken beide auf das Seeecho im Nahbereich und lassen sich nicht sauber trennen.
- Der Offset für flaches Land ist kaum bestimmbar, weil flaches Land vom Wasser aus fast nie sichtbar ist.
- Die Kalibrierung landet leicht unter dem Wert der wahren Parameter. Das heißt: Unterhalb von etwa 0,55 unterscheidet das Maß nur noch Rauschen. Vier Scans tragen nicht mehr.

Zwei Dinge wurden dabei am Maß geändert, weil die erste Fassung versagte: gleiche Gewichte je Zelle statt Gewichtung nach Pixelzahl (sonst dominiert die leere See), und Kantensuche im geglätteten Bild mit niedriger Schwelle (sonst lösen einzelne Speckle-Spitzen aus).

## 6. Bekannte Lücken zur Realität

Siehe `docs/MODELL.md`, Abschnitt 7. Die wichtigsten für das Deskriptor-Training: Speckle ist nicht ortsfest; die Verarbeitungskette des Quantum ist seit 2026-10-12 strukturell nachgebildet, aber nicht kalibriert; Dihedral-Streuer an Wandkanten sind empirisch, Kräne/Masten/Schiffe fehlen. Hintergrund zur Helligkeit über die Entfernung: `docs/RECHERCHE_ENTFERNUNGSABFALL.md`.

## 7. Geplante Qualitätsstufen

| Stufe | Inhalt | erwartete Zeit je Frame |
|---|---|---|
| Q0 | heutiger `fast`-Renderer | Sekunden |
| Q1 | + ortsfestes Speckle, + Verarbeitungskette des Quantum, + kalibrierte Punktantwort | Sekunden |
| Q2 | + Ecken- und Facettenstreuer, + Mehrwegeausbreitung, + Bewegung während der Umdrehung, + 1-m-DOM | zehn Sekunden bis Minuten |
| Q3 | IQ-Referenz | Stunden |

Die Zeiten sind Schätzungen. Je Stufe werden Abweichung zu echten Scans und Rechenzeit gemessen. Das Ergebnis begründet, mit welcher Stufe die Trainingsdaten erzeugt werden. Mike hat für Q3 Stunden pro Frame freigegeben.

## 8. Externe Daten

- **DOM/DGM Rostock:** LAiV-MV, 1 m, EPSG:25833, 339 DOM- und 445 DGM-Kacheln lokal bei Mike. Die DOM-Dateien enthalten keine CRS-Angabe; das Koordinatensystem wird im Code gesetzt.
- **DSM Portugal:** DGT Modelo Digital de Superfície 50 cm (2024), EPSG:3763, 112 Kacheln à 1 × 1 km um Sesimbra/Arrábida, lokal bei Mike. Kein DGM; die Objekthöhe wird aus dem DSM geschätzt.
- **Seezeichen:** OpenSeaMap-Daten über die Overpass-API, wie bei der Dagdilelis-Reimplementierung.
- **Pohang Canal Dataset:** Radar im X-Band, 9,3–9,4 GHz, 50–1654,8 m; das Modell steht nicht im Paper ([arXiv:2303.05555](https://arxiv.org/abs/2303.05555)). Bilder liegen kartesisch als PNG vor. Ein Höhenmodell mit Gebäuden fehlt; Mike sucht eine Quelle und kauft voraussichtlich eines.

## 9. Verwandte Arbeiten im Projekt

Dagdilelis et al. (arXiv:2202.03268, Küstenabgleich mit ENC, in Python reimplementiert), LodeStar (Jang et al., RA-L 2024), Flemmen et al. 2023 (Radar-Odometrie). `IMPLEMENTIERUNGSPLAN.md` im Wurzelordner ist der ursprüngliche Plan der Simulation und nur noch historisch.
