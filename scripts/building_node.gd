class_name BuildingNode
extends Node2D
## Gebäude-Platzhalter: grünes X auf der Grundfläche (keine Textur nötig).

var building_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var size: Vector2i = Vector2i.ONE
var is_ghost: bool = false
var ghost_valid: bool = true

var _layer: TileMapLayer = null


func setup(layer: TileMapLayer, p_id: String, p_cell: Vector2i) -> void:
	_layer = layer
	building_id = p_id
	cell = p_cell
	size = BuildingData.get_building(p_id).get("size", Vector2i.ONE)
	z_index = cell.x + cell.y + size.x + size.y
	queue_redraw()


func _draw() -> void:
	if _layer == null:
		return
	var color := Color(0.2, 0.95, 0.25, 0.85) if not is_ghost \
			else (Color(0.3, 1.0, 0.35, 0.55) if ghost_valid else Color(1.0, 0.25, 0.25, 0.55))
	_draw_footprint_x(color)


func _draw_footprint_x(color: Color) -> void:
	var corners := _footprint_corners_local()
	if corners.size() < 4:
		return
	var min_p := corners[0]
	var max_p := corners[0]
	for p in corners:
		min_p = min_p.min(p)
		max_p = max_p.max(p)
	var pad := 6.0
	var tl := min_p + Vector2(pad, pad)
	var br := max_p - Vector2(pad, pad)
	draw_line(tl, br, color, 3.0)
	draw_line(Vector2(br.x, tl.y), Vector2(tl.x, br.y), color, 3.0)
	draw_polyline(corners, color.lightened(0.2), 2.0, true)


func _footprint_corners_local() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var offsets: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(size.x, 0),
		Vector2i(size.x, size.y),
		Vector2i(0, size.y),
	]
	var origin := _layer.map_to_local(cell)
	for off in offsets:
		pts.append(_layer.map_to_local(cell + off) - origin)
	return pts
