# AGENTS.md – Arbeitsanweisungen für KI-Assistenten (Codex u. a.)

Dieses Repository gehört zur Masterarbeit von Mike (Michael Stober): GNSS-freie Lokalisierung autonomer Wasserfahrzeuge mit Marineradar. Hier entsteht die **Simulation synthetischer Radarscans** (Raymarine Quantum 2 und weitere Radare) aus Höhenmodellen, inklusive **Kalibrierung an echten Scans**. Die synthetischen Scans dienen später als Trainingsdaten für einen gelernten Feature-Deskriptor.

**Zuerst lesen, in dieser Reihenfolge:**
1. `docs/KONTEXT.md` – Ziel, Stand, Architektur
2. `docs/ENTSCHEIDUNGEN.md` – was entschieden ist und was offen ist
3. `docs/ROADMAP.md` – Aufgaben mit Abnahmekriterien
4. `docs/MODELL.md` – Formeln und Begründungen (Grundlage des Thesis-Kapitels)
5. `docs/DATENFORMATE.md` – Ein- und Ausgabeformate
6. `docs/RECHERCHE_ENTFERNUNGSABFALL.md` – Recherche zur Echointensität über die Entfernung (Quantum 2, 8 NM): Physik, Anzeigekette des Geräts, Befunde der Simulation, Optionen A–C

---

## 1. Zusammenarbeit: Mike entscheidet mit

Mike will aktiv in die Gestaltung eingebunden sein. Das ist die wichtigste Regel dieses Repos.

- **Keine stillen Annahmen.** Fehlt eine Information (Datenformat, Parameterwert, Verhalten des echten Radars), dann fragen. Nicht raten und weiterbauen.
- **Vor jeder Gestaltungsentscheidung fragen.** Dazu zählen: Modellwahl (z. B. welches Streumodell), neue Parameter und ihre Defaults, Änderungen an Datenformaten oder Schnittstellen, neue Abhängigkeiten, Umbau der Ordnerstruktur, Wahl von Metriken und Gewichten.
- **Optionen statt fertiger Lösung.** Zu jeder Entscheidung 2–4 Optionen mit Vor- und Nachteilen nennen (Genauigkeit, Rechenzeit, Aufwand, Begründbarkeit in der Arbeit). Eine Empfehlung ist erwünscht, die Wahl trifft Mike.
- **Erst Plan, dann Code.** Bei Aufgaben, die mehr als eine Datei oder ein Modell betreffen: kurzen Plan vorlegen und Freigabe abwarten.
- **Kleine, überprüfbare Schritte.** Ein Thema pro Änderung. Nach jedem Schritt zeigen, was sich geändert hat und wie es geprüft wurde.
- **Unvermeidbare Annahmen sichtbar machen.** In JSON mit einem `_assumed`- oder `_`-Kommentarfeld, im Code als Kommentar, und als Eintrag unter „Offen“ in `docs/ENTSCHEIDUNGEN.md`.
- **Entscheidungen protokollieren.** Jede Entscheidung von Mike kommt mit Datum und Begründung in `docs/ENTSCHEIDUNGEN.md`.
- **Ehrlich berichten.** Klar trennen zwischen „getestet“, „implementiert, aber ungetestet“ und „nicht umgesetzt“. Fehlgeschlagene Tests und Grenzen des Modells nennen.

Ohne Rückfrage erlaubt: Tippfehler, Kommentare, reine Fehlerbehebung ohne Verhaltensänderung, Tests ergänzen, Dokumentation an den Code angleichen.

## 2. Wissenschaftlicher Anspruch

Die Arbeit muss jede Modellannahme begründen können.

- Jede Formel im Code bekommt einen Kommentar mit Quelle (Paper, Doku-Seite, Datenblatt) oder dem Hinweis „eigene Herleitung“.
- Neue Modellteile zusätzlich in `docs/MODELL.md` eintragen: Formel, Begründung, Alternativen, Grenzen.
- Behauptungen über das echte Radar nur mit Quelle. Unbelegtes als Annahme kennzeichnen.
- Jede Modellerweiterung wird mit dem Kalibriermaß (`mrsim.calib.discrepancy`) und der Rechenzeit bewertet (Ablation), nicht nach Augenschein.

## 3. Technische Regeln

- **Plattformen:** Das Repo läuft unter Windows (Mikes privater Laptop) und Linux (Arbeitsrechner). Keine absoluten Pfade im Repo. Maschinenspezifische Pfade stehen in `config/local.json` (nicht eingecheckt, Vorlage `config/local.example.json`). Pfade immer mit `fullfile` bauen.
- **MATLAB R2025b** mit Radar, Phased Array, Mapping und ROS Toolbox ist die Zielumgebung.
- **Der Kern läuft auch in GNU Octave** (so wurde er ohne MATLAB-Lizenz getestet). Deshalb im Kern: keine `arguments`-Blöcke (stattdessen `inputParser`), keine `string`-Objekte (nur `char`), kein `readtable`/`writetable`, Toolbox-Aufrufe mit `exist(...)`-Abfrage und Fallback. Soll diese Regel fallen, vorher Mike fragen.
- **Parameter gehören in JSON** unter `config/`, nicht in den Code.
- **Struktur:** Funktionen im Package `+mrsim` (`+config`, `+dem`, `+scene`, `+geo`, `+refl`, `+render`, `+real`, `+calib`, `+io`). Einstiegspunkte im Repo-Wurzelordner.
- **Kommentare und Meldungen** auf Deutsch in ASCII (ae/oe/ue), wie im Bestand. Der Thesis-Text ist Englisch.
- **Große Daten nie einchecken** (`cache/`, `out/`, `data/`, DOM/DGM-Kacheln, Aufnahmen). Siehe `.gitignore`.

## 4. Prüfen vor jeder Übergabe

```matlab
addpath tests; runAllTests            % 16 Selbsttests, ohne Daten, ~30 s
runCalibrationRecovery                % braucht DOM-Cache; prüft die Kalibrierung an synthetischer Wahrheit
```

- Alle Selbsttests müssen bestehen. Für neue Funktionen einen Test in `tests/runAllTests.m` ergänzen.
- Bei Änderungen an Renderer, Sensormodell oder Metrik zusätzlich `runCalibrationRecovery` laufen lassen und das Ergebnis berichten.
- `ppiIQ.m` und `readScansMcap.m` wurden nie in MATLAB ausgeführt. Beim ersten Lauf Fehler erwarten und mit Mike durchgehen.

## 5. Was nicht getan werden soll

- Parameter „passend drehen“, bis ein Bild gut aussieht. Kalibriert wird über `runCalibration`, nachvollziehbar und mit Leave-one-out.
- Annahmen aus dieser Datei oder aus Kommentaren als Fakten über das echte Radar ausgeben.
- Echte Daten, Pfade oder Zugangsdaten ins Repo schreiben.
- Den Octave-kompatiblen Kern, das kanonische Scan-Format oder die Trennung Szenenantwort/Sensormodell ohne Rücksprache umbauen.
