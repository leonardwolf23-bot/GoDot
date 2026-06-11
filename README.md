# Vegane Stadt 2040

Ein 2.5D-Städteaufbauspiel in Godot 4: Baue ab dem 1. Januar 2040 eine vegane
Stadt in Deutschland auf, halte den veganen Anteil bei 100 %, erforsche
Zukunftstechnologien und nimm Region für Region ganz Deutschland ein.

![Genre](https://img.shields.io/badge/Genre-City%20Builder-green)
![Engine](https://img.shields.io/badge/Engine-Godot%204.4-blue)

## Schnellstart

1. [Godot 4.4](https://godotengine.org/download) herunterladen (die normale
   Version, **nicht** ".NET").
2. Godot starten → **Importieren** → diese Projektmappe auswählen
   (die Datei `project.godot`).
3. Oben rechts auf **Play** (▶) drücken — fertig. Es sind keine weiteren
   Schritte, Plugins oder Assets nötig.

## Steuerung

| Aktion | Eingabe |
|---|---|
| Kamera bewegen | `W A S D` / Pfeiltasten / mittlere Maustaste ziehen |
| Zoomen | Mausrad |
| Gebäude bauen | Im Baumenü unten anklicken, dann Linksklick in die Welt |
| Straßen "malen" | Straße wählen, linke Maustaste gedrückt halten und ziehen |
| Bau-/Abrissmodus abbrechen | Rechtsklick oder `Esc` |
| Spielgeschwindigkeit | Buttons ⏸ / 1x / 2x / 3x oben rechts |

## Spielziel

- **Sieg:** Alle 16 Bundesländer eingenommen, veganer Anteil 100 %, Stadt
  stabil versorgt (7 Tage am Stück).
- **Niederlage:** Der vegane Anteil fällt unter 50 %.
- Zwischen 50 % und 80 % herrscht **Krise** — noch nicht verloren, aber
  gefährlich.

## Projektstruktur

```
project.godot               Projekteinstellungen + Autoload-Liste
icon.svg                    Spiel-Icon
scenes/
  main_menu.tscn            Hauptmenü (erste Szene)
  character_select.tscn     Charakterauswahl (Landeschefs)
  game.tscn                 Die eigentliche Spiel-Szene
scripts/
  autoload/                 Singletons (überall verfügbar)
    game_data.gd            DATEN: Gebäude, Forschung, Charaktere, Balancing
    game_state.gd           SIMULATION: Ressourcen, Bevölkerung, Zeit, Sieg
    research_manager.gd     Forschungslogik
    save_manager.gd         Speichern/Laden (JSON in user://)
  world/                    Weltobjekte
    game.gd                 Wurzel der Spiel-Szene
    city_grid.gd            Isometrisches Raster, Bauen, Abriss, Vorschau
    building_node.gd        Zeichnet ein einzelnes 2.5D-Gebäude
    camera_controller.gd    Kamera (Bewegen + Zoom)
  ui/                       Benutzeroberfläche
    main_menu.gd            Hauptmenü
    character_select.gd     Charakterauswahl
    hud.gd                  Obere Leiste, Buttons, Meldungen
    build_menu.gd           Baumenü unten
    research_panel.gd       Forschungsfenster
    health_panel.gd         Gesundheitsfenster
    region_panel.gd         Deutschland-Fenster (Regionen einnehmen)
    game_over_screen.gd     Sieg-/Niederlage-Overlay
tests/
  sim_test.tscn / .gd       Automatischer Test der gesamten Spiellogik
docs/
  ANLEITUNG.md              Ausführliche Schritt-für-Schritt-Erklärung
```

## Architektur in einem Satz

**GameData** sagt, *was es gibt* → **GameState** simuliert, *was passiert* →
die **Welt** (CityGrid) zeigt es an und meldet Bau-Aktionen zurück → die
**UI** liest nur Werte und hört auf Signale. Keine Schicht greift "quer" in
eine andere.

## Tests ausführen

```bash
godot --headless --path . res://tests/sim_test.tscn
```

Erwartete Ausgabe: `ALLE 51 TESTS BESTANDEN ✓`

## Eigene Grafiken

Lege ein PNG mit transparentem Hintergrund unter `assets/buildings/` ab,
benannt nach der Gebäude-ID (z. B. `wohnmodul.png`) – das Spiel benutzt es
automatisch statt des gezeichneten Quaders. Alle Regeln und Werkzeuge:
[`docs/SPRITES.md`](docs/SPRITES.md).

## Weiterlesen

Die komplette, anfängerfreundliche Erklärung **aller** Systeme (Grid-Mathematik,
Signale, Balancing, Debugging, Erweiterungsideen) steht in
[`docs/ANLEITUNG.md`](docs/ANLEITUNG.md).
