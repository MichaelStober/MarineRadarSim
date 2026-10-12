# Recherche: Echointensität über die Entfernung (Quantum 2, 8 NM)

Stand: 2026-10-12. Entstanden in einer Claude-Sitzung mit Mike. Gedacht als Wissensbasis für die Weiterarbeit (z. B. mit Codex).
Gilt für das **Raymarine Quantum 2**. Andere Radare kommen erst später für Vergleiche dazu (Anhang B).

**Kennzeichnung jeder Aussage:**
- **[belegt]**: Quelle angegeben.
- **[gerechnet]**: Radargleichung mit den Parametern aus `config/quantum2.json`; Rechenweg in Anhang A.
- **[Sim]**: in der Simulation gemessen.
- **[Mike]**: Beobachtung von Mike an echten Quantum-2-Aufnahmen, noch nicht quantifiziert.
- **[Hypothese]**: plausibel, aber nicht belegt. Vor der Umsetzung mit Mike klären.

Regeln aus `AGENTS.md` gelten weiter: Gestaltungsentscheidungen trifft Mike. Kapitel 6 ist deshalb eine Entscheidungsvorlage, kein Auftrag.

---

## 0. Kurzfassung

1. **Die Physik fällt stark ab, die Anzeige des Radars nicht.**
   - Zwischen 2 und 8 km verliert eine steile Landfront etwa 18 dB (r⁻³), eine Tonne etwa 24 dB (r⁻⁴) [gerechnet].
   - Ein Marineradar zeigt das nicht linear an. Gain wirkt als Schwelle über dem Rauschen, danach folgt eine logarithmische, früh sättigende Abbildung [belegt, Kap. 3].
   - Alles, was deutlich über dem Rauschen liegt, erscheint damit gleich hell. Der Abfall verschwindet weitgehend im gesättigten Bereich.
2. **Unsere Empfängerkette hat ein zu breites und zu hoch liegendes Fenster.**
   - Abbildung: `floor_db` 3 → 0, `sat_db` 35 → 252. Rauschen wird schwarz.
   - Die stärksten simulierten Landechos jenseits von 2 km liegen bei 20–25 dB [Sim]. Sie bleiben dadurch mittelgrau, ab ca. 6 km verschwinden sie ganz.
3. **Im Nahbereich ist die Simulation wahrscheinlich zu stark.**
   - Sie rechnet überall mit dem vollen Pulskompressionsgewinn des langen Chirps (8 NM: 16 µs × 20 MHz → 25 dB).
   - Ein Chirp-Radar ist während des Sendens taub. Bei 16 µs betrifft das ca. 2,4 km.
   - Den Nahbereich muss das echte Gerät daher mit einem kürzeren, energieärmeren Puls abdecken [Hypothese für Quantum 2, Kap. 3.4].
   - Folge: In der Simulation ist das Verhältnis „nah zu fern“ zu groß.
4. **Tonnen fehlen in der Simulation vollständig**, weil `targets.file` leer ist [Sim].
5. **Seeclutter wird von unserem STC fast ausgelöscht.**
   - Der Default dämpft bis 1,5 km um bis zu 30 dB.
   - Das NRL-Modell liefert bei 3 m Antennenhöhe ohnehin nur ca. 18 dB SNR bei 500 m und ca. 5 dB bei 1 km [gerechnet].
6. **Helle Einzelstreuer fehlen.**
   - Gemeint sind Kaimauern, Spundwände, Kräne, Schiffe und Gebäudeecken (Winkelreflektoren).
   - Die σ⁰-Modelle (Nathanson, NRL) liefern Flächenmittelwerte. Sie bilden die dominanten hellen Punkte echter Bilder nicht ab.
7. **Testartefakt beachten.** Im Cloud-Test lagen 87 % der 8-NM-Fläche außerhalb der DOM-Kacheln (`missing_frac` = 0,87 in `index.csv`). Diese Fläche wurde als See gefüllt [Sim]. Bei jeder 8-NM-Simulation zuerst `missing_frac` prüfen.

---

## 1. Beobachtung

- **[Mike]** Simulierte Quantum-2-Scans bei 8 NM werden mit der Entfernung deutlich dunkler. Echte Quantum-2-Aufnahmen (Rostock) zeigen das nicht.
- **[Mike]** In echten Rostock-Scans sind die Fahrwassertonnen (Seekanal) sehr deutlich. Seeclutter ist intensiv sichtbar. Das Gesamtbild unterscheidet sich stark von der Simulation.
- **[Mike]** Bei Pohang und MOANA (ca. 1 NM Range) fiel das nicht auf. Bei 1 NM ist der Entfernungsbereich klein, und fast alles liegt weit über dem Rauschen.

---

## 2. Physik: was die Radargleichung erwartet

### 2.1 Radargleichung (wie in `sceneResponse.m`)

SNR einer Zelle nach Pulskompression:

```
SNR = Pt · G² · λ² · σ · F⁴ / ((4π)³ · r⁴ · L) · G_pc / (k_B · T0 · B · NF)
```

- **Flächenziel** (See, Land): σ = σ⁰(ψ) · A mit A ≈ r · θ_az · ΔR. Daraus folgt **SNR ∝ σ⁰(ψ) / r³**.
- **Punktziel** (Tonne, Schiff): σ fest, daraus folgt **SNR ∝ 1 / r⁴**.
- **Seeclutter:** Zusätzlich sinkt der Grazingwinkel ψ ≈ h_ant / r mit der Entfernung. σ⁰ fällt dabei stark (NRL: ca. −5 dB je Verdopplung bei 0,2–1°). Insgesamt also etwa r⁻⁴ bis r⁻⁵.

Parameter für 8 NM aus `config/quantum2.json`:

| Parameter | Wert | Status |
|---|---|---|
| Pt | 20 W | [belegt] Datenblatt |
| G | 24 dBi | [Hypothese] Annahme `_assumed` |
| λ | 3,19 cm | belegt |
| L | 3 dB | Annahme |
| NF | 4 dB | [belegt] |
| B | 20 MHz | Annahme |
| τ | 16 µs | Annahme |
| G_pc = τ · B | 320 (25 dB) | aus τ und B |
| θ_az | 4,9° | [belegt] |
| ΔR = c · τ_3dB / 2 | 10,5 m | Annahme |

### 2.2 Zahlen [gerechnet]

SNR vor STC, Freiraum ohne Abschattung. Skript in Anhang A.

| Entfernung | See NRL SS3, H (σ⁰) | Steile Front σ⁰ = −10 dB | Tonne 10 dBsm, Freiraum | Tonne 10 dBsm, mit Mehrweg (h = 3 / 3,5 m) |
|---|---|---|---|---|
| 0,5 km | 18,0 dB (−47,9 dB) | 55,9 dB | 49,4 dB | 59,0 dB (konstruktiv) |
| 1 km | 4,6 dB (−52,0 dB) | 46,6 dB | 37,0 dB | 46,9 dB |
| 2 km | −9,1 dB (−56,8 dB) | 37,7 dB | 25,2 dB | 34,6 dB |
| 4 km | −23,8 dB (−62,3 dB) | 28,6 dB | 13,0 dB | 12,8 dB |
| 8 km | −38,6 dB (−68,2 dB) | 19,6 dB | 1,0 dB | −10,6 dB |
| 14 km | −50,8 dB (−73,1 dB) | 12,3 dB | −8,7 dB | −29,9 dB |

Hinweise zur Tabelle:
- **NRL-Formel:** Gregers-Hansen & Mital (2012), Koeffizienten für H-Polarisation aus dem Gedächtnis implementiert. Gegen MATLAB prüfen: `seareflectivity(3, psi, 9.4e9, 'Polarization', 'H')`. Unter 0,1° Grazingwinkel (r > ca. 1,7 km bei 3 m) liegt NRL außerhalb seines Gültigkeitsbereichs.
- **Abschätzung:** Die Werte sind Größenordnungen, keine Vorhersage für Rostock. Sie zeigen aber die Steigungen.

### 2.3 Mehrweg über die Seeoberfläche (in der Simulation noch nicht enthalten)

Zweiwegemodell über glatter See:

```
F⁴ = (2 · sin(2π · h_ant · h_ziel / (λ · r)))⁴
```

- Jenseits von r_c ≈ 4 · h_ant · h_ziel / λ gilt SNR ∝ r⁻⁸.
- Werte für r_c:

| Ziel | Zielhöhe | r_c |
|---|---|---|
| Tonne | 3,5 m | ca. 1,3 km |
| Landfront | 10 m | ca. 3,8 km |
| Landfront | 30 m | ca. 11 km |

- Bei rauer See ist der Reflexionsfaktor kleiner als 1. Der Effekt fällt dann schwächer aus.
- Konsequenz: Ferne Tonnen werden physikalisch noch schwächer, nicht stärker. Nahe Tonnen (unter ca. 1,5 km) können bis zu 12 dB gewinnen.
- Quelle: Standardmodell, z. B. Skolnik, *Radar Handbook*; Bole et al., *Radar and ARPA Manual*.

### 2.4 Radarhorizont (in der Simulation über k = 4/3 enthalten)

- Formel: d = √(2 · k · R_E · h).
- 3 m Antennenhöhe: d ≈ 7,1 km.
- Am Rand der 8-NM-Scale (14,8 km) muss ein Ziel mindestens ca. 3,5 m hoch sein, um überhaupt gesehen zu werden.
- Bei 8 km reichen wenige Zentimeter. Der Horizont ist also nicht die Hauptursache für den Abfall bis etwa 10 km.

---

## 3. Was das Quantum 2 aus dem Signal macht

### 3.1 Hersteller-Dokumentation [belegt]

**Gain** ([Doku](https://docs.raymarine.com/87342/en-US/latest/Gain-4C04D783.html)):
- „The manual Gain control sets the detection threshold for the strength of targets.“
- Gain soll so eingestellt werden, dass jenseits des Seeclutters minimales Rauschen sichtbar ist.
- „The Gain control may require further adjustment when the range scale changes.“
- **Gain ist also eine Schwelle relativ zum Rauschen, keine reine Verstärkung.**

**STC preset** ([Doku](https://docs.raymarine.com/81406/en-US/latest/RadarAdvancedSettingsMenu-62A4701D.html)):
- „The Sensitivity Time Control (STC) can be used to equalize targets across the image.“
- Wertebereich 0–100 %.
- **Das ist der klarste Herstellerbeleg für einen gewollten Ausgleich über die Entfernung.**

**Sea** ([Doku](https://docs.raymarine.com/87342/en-US/latest/SeaClutter-4C72AFA7.html)):
- Maximale Dämpfung bei Entfernung 0, nimmt mit der Entfernung ab.
- Automatisch oder manuell einstellbar.
- Wirkt laut [Doku](https://docs.raymarine.com/81406/en-US/latest/RadarSensitivityControls-B34D0BA4.html) „for up to 5 nm depending on conditions“.
- Es gibt eine „Sea Clutter Curve“; deren Form ist nicht dokumentiert.

**Modi** ([Doku](https://docs.raymarine.com/81406/en-US/latest/RadarModes-4A9D65DC.html), [Vergleich](https://docs.raymarine.com/81406/en-US/latest/RadarFeatureComparison-3FE24D8B.html)):
- Quantum 2: Harbour, Coastal, Offshore, Weather.
- **Kein Buoy-Modus.**
- Die Presets der Modi sind nicht dokumentiert.

**Expanded Returns:** vorhanden, vergrößert Echos. Die Stufe ist nicht einstellbar.

**Doppler:** färbt sich nähernde und entfernende Ziele ein. Das betrifft nicht stillstehende Tonnen und Land.

**Raymarine Radar SDK** ([Link](https://www.raymarine.com/en-us/support/sdk)):
- Liefert „processed radar data“.
- Gain, Sea, Rain und Clutter sind auf Auto oder manuell stellbar.
- **Die Spokes, die Mike aufzeichnet, sind also bereits nachverarbeitet**, nicht die Rohleistung.

### 3.2 Andere Hersteller und Normen [belegt]

- **Furuno** (TimeZero-Doku, [Link](https://userguide.mytimezero.com/tz-navigator/Radar_Controls.htm)):
  - „The pulse lengths are pre-set for each range“.
  - Sea entspricht STC, Rain entspricht FTC, beide auch automatisch (ACE).
- **IMO MSC.192(79)** ([PDF](https://wwwcdn.imo.org/localresources/en/KnowledgeCentre/IndexofIMOResolutions/MSCResolutions/MSC.192(79).pdf)):
  - Gain regelt „system gain or signal threshold level“.
  - Gefordert sind wirksame manuelle und automatische Anti-Clutter-Funktionen.
  - Gilt für Berufsschifffahrt; das Quantum 2 ist nicht danach typgeprüft.
- **Olofsson et al.** (FUSION 2020): Das dort verwendete Radar schwellt das Bild herstellerseitig bei ca. 25 % des dB-Bereichs vor.

### 3.3 Abgeleitetes Modell der Anzeigekette [Hypothese]

Struktur, wie sie aus 3.1/3.2 folgt (Reihenfolge plausibel, Parameter unbekannt):

```
P(r)  → (Chirp oder kurzer Puls je Entfernung, siehe 3.4)
      → Log-Empfänger:  x = 10·log10(SNR)
      → STC/Sea-Kurve:  x' = x − A_sea(r)        (wirkt bis einige NM)
      → Gain als Schwelle relativ zum Rauschen:  x'' = x' − T_gain
      → Abbildung mit kleinem Dynamikbereich D: pix = clip(x'' / D · 252, 0, 252)
      → evtl. Rauschsockel: Rauschen erscheint als dunkles Grau statt Schwarz
      → Expanded Returns (morphologische Dilatation)
```

Warum das den Abfall „versteckt“:
- Liegt D bei 15–25 dB und T_gain knapp über dem Rauschen, ist eine Landfront bei 8 km mit ca. 20 dB SNR schon fast weiß.
- Dieselbe Landfront bei 2 km mit ca. 38 dB ist ebenfalls weiß.
- Der physikalische Unterschied von 18 dB ist im Bild nicht mehr zu sehen.

### 3.4 Kurzer Puls im Nahbereich [Hypothese, physikalisch zwingend dem Grunde nach]

- Ein Radar mit einem einzigen langen Chirp ist während des Sendens taub. Der blinde Bereich ist c · τ / 2:

| Chirplänge τ | blinder Bereich |
|---|---|
| 16 µs | 2,4 km |
| 22 µs | 3,3 km |

- Das Datenblatt nennt Pulsbreiten von 40 ns bis 14,7 µs **und** Chirps von 400 ns bis 22 µs.
- Das passt zu Pulsfolgen aus kurzem Puls für den Nahbereich und langem Chirp für den Fernbereich. Andere Solid-State-Marineradare arbeiten so.
- Für das Quantum 2 ist das nicht dokumentiert.
- Konsequenzen:
  - Im Nahbereich fehlen gegenüber unserer Simulation bis zu 10 · log10(E_lang / E_kurz) dB.
  - Das echte Bild ist dadurch über die Entfernung gleichmäßiger als die Simulation.
  - An der Übergangsentfernung kann eine sichtbare Stufe liegen. In echten Quantum-Scans gezielt danach suchen.

---

## 4. Befunde in der aktuellen Simulation [Sim]

### 4.1 Testaufbau

| Einstellung | Wert |
|---|---|
| Umgebung | Octave (Cloud) |
| Backend | `fast` |
| Range-Scale | 8 NM |
| Track / Frame | `examples/track_warnemuende.csv`, Frame 5 |
| Position | 54,22116 N / 12,13111 E |
| Heading | COG, head-up |

Abweichungen gegenüber MATLAB:
- **Reflektivität:** In Octave fehlt die Radar Toolbox. σ⁰ ist deshalb constant gamma: See −45, flach −18, Wald −12, Bebauung −6 dB. In MATLAB gelten NRL und Nathanson.
- **DOM-Abdeckung:** nur 31 Kacheln, ca. 12 × 8 km. `missing_frac` = 0,87, der Rest ist als See gefüllt.

### 4.2 SNR vor der Empfängerkette

| Entfernungsband | max SNR | p99,9 | Anteil > 10 dB |
|---|---|---|---|
| 0–0,9 km | 54,5 dB | 52,3 dB | 0,256 |
| 1,9–2,8 km | 25,9 dB | 23,9 dB | 0,038 |
| 2,8–3,7 km | 23,7 dB | 21,2 dB | 0,048 |
| 3,7–4,6 km | 24,4 dB | 17,3 dB | 0,013 |
| 4,6–5,6 km | 18,4 dB | 12,8 dB | 0,004 |
| 5,6–6,5 km | 17,8 dB | 11,2 dB | 0,002 |
| > 6,5 km | ca. 10–11 dB | ca. 8,4 dB | ca. 0 |

- Jenseits von 6,5 km sind nur noch Rauschspitzen übrig (Maximum einer Gamma-Verteilung über 2048 Spokes).
- Grund ist hier hauptsächlich die fehlende DOM-Abdeckung.
- Die Rostocker Küste ist flach. Hinter der ersten Düne bzw. Waldkante bei 3 m Antennenhöhe ist ohnehin fast alles abgeschattet. Das ist physikalisch korrekt.

### 4.3 Empfängerkette (`+mrsim/+render/receiverChain.m`)

```
A_STC(r) = min(stc_max_db, 10 · stc_exponent · log10(stc_range_m / r))   für r < stc_range_m
pix      = clip( (SNR_dB − A_STC + gain_db − floor_db) / (sat_db − floor_db) · 252, 0, 252 )
```

Defaults: `stc_range_m` 1500, `stc_exponent` 3, `stc_max_db` 30, `gain_db` 0, `floor_db` 3, `sat_db` 35.

Folgen:
- Rauschen (SNR ≈ 0 dB) wird zu Pixel 0. Im echten Bild ist Rauschen bei richtig eingestelltem Gain als feines Grau sichtbar ([belegt]: Raymarine-Gain-Empfehlung, „minimal noise“).
- 20 dB SNR wird zu Pixel 134 (mittelgrau), 25 dB zu 173.
- Weiß gibt es erst ab 35 dB. Das erreichen jenseits von ca. 2 km nur große Ziele (Schiffe, Kräne, steile Fronten).
- Das STC löscht den Seeclutter. Bei 500 m wird um 14 dB gedämpft, bei NRL-SNR von ca. 18 dB bleiben ca. 4 dB übrig, also fast Pixel 0.

### 4.4 Weitere Lücken

- **Tonnen:** `scene.targets.file` ist leer, es gibt keine Punktziele. `mrsim.scene.downloadSeamarks` (OpenSeaMap/Overpass) existiert, ist aber ungetestet.
- **Pulskompression:** Der volle Gewinn `pc_gain` gilt überall. Ein blinder Bereich bzw. kurzer Nahbereichspuls fehlt (Kap. 3.4).
- **Mehrweg:** nicht modelliert (Kap. 2.3).
- **Helle Einzelstreuer:** keine Winkel-, Dihedral- oder Spundwand-Streuer. Die Kanten im DSM gehen nur über σ⁰(ψ) und die lokale Steigung ein.
- **Expanded Returns:** keine Dilatation.

---

## 5. Erklärung je Beobachtung

| Beobachtung | Hauptursachen | Nebenursachen |
|---|---|---|
| Sim fällt bei 8 NM stark ab, real nicht | Fenster der Empfängerkette (4.3); fehlende Sättigung bzw. Schwelle relativ zum Rauschen (3.3) | DOM-Abdeckung (`missing_frac`); Nahbereich zu stark wegen vollem `pc_gain` (3.4); fehlende helle Streuer |
| Tonnen real sehr deutlich, in der Sim nicht | `targets.file` leer | Tonnen mit Radarreflektor: 5–10 m², IMO MSC.192(79) Tab. 2. Bis 2 km ca. 25–35 dB SNR, real also gesättigt. Expanded Returns vergrößert sie zusätzlich. |
| See real intensiv, in der Sim kaum | STC-Default zu stark; Seegang bzw. σ⁰ unbekannt | Gerät im Harbour-Modus dämpft vermutlich weniger [Hypothese]; Auto-Sea-Einstellung zum Aufnahmezeitpunkt unbekannt. NRL ist ein Mittelwert, reale See bei kleinem Grazingwinkel ist spitzig (K-Verteilung, Spikes). |
| Gesamtbild sehr unterschiedlich | alles oben zusammen | Speckle nicht ortsfest; Punktantwort und Azimutkeule nicht kalibriert; Rauschsockel fehlt |

---

## 6. Optionen (Entscheidungsvorlage für Mike)

Gelernte Sim-to-Real-Ansätze (z. B. GAN- oder CycleGAN-Sensormodelle) sind **ausgeschlossen**. Dafür gibt es zu wenig reale Daten (Mike, 2026-10-12).

### Option A: Empfängermodell nach Quantum-Art

**Was:** `receiverChain` wird umgebaut zu: Schwelle relativ zum Rauschen, Rauschsockel, schmaleres Log-Fenster, optional eine Gain-Kurve G(r) und ein Nahbereichsmodell für den kurzen Puls.

Mögliche Parametrierung (Namen sind Vorschläge):
- `threshold_db`: Schwelle über dem mittleren Rauschen. Default z. B. 3–6 dB.
- `dynamic_range_db`: Abstand Schwelle bis Weiß. Default z. B. 15–25 dB.
- `noise_pedestal_px`: Pixelwert für Rauschen knapp über der Schwelle. Alternativ ergibt er sich aus der Schwelle.
- `range_gain`: Kurve G(r) in dB, z. B. `a · log10(r / r0)`, begrenzt auf [0, G_max]. Alternativ stückweise linear. Entspricht dem STC-Preset bzw. „equalize targets“.
- `sea_curve`: ersetzt das heutige STC. Dämpfung A(r) = min(A_max, k · log10(r_s / r)), r_s bis ca. 5 NM.
- `short_pulse`: Übergangsentfernung r_sp und Energieverhältnis ΔE_dB. Unterhalb von r_sp wird `pc_gain` durch den Gewinn des kurzen Pulses ersetzt.

**Was ohne echte Quantum-Scans geht:**
- Die Struktur implementieren und testen.
- Defaults als `_assumed` aus Kap. 3 begründen.
- Prüfen, dass die Simulation qualitativ das Verhalten aus Kap. 1 zeigt: kein starker Abfall, sichtbarer Rauschsockel, gesättigtes Land.
- Die Parameter in `config/calibration.json` als kalibrierbar eintragen.

**Was echte Scans braucht:** die Zahlenwerte. Ohne sie bleiben es Annahmen. Für die Arbeit ist das ehrlich zu kennzeichnen.

**Aufwand:** klein. Nur `receiverChain.m`, `quantum2.json`, Tests und `MODELL.md`; billig, weil nach `sceneResponse`.

**Offen für Mike:**
- Welche Teilblöcke (Schwelle, Fenster, G(r), Sea-Kurve, kurzer Puls)?
- Defaults?
- Soll das alte STC-Modell als Option erhalten bleiben (Ablation)?

### Option B: Seezeichen plus Mehrweg

**Was:**
1. `downloadSeamarks` testen und Tonnen für Rostock laden.
2. RCS je Tonnentyp festlegen:
   - mit Radarreflektor ca. 10 dBsm
   - ohne Reflektor ca. 0–7 dBsm
   - Quelle: IMO MSC.192(79), Tab. 2
3. Zweiwege-Mehrweg F⁴ (Kap. 2.3) für Punktziele, optional auch für Land.

**Was ohne echte Daten geht:** alles bis auf die Feinabstimmung der RCS-Werte.

**Aufwand:** klein bis mittel. Overpass ist aus der Cloud gesperrt, also bei Mike lokal ausführen.

**Offen für Mike:**
- RCS-Tabelle je OpenSeaMap-Typ (`buoy_lateral`, `buoy_cardinal`, …).
- Gilt `seamark:radar_reflector=yes` als Kriterium?
- Mehrweg für Land ja oder nein?

### Option C: Helle Einzelstreuer aus dem DSM

**Was:** Kanten im DSM erkennen, die zum Radar zeigen (Gebäudefront plus Boden bzw. Wasser = Dihedral), und ihnen ein zusätzliches RCS geben.
- Beispiele: Kaimauern, Spundwände, Hausecken.
- Formeln: Dihedral σ = 8π · a² · b² / λ², begrenzt durch Kantenlänge und Ausrichtung. Alternativ ein empirischer Bonus je Klasse „Bebauung“.
- Gehört zu Qualitätsstufe Q2 (`KONTEXT.md`).

**Was ohne echte Daten geht:** Implementierung und visuelle Plausibilität. Die Stärke muss später kalibriert werden.

**Aufwand:** mittel bis groß. Rechenzeit steigt.

**Offen für Mike:** Priorität gegenüber A und B; Modellwahl (physikalisch oder empirisch).

### Reihenfolge-Vorschlag (Empfehlung, Mike entscheidet)

1. A (größter Effekt, billig).
2. B.
3. C.

Vorher `missing_frac` bei den eigenen 8-NM-Läufen prüfen und fehlende DOM-Kacheln nachladen.

---

## 7. Was echte Quantum-2-Scans liefern müssen

Damit A–C kalibriert werden können (4 Scans je Umgebung, wie geplant):

1. **Settings zum Aufnahmezeitpunkt:** Range-Scale, Modus, Gain (Auto/Wert), Sea (Auto/Wert), Rain, STC-Preset, Interference Rejection. Diese kommen aus der Settings-Message im MCAP.
2. **Mehrere Range-Scales** an derselben Stelle, mindestens 2 NM und 8 NM. Dann lassen sich G(r) und Sea-Kurve von der Szene trennen.
3. **Ein Sektor mit freier See bis zum Rand.** Daraus ergeben sich Rauschsockel und Schwelle.
4. **Bekannte Tonnen im Bild** (Seekanal Rostock) mit Positionen aus OpenSeaMap. Sie liefern die Punktantwort, die Azimutkeule und eine RCS-Plausibilität.

**Auswertung je Scan:**
- Profile über die Entfernung (Median, p90, p99 je Bin über alle gültigen Spokes), getrennt nach Land- und See-Maske.
- Dasselbe für die Simulation mit identischer Pose und Scale.
- Dazu die Kalibrierung über `runCalibration` (W₁ je Klasse × Entfernungsband).

**Suche nach Stufen:** Im echten Profil nach einer Stufe bei 1–3,5 km suchen. Eine Stufe dort spräche für den Pulswechsel aus Kap. 3.4.

---

## 8. Offene Fragen an Mike

1. Welche Teile von Option A, mit welchen Defaults?
2. RCS-Tabelle für Seezeichen (Option B)?
3. Option C jetzt oder erst mit Q2?
4. Welche Range-Scales und Settings wurden bei den Rostock-Aufnahmen verwendet (Modus Harbour/Coastal, Auto-Gain, Auto-Sea)?
5. Ist der volle Rostock-DOM-Bestand (339 Kacheln) auf dem Arbeitslaptop vorhanden? Siehe `missing_frac`.

---

## 9. Literatur und Quellen

- Raymarine Quantum 2:
  - Doku 87342 (Installation)
  - Doku 81406 (LightHouse 4)
  - Links in Kap. 3.1
- IMO MSC.192(79), Performance Standards for Radar Equipment, inkl. Tab. 2 RCS von Tonnen.
- Olofsson, Hendeby, Gustafsson, Maas, Maranò: *GNSS-Free Maritime Navigation using Radar and Digital Elevation Models*. FUSION 2020. [PDF](https://liu.diva-portal.org/smash/get/diva2:1453387/FULLTEXT01.pdf)
  - Nächster verwandter Ansatz: DEM, Sichtbarkeit, RCS proportional zur projizierten Fläche, Schwelle.
- Suo et al.: *Maritime Radar Terrain Echo Simulation Based on DEM and SAR*. J. System Simulation 32(3), 2020. [Link](https://dc-china-simulation.researchcommons.org/journal/vol32/iss3/20)
- Zhang et al.: *Wide-ranging radar simulation data generation based on multi-scale electronic charts*. J. Marine Eng. & Tech. 15(2), 2016. [Link](https://www.tandfonline.com/doi/full/10.1080/20464177.2016.1171276)
- Li et al.: *Marine Radar Target Ship Echo Generation … Based on RCS*. JMSE 13(2), 348, 2025. [Link](https://www.mdpi.com/2077-1312/13/2/348)
  - Für Schiffe und Bojen.
- Mock, Magnusson, Hertzberg: *RadaRays*. IEEE RA-L 2025. [arXiv](https://arxiv.org/abs/2310.03505), [Code](https://github.com/uos/radarays)
  - Open-Source-Simulator für rotierende Radare.
  - Vergleichsprotokoll Sim vs. Real.
- Bialer et al.: *RadSimReal*. CVPR 2024. [arXiv](https://arxiv.org/abs/2404.18150)
  - Anpassung an gemessene Punktantwort und Rauschen; braucht wenige echte Daten.
- Rezvov et al.: *Synthetic X-band radar sea clutter*. Frontiers in Marine Science 11, 2024. [Link](https://www.frontiersin.org/journals/marine-science/articles/10.3389/fmars.2024.1363135/full)
  - Synthetisches Seeclutter-Pretraining.
- MATLAB-Beispiele:
  - „Simulate a Maritime Radar PPI“: kein STC, keine Normierung, nur 1 km.
  - „Maritime Radar Sea Clutter Modeling“
  - „Introduction to Radar Scenario Clutter Simulation“: `landSurface` mit Abschattung, zur Gegenprüfung des Raycastings.
- Gregers-Hansen, Mital: *An Improved Empirical Model for Radar Sea Clutter Reflectivity*. IEEE TAES 48(4), 2012. Das ist das NRL-Modell.
- Lehrbücher:
  - Bole, Wall, Norris: *Radar and ARPA Manual*, 3. Aufl., 2014 (Log-Empfänger, STC, Anzeige).
  - Briggs: *Target Detection by Marine Radar*, IEE 2004.
- Reflektoren: QinetiQ/MAIB, *Performance investigation of marine radar reflectors on the market*, 2007. [PDF](https://assets.publishing.service.gov.uk/media/547c705540f0b6024400008d/Radar_reflectors_report.pdf)
  - Spitzen-RCS von 4–67 m², stark abhängig vom Aspektwinkel.

---

## Anhang A: Rechenweg zu Kap. 2.2 (Python, reproduzierbar)

```python
import numpy as np
Pt=20; G=10**2.4; lam=3e8/9.4e9; L=10**.3; NF=10**.4; B=20e6; Gpc=16e-6*B
th=np.radians(4.9); dR=10.5; kT=1.380649e-23*290
def snr(sig, r, F4=1.0):
    return 10*np.log10(Pt*G**2*lam**2*sig*F4/((4*np.pi)**3*r**4*L)*Gpc/(kT*B*NF))
def nrl_h(psi, SS=3, f=9.4):   # psi in Grad; Gregers-Hansen & Mital 2012, H-Pol (gegen MATLAB pruefen)
    return (-73.0 + 20.78*np.log10(np.sin(np.radians(psi)))
            + (27.5 + 7.351*psi)*np.log10(f)/(1 + 0.95*psi)
            + 25.65*(SS + 1)**(1/(2 + 0.085*psi + 0.033*SS)) + 0.0054*psi**2)
def tworay(h1, h2, r): return (2*np.sin(2*np.pi*h1*h2/(lam*r)))**4
for r in [500, 1000, 2000, 4000, 8000, 14000]:
    psi = np.degrees(np.arctan(3/r)); A = r*th*dR
    print(r, snr(10**(nrl_h(psi)/10)*A, r), snr(0.1*A, r), snr(10, r), snr(10, r, tworay(3, 3.5, r)))
```

---

## Anhang B: Vergleichsdaten anderer Radare (für später)

Kurz festgehalten. Die Simulation bleibt vorerst beim Quantum 2.

**Datensatz `km_data`** (Begleitdaten zu Flemmen et al. 2023, Repo `hflemmen/radar_odometry`, Kongsberg Maritime):
- Sequenz b: S-Band, Antenne 21 m über See, 3,1° Keule.
- 200 Umdrehungen als BMP mit 4096 Spokes × 2000 Bins, 8 bit, 6,8134 m/Bin, also 13,6 km. Die Paper-Version hat 3,4 m/Bin und 19 km.
- Zu jeder BMP gehört eine TXT je Spoke mit:
  - Zeit
  - Azimut gegen den Uhrzeigersinn relativ zum Bug [rad]
  - Heading [rad]
  - Lat/Lon [rad]
  - m/Bin
- Aufnahme: 2018-06-25, 08:17–08:25 UTC, Meløy (Nordland, Norwegen), 66,951 N / 13,482 E → 66,966 N / 13,554 E.
- DEM: Kartverket hoydedata.no, DOM 1 m.

**Befund:**
- Rauschsockel sichtbar (Median ca. 28/255) und flach bis 13,6 km.
- Land bei 12 km ähnlich hell wie bei 2 km (gesättigt).
- Seeclutter stark bis ca. 2 km.
- Das stützt Kap. 3.3 qualitativ.
- Es ist aber ein anderes Radar (S-Band, große Antennenhöhe, unbekannte Leistung) und **kein Beleg für das Quantum 2**.
