# Roadmap

Reihenfolge wie von Mike festgelegt (2026-10-01). Jede Aufgabe hat ein Abnahmekriterium. Vor Beginn einer Aufgabe die zugehörigen offenen Punkte in `docs/ENTSCHEIDUNGEN.md` mit Mike klären.

## Phase 0 – Erster Lauf in MATLAB (sofort möglich)

| # | Aufgabe | Abnahme |
|---|---|---|
| 0.1 | DOM/DGM nach `rostock_dom/` und `rostock_dem/` legen (oder `config/local.json`), `addpath tests; runAllTests` | 16 Tests bestehen in MATLAB R2025b unter Windows und Linux |
| 0.2 | `simulatePpiFromCsv('examples/track_c_warnemuende_heading.csv', 'out/c', 'RangeScaleNM', 2)` | Cache wird gebaut, Bilder entstehen, Toolbox-Reflektivität wird verwendet (Meldung „sigma0-Quellen“ nennt `seareflectivity`/`landreflectivity`) |
| 0.3 | `runCalibrationRecovery` in MATLAB | Tabelle wie in `docs/KONTEXT.md`, Abschnitt 5; Abweichungen dokumentieren |
| 0.4 | `ppiIQ` einmal mit `max_pulses = 50` ausführen | läuft durch oder die Fehler sind mit Mike besprochen |

## Phase 1 – Daten-Schnittstelle

| # | Aufgabe | Abnahme |
|---|---|---|
| 1.1 | NPZ: `mrsim.real.inspectNpz` auf eine echte Datei, Mapping ausfüllen (offene Punkte 1–3) | `importNpzScans` liefert Scans mit plausibler `valid`-Maske; Vorschau-PNG stimmt mit Mikes Darstellung überein |
| 1.2 | MCAP: `inspectMcap`, Mapping ausfüllen, `readScansMcap` zum Laufen bringen | Scan aus MCAP ist identisch mit dem aus NPZ für denselben Zeitpunkt |
| 1.3 | Spoke-Statistik über alle Aufnahmen (`spokeStats`) | Bericht: Anteil fehlender Spokes, Sektorlängen, betroffene Bearings |
| 1.4 | Pohang: Importer für kartesische PNG mit Pose (offener Punkt 5) | Scan im kanonischen Format, Ausrichtung an einer bekannten Struktur geprüft |
| 1.5 | Seezeichen für Rostock laden (`downloadSeamarks`), in der Szene eintragen | Tonnen erscheinen in der Simulation an den Positionen der echten Scans |

## Phase 2 – Kalibrierung mit echten Scans

| # | Aufgabe | Abnahme |
|---|---|---|
| 2.1 | 4 Scans je Umgebung auswählen (Rostock offshore, Rostock Hafen) | Liste mit Zeit, Pose, Einstellungen, Begründung der Auswahl |
| 2.2 | `runCalibration` auf Stufe Q0 | Report mit Abweichung vorher/nachher, Leave-one-out, Vergleichsbildern |
| 2.3 | Maß und Gewichte mit Mike prüfen (offene Punkte 12–14) | Entscheidung protokolliert |
| 2.4 | Punktantwort aus isolierten Punktzielen (Tonnen) schätzen | Keulenbreite und Entfernungsauflösung mit Unsicherheit |

## Phase 3 – Physik-Erweiterungen als Ablation

Jede Erweiterung einzeln einbauen und mit Abweichung und Rechenzeit gegen den Stand davor vergleichen.

| # | Erweiterung | Stufe |
|---|---|---|
| 3.1 | Ortsfestes Speckle (offener Punkt 8) | Q1 |
| 3.2 | Verarbeitungskette des Quantum, abhängig von den Einstellungen (offener Punkt 9) | Q1 |
| 3.3 | Facetten- und Eckenstreuer (offener Punkt 10) | Q2 |
| 3.4 | Mehrwegeausbreitung, Refraktion (offener Punkt 11) | Q2 |
| 3.5 | Bewegung während der Umdrehung, Roll/Pitch | Q2 |
| 3.6 | Vergleich Q0–Q3: Abweichung gegen Rechenzeit | Diagramm und Tabelle für die Arbeit |

## Phase 4 – Profile und weitere Radare

| # | Aufgabe | Abnahme |
|---|---|---|
| 4.1 | Hardware-Profil und Betriebsprofil trennen | Quantum-Einstellungen (Mode, Gain, Sea, Rain, IR, TE) wählbar; kalibrierte Werte je Profil |
| 4.2 | Allgemeiner GeoTIFF-Leser (beliebiges Kachelschema und Koordinatensystem) | Szene außerhalb von MV lässt sich einrichten |
| 4.3 | Radarprofil für Pohang, kartesische Ausgabe | Simulierte Scans im Format des Datensatzes |

## Phase 5 – Trainingsdaten

| # | Aufgabe | Abnahme |
|---|---|---|
| 5.1 | Domain Randomization um die kalibrierten Parameter (offener Punkt 15) | Konfiguration mit Verteilungen, Protokoll je erzeugtem Scan |
| 5.2 | Spoke-Dropout als Augmentierung | Statistik der simulierten Ausfälle entspricht der gemessenen |
| 5.3 | Erzeugung großer Mengen (parallel) | Durchsatz gemessen, Daten mit Metadaten und Ground Truth |

## Begleitend – Thesis-Kapitel

`docs/MODELL.md` wird mit jeder Modelländerung fortgeschrieben und am Ende ins Englische übertragen (LaTeX-Vorlage von Prof. Marchthaler).
