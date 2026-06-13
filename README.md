# Iso City Starter (Godot 4.6)

Minimaler Neustart: isometrischer City-Builder mit **64×32**-Kacheln (Breite × Höhe).

## Features

- Godot **4.6** + `TileMapLayer` (isometrisch)
- **3 Gebäude:** 1×1, 2×2, 3×3 — als grünes X
- **Kein Gras-PNG?** → rotes X pro Zelle (kein Platzhalter-Bild)
- **Gras-PNG vorhanden?** → `assets/tiles/grass.png` (64×32) wird benutzt

## Steuerung

| Taste / Aktion | Effekt |
|---|---|
| `1` / `2` / `3` | Gebäude wählen (1×1 / 2×2 / 3×3) |
| Linksklick | Gebäude platzieren |
| Rechtsklick / Esc | Bau abbrechen |
| WASD | Kamera bewegen |
| Mausrad | Zoomen |

## Assets hinzufügen

```
assets/tiles/grass.png   → 64×32 px, isometrische Gras-Raute (optional)
```

Ohne Datei: rote X-Markierungen auf dem Boden.

## Projektstruktur

```
scenes/main.tscn
scripts/
  building_data.gd   # 3 Gebäude-Definitionen
  city_grid.gd       # Tilemap + Platzierung
  building_node.gd   # Grünes X
  camera_controller.gd
  hud.gd
  game.gd
```

## Starten

Godot 4.6 öffnen → Projektordner wählen → F5
