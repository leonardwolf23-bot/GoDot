# Sprite-Anleitung: Top-Down / Low Top-Down

Diese Anleitung erklärt, wie du Grafiken zeichnest, die in **Vegane Stadt 2040** optisch und technisch passen.

---

## Kurz: Was dein Spiel erwartet

| Typ | Datei | Größe | Perspektive |
|-----|-------|-------|-------------|
| Standard-Gebäude (3×3) | `assets/buildings/<id>.png` | **192×192 px** | Low Top-Down |
| Straße (1×1) | `assets/buildings/strasse.png` | **64×64 px** | Draufsicht |
| Boden-Tile (Gras) | `assets/tiles/iso/grass.png` | **64×32 px** (Raute) | Isometrisch |
| Villager | `assets/test/villager/...` | **124×124 px** pro Frame | Low Top-Down, 8 Richtungen |

**Wichtig:** Das Spiel nutzt ein **isometrisches 64×32-Raster** (2:1-Rauten). Boden-Kacheln: siehe [`docs/ISO_TILES.md`](ISO_TILES.md). Gebäude-Sprites: Low Top-Down mit isometrischer Boden-Raute.

---

## 1. Perspektive verstehen

### ❌ Nicht Isometrie
Isometrische Spiele nutzen Rauten-Tiles im 2:1-Verhältnis. Das ist **nicht** dein Spiel.

### ✅ Low Top-Down (leichte Draufsicht)
Du schaust **fast von oben**, aber nicht komplett flach:

- Man sieht **Dächer** und oft ein Stück **Südwand** (untere Kante im Bild).
- Nordwand ist meist **nicht** oder nur angedeutet sichtbar.
- Schatten fallen typischerweise **nach unten-rechts** oder **nach Süden**.

**Gedächtnisregel:** Stell dir vor, die Kamera hängt schräg über der Stadt – etwa wie bei alten Siedler-/Aufbauspielen.

**Faustwinkel fürs Zeichnen:** ca. **60–75° von der Horizontalen** (also nicht 90° senkrecht von oben, aber auch nicht 45° isometrisch).

---

## 2. Raster & Canvas-Größen

### Gebäude (fast alles 3×3)
- **1 Tile = 64 px**
- **3×3 Gebäude = 192×192 px**
- Vorlage im Projekt: `assets/templates/building_3x3_grid.png`

```
┌────────┬────────┬────────┐  ← 64 px
│        │        │        │
├────────┼────────┼────────┤
│        │  HAUS  │        │  192 px gesamt
├────────┼────────┼────────┤
│        │        │        │
└────────┴────────┴────────┘
     192 px gesamt
```

### Straße
- **64×64 px**
- Vorlage: `assets/templates/tile_1x1_grid.png`

### Technik im Spiel
Godot zeichnet dein PNG **auf die Grundfläche gestreckt**. Wenn du z. B. 512×300 exportierst, wird es auf 192×192 verzerrt. **Immer im Zielseitenverhältnis zeichnen.**

---

## 3. Schritt-für-Schritt: Gebäude zeichnen

### Schritt 1 – Canvas anlegen (Aseprite / Krita / Photoshop)
1. Neues Bild: **192×192 px**
2. Raster / Hilfslinien alle **64 px**
3. Optional: `building_3x3_grid.png` als Hintergrund-Layer (50 % Deckkraft)

### Schritt 2 – Grundfläche blocken
- Die **gesamte 192×192-Fläche** ist die belegte Baufläche im Spiel.
- Zeichne zuerst die **Bodenplatte / Fundament** als Draufsicht-Rechteck.
- Das Gebäude „sitzt“ oben links auf der Zelle – kein Versatz nötig.

### Schritt 3 – Wände & Dach (Low Top-Down)
Typischer Aufbau von unten nach oben:

1. **Schatten** auf dem Boden (weich, halbtransparent)
2. **Südwand** – am sichtbarsten (untere Bildkante)
3. **Seitenwände** – nur leicht angedeutet (West/Ost)
4. **Dach** – größter sichtbarer Teil, von oben/leicht schräg
5. **Details** – Schornstein, Fenster, Schild, Bäume

**Süden = unten im Sprite** (weil im Spiel höhere Y-Werte weiter „unten“ auf der Karte liegen und darüber gezeichnet werden).

### Schritt 4 – Licht & Schatten festlegen
Wähle **eine** Lichtrichtung für alle Gebäude, z. B.:

- Licht von **oben links**
- Schatten nach **unten rechts**

So sehen alle Gebäude zusammen konsistent aus.

### Schritt 5 – Export
- Format: **PNG mit Transparenz**
- Keine eingebetteten Hintergründe
- Dateiname = Gebäude-ID aus `game_data.gd`, z. B. `soja_farm.png`
- Ablage: `assets/buildings/`

### Schritt 6 – Im Spiel testen
1. Godot öffnen / Spiel starten
2. Gebäude neben `holzfaeller` oder `steinmetz` bauen
3. Prüfen: Größe, Winkel, Schatten, Lesbarkeit bei Zoom

---

## 4. Villager / Figuren (8 Richtungen)

Deine Villager nutzen **low top-down** mit 8 Blickrichtungen:

- `south`, `south-east`, `east`, `north-east`, `north`, `north-west`, `west`, `south-west`

**Empfehlung:**
- Frame-Größe: **124×124 px** (wie in `assets/test/villager/metadata.json`)
- Figur steht **mittig** auf dem Tile
- Füße auf ca. **70–80 % der Bildhöhe** (nicht ganz unten am Rand)
- Im Spiel werden sie auf **55 %** skaliert – also etwas großzügig zeichnen

**Animation Walking:** 6 Frames pro Richtung reichen für einen simplen Loop.

---

## 5. Stil-Checkliste (vor dem Einchecken)

- [ ] Richtige Pixelgröße (192×192 oder 64×64)?
- [ ] Kein Isometrie-Winkel?
- [ ] Gleiche Lichtrichtung wie andere Gebäude?
- [ ] Grundfläche passt ins 3×3-Raster?
- [ ] PNG mit Alpha-Kanal?
- [ ] Im Spiel neben Referenz-Gebäude getestet?
- [ ] Bei Zoom 1.6× (Spiel-Start) noch erkennbar?

---

## 6. Häufige Fehler

| Fehler | Symptom | Lösung |
|--------|---------|--------|
| Isometrie gezeichnet | Gebäude wirken „schief“ zum Raster | Draufsicht + leichte Südwand |
| Falsches Seitenverhältnis | Gebäude wirkt gestaucht | Exakt 192×192 exportieren |
| Zu viel Höhe nach außen | Überlappt Nachbarn komisch | Hohe Teile (Türme) zentral halten |
| Flache 90°-Draufsicht | Passt nicht zu Villagern | Etwas Südwand/Dachhöhe zeigen |
| Uneinheitliches Licht | Gebäude „passen nicht zusammen“ | Eine Lichtquelle für alle Sprites |

---

## 7. Empfohlene Tools

### Aseprite (ideal für Pixel Art)
1. Sprite → Canvas Size → 192×192
2. View → Grid → 64×64
3. Referenz-Layer mit `holzfaeller.png`
4. Export als PNG

### Krita
1. Neues Dokument 192×192, 72 DPI
2. Raster: 64 px
3. „Gitter anzeigen“ aktivieren

### Photoshop
1. 192×192 px, transparent
2. View → New Guide Layout → 3 Spalten / 3 Zeilen

---

## 8. Referenz-Assets im Projekt

| Datei | Warum nützlich |
|-------|----------------|
| `assets/buildings/holzfaeller.png` | Korrekte 192×192 Größe |
| `assets/buildings/steinmetz.png` | Gleicher Stil / Maßstab |
| `assets/buildings/baustelle.png` | Baustellen-Overlay |
| `assets/templates/building_3x3_grid.png` | Raster-Vorlage |
| `assets/test/villager/metadata.json` | Villager-Perspektive & Größe |

---

## 9. Welche Gebäude-ID für welche Datei?

Alle IDs stehen in `scripts/autoload/game_data.gd` unter `BUILDINGS`.

Beispiele:
- `rathaus` → `rathaus.png`
- `soja_farm` → `soja_farm.png`
- `strasse` → `strasse.png`

Godot lädt automatisch, wenn der Dateiname zur ID passt.

---

## 10. Mini-Workflow zum Üben

1. `building_3x3_grid.png` in Aseprite öffnen
2. `holzfaeller.png` als Referenz daneben legen
3. Ein einfaches 3×3-Häuschen skizzieren (Dach + Südwand)
4. Als `mein_test_gebaeude.png` speichern (temporär)
5. Im Spiel als Platzhalter testen
6. Winkel anpassen, bis es neben Holzfäller natürlich wirkt

Wenn ein Gebäude neben dem Holzfäller „auf der gleichen Erde steht“, hast du die Perspektive getroffen.
