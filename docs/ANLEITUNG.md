# Vegane Stadt 2040 – Die komplette Anleitung

Diese Anleitung erklärt **jedes System des Spiels** Schritt für Schritt –
geschrieben für absolute Anfänger ohne Programmiererfahrung. Du musst nichts
selbst programmieren: Die gesamte Codebase ist fertig. Aber wenn du verstehst,
*wie* sie funktioniert, kannst du sie später selbst erweitern und balancen.

---

## Inhaltsverzeichnis

1. [Godot installieren und das Projekt öffnen](#1-godot-installieren-und-das-projekt-öffnen)
2. [Wie Godot denkt: Szenen, Nodes, Skripte, Signale](#2-wie-godot-denkt-szenen-nodes-skripte-signale)
3. [Die Projektstruktur und Architektur](#3-die-projektstruktur-und-architektur)
4. [Der Ablauf: vom Hauptmenü bis zum Sieg](#4-der-ablauf-vom-hauptmenü-bis-zum-sieg)
5. [Der Tages- und Kalender-Timer](#5-der-tages--und-kalender-timer)
6. [Das Grid-System und die 2.5D-Perspektive](#6-das-grid-system-und-die-25d-perspektive)
7. [Gebäudeplatzierung, Straßen und die Vorschau](#7-gebäudeplatzierung-straßen-und-die-vorschau)
8. [Ressourcen und Wirtschaft](#8-ressourcen-und-wirtschaft)
9. [Bevölkerung und Wachstum](#9-bevölkerung-und-wachstum)
10. [Die Gesundheitswerte](#10-die-gesundheitswerte)
11. [Der vegane Anteil](#11-der-vegane-anteil)
12. [Das Forschungssystem](#12-das-forschungssystem)
13. [Die Startcharaktere (Landeschefs)](#13-die-startcharaktere-landeschefs)
14. [Regionen, Sieg und Niederlage](#14-regionen-sieg-und-niederlage)
15. [Die Benutzeroberfläche (UI)](#15-die-benutzeroberfläche-ui)
16. [Speichern und Laden](#16-speichern-und-laden)
17. [Balancing-Grundlagen](#17-balancing-grundlagen)
18. [Debugging und Fehlervermeidung](#18-debugging-und-fehlervermeidung)
19. [Das Spiel erweitern: Schritt-für-Schritt-Rezepte](#19-das-spiel-erweitern-schritt-für-schritt-rezepte)

---

## 1. Godot installieren und das Projekt öffnen

1. Gehe auf <https://godotengine.org/download> und lade **Godot 4.4**
   herunter. Wichtig: Nimm die **Standard-Version**, *nicht* die
   ".NET"-Version (die ist für C#, wir benutzen GDScript).
2. Godot ist eine einzelne Datei – einfach entpacken und starten, keine
   Installation nötig.
3. Im Godot-Startfenster: **Importieren** anklicken, dann den Ordner dieses
   Projekts auswählen (die Datei `project.godot` darin).
4. Das Projekt öffnet sich im Editor. Drücke oben rechts **▶ (Play)** oder
   `F5`. Das Hauptmenü erscheint – du kannst sofort spielen.

> **Häufiger Anfängerfehler:** Wenn du Dateien *außerhalb* von Godot
> verschiebst oder umbenennst, gehen Verweise kaputt. Mach das immer im
> Godot-Dateimanager (links unten im Editor) – dann passt Godot alle Pfade
> automatisch an.

---

## 2. Wie Godot denkt: Szenen, Nodes, Skripte, Signale

Diese vier Begriffe musst du verstehen – mehr nicht:

### Nodes (Knoten)
Alles in Godot ist ein **Node**: ein Kamera-Node, ein Text-Node (`Label`),
ein Button-Node, ein unsichtbarer Logik-Node. Nodes haben jeweils genau
*eine* Aufgabe und werden wie ein Stammbaum ineinander verschachtelt.

### Szenen
Eine **Szene** (`.tscn`-Datei) ist ein gespeicherter Baum aus Nodes.
Unser Spiel hat drei Szenen:

| Szene | Inhalt |
|---|---|
| `scenes/main_menu.tscn` | Hauptmenü |
| `scenes/character_select.tscn` | Charakterauswahl |
| `scenes/game.tscn` | Das eigentliche Spiel |

Mit `get_tree().change_scene_to_file(...)` wechselt man zwischen Szenen –
so kommt man vom Menü ins Spiel.

### Skripte
Ein **Skript** (`.gd`-Datei, Sprache: GDScript) wird an einen Node gehängt
und gibt ihm Verhalten. Zwei Funktionen ruft Godot automatisch auf:

- `_ready()` – einmal, wenn der Node startklar ist (unser "Aufbau-Code").
- `_process(delta)` – jeden Frame; `delta` = Sekunden seit dem letzten
  Frame (unser "Dauerlauf-Code", z. B. der Tages-Timer).

### Signale
Ein **Signal** ist eine Rundfunk-Durchsage: Ein Node ruft z. B.
„`day_passed`!" und alle Nodes, die sich mit `connect()` angemeldet haben,
reagieren. **Das ist der wichtigste Trick für saubere Architektur:** Die
Spiellogik muss die UI nicht kennen – sie sendet nur Signale, und die UI
aktualisiert sich selbst.

```gdscript
# In der Spiellogik (Sender):
signal resources_changed
resources_changed.emit()

# In der UI (Empfänger):
GameState.resources_changed.connect(_refresh_top_bar)
```

### Autoloads (Singletons)
Ein **Autoload** ist ein Node, den Godot beim Spielstart automatisch lädt
und der **in jeder Szene unter seinem Namen erreichbar** ist. Eingerichtet
wird das in `project.godot` unter `[autoload]`. Unsere vier Autoloads:

| Name | Datei | Aufgabe |
|---|---|---|
| `GameData` | `scripts/autoload/game_data.gd` | Alle Spieldaten (reine "Datenbank") |
| `GameState` | `scripts/autoload/game_state.gd` | Die laufende Simulation |
| `ResearchManager` | `scripts/autoload/research_manager.gd` | Forschungslogik |
| `SaveManager` | `scripts/autoload/save_manager.gd` | Speichern/Laden |

Dadurch kann *jedes* Skript einfach `GameState.population` schreiben –
ohne komplizierte Verweise.

---

## 3. Die Projektstruktur und Architektur

Das wichtigste Designprinzip des Projekts ist die **Trennung der Schichten**:

```
┌─────────────────────────────────────────────────────────┐
│  GameData (Daten)                                       │
│  "WAS gibt es?" – Gebäude, Forschung, Charaktere,       │
│  Regionen, Balancing-Zahlen. KEINE Logik.               │
└────────────────────────┬────────────────────────────────┘
                         │ liest
┌────────────────────────▼────────────────────────────────┐
│  GameState + ResearchManager (Spiellogik/Simulation)    │
│  "WAS passiert?" – Ressourcen, Zeit, Bevölkerung,       │
│  Gesundheit, veganer Anteil, Sieg/Niederlage.           │
│  Sendet SIGNALE, kennt weder Welt noch UI.              │
└───────▲────────────────────────────────────┬────────────┘
        │ meldet Bau/Abriss                  │ Signale
┌───────┴──────────────────┐    ┌────────────▼────────────┐
│  Welt (scripts/world/)   │    │  UI (scripts/ui/)       │
│  CityGrid, BuildingNode, │    │  HUD, Baumenü, Panels.  │
│  Kamera. Nur Darstellung │    │  Liest nur Werte, ruft  │
│  und Platzierungsregeln. │    │  öffentliche Funktionen.│
└──────────────────────────┘    └─────────────────────────┘
```

**Warum ist das gut?**
- Balancing ändern = nur `game_data.gd` anfassen.
- Neue UI bauen = Spiellogik bleibt unberührt.
- Grafiken austauschen = nur `building_node.gd` ändern.
- Die Logik lässt sich **ohne Grafik testen** (siehe `tests/sim_test.gd` –
  51 automatische Tests!).

---

## 4. Der Ablauf: vom Hauptmenü bis zum Sieg

1. **Hauptmenü** (`main_menu.gd`): "Neues Spiel" → Charakterauswahl.
   "Spiel laden" ist nur aktiv, wenn `SaveManager.has_save()` true ist.
2. **Charakterauswahl** (`character_select.gd`): Drei Karten mit Boni und
   Nachteilen. Klick auf "Wählen" ruft `GameState.new_game(character_id)`
   auf – das setzt **alle** Werte auf die Startwerte (1. Januar 2040,
   20 Bürger, 100 % vegan) – und wechselt zur Spiel-Szene.
3. **Spiel-Szene** (`game.gd`): Prüft beim Start:
   - Ist `GameState.buildings` leer? → Neues Spiel → Rathaus + Startstraße
     in die Kartenmitte setzen (`grid.place_starting_buildings()`).
   - Sonst → geladenes Spiel → Welt aus den Daten wieder aufbauen
     (`grid.rebuild_from_state()`).
4. **Spielen**: bauen, forschen, wachsen, Regionen einnehmen.
5. **Ende**: `GameState` sendet das Signal `game_over(victory, reason)` →
   der `GameOverScreen` blendet sich ein.

---

## 5. Der Tages- und Kalender-Timer

Datei: `scripts/autoload/game_state.gd`

Das Spiel läuft in Echtzeit, ein Spieltag dauert standardmäßig
**5 echte Sekunden** (einstellbar in `GameData.SECONDS_PER_DAY`).

So funktioniert es – das ist das Standard-Muster für Spiel-Timer:

```gdscript
func _process(delta: float) -> void:
    if is_game_over or game_speed <= 0.0:
        return
    _day_timer += delta * game_speed   # game_speed: 0=Pause, 1x, 2x, 3x
    while _day_timer >= GameData.SECONDS_PER_DAY:
        _day_timer -= GameData.SECONDS_PER_DAY
        _advance_one_day()
```

- `delta` sind die Sekunden seit dem letzten Frame. Wir sammeln sie in
  `_day_timer`, bis ein Tag "voll" ist.
- Das `while` (statt `if`) ist ein Sicherheitsnetz: Falls das Spiel kurz
  ruckelt und mehr als ein Tag "aufgelaufen" ist, werden alle nachgeholt.
- Der **Kalender** (`_advance_calendar()`) zählt Tag → Monat → Jahr hoch,
  mit echten Monatslängen aus `GameData.MONTH_DAYS`.
  `get_date_string()` macht daraus z. B. „14. März 2041".

Jeder Tag löst **den Tages-Tick** aus – die komplette Simulation in fester
Reihenfolge:

```
_advance_one_day()
 ├─ 1. _simulate_economy()            Produktion, Verbrauch, Steuern, Strom
 ├─ 2. _simulate_health()             Gesundheitswerte bewegen sich
 ├─ 3. _simulate_vegan_share()        Veganer Anteil steigt/sinkt
 ├─ 4. _simulate_population_growth()  Neue Bürger ziehen ein
 ├─ 5. _check_win_lose()              Sieg-/Niederlageprüfung
 └─ 6. Signale: day_passed, resources_changed, health_changed
```

---

## 6. Das Grid-System und die 2.5D-Perspektive

Datei: `scripts/world/city_grid.gd`

### Die Iso-Mathematik (das Herz der 2.5D-Optik)

Logisch ist die Stadt ein ganz normales Schachbrett: Zelle (0,0), (1,0),
(2,5) usw. Die schräge 2.5D-Optik entsteht **nur durch eine Umrechnungs-
formel** beim Zeichnen:

```gdscript
# Zelle -> Bildschirmpixel ("kippt" das Schachbrett zur Raute):
Bildschirm-x = (zelle.x - zelle.y) * 32
Bildschirm-y = (zelle.x + zelle.y) * 16
```

Eine Zelle ist auf dem Bildschirm eine **Raute von 64×32 Pixeln**
(klassisches 2:1-Isometrie-Format). Die Umkehrformel (`world_to_cell`)
rechnet die Mausposition zurück in eine Zelle – so weiß das Spiel, wohin
du klickst.

> Du musst diese Formeln nicht herleiten können. Merke dir nur:
> `cell_to_world()` = "Wo male ich hin?", `world_to_cell()` = "Wo hat der
> Spieler hingeklickt?". Beides wird im Test `sim_test.gd` automatisch
> gegeneinander geprüft.

### Die Höhe (das ".5" in 2.5D)

Gebäude sind keine flachen Bilder, sondern werden in
`building_node.gd` als **isometrische Quader** gezeichnet: Grundfläche +
zwei Seitenwände (dunkler) + Dach (heller) + Leuchtstreifen bei hohen
Gebäuden. Die Höhe kommt aus `GameData` (`"hoehe": 64`).

**Verdeckung:** Damit vordere Gebäude hintere verdecken, bekommt jedes
Gebäude `z_index = 10 + zelle.x + zelle.y` – je weiter "unten" auf der
Karte, desto später wird es gezeichnet.

### Die Karte wächst

`get_map_size()` gibt `16 + 2 × (Anzahl eingenommener Regionen)` zurück.
Jede neue Region macht die baubare Fläche also größer – ganz ohne
Extra-Code, weil Boden und Platzierungsprüfung dieselbe Funktion benutzen.

---

## 7. Gebäudeplatzierung, Straßen und die Vorschau

### Belegung und Überlappungsverbot

`CityGrid` führt ein Dictionary `occupied`: Zelle → Gebäude-Node.
Ein 2×2-Gebäude trägt sich in 4 Zellen ein. Die Prüfung vor dem Bau:

```gdscript
func is_placement_valid(building_id, cell) -> bool:
    # 1. Alle Zellen innerhalb der Karte?
    # 2. Keine Zelle in `occupied`?  -> Überlappung unmöglich
    # 3. Falls "braucht_strasse": grenzt der Rand an eine Straße?
```

### Straßen

Straßen stehen zusätzlich im Dictionary `roads`. Fast alle Gebäude haben
`"braucht_strasse": true` – sie dürfen nur gebaut werden, wenn der
**Ring aus Zellen um ihre Grundfläche** mindestens eine Straße enthält.
Straßen lassen sich „malen": Maustaste gedrückt halten und ziehen
(siehe `_unhandled_input`: bei `InputEventMouseMotion` + gedrückter Taste
wird weitergebaut).

**Netz-Regel:** Straßen können nicht „irgendwo" gebaut werden. Eine neue
Straße muss **direkt** (oben/unten/links/rechts, nicht diagonal) an eine
bestehende Straße anschließen – so wächst ein zusammenhängendes Netz vom
Rathaus aus. Einzige Ausnahme: Direkt am Rathaus darf immer eine Straße
beginnen, damit das Netz nie komplett aussterben kann
(`_has_orthogonal_road_neighbor` in `city_grid.gd`).

### Bezirks-Boni (Nachbarschafts-Belohnung)

Gebäude **derselben Kategorie**, die direkt aneinander grenzen, verstärken
sich gegenseitig: **+10 % Produktion und Effekte pro gleichartigem
Nachbarn, maximal +30 %**. Ein Wohnviertel, ein Farm-Bezirk oder eine
Klinik-Meile lohnen sich also. Straßen zählen nicht. Die Logik steckt in
`GameState.get_district_bonus()`; der Hover-Tooltip im Spiel zeigt den
aktuellen Bonus jedes Gebäudes an.

### Bauzeit (Baustellen)

Jedes Gebäude braucht **1 Tag Bauzeit** (nur Straßen stehen sofort).
Während des Baus zeigt die Zelle ein Baustellen-Sprite
(`assets/buildings/baustelle.png`), und das Gebäude produziert nichts,
bietet keinen Wohnraum und hat keine Effekte. Nach dem nächsten Tages-Tick
meldet `GameState` das Signal `building_completed`, die Welt tauscht das
Sprite aus und eine Meldung erscheint. Gespeichert wird der Baufortschritt
im Feld `bau_tage_uebrig` jedes Gebäudes. Wer längere Bauzeiten für große
Gebäude will, ändert nur die Zeile in `GameState.register_building()`.

### Die visuelle Platzierungsvorschau ("Geist")

Sobald du im Baumenü ein Gebäude wählst, erzeugt das Grid einen
halbtransparenten `BuildingNode` mit `is_ghost = true`. Er folgt der Maus
und färbt sich:

- **Grün** = Platz frei, Straße vorhanden, genug Satoshis.
- **Rot** = irgendetwas verhindert den Bau.

Erst beim Klick fragt die Welt die Spiellogik:
`GameState.register_building(id, cell)` zieht das Geld ab und trägt das
Gebäude in die Simulation ein. Schlägt das fehl (z. B. zu teuer), wird
**nichts** gebaut – Welt und Logik können nie auseinanderlaufen.

### Eingabe-Trick gegen Fehlbauten

Das Grid benutzt `_unhandled_input` statt `_input`. UI-Klicks (Buttons,
Panels) werden von Godot zuerst an die UI gegeben und dort "verbraucht" –
sie erreichen das Grid gar nicht. So baust du nie aus Versehen ein Gebäude,
während du einen Button drückst. **Rechtsklick oder `Esc`** bricht jeden
Modus ab.

---

## 8. Ressourcen und Wirtschaft

Die vier Ressourcen leben in `GameState.resources`:

| Ressource | Quelle | Verbraucher |
|---|---|---|
| **Wasser** | Rathaus, Regenwassersammler, Wasserwerk | 1/Tag pro Bürger, Farmen, Atomkraftwerk |
| **Essen** | Gärten, Farmen, Labore, Fabriken | 1/Tag pro Bürger, Food Courts |
| **Satoshis** | Steuern (2/Tag pro Bürger), Märkte, Handelszentren | Gebäude, Straßen, Regionen |
| **Technikpunkte** | Rathaus, Forschungslabor, Universität | Forschung |

### Der Wirtschafts-Tick im Detail (`_simulate_economy`)

1. **Strom zuerst:** Alle `energie_leistung`- und `energie_bedarf`-Werte
   werden summiert. Reicht der Strom nicht, arbeiten **alle** Gebäude mit
   reduzierter Effizienz (`Leistung ÷ Bedarf`, aber nie unter 40 % – damit
   ein Engpass unangenehm ist, aber keine Todesspirale auslöst).
2. **Produktion:** Jedes Gebäude produziert laut `GameData`, multipliziert
   mit Effizienz, Forschungsboni (`produktions_mult`) und ggf.
   Charakterboni.
3. **Bürger:** zahlen Steuern, trinken Wasser, essen Essen.
4. **Bilanz anwenden:** Ressourcen können nie unter 0 fallen – aber bei
   0 Essen/Wasser gibt es harte Strafen auf Stimmung und veganen Anteil.

Die Tagesbilanz steht in `GameState.daily_report` und wird in der oberen
Leiste angezeigt, z. B. `Essen: 250 (+12)` – so siehst du sofort, ob du
ins Minus läufst.

---

## 9. Bevölkerung und Wachstum

Datei: `game_state.gd`, Funktion `_simulate_population_growth()`

Neue Bürger ziehen **automatisch** ein, wenn an einem Tag **alle fünf**
Bedingungen stimmen:

1. **Freie Wohnungen** (`get_housing_capacity()` zählt den `wohnraum`
   aller Gebäude zusammen).
2. **Essens-Überschuss**: Tagesbilanz positiv UND Vorrat > 2 Tage.
3. **Genug Wasser**: Vorrat > 1 Tag.
4. **Gesundheit stabil**: Protein, B12 und Vitamin D jeweils ≥ 50.
5. **Mentale Gesundheit** ≥ 50.

Dann wachsen **2 % der Bevölkerung pro Tag** (mindestens 1 Person), aber
nie über den Wohnraum hinaus. Das fühlt sich organisch an: Eine gesunde
20-Personen-Stadt wächst langsam, eine gesunde 500-Personen-Stadt schnell.

---

## 10. Die Gesundheitswerte

Datei: `game_state.gd`, Funktion `_simulate_health()`

Alle Werte (außer BMI) laufen von 0–100. Das System arbeitet mit
**Zielwerten und Trägheit**:

1. Aus Gebäuden (+ Forschung + Charakter) wird ein **Zielwert** berechnet.
2. Der **aktuelle Wert** nähert sich dem Ziel jeden Tag um 10 % an
   (`lerpf(aktuell, ziel, 0.1)`).

Dadurch ändern sich Werte **organisch statt sprunghaft** – baust du eine
B12-Klinik, steigt B12 über ~2 Wochen, nicht sofort.

**Wachstumsdruck:** Pro 25 Bürger sinken alle Basis-Zielwerte um 5 Punkte.
Eine große Stadt *braucht* deshalb aktiv Gesundheits-Infrastruktur – das
ist der zentrale Schwierigkeits-Motor des Spiels.

| Wert | Verbessert durch | Verschlechtert durch |
|---|---|---|
| **Protein** | Farmen, Protein-Labor, Forschung, Vegan Gains | Stadtwachstum |
| **B12** | B12-Klinik, Gesundheitszentrum, Forschung | Stadtwachstum |
| **Vitamin D** | Parks, Sonnen-Therapiezentrum, Forschung | Stadtwachstum |
| **Mental** | Parks, Kultur, Food Courts, Versorgung | Hunger/Durst (−25!), Überbevölkerung (−15), Vegan-Krise (−10) |
| **BMI** (Ziel: 20–25) | Fitnessstudio, Ernährungs-Forschung (senken) | Fleischersatz, Fast Food, Einkaufshalle (erheben) |

Der **BMI** ist ein bewusster Zielkonflikt: Fleischersatz und Food Courts
stärken den veganen Anteil, treiben aber den BMI hoch – du musst mit
Fitness und Forschung gegensteuern.

---

## 11. Der vegane Anteil

Datei: `game_state.gd`, Funktion `_simulate_vegan_share()`

Der wichtigste Wert des Spiels. Jeden Tag wird ein `delta` berechnet:

**Negativ (pro Tag):**

| Ursache | Wirkung |
|---|---|
| Essen aufgebraucht | −1.0 |
| Wasser aufgebraucht | −0.8 |
| Protein / B12 unter 50 | je −0.3 |
| Vitamin D unter 50 | −0.2 |
| Mentale Gesundheit unter 40 | −0.4 |
| BMI über 28 oder unter 18.5 | −0.2 |
| Keine einzige Forschung + über 60 Bürger | −0.2 |

**Positiv (pro Tag):**

| Ursache | Wirkung |
|---|---|
| Vegan-Effekte von Gebäuden (Food Courts, Bildungszentrum, Käse-Manufaktur …) | +0.05 × Summe |
| Forschungs-Boni (`vegan_bonus`, z. B. Käseersatz) | direkt |
| Protein, B12 UND Vitamin D alle ≥ 70 | +0.15 |
| Mentale Gesundheit ≥ 75 | +0.10 |

Charaktere wie die Militante Veganerin **halbieren negative** Deltas.

**Spielregeln:** Unter 80 % = Krisenwarnung (rotes Banner). Unter 50 % =
sofortige Niederlage. Für den Sieg müssen wieder volle 100 % erreicht sein.

---

## 12. Das Forschungssystem

Dateien: `research_manager.gd` (Logik), `game_data.gd` (die 22 Forschungen),
`research_panel.gd` (UI)

Jede Forschung kostet **Technikpunkte** und kann zwei Dinge tun:

1. **Ein Gebäude freischalten** (`schaltet_frei`): z. B. schaltet
   "Indoor Farming" die Indoor-Vertikalfarm frei. Das Baumenü prüft das
   automatisch und zeigt gesperrte Gebäude ausgegraut mit
   "[Forschung nötig]".
2. **Dauerhafte Simulations-Boni** (`effekte`): z. B. gibt
   "B12-Optimierung" +10 auf den B12-Zielwert; "Effiziente Stromnetze"
   senkt den Strombedarf aller Gebäude um 15 %.

**Voraussetzungsketten:** `"voraussetzung": "solarenergie"` bedeutet:
Atomkraft ist erst nach Solarenergie erforschbar. So entstehen kleine
Technologie-Bäume in vier Kategorien (Landwirtschaft, Gesellschaft,
Gesundheit, Energie).

**Forschungsdauer:** Forschung braucht Zeit – und es läuft immer nur
**eine** gleichzeitig. Die Dauer wächst mit den Kosten: Starter-Forschungen
(bis 30 TP) sind sofort fertig, die großen Endgame-Forschungen dauern bis
zu 7 Spieltage. Die Technikpunkte werden beim Start bezahlt; das
Forschungsfenster zeigt einen Countdown („Läuft... noch X Tage").
Die Staffelung steht in `GameData.get_research_duration()` – einzelne
Forschungen lassen sich mit einem eigenen Feld `"dauer": X` übersteuern.

**Technik-Detail:** `get_combined_effects()` summiert die Effekte aller
abgeschlossenen Forschungen und **cached** das Ergebnis (es wird nur neu
berechnet, wenn sich etwas ändert) – die Simulation fragt das jeden Tag ab.

---

## 13. Die Startcharaktere (Landeschefs)

Datei: `game_data.gd` → `CHARACTERS`, UI: `character_select.gd`

| Charakter | Boni | Nachteile |
|---|---|---|
| **Die Militante Veganerin** | Veganer Anteil sinkt nur halb so schnell; Vegan-Gebäude 50 % stärker | Stimmungs-Strafen bei Knappheit doppelt so hart |
| **Vegan Gains** | +10 Protein, +5 alle Gesundheitsziele, Gesundheitsgebäude 50 % stärker | Bürger essen 15 % mehr |
| **Earthling Ed** | +10 mentale Gesundheit, veganer Anteil sinkt 25 % langsamer | Forschung 15 % langsamer, −300 Start-Satoshis |

Die Modifikatoren sind reine Zahlen im Dictionary `"modifikatoren"` –
die Simulation fragt sie an den passenden Stellen ab
(`_get_character_mods()`). Neue Charaktere hinzufügen = ein neuer Eintrag
im Dictionary, die Auswahl-UI baut sich automatisch daraus auf.

---

## 14. Regionen, Sieg und Niederlage

### Deutschland einnehmen

`GameData.REGIONS` listet alle 16 Bundesländer mit steigenden Kosten
(Satoshis) und Mindestbevölkerung. Du startest mit Berlin. Im
"Deutschland"-Fenster nimmst du die **jeweils nächste** Region ein –
jede macht die Baukarte größer.

### Siegbedingungen (alle gleichzeitig, 7 Tage am Stück)

1. Alle 16 Regionen eingenommen.
2. Veganer Anteil = 100 %.
3. Versorgung: Essen- und Wasservorrat > 0 **und** Tagesbilanz nicht negativ.
4. Stabilität: Mental, Protein, B12, Vitamin D alle ≥ 60, niemand obdachlos.

Die 7-Tage-Regel (`_victory_stable_days`) verhindert "Glücks-Siege", bei
denen die Werte nur eine Sekunde lang stimmen.

### Niederlage

Veganer Anteil < 50 % → sofort verloren. Zwischen 50 % und 80 % zeigt das
HUD ein rotes Krisen-Banner – noch nicht verloren, aber höchste Zeit zu
handeln (Essen sichern, Gesundheit stabilisieren, Vegan-Gebäude bauen).

---

## 15. Die Benutzeroberfläche (UI)

Die gesamte UI wird **per Code in `_ready()` aufgebaut** statt im Editor
zusammengeklickt. Vorteil für dich: Es kann nichts "verrutschen" oder
versehentlich gelöscht werden, und jede Zeile ist nachlesbar.

| Datei | Element |
|---|---|
| `hud.gd` | Obere Leiste (Ressourcen, Bevölkerung, Vegan-%, Strom, Datum, Geschwindigkeit), rechte Buttons, Meldungen, Krisen-Banner |
| `build_menu.gd` | Baumenü unten: Kategorien → Gebäude-Buttons mit Preis, Tooltip, Sperr-Logik |
| `research_panel.gd` | Forschungsfenster |
| `health_panel.gd` | Gesundheitsbalken (grün/gelb/rot) + automatische Tipps |
| `region_panel.gd` | Deutschland-Fenster |
| `game_over_screen.gd` | Sieg/Niederlage-Overlay |

**Das UI-Grundprinzip dieses Projekts:** Die UI *schreibt nie* direkt in
die Simulation. Sie ruft nur öffentliche Funktionen auf
(`GameState.claim_next_region()`, `ResearchManager.do_research(...)`,
`grid.start_build_mode(...)`) und aktualisiert sich über Signale. Dadurch
kann ein UI-Fehler niemals den Spielstand beschädigen.

Zwei Stolperfallen, die hier bereits gelöst sind (merken für eigene UIs!):

- Das HUD-Wurzel-Control hat `mouse_filter = MOUSE_FILTER_IGNORE` – sonst
  würde das unsichtbare Vollbild-Control **alle** Klicks schlucken und du
  könntest nie ins Spielfeld klicken.
- Buttons reagieren auf `pressed` und "verbrauchen" das Event, deshalb
  baut ein Klick auf einen Button nie gleichzeitig ein Gebäude.

---

## 16. Speichern und Laden

Datei: `save_manager.gd`

- Gespeichert wird als **lesbare JSON-Datei** unter `user://savegame.json`.
  `user://` ist Godots sicherer, beschreibbarer Benutzerordner (unter
  Windows: `%APPDATA%\Godot\app_userdata\Vegane Stadt 2040\`).
- `GameState.to_save_dict()` packt den kompletten Zustand in ein
  Dictionary; `from_save_dict()` stellt ihn wieder her.
- **Stolperfalle gelöst:** `Vector2i` (Gebäudepositionen) kann JSON nicht
  speichern – wir zerlegen sie in `cell_x`/`cell_y` und bauen sie beim
  Laden wieder zusammen.
- Beim Laden wird die JSON geprüft (`JSON.parse_string` kann `null`
  liefern, z. B. bei beschädigter Datei) – statt Absturz gibt es eine
  saubere Fehlermeldung.
- Nach dem Laden ruft die Spiel-Szene `grid.rebuild_from_state()` auf –
  die Welt wird aus den Daten neu aufgebaut. Außerdem wird der
  Forschungs-Cache geleert (`ResearchManager.invalidate_cache()`).
- Es gibt eine `save_version` im Spielstand: Wenn du später das Format
  änderst, kannst du alte Stände erkennen und konvertieren.

---

## 17. Balancing-Grundlagen

**Alle** Stellschrauben liegen in `scripts/autoload/game_data.gd` – du
musst nie Logik-Code anfassen:

| Was ändern? | Wo? |
|---|---|
| Tageslänge | `SECONDS_PER_DAY` (5 Sekunden) |
| Startgeld/-ressourcen | `START_RESOURCES` |
| Verbrauch & Steuern pro Bürger | `WATER_PER_CITIZEN`, `FOOD_PER_CITIZEN`, `TAX_PER_CITIZEN` |
| Gebäude (Preis, Produktion, Effekte, Größe, Farbe, Höhe) | `BUILDINGS` |
| Forschung (Kosten, Boni, Ketten) | `RESEARCH` |
| Charakter-Boni | `CHARACTERS` |
| Regionskosten | `REGIONS` |
| Niederlage-/Krisen-Schwelle | `VEGAN_LOSE_THRESHOLD`, `VEGAN_CRISIS_THRESHOLD` |

**Drei Faustregeln für gutes Balancing:**

1. **Amortisationszeit:** Ein Wirtschaftsgebäude sollte sich in ca. 10–20
   Tagen bezahlt machen (Veganer Markt: 300 ₿ ÷ 25 ₿/Tag = 12 Tage ✓).
   Stärkere Gebäude dürfen *etwas* effizienter sein, damit Fortschritt
   sich lohnt – aber nicht viel, sonst sind frühe Gebäude sinnlos.
2. **Eine Schraube zur Zeit:** Ändere einen Wert, spiele 10 Minuten, dann
   den nächsten. Wer fünf Werte gleichzeitig ändert, weiß nie, was gewirkt
   hat.
3. **Zielkonflikte erhalten:** Der Reiz des Spiels lebt davon, dass
   Fleischersatz den veganen Anteil hebt, aber den BMI verschlechtert.
   Balanciere so, dass keine Strategie "alles gleichzeitig" bekommt.

---

## 18. Debugging und Fehlervermeidung

### Was im Projekt schon eingebaut ist

- **51 automatische Tests** (`tests/sim_test.gd`) prüfen die komplette
  Spiellogik ohne Grafik. Nach jeder Code-Änderung ausführen:

  ```bash
  godot --headless --path . res://tests/sim_test.tscn
  ```

  Steht am Ende `ALLE 51 TESTS BESTANDEN ✓`, hast du nichts kaputt gemacht.
- **Defensive Prüfungen:** Speicherdateien werden validiert, fehlende
  Ressourcen können nicht unter 0 fallen, das Spiel stürzt nicht ab, wenn
  die Spiel-Szene direkt (ohne Menü) gestartet wird.
- **Klare Fehlermeldungen:** `push_error()` / `push_warning()` statt
  stillem Versagen.

### Godot-Werkzeuge, die du kennen solltest

| Werkzeug | Wofür |
|---|---|
| **Ausgabe-Panel** (unten im Editor) | Hier landen alle `print()`- und Fehlermeldungen. Rot = Fehler mit Datei + Zeile. |
| **Debugger → Fehler** | Liste aller Laufzeitfehler mit Stacktrace. |
| **Szene → Remote-Tab** (während das Spiel läuft) | Live-Blick in den echten Szenenbaum: Du kannst `GameState` anklicken und alle Werte (Bevölkerung, Ressourcen …) in Echtzeit beobachten – das beste Debug-Werkzeug für dieses Spiel! |
| **Haltepunkte** | Klick links neben eine Codezeile → Spiel pausiert dort, du siehst alle Variablen. |

### Die fünf häufigsten Anfängerfehler (und wie dieses Projekt sie vermeidet)

1. **"Identifier not found"** – Tippfehler in Namen. GDScript unterscheidet
   Groß-/Kleinschreibung: `GameState` ≠ `gamestate`.
2. **Node-Pfade kaputt** (`get_node("...")` schlägt fehl) – wir benutzen
   fast überall Autoloads und bauen UI per Code, daher gibt es kaum
   zerbrechliche Pfade.
3. **Vergessene Signal-Verbindung** – UI zeigt alte Werte. Prüfe im
   Zweifel, ob in `_ready()` das passende `connect()` steht.
4. **Daten in `res://` speichern** – im exportierten Spiel schreibgeschützt!
   Immer `user://` verwenden (machen wir).
5. **Logik in der UI** – führt zu unauffindbaren Bugs. Regel: Wenn eine
   Zahl sich ändern soll, gehört der Code in `GameState`, nie in ein Panel.

---

## 19. Das Spiel erweitern: Schritt-für-Schritt-Rezepte

### Rezept A: Ein neues Gebäude (2 Minuten)

Öffne `scripts/autoload/game_data.gd` und füge in `BUILDINGS` einen
Eintrag hinzu – z. B. eine Algen-Farm:

```gdscript
"algen_farm": {
    "name": "Algen-Farm",
    "beschreibung": "Spirulina und Chlorella: Protein aus dem Wasserbecken.",
    "kategorie": "essen",
    "kosten": 600,
    "groesse": Vector2i(1, 1),
    "farbe": Color(0.2, 0.6, 0.55),
    "hoehe": 24,
    "wohnraum": 0,
    "produktion": {"essen": 15.0},
    "verbrauch": {"wasser": 5.0},
    "energie_bedarf": 3,
    "energie_leistung": 0,
    "effekte": {"protein": 3.0, "b12": 2.0},
    "forschung_noetig": "",
    "braucht_strasse": true,
    "baubar": true,
},
```

Speichern – fertig. Baumenü, Tooltip, Simulation, Speichern/Laden und
Zeichnung funktionieren automatisch, weil alle Systeme nur die Daten lesen.

### Rezept B: Eine neue Forschung

Gleiches Prinzip in `RESEARCH` – mit `"schaltet_frei": "algen_farm"`
verknüpfst du sie mit deinem neuen Gebäude.

### Rezept C: Echte Grafiken statt gezeichneter Quader

Schon eingebaut! Lege einfach ein PNG mit transparentem Hintergrund unter
`assets/buildings/` ab, benannt nach der Gebäude-ID (z. B.
`wohnmodul.png`) – das Spiel erkennt und benutzt es automatisch, inklusive
der grün/roten Bauvorschau. Alle Regeln (Größen, Ausrichtung) und
Werkzeug-Empfehlungen (Kenney-Gratis-Assets, Piskel, KI-Generatoren)
stehen in [`SPRITES.md`](SPRITES.md).

### Weitere Ideen, für die das Gerüst vorbereitet ist

- **Ereignis-System:** zufällige Events pro Tag (Dürre, vegane Messe) –
  einfach in `_advance_one_day()` einhängen und über
  `GameState.notification` melden.
- **Mehrere Speicherstände:** `SAVE_PATH` zu `user://save_%d.json` machen.
- **Sound/Musik:** `AudioStreamPlayer`-Node ins HUD, bei Signalen abspielen.
- **Detailliertere Regionen:** pro Bundesland eigene Karte oder Boni.

Viel Spaß beim Aufbau deiner veganen Zukunft!
