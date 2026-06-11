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


func setup(p_building_id: String, p_cell: Vector2i) -> void:
	building_id = p_building_id
	cell = p_cell
	var data: Dictionary = GameData.get_building(building_id)
	size = data["groesse"]
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
