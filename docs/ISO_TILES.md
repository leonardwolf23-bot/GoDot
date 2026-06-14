# Isometrisches Tilemap-System (32×64)

Das Spiel nutzt ein **isometrisches 32×64-Raster** (Breite × Höhe pro Kachel) mit einem gemeinsamen Koordinatensystem
für Boden, Gebäude und Mausklicks. Die Spiellogik arbeitet weiterhin in
**logischen Gitterzellen** – nur die Darstellung ist isometrisch.

Die nördliche Spitze jeder Zelle ist der Ankerpunkt (`cell_to_world`). Gebäude werden
als **Iso-Quader** (oder PNG-Sprite mit passender Boden-Raute) auf dieser Grundfläche gezeichnet.

---

## Kachelgröße

| Eigenschaft | Wert |
|---|---|
| Rastermaß | **32 × 64 px** (Breite × Höhe der Raute) |
| Projektion | Isometrie (wie in Godot TileMap) |
| 1×1-Gebäude | Boden-Raute **32 px** breit |
| 3×3-Gebäude (Standard) | Boden-Raute **96 px** breit |

---

## Eigene Boden-Kacheln platzieren

Alle Terrain-Kacheln liegen in **`assets/tiles/iso/`**:

| Datei | Verwendung |
|---|---|
| `grass.png` | Standard-Gras |
| `river.png` | Fluss |
| `road.png` | Straße |
| `tree.png` | Baum (blockiert Bau) |
| `rock.png` | Fels (blockiert Bau) |
| `dirt.png` | Rand außerhalb der Karte |
| `terrain_atlas.png` | Atlas mit allen Kacheln (wird vom Spiel geladen) |

### Neue Kachel hinzufügen

1. Erstelle eine **32×64 px PNG** mit transparenter Fläche außerhalb der Raute.
2. Die **Raute** füllt die volle 32×64-Fläche (Spitze oben, Spitze unten).
3. Lege die Datei in `assets/tiles/iso/` ab, z. B. `grass.png`.
4. Spiel neu starten – **nur die Einzeldatei reicht** (z. B. `grass.png`).

Optional: `terrain_atlas.png` nur als Fallback, wenn eine Einzeldatei fehlt.

**Wichtig:** PNGs werden **1:1 in Originalgröße** gezeichnet – nicht gestreckt. Größe muss exakt **32×64** sein.

**Vorlage:** `assets/templates/tile_1x1_iso_grid.png` (Rastervorlage zum Pixeln).

---

## Gebäude-Sprites

Die Regeln aus `SPRITES.md` gelten unverändert:

| Gebäudegröße | Boden-Raute (sichtbar) | Empfohlene Bildbreite |
|---|---|---|
| 1×1 | 64 px | 64, 128 oder 256 px |
| 2×2 | 128 px | 128, 256 oder 512 px |
| 3×3 | 192 px | 192, 384 oder 768 px |

Dateiname = Gebäude-ID, z. B. `rathaus.png` → `assets/buildings/`.

Die **unterste Bildkante** muss die untere Ecke der Boden-Raute treffen.

---

## Technische Dateien

| Datei | Aufgabe |
|---|---|
| `scripts/world/iso_utils.gd` | Koordinaten-Umrechnung Zelle ↔ Welt |
| `scripts/world/city_grid.gd` | Boden-Kacheln (lädt `grass.png` usw. direkt) |
| `scripts/world/building_node.gd` | Gebäude-Sprites auf der Raute |
