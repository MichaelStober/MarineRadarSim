# Entscheidungen

Jede Entscheidung von Mike kommt hier mit Datum hinein. Offene Punkte stehen unten; sie dürfen nicht stillschweigend entschieden werden (siehe `AGENTS.md`).

## Entschieden

| Datum | Entscheidung | Begründung / Herkunft |
|---|---|---|
| 2026-09-24 | Primäres Backend ist `fast` (Raycasting über das DOM mit Gauß-Fleck je Reflexionspunkt) | Mike hat das Verfahren schon erfolgreich getestet; IQ-Simulation ist für ganze Tracks zu langsam |
| 2026-09-24 | Spoke-Format 2048 × 1024, Werte 0–252; Antennenhöhe 3 m | Angabe von Mike |
| 2026-09-24 | Range-Scales 1, 2, 3, 4, 7, 8, 10 NM einstellbar | Angabe von Mike |
| 2026-09-24 | Heading ist optional (`HeadingMode` auto/north/csv/cog, `HeadingDeg`) | Heading lag zunächst nicht vor |
| 2026-09-24 | Koordinatensystem der Höhendaten: ETRS89 / UTM 33N (EPSG:25833) | Portal-Metadaten, von Mike bestätigt |
| 2026-10-01 | Höhen für das Raycasting kommen aus dem **DOM** (Oberflächenmodell), nicht aus dem DGM | Bauwerke und Bewuchs prägen das Radarbild |
| 2026-10-01 | Reihenfolge: erst Daten-Schnittstelle und Kalibrierung, dann Physik-Erweiterungen als Ablation, dann Profile/Multi-Radar; Formelkapitel begleitend | Antwort von Mike |
| 2026-10-01 | Je Umgebung werden 4 echte Scans für die Kalibrierung untersucht | Antwort von Mike |
| 2026-10-01 | Für die Referenzstufe Q3 (IQ) sind Stunden pro Frame in Ordnung | Antwort von Mike |
| 2026-10-01 | Fehlende Spokes in eigenen Aufnahmen werden maskiert (Kalibrierung) und als Augmentierung nachgebildet (Training) | Aufnahme-Setup liefert derzeit Lücken bei bestimmten Bearings |
| 2026-10-01 | Tonnen und Baken aus ENC/OpenSeaMap gehen als Punktziele in die Simulation ein | Viele Tonnen tragen Radarreflektoren und sind im Scan sichtbar |
| 2026-10-01 | Das Repo muss ohne Claude unter Linux laufen und mit Codex weiterentwickelbar sein; Mike wird in Entscheidungen eingebunden | Arbeitslaptop |
| 2026-10-01 | PPI-Bilder aus dem PPI-Node werden nicht verwendet | Enthalten eingezeichnete Grafiken |
| 2026-10-12 | Zweites Gebiet: Portugal (Sesimbra) mit DGT-DSM 50 cm, eigene Szenendatei `scene_portugal.json` | Wunsch von Mike; Daten liegen vor |
| 2026-10-12 | Kein gelernter Sim-to-Real-Ansatz (GAN/CycleGAN-Sensormodell) | Zu wenig reale Daten (Mike). Stattdessen physikalisch/parametrisch + Kalibrierung, siehe `docs/RECHERCHE_ENTFERNUNGSABFALL.md` |
| 2026-10-12 | Simulation bleibt auf das Quantum 2 fokussiert; andere Radare (z. B. Kongsberg S-Band aus `km_data`) erst später für Vergleiche | Mike |

## Offen – Mike entscheidet

### Daten
1. **NPZ-Aufnahmen:** Wie heißen die Schlüssel (Spokes, Zeit, Winkel)? Liegt ein Scan je Datei vor oder mehrere? Wie sind fehlende Spokes kodiert: Nullzeilen, eigene Maske oder fehlende Winkel? Bis das klar ist, steht in `config/real_npz_mapping.json` die Regel `zero_rows` als Platzhalter.
2. **GPS zu den NPZ:** In welchem Format liegt es vor und wie wird es zeitlich zugeordnet?
3. **Heading für die extrahierten Daten:** Die extrahierten Scans haben kein Heading, die MCAP-Dateien schon. Optionen: (a) Scans direkt aus MCAP lesen, (b) Heading nachträglich exportieren, (c) Kurs aus den GPS-Positionen, (d) je Scan per Kreuzkorrelation gegen die Simulation schätzen. (d) vermischt Heading-Fehler und Montage-Offset.
4. **MCAP:** Topic-Namen und Nachrichtendefinition der Spokes, des GNSS, des Headings und der Einstellungen (`mrsim.real.inspectMcap` liefert die Liste).
5. **Pohang:** Radarmodell, Pixelgröße und Ausrichtung der PNG, Format der Referenzposen, Quelle für ein Höhenmodell.

### Modell
6. **DGM in der Klassifikation:** Beibehalten (Objekthöhe = DOM − DGM) oder ganz darauf verzichten (`dgm_dir` leer)? Das Raycasting ist davon nicht betroffen.
7. **Radarquerschnitt der Tonnen:** Standard 10 dBsm mit Reflektor, 0 dBsm ohne, Höhe 3 m sind Annahmen. Alternativen: Werte je Tonnentyp, oder als Kalibrierparameter schätzen.
8. **Ortsfestes Speckle (Stufe Q1):** Phase je Weltzelle festhalten. Offen ist, wie stark sie vom Blickwinkel abhängen soll.
9. **Verarbeitungskette des Quantum:** Welche Stufen werden nachgebildet und wie hängen sie von den geloggten Einstellungen ab? Dafür braucht es Aufnahmen derselben Szene mit unterschiedlichen Einstellungen.
10. **Diskrete Streuer in Hafen und Kanal:** Facettenmodell aus dem DOM, Ecken-Verstärkung am Mauerfuß, Schiffe aus AIS – was davon und in welcher Reihenfolge?
11. **Mehrwegeausbreitung und Refraktion:** einbauen oder nur randomisieren?

### Kalibrierung
12. **Abweichungsmaß:** Die Gewichte (`w_dist`, `w_edge` = 1), die Zahl der Entfernungsbänder (8) und die Kantenschwelle (5) sind erste Werte aus dem Wiederfindungsexperiment. Zu prüfen mit echten Scans.
13. **Gruppierung:** Getrennte Kalibrierung je Radar-Mode ist voreingestellt (`group_by`). Auch nach Range-Scale oder Gain/Sea-Auto trennen?
14. **Identifizierbarkeit:** See-Offset und `stc_max_db` sind gekoppelt, der Offset für flaches Land ist kaum bestimmbar. Optionen: Parameter festhalten, Grenzen enger setzen, oder Scans aus anderen Geometrien hinzunehmen.
15. **Domain Randomization:** Um welche Parameter und wie breit wird beim Erzeugen der Trainingsdaten gestreut?

### Portugal (seit 2026-10-12)
18. **Wasserstand:** Das DSM hat Wasser bei 0 m. An der Atlantikküste ist der Tidenhub deutlich; für den Vergleich mit echten Scans muss `water_level_m` je Scan aus Pegeldaten kommen. Quelle der Pegel offen.
19. **Fehlende Bereiche:** Außerhalb der Befliegung gilt `missing_data: "sea"`. Landseitige Lücken würden damit als See gerechnet. Alternative `"none"` (kein Echo, keine Abschattung).
20. **Auflösung:** Die DSM-Daten haben 0,5 m, genutzt werden bisher wie in Rostock 2/5/10 m. Eine 1-m- oder 0,5-m-Stufe für nahe Range-Scales wäre möglich (Rechenzeit, Speicher).
21. **Klassifikation ohne DGM:** Objekthöhe per morphologischer Öffnung; im steilen Gelände (Arrábida) unsicher. Alternative: DGM der DGT beschaffen, falls verfügbar.

### Lernen (außerhalb dieses Repos, aber abhängig davon)
22. **Netz:** CNN (ResNet-18/50) oder Transformer; polare oder kartesische Eingabe.
23. **Aufteilung** der echten Daten in Training, Validierung und Test über Pohang, MOANA, Rostock und Portugal.
