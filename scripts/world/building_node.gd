class_name BuildingNode
extends Node2D
## BuildingNode (Weltobjekt)
## =========================
## Stellt EIN Gebäude in der 2.5D-Welt dar.
##
## Wir benutzen KEINE Bilddateien, sondern zeichnen jedes Gebäude selbst
## als isometrischen Quader (Boden-Raute + zwei Seitenwände + Dach).
## Das hat zwei Vorteile:
##   1. Das Projekt läuft sofort, ohne Grafiken herunterladen zu müssen.
##   2. Später kann man die _draw()-Funktion einfach durch Sprite2D-Texturen
##      ersetzen, ohne den Rest des Codes anzufassen.

## Halbe Breite / halbe Höhe einer Iso-Rasterzelle in Pixeln.
## (Eine Zelle ist also 64 x 32 Pixel groß - klassisches 2:1-Iso-Format.)
const TILE_HALF_W := 32.0
const TILE_HALF_H := 16.0

var building_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var size: Vector2i = Vector2i.ONE

## Geist-Modus für die Platzierungsvorschau (halbtransparent).
var is_ghost: bool = false
var ghost_valid: bool = true

## Optionales Sprite: Liegt eine Bilddatei unter
## res://assets/buildings/<gebaeude_id>.png, wird sie automatisch benutzt.
## Gibt es kein Bild, zeichnet das Spiel wie bisher den Farb-Quader.
var _texture: Texture2D = null


func setup(p_building_id: String, p_cell: Vector2i) -> void:
	building_id = p_building_id
	cell = p_cell
	var data: Dictionary = GameData.get_building(building_id)
	size = data["groesse"]

	## Eigenes Sprite vorhanden? Einfach PNG in assets/buildings/ legen,
	## benannt nach der Gebäude-ID (z.B. "wohnmodul.png") - mehr ist nicht nötig.
	var texture_path := "res://assets/buildings/%s.png" % building_id
	if ResourceLoader.exists(texture_path):
		_texture = load(texture_path)
	elif FileAccess.file_exists(texture_path):
		## Fallback: PNG wurde gerade erst hineinkopiert und von Godot noch
		## nicht importiert -> Bild direkt von der Festplatte laden.
		var img := Image.load_from_file(ProjectSettings.globalize_path(texture_path))
		if img != null:
			_texture = ImageTexture.create_from_image(img)

	## y-Sortierung: Gebäude weiter "unten" im Bild werden später gezeichnet
	## und verdecken so Gebäude dahinter. z_index = Bildschirm-y reicht dafür.
	z_index = int(position.y)
	queue_redraw()


## Rechnet eine Rasterzelle in Welt-Pixelkoordinaten um (Mittelpunkt-Versatz
## der Zelle relativ zu DIESEM Gebäude-Ursprung).
func _cell_offset_to_pixels(offset: Vector2) -> Vector2:
	return Vector2(
		(offset.x - offset.y) * TILE_HALF_W,
		(offset.x + offset.y) * TILE_HALF_H
	)


func _draw() -> void:
	var data: Dictionary = GameData.get_building(building_id)
	if data.is_empty():
		return

	## Gibt es ein eigenes Sprite, wird das gezeichnet - sonst der Quader.
	if _texture != null:
		_draw_sprite()
		return

	## Straßen bekommen eine eigene futuristische Optik (dunkler Asphalt
	## mit Neon-Randstreifen) statt des Standard-Quaders.
	if building_id == "strasse" and not is_ghost:
		_draw_road()
		return

	var base_color: Color = data["farbe"]
	var height: float = data["hoehe"]
	var w: float = size.x
	var h: float = size.y

	## Die vier Ecken der Grundfläche (in Pixeln, relativ zum Gebäude-Ursprung).
	## Der Ursprung des Gebäudes liegt an der OBEREN Ecke der Raute.
	var top := _cell_offset_to_pixels(Vector2(0, 0))
	var right := _cell_offset_to_pixels(Vector2(w, 0))
	var bottom := _cell_offset_to_pixels(Vector2(w, h))
	var left := _cell_offset_to_pixels(Vector2(0, h))

	## Farbvarianten für den 3D-Effekt: Dach hell, Wände dunkler.
	var roof_color := base_color.lightened(0.15)
	var left_wall := base_color.darkened(0.25)
	var right_wall := base_color.darkened(0.45)

	if is_ghost:
		## Vorschau: grün = erlaubt, rot = verboten. Halbtransparent.
		var tint := Color(0.3, 1.0, 0.3, 0.55) if ghost_valid else Color(1.0, 0.25, 0.25, 0.55)
		roof_color = tint
		left_wall = tint.darkened(0.2)
		right_wall = tint.darkened(0.4)

	var up := Vector2(0, -height)

	## Linke Wand (zwischen "left" und "bottom").
	draw_colored_polygon(PackedVector2Array([
		left, bottom, bottom + up, left + up,
	]), left_wall)

	## Rechte Wand (zwischen "bottom" und "right").
	draw_colored_polygon(PackedVector2Array([
		bottom, right, right + up, bottom + up,
	]), right_wall)

	## Dach (die nach oben verschobene Grundfläche).
	draw_colored_polygon(PackedVector2Array([
		top + up, right + up, bottom + up, left + up,
	]), roof_color)

	## Dezente Umrandung, damit sich Gebäude optisch abheben.
	var outline := Color(0, 0, 0, 0.35)
	draw_polyline(PackedVector2Array([
		top + up, right + up, bottom + up, left + up, top + up,
	]), outline, 1.5)
	draw_line(left, left + up, outline, 1.5)
	draw_line(bottom, bottom + up, outline, 1.5)
	draw_line(right, right + up, outline, 1.5)

	## Kleine futuristische Details: Leuchtstreifen auf hohen Gebäuden.
	if height >= 36 and not is_ghost:
		var glow := Color(0.7, 1.0, 0.95, 0.8)
		var steps: int = int(height / 18.0)
		for i in range(1, steps):
			var y_offset := Vector2(0, -i * 18.0)
			draw_line(left + y_offset, bottom + y_offset, glow, 1.0)


## Zeichnet eine futuristische Straße: dunkler Asphalt mit leuchtenden
## Neon-Randstreifen - passend zum Neon-Stil der Gebäude-Sprites.
func _draw_road() -> void:
	var top := Vector2(0, 0)
	var right := Vector2(TILE_HALF_W, TILE_HALF_H)
	var bottom := Vector2(0, TILE_HALF_H * 2)
	var left := Vector2(-TILE_HALF_W, TILE_HALF_H)

	## Asphalt-Fläche (dunkles Blaugrau).
	draw_colored_polygon(PackedVector2Array([top, right, bottom, left]),
			Color(0.13, 0.15, 0.19))

	## Neon-Randstreifen entlang der Rautenkanten (Cyan, leicht leuchtend).
	var neon := Color(0.2, 0.9, 0.95, 0.9)
	draw_polyline(PackedVector2Array([top, right, bottom, left, top]), neon, 2.0)

	## Dezente Mittelmarkierung (zwei kurze Striche).
	var center := Vector2(0, TILE_HALF_H)
	var marking := Color(0.5, 1.0, 0.8, 0.5)
	draw_line(center + Vector2(-10, -5), center + Vector2(-2, -1), marking, 1.5)
	draw_line(center + Vector2(2, 1), center + Vector2(10, 5), marking, 1.5)


## Zeichnet das PNG-Sprite passgenau auf die Grundfläche des Gebäudes.
##
## Die Konvention für Sprites (siehe docs/SPRITES.md):
##   - Breite des Bildes = sichtbare Breite der Grundfläche
##     (1x1-Gebäude: 64 px, 2x2-Gebäude: 128 px - oder ein Vielfaches davon,
##     das Bild wird automatisch passend skaliert)
##   - Die UNTERKANTE des Bildes liegt auf der unteren Ecke der Boden-Raute.
##   - Transparenter Hintergrund (PNG mit Alpha).
func _draw_sprite() -> void:
	## Sichtbare Pixel-Breite der Grundfläche in der Iso-Ansicht.
	var footprint_width := (size.x + size.y) * TILE_HALF_W
	## Höhe proportional zur Bilddatei skalieren (Seitenverhältnis bleibt).
	var draw_height := footprint_width * _texture.get_height() / _texture.get_width()

	## Linke Ecke der Raute liegt bei -size.y * 32, die Unterkante bei
	## (size.x + size.y) * 16 (untere Ecke der Boden-Raute).
	var left_x := -size.y * TILE_HALF_W
	var bottom_y := (size.x + size.y) * TILE_HALF_H
	var rect := Rect2(left_x, bottom_y - draw_height, footprint_width, draw_height)

	## Im Geist-Modus wird das Sprite grün/rot eingefärbt (Vorschau).
	var tint := Color.WHITE
	if is_ghost:
		tint = Color(0.4, 1.0, 0.4, 0.6) if ghost_valid else Color(1.0, 0.3, 0.3, 0.6)

	draw_texture_rect(_texture, rect, false, tint)
