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
eingetragen in die nächstgelegene Feinzelle, sofern der Elevationswinkel zum Ziel den bisherigen Horizont auf dem Strahl übersteigt. Die Standardwerte für σ_t (10 dBsm mit Reflektor, 0 dBsm ohne) und die Höhe (3 m) sind **Annahmen**.

## 4. Punktantwort und Speckle (`+render/sensorModel.m`)

Jeder Reflexionspunkt wird als Gauß-Fleck in Azimut und Entfernung verteilt; benachbarte Punkte überlagern sich. Das entspricht einer Faltung des Feingitters mit der Punktantwort.

**Kohärente Summe.** Amplitude je Zelle a = √(q·τ)·e^{jφ}, φ ~ U(0, 2π). Dann
b = (h_az ⊗ h_r) ∗ a, P = |b|².
Speckle entsteht so aus der Interferenz der Streuer in einer Auflösungszelle und muss nicht nachträglich aufmultipliziert werden. Der Erwartungswert E[P] = Σ q_i·|h_i|² entspricht σ⁰ mal effektiver Auflösungsfläche.

**Antenne.** Zweiwege-Leistungsdiagramm als Gauß mit Halbwertsbreite θ_3dB/√2 (θ_3dB = 4,9° Einweg); die Amplitudenantwort h_az ist die Wurzel daraus. Zusätzlich eine breite Gauß-Komponente für Nebenkeulen (Pegel und Breite sind Annahmen). Die Faltung ist zirkulär über 360° (per FFT).

**Puls.** Leistungsantwort Gauß mit Halbwertsbreite Δr = c·τ_3dB/2 (τ_3dB = 40 ns → 6 m).

**Seeclutter.** Textur τ ~ Gamma(ν, 1/ν) auf Seezellen. Zusammen mit dem Rayleigh-Speckle ergibt das K-verteiltes Clutter (Produktmodell).

**Rauschen.** n ~ Gamma(N_p, 1/N_p): Rauschleistung gemittelt über N_p = PRF/(f_rot·N_s) Pulse je Spoke. Beim Quantum 2 sind das 1,1 bis 7,2 Pulse (PRF 920–5900 Hz, 24 U/min, 2048 Spokes).

## 5. Empfängerkette (`+render/receiverChain.m`)

v = SNR_dB − A_STC(r) + G, A_STC(r) = min(A_max, 10·m·log₁₀(r_STC/r)) für r < r_STC,
Pixel = clip( round( 252·(v − v_floor)/(v_sat − v_floor) ), 0, 252 ).

Das ist ein einfaches Ersatzmodell. Die echte Verarbeitung des Quantum (Gain auto, Sea auto mit Clutter-Kurve, Rain, Interference Rejection, Target Expansion, Modes) ist nicht veröffentlicht und wird parametrisch nachgebildet und kalibriert.

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
2. Radiometrie: Klassen-Offsets, STC, floor/sat.
3. Punktantwort: Keulenbreite, Nebenkeulen, Entfernungsauflösung.
4. Textur: Formparameter ν.
5. Optional gemeinsam.

Grenzen über θ = lb + (ub − lb)/(1 + e^{−x}). Optimierer: `bayesopt`, falls vorhanden, sonst Nelder–Mead (`fminsearch`). Die Zufallszahlen sind je Scan fest (common random numbers), damit das Ziel in θ deterministisch ist.

**Nicht identifizierbar:** Der Empfänger-Gain und ein gemeinsamer Offset aller Klassen wirken gleich. Der Gain bleibt deshalb fest.

**Validierung:** Leave-one-out (`leaveOneOut.m`) und das Wiederfindungsexperiment mit synthetischer Wahrheit (`tests/runCalibrationRecovery.m`). Ergebnisse siehe `docs/KONTEXT.md`, Abschnitt 5.

## 7. Bekannte Grenzen des Modells

| Lücke | Wirkung | Status |
|---|---|---|
| Speckle wird je Frame neu gezogen | Landechos ändern sich von Scan zu Scan vollständig; real sind sie stabil | offen, hohe Priorität für das Deskriptor-Training |
| Verarbeitung des Quantum nur als STC + dB-Abbildung | Helligkeitsverteilung und Kantenbreite | offen |
| Nur Flächenstreuer und Punktziele aus Listen | Ecken (Mauer–Wasser), Kräne, Schiffe fehlen | offen |
| Keine Mehrwegeausbreitung über See | Lobing niedriger Ziele bei 3 m Antennenhöhe | offen |
| Scan als Momentaufnahme | Verzerrung durch Fahrt und Kursänderung in 2,5 s fehlt | offen |
| Antennendiagramm und Pulsantwort als Gauß | Form der Echos | aus Punktzielen zu kalibrieren |
| Radarquerschnitt der Tonnen pauschal | Helligkeit der Tonnen | Annahme |

## Quellen
- MathWorks: [seareflectivity](https://www.mathworks.com/help/radar/ref/seareflectivity.html), [landreflectivity](https://www.mathworks.com/help/radar/ref/landreflectivity.html), [Simulate Maritime Radar PPI](https://www.mathworks.com/help/radar/ug/simulate-maritime-radar-ppi.html)
- Raymarine: [Quantum 2 Q24D, technische Daten](https://www.raymarine.com/en-us/our-products/marine-radar/quantum/quantum-2-q24d-radome)
- Jang, Jung, Jeon, Kim: LodeStar – Maritime Radar Descriptor for Semi-Direct Radar Odometry, IEEE RA-L 9(2), 2024 (liegt im Projekt)
- Karney: Transverse Mercator with an accuracy of a few nanometers, J. Geodesy 85, 2011 (UTM-Reihe; aus dem Gedächtnis zitiert, vor Verwendung prüfen)
