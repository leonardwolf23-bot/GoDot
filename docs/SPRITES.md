# Eigene Sprites für die Gebäude

> **Hinweis:** Das Spiel wird bereits mit fertigen Sprites für alle
> Gebäude ausgeliefert (in `assets/buildings/`) - im **minimalistischen
> Low-Poly-Stil**: flache Farbflächen, klare Silhouetten, wenig Detail,
> damit Gebäude auch beim Rauszoomen gut erkennbar bleiben. Diese
> Anleitung brauchst du nur, wenn du einzelne Sprites **austauschen**
> oder für neue Gebäude **eigene** erstellen willst. Einfach die
> jeweilige PNG-Datei ersetzen - Regeln siehe unten. Die Straße hat
> kein PNG: Sie wird vom Code als schmale Fahrbahn gezeichnet
> (`building_node.gd`, Funktion `_draw_road`).

Das Spiel ist im **2D-Modus** von Godot gebaut (kein 3D!). Der räumliche
Look entsteht durch die isometrische Perspektive – man nennt das 2.5D.
Standardmäßig zeichnet das Spiel die Gebäude als einfache Farb-Quader.
Sobald du aber ein passendes PNG-Bild bereitstellst, **benutzt das Spiel
automatisch dein Bild** – ohne dass du eine Zeile Code ändern musst.

---

## 1. So fügst du ein Sprite hinzu (das ganze "System")

1. Erstelle/besorge ein PNG-Bild (Regeln siehe unten).
2. Benenne es **exakt nach der Gebäude-ID**, z. B.:

   | Datei | Gebäude |
   |---|---|
   | `rathaus.png` | Futuristisches Rathaus |
   | `wohnmodul.png` | Wohnmodul |
   | `strasse.png` | Straße |
   | `hydro_farm.png` | Hydro-Farm |
   | `kaese_manufaktur.png` | Käseersatz-Manufaktur |

   (Alle IDs stehen in `scripts/autoload/game_data.gd` im Dictionary
   `BUILDINGS` – der Name vor dem `{`.)

3. Lege die Datei in den Ordner **`assets/buildings/`**.
4. Spiel starten – fertig. Gebäude mit Bild benutzen das Bild, alle anderen
   werden weiterhin als Quader gezeichnet. Du kannst also **Stück für Stück**
   umstellen.

Auch die grün/rote **Platzierungsvorschau** funktioniert automatisch mit
deinen Sprites (das Bild wird halbtransparent eingefärbt).

---

## 2. Die Bild-Regeln (wichtig!)

### Format
- **PNG mit transparentem Hintergrund** (kein JPG – JPG kann keine
  Transparenz!).
- Das Bild wird automatisch auf die Grundfläche skaliert. Damit nichts
  verzerrt, gilt:

### Breite
Die Breite des Bildes entspricht der **sichtbaren Breite der Boden-Raute**:

| Gebäudegröße | Sichtbare Breite | Empfohlene Bildbreite |
|---|---|---|
| 1×1 (die meisten) | 64 px | 64, 128 oder 256 px |
| 2×2 (Rathaus, Arkologie, Atomkraftwerk, Auto-Farm, Einkaufshalle, Universität) | 128 px | 128, 256 oder 512 px |

Größere Vielfache (128/256 statt 64) sind besser – das Spiel rechnet sie
runter und es bleibt scharf beim Zoomen.

### Höhe
Beliebig! Die Höhe ergibt sich aus deinem Bild (Seitenverhältnis bleibt
erhalten). Ein hoher Turm = hohes Bild, ein Park = flaches Bild.

### Ausrichtung (die wichtigste Regel)
- Unten im Bild muss die **isometrische Boden-Raute** deines Gebäudes sein,
  im **2:1-Format** (doppelt so breit wie hoch, z. B. 64×32 px bei 1×1).
- Die **unterste Bildkante** = die untere Ecke der Raute. Das Spiel setzt
  dein Bild so, dass diese Unterkante exakt auf der Rasterzelle "steht".
- Blickrichtung: Die Kamera schaut von "oben rechts vorne" – male die
  **linke und rechte Seitenwand sichtbar**, wie bei den eingebauten Quadern.

```
   Bild (z.B. 128 x 192 px für ein 1x1-Hochhaus):
   ┌──────────────┐
   │   (frei /    │
   │ transparent) │
   │  ▄▄▄▄▄▄▄▄    │  <- Gebäude
   │  █ Turm █    │
   │  █      █    │
   │ ◢██████████◣ │  <- Boden-Raute, 2:1 (Breite : Höhe)
   └──◥██████◤───┘  <- Unterkante = untere Rauten-Ecke
```

---

## 3. Womit erstellt man solche Sprites? (3 Wege)

### Weg A: Fertige Gratis-Assets (der schnellste Weg)
Für den Anfang musst du gar nichts selbst malen:

- **Kenney** (<https://kenney.nl/assets>): Suche nach "Isometric" –
  z. B. *Isometric Buildings*, *Isometric City*. Komplett kostenlos
  (CC0-Lizenz, auch kommerziell nutzbar), sauberer Stil, passendes
  2:1-Format. Einfach herunterladen, passend umbenennen, in
  `assets/buildings/` legen.
- **OpenGameArt** (<https://opengameart.org>): Suche "isometric building".
  Lizenz pro Asset prüfen (CC0 ist am unkompliziertesten).
- **itch.io** (<https://itch.io/game-assets/free/tag-isometric>): viele
  kostenlose Iso-Packs.

### Weg B: Selbst pixeln (volle Kontrolle über den Stil)
Empfohlene kostenlose Programme:

- **LibreSprite** oder **Piskel** (im Browser: <https://www.piskelapp.com>) –
  einfache Pixel-Art-Editoren, perfekt für den Einstieg.
- **Krita** (<https://krita.org>) – kostenloses Mal-Programm, gut für
  größere/weichere Sprites.
- **Aseprite** (~20 €) – der Branchenstandard für Pixel-Art, falls du
  tiefer einsteigen willst.

Praktische Tipps fürs Iso-Pixeln:
1. Beginne mit der **Boden-Raute**: Linien im Muster "2 Pixel rechts,
   1 Pixel runter" ergeben exakt die 2:1-Iso-Steigung.
2. Zieh die Wände **senkrecht nach oben**, Dach = die Raute noch einmal.
3. **Licht von oben links**: Dach am hellsten, linke Wand mittel, rechte
   Wand am dunkelsten (genauso machen es die eingebauten Quader – so passt
   alles zusammen).
4. Für den Spiel-Stil: helle, freundliche Grundfarben + türkis/grüne
   Leucht-Akzente (Fensterbänder, Solarpanels, Pflanzen auf Dächern).

### Weg C: KI-Bildgeneratoren
Funktioniert erstaunlich gut für Iso-Gebäude. Wichtig ist der Prompt,
z. B.:

> *"isometric pixel art building, futuristic vegan vertical farm with
> glowing green LED bands, 2:1 isometric perspective, white background,
> single building, game asset, clean edges"*

Danach musst du fast immer **den Hintergrund entfernen** (Transparenz):
- kostenlos im Browser: <https://www.remove.bg> oder in Krita/GIMP mit dem
  Zauberstab-Werkzeug den Hintergrund wegradieren.
- Achte darauf, dass die Boden-Raute halbwegs im 2:1-Winkel ist – sonst
  "schwebt" das Gebäude schief auf der Zelle. Notfalls in Krita leicht
  drehen/stauchen.

---

## 4. Häufige Fehler

| Problem | Ursache / Lösung |
|---|---|
| Bild wird ignoriert, Quader bleibt | Dateiname falsch (muss exakt der Gebäude-ID entsprechen, klein geschrieben, `.png`) oder im falschen Ordner. |
| Gebäude "schwebt" oder steht zu tief | Unter der Boden-Raute ist noch leerer/transparenter Rand → unten abschneiden. Die Unterkante des Bildes muss die untere Rauten-Ecke sein. |
| Gebäude wirkt verzerrt | Bildbreite passt nicht zur Grundfläche (1×1 → Vielfaches von 64 px breit, 2×2 → Vielfaches von 128 px). |
| Schwarzer Kasten ums Gebäude | Bild ist JPG oder PNG ohne Alpha → als PNG mit Transparenz exportieren. |
| Bild unscharf beim Heranzoomen | Quellbild zu klein → in doppelter/vierfacher Größe erstellen. |
| Sprite verdeckt Nachbarn falsch | Passiert nur, wenn das Bild viel breiter ist als die Grundfläche. Halte seitliche Überstände klein. |

---

## 5. Wie es technisch funktioniert (für Neugierige)

Die gesamte Sprite-Logik steckt in **einer Datei**:
`scripts/world/building_node.gd`.

- In `setup()` wird geprüft, ob `res://assets/buildings/<id>.png`
  existiert (`ResourceLoader.exists`). Wenn ja, wird die Textur geladen.
- In `_draw()` gilt: Textur vorhanden → `_draw_sprite()` zeichnet das Bild
  passgenau auf die Boden-Raute. Keine Textur → der bisherige Quader-Code
  läuft.
- Der Rest des Spiels (Logik, Grid, UI, Speichern) weiß von alledem
  nichts – genau dafür ist die Trennung von Logik und Darstellung da.

Wenn du später auch den **Boden** (Gras/Straßenkacheln) durch Texturen
ersetzen willst: Das passiert analog in `scripts/world/city_grid.gd` in
der `_draw()`-Funktion – sag einfach Bescheid, dann baue ich das genauso
als "PNG-rein-und-fertig"-System.
