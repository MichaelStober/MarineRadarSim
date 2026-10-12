# Simulationsmodell – Formeln, Begründungen, Grenzen

Stand: 2026-10-01. Dieses Dokument beschreibt, was der Code rechnet, und ist die Grundlage für das Methodenkapitel (die Arbeit selbst wird auf Englisch geschrieben). Jede Gleichung nennt die Datei, in der sie umgesetzt ist.

Notation: Radarposition **p** = (E, N) in UTM, Antennenhöhe h_a über Wasser, Spoke-Index k = 0…N_s−1, Bin-Index j = 1…N_b, Entfernung r, geographischer Azimut θ (im Uhrzeigersinn ab Nord).

---

## 1. Zerlegung in Szenenantwort und Sensormodell

Die Simulation ist in zwei Teile getrennt:

y = R_ψ( | h_ψ ∗ Σ_c √g_c · a_c |² + n )

- **a_c** – Szenenantwort: komplexe Streuamplitude je Feinzelle und Oberflächenklasse c. Hängt nur von Geometrie, Gelände und Radargleichung ab. Teuer. (`+render/sceneResponse.m`)
- **g_c, h_ψ, n, R_ψ** – Sensormodell: Klassen-Offsets, Punktantwort (Antenne × Puls), Rauschen, Empfängerkette. Billig. (`+render/sensorModel.m`, `+render/receiverChain.m`)

**Begründung:** Die Faltung ist linear in der Amplitude. Deshalb lassen sich alle Sensorparameter ψ ändern, ohne die Geometrie neu zu rechnen. Das macht die Kalibrierung (Abschnitt 6) erst praktikabel: Eine Auswertung kostet Sekundenbruchteile statt Sekunden.

## 2. Geometrie (`+render/samplePolar.m`, `+render/sceneResponse.m`)

**Abtastung.** Feingitter mit N_a = N_s·o_a Strahlen und N_r = N_b·o_r Entfernungen (o = Oversampling). Strahl i hat den Azimut
θ_i = θ_0 + ((i−1) − (o_a−1)/2)·Δθ, Δθ = 360°/N_a,
mit θ_0 = Heading (Head-up) oder 0 (North-up). Die Abtastpunkte liegen bei
E_ij = E + r_j·sin(θ_i − γ), N_ij = N + r_j·cos(θ_i − γ),
wobei γ die Meridiankonvergenz ist (Gitternord gegen geographisch Nord, bei Rostock ≈ −2,3°; `+geo/gridConvergence.m`). Ohne γ wäre das Bild um diesen Winkel verdreht. Die Projektion ist eine allgemeine transversale Mercatorabbildung (Krüger-Reihe, `+geo/tmForward.m`) mit Ursprung, Maßstab und Falschem Rechts-/Hochwert aus der Szene; damit sind UTM (Rostock) und PT-TM06 (Portugal, γ ≈ −0,6° bei Sesimbra) abgedeckt.

**Erdkrümmung.** In einer ebenen Szene wird die Höhe korrigiert:
h′ = h − w − r² / (2·k·R_E), k = 4/3 (Standardatmosphäre), R_E = 6371 km, w = Wasserstand.
Bei 3 km sind das 0,53 m, also dieselbe Größenordnung wie die Strandhöhe; bei 10 NM rund 20 m.

**Sichtbarkeit (Radarschatten).** Elevationswinkel ε(r) = atan((h′(r) − h_a)/r). Eine Zelle ist sichtbar, wenn
ε(r) ≥ max_{r′<r} ε(r′).

**Lokaler Einfallswinkel (Grazing).** ψ = atan(∂h′/∂r) − ε. Dem Radar zugewandte Flanken (Dünenfront, Gebäudewand) haben großes ψ und streuen stark zurück. Für See gilt ψ = −ε (mittlere Oberfläche eben).

**Höhenmodell.** DOM (Oberflächenmodell mit Bewuchs und Gebäuden), weil das Radar die Oberkante sieht. Beim Verkleinern auf 2/5/10 m wird je Block das **Maximum** genommen, damit Dünenkamm und Gebäudekanten für die Abschattung erhalten bleiben (`+dem/buildTileCache.m`).

## 3. Radiometrie (`+render/sceneResponse.m`, `+refl/buildReflectivityTable.m`)

**Flächenstreuer.** Je Feinzelle mit Fläche A = r·Δθ·Δr:
q = P_t·G²·λ²·σ⁰(ψ, c)·A·g_el(ε)² / ((4π)³·r⁴·L) · G_pc / (k_B·T_0·B·F)

- σ⁰(ψ, c): normierter Rückstreuquerschnitt je Klasse. Radar Toolbox: `seareflectivity` (NRL-Modell, gültig 0,1–60°) für See, `landreflectivity` (Nathanson, 0–60°) für Land. Das Barton-Modell ist erst ab 20° gültig und scheidet für streifenden Einfall aus.
- g_el: Elevationsdiagramm, Gauß mit 20° Halbwertsbreite.
- G_pc = max(1, τ_tx·B): Pulskompressionsgewinn.
- q ist direkt das SNR der Zelle (Rauschleistung k_B·T_0·B·F, F = 4 dB laut Datenblatt).

**Klassen** (`+scene/classifySurface.m`): See, flaches Land, Vegetation, Bebauung. Objekthöhe nDOM = DOM − DGM; Gebäude gegen Vegetation über die Ebenheit der Oberfläche (|Laplace(DOM)| im Objektinneren).

**Punktziele** (Tonnen, Baken aus ENC/OSM; `+scene/loadTargets.m`). Ein Ziel mit Radarquerschnitt σ_t in Entfernung r_t:
q_t = P_t·G²·λ²·σ_t·g_el² / ((4π)³·r_t⁴·L) · G_pc / (k_B·T_0·B·F),
eingetragen in die nächstgelegene Feinzelle, sofern der Elevationswinkel zum Ziel den bisherigen Horizont auf dem Strahl übersteigt.

Seit 2026-10-12 (Option B, Entscheidung Mike):

- **Mittlerer RCS und Höhe je Kategorie** (`scene.targets.categories`, Annahmen nach IMO MSC.192(79), Tab. 2):

  | Kategorie | Regel | σ̄_t | Höhe |
  |---|---|---|---|
  | `buoy_reflector` | Tonne mit `seamark:radar_reflector=yes` | 10 dBsm | 3,5 m |
  | `buoy` | übrige Tonnen | 7 dBsm | 3,5 m |
  | `spar` | Spierentonne ohne Reflektor | 0 dBsm | 1 m |
  | `beacon` | Baken (`beacon_*`) | 13 dBsm (Annahme) | 5 m |

  Werte in der CSV (`rcs_dbsm`, `height_m`) haben Vorrang. Kalibrierung über `class_offset_db(5)`.
- **Aspektschwankung** (`targets.fluctuation = "swerling1"`): σ_t ~ Exp(σ̄_t) je Frame (Swerling 1). Begründung: Reflektoren haben Spitzen- und Nullstellenwerte, die um mehr als eine Größenordnung auseinanderliegen (QinetiQ/MAIB 2007).
- **Zweiwege-Mehrweg** über die See, nur für Punktziele (`+render/multipathFactor.m`):
  F = |1 + Γ·ρ_s·e^{−jΔφ}|, Δφ = 4π·h_a·h_t/(λ·r), ρ_s = exp(−2·(2π·σ_h·sin ψ/λ)²), ψ = atan((h_a+h_t)/r), Faktor F⁴ auf q_t.
  Γ = −1 (H-Pol., kleiner Grazingwinkel). σ_h = H_1/3/4 aus dem Seegang (WMO-Klassenmitte). Flache Erde, kein Divergenzfaktor.
  Für glatte See gilt F⁴ = (2·sin(2π·h_a·h_t/(λ·r)))⁴; jenseits r_c ≈ 4·h_a·h_t/λ (Tonne: ≈ 1,3 km) fällt q_t mit r⁻⁸.

**Dihedral-Streuer** (Option C, hybrid, Entscheidung Mike 2026-10-12; `sceneResponse.m/findScatterers`, Stärke in `sensorModel.m`). Wand plus Boden oder Wasser davor wirkt als Winkelreflektor und erzeugt die hellen Einzelpunkte echter Bilder (Kaimauern, Spundwände, Hausecken). Die σ⁰-Modelle liefern nur Flächenmittel und bilden das nicht ab.

- **Kandidat** auf dem feinen Polargitter: Anstieg dh_j = h_j − h_{j−1} > 0 zum Radar hin, Gesamtanstieg über ein Fenster von w = ⌈Δ_DEM/Δr⌉ + 1 Zellen ≥ `min_wall_m` (fängt die Interpolationsrampe ab), Zelle und Fuß (tiefste Zelle im Fenster) sichtbar.
- **Radarquerschnitt:** σ_d = 10^{C/10} · a · b · cosⁿ(Δα) · (Kaimauer ? 10^{Δ_q/10} : 1).
  - a = min(dh_j, `max_wall_m`): Wandhöhenanteil der Zelle; Summe über die Rampe = Wandhöhe.
  - b = r·Δθ: Zellbreite.
  - cos Δα = max(g_r, 0)/√(g_r² + g_θ²): Wandnormale gegen Sichtlinie aus dem Höhengradienten.
  - Kaimauer: Fuß ist See.
- **Leistung** q_d = q₁·σ_d mit q₁ = P_t·G²·λ²·g_el²/((4π)³·r⁴·L)·G_pc/(k_B·T_0·B·F), kohärent mit eigener Zufallsphase zur Zelle addiert.
- **Annahmen:** C = 8 dB (frontale Wand 5 m × 3 m ≈ 20 dBsm), n = 4, Δ_q = 6 dB. C, n und Δ_q liegen im Sensormodell und werden billig kalibriert.
- **Grenzen:** keine echte Dihedral-Physik (ideal 8π·a²·b²/λ² mit sehr schmaler Orientierungskeule, bei DSM-Auflösung nicht beherrschbar). Kräne, Masten und Schiffe fehlen weiter. Die Höhenkanten hängen von der DEM-Stufe ab (10 m bei 7–10 NM).

## 4. Punktantwort und Speckle (`+render/sensorModel.m`)

Jeder Reflexionspunkt wird als Gauß-Fleck in Azimut und Entfernung verteilt; benachbarte Punkte überlagern sich. Das entspricht einer Faltung des Feingitters mit der Punktantwort.

**Kohärente Summe.** Amplitude je Zelle a = √(q·τ)·e^{jφ}, φ ~ U(0, 2π). Dann
b = (h_az ⊗ h_r) ∗ a, P = |b|².
Speckle entsteht so aus der Interferenz der Streuer in einer Auflösungszelle und muss nicht nachträglich aufmultipliziert werden. Der Erwartungswert E[P] = Σ q_i·|h_i|² entspricht σ⁰ mal effektiver Auflösungsfläche.

**Antenne.** Zweiwege-Leistungsdiagramm als Gauß mit Halbwertsbreite θ_3dB/√2 (θ_3dB = 4,9° Einweg); die Amplitudenantwort h_az ist die Wurzel daraus. Zusätzlich eine breite Gauß-Komponente für Nebenkeulen (Pegel und Breite sind Annahmen). Die Faltung ist zirkulär über 360° (per FFT).

**Puls.** Leistungsantwort Gauß mit Halbwertsbreite Δr = c·τ_3dB/2 (τ_3dB = 40 ns → 6 m).

**Seeclutter.** Textur τ ~ Gamma(ν, 1/ν) auf Seezellen. Zusammen mit dem Rayleigh-Speckle ergibt das K-verteiltes Clutter (Produktmodell).

**Kurzpuls im Nahbereich** (Option A, **Hypothese** für das Quantum 2; `radar.short_pulse`). Während des langen Chirps (τ_lang) ist der Empfänger taub. Den Nahbereich r < r_sp = c·τ_lang/2 muss daher ein kurzer Puls τ_kurz abdecken. Dort gilt
P ← P · G_pc,kurz/G_pc,lang, G_pc = max(1, τ·B),
bei 8 NM (16 µs gegen angenommene 1 µs) also −12 dB bis 2,4 km. Das echte Bild wird dadurch über die Entfernung gleichmäßiger. Die geänderte Entfernungsauflösung des kurzen Pulses ist nicht modelliert. τ_kurz ist kalibrierbar und je Scale über `range_scales[].short_pulse_s` überschreibbar.

**Rauschen.** n ~ Gamma(N_p, 1/N_p): Rauschleistung gemittelt über N_p = PRF/(f_rot·N_s) Pulse je Spoke. Beim Quantum 2 sind das 1,1 bis 7,2 Pulse (PRF 920–5900 Hz, 24 U/min, 2048 Spokes).

## 5. Empfängerkette (`+render/receiverChain.m`)

Seit 2026-10-12 nach Quantum-Art (Option A; die alte Kette mit floor/sat/STC ist ersetzt, Entscheidung Mike). Herleitung und Belege: `docs/RECHERCHE_ENTFERNUNGSABFALL.md`, Kap. 3.

x(r) = SNR_dB(r) − A_sea(r) + G(r)

A_sea(r) = min(A_max, 10·m·log₁₀(r_s/r)) für r < r_s, sonst 0

G(r) = min(max(g·log₁₀(r/r₀), 0), G_max)

Pixel = round( 252 · clip( (x − T)/D, 0, 1 ) )

| Symbol | Parameter | Default (Annahme) | Bedeutung, Beleg |
|---|---|---|---|
| T | `threshold_db` | 2 dB | Gain als Detektionsschwelle relativ zum mittleren Rauschen (SNR = 0 dB). Raymarine: „The manual Gain control sets the detection threshold“; Rauschen soll gerade noch minimal sichtbar sein. |
| D | `dynamic_range_db` | 20 dB | Abstand Schwelle bis Weiß. Log-Abbildung mit früher Sättigung: alles deutlich über dem Rauschen erscheint ähnlich hell. |
| A_max, r_s, m | `sea_max_db`, `sea_range_m`, `sea_exponent` | 10 dB, 1000 m, 2 | Sea-Clutter-Kurve. Raymarine: maximale Dämpfung bei r = 0, nimmt mit r ab, wirkt bis zu 5 NM. |
| g, r₀, G_max | `range_gain_db_per_decade`, `range_gain_r0_m`, `range_gain_max_db` | 0 (aus), 1000 m, 20 dB | Gain-Kurve; entspricht dem STC-Preset „equalize targets across the image“. Ohne echte Scans kein Wert → aus. |

**Warum der Abfall über die Entfernung im Bild klein ist:** Physikalisch fallen Flächenziele mit r⁻³, Punktziele mit r⁻⁴ (zwischen 2 und 8 km etwa 18 bzw. 24 dB). Liegt ein Ziel aber an beiden Stellen mehr als T + D über dem Rauschen, ist es an beiden Stellen weiß. Im Nahbereich dämpfen zusätzlich Sea-Kurve und Kurzpuls. Zusammen ergibt das das gleichmäßige Bild echter Geräte.

Nicht nachgebildet: Rain/FTC, Interference Rejection, Expanded Returns (Dilatation), Doppler-Einfärbung und die Presets der Modi (Harbour/Coastal/Offshore/Weather).

## 6. Kalibrierung als Systemidentifikation (`+calib/`)

Gegeben K echte Scans y_k mit Pose. Gesucht sind Parameter θ, die die Abweichung minimieren:

θ* = argmin_θ (1/K)·Σ_k D_k(θ)

**Abweichungsmaß** (`discrepancy.m`):
D_k = w_d·D_dist/N_d + w_e·D_edge/N_e

- D_dist = Σ_{c,b} w_cb·W₁(F^real_cb, F^sim_cb) / (252·Σ w_cb). F ist die Verteilung der Pixelwerte je Klasse c (See/Land) und Entfernungsband b. W₁ ist die Wasserstein-Distanz; für diskrete Werte exakt Σ_v |F_r(v) − F_s(v)|.
- D_edge = mittlerer, gekappter Abstand der ersten Rückstreuung je Spoke im geglätteten Bild (Küsten- und Objektkante).
- N_d, N_e: Werte der Terme bei den Startparametern. Beide Terme starten so bei 1.
- Nur gültige Spokes Ω_k gehen ein. Fehlende Bearings der echten Aufnahme verfälschen das Maß damit nicht.

**Warum Verteilungen statt Pixel:** Speckle und Restfehler der Pose machen einen pixelweisen Vergleich unbrauchbar. Zwei Realisierungen derselben Szene unterscheiden sich pixelweise stark, in ihren Verteilungen kaum.

**Warum gleiche Zellgewichte:** Etwa 99 % der Pixel sind leere See. Gewichtet nach Pixelzahl dominieren sie das Maß, und die informativen Landzellen zählen kaum.

**Stufen** (`calibrate.m`), jeweils nur die Parameter der Stufe:
1. Geometrie: Azimut-Offset der Antenne per zirkulärer Kreuzkorrelation eines radialen Deskriptors d(k) = mean_r log(1 + I(k, r)) (Idee wie LodeStar, Jang et al., RA-L 2024). Summiert über alle Scans.
2. Radiometrie: Klassen-Offsets, Schwelle T, Fenster D, Sea-Kurve.
3. Entfernung (`range`): Gain-Kurve G(r), Kurzpuls τ_kurz. Braucht Scans mehrerer Range-Scales bzw. Ziele über den ganzen Bereich.
4. Streuer (`scatterers`): Punktziel-Offset, C, n, Δ_q.
5. Punktantwort: Keulenbreite, Nebenkeulen, Entfernungsauflösung.
6. Textur: Formparameter ν.
7. Optional gemeinsam.

Grenzen über θ = lb + (ub − lb)/(1 + e^{−x}). Optimierer: `bayesopt`, falls vorhanden, sonst Nelder–Mead (`fminsearch`). Die Zufallszahlen sind je Scan fest (common random numbers), damit das Ziel in θ deterministisch ist.

**Kopplungen:** Die Schwelle T wird im Wesentlichen vom Rauschen festgelegt, die Klassen-Offsets von den Echos. Sea-Kurve und See-Offset sind gekoppelt, ebenso Gain-Kurve und Offsets, wenn nur eine Range-Scale vorliegt.

**Validierung:** Leave-one-out (`leaveOneOut.m`) und das Wiederfindungsexperiment mit synthetischer Wahrheit (`tests/runCalibrationRecovery.m`). Ergebnisse siehe `docs/KONTEXT.md`, Abschnitt 5.

## 7. Bekannte Grenzen des Modells

| Lücke | Wirkung | Status |
|---|---|---|
| Speckle wird je Frame neu gezogen | Landechos ändern sich von Scan zu Scan vollständig; real sind sie stabil | offen, hohe Priorität für das Deskriptor-Training |
| Verarbeitung des Quantum als Schwelle + Fenster + Sea-Kurve + G(r) + Kurzpuls (seit 2026-10-12), Werte angenommen | Helligkeit über die Entfernung | Struktur umgesetzt, Kalibrierung an echten Scans offen |
| Dihedral-Streuer nur aus DSM-Kanten, empirische Stärke (seit 2026-10-12) | Helle Punkte an Kaimauern, Gebäuden | umgesetzt, Kalibrierung offen; Kräne, Masten, Schiffe fehlen |
| Mehrweg nur für Punktziele (seit 2026-10-12) | Lobing von Landfronten fehlt | bewusst (Entscheidung Mike) |
| Expanded Returns, Rain, Interference Rejection nicht nachgebildet | Form und Größe der Echos | offen |
| Scan als Momentaufnahme | Verzerrung durch Fahrt und Kursänderung in 2,5 s fehlt | offen |
| Antennendiagramm und Pulsantwort als Gauß | Form der Echos | aus Punktzielen zu kalibrieren |
| Radarquerschnitt der Seezeichen je Kategorie (IMO), Swerling 1 | Helligkeit der Tonnen | Annahme, über `class_offset_db(5)` kalibrierbar |

## Quellen
- Raymarine-Dokumentation zu Gain, STC, Sea und Modi: siehe `docs/RECHERCHE_ENTFERNUNGSABFALL.md`, Kap. 3 und 9
- IMO MSC.192(79), Tab. 2 (Radarquerschnitt von Tonnen)
- Skolnik, Radar Handbook; Bole, Wall, Norris: Radar and ARPA Manual (Mehrweg, Log-Empfänger, STC)
- MathWorks: [seareflectivity](https://www.mathworks.com/help/radar/ref/seareflectivity.html), [landreflectivity](https://www.mathworks.com/help/radar/ref/landreflectivity.html), [Simulate Maritime Radar PPI](https://www.mathworks.com/help/radar/ug/simulate-maritime-radar-ppi.html)
- Raymarine: [Quantum 2 Q24D, technische Daten](https://www.raymarine.com/en-us/our-products/marine-radar/quantum/quantum-2-q24d-radome)
- Jang, Jung, Jeon, Kim: LodeStar – Maritime Radar Descriptor for Semi-Direct Radar Odometry, IEEE RA-L 9(2), 2024 (liegt im Projekt)
- Karney: Transverse Mercator with an accuracy of a few nanometers, J. Geodesy 85, 2011 (UTM-Reihe; aus dem Gedächtnis zitiert, vor Verwendung prüfen)
