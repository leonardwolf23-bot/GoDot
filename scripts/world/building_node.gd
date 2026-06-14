class_name BuildingNode
extends Node2D
## Gebäude-Darstellung im isometrischen 64×32-Raster (Iso-Quader oder Sprite).

var building_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var size: Vector2i = Vector2i.ONE
var is_ghost: bool = false
var ghost_valid: bool = true
var is_under_construction: bool = false
var _texture: Texture2D = null


func setup(p_building_id: String, p_cell: Vector2i) -> void:
	building_id = p_building_id
	cell = p_cell
	var data: Dictionary = GameData.get_building(building_id)
	size = data["groesse"]

	var texture_path := "res://assets/buildings/%s.png" % building_id
	if ResourceLoader.exists(texture_path):
		_texture = load(texture_path)
	elif FileAccess.file_exists(texture_path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(texture_path))
		if img != null:
			_texture = ImageTexture.create_from_image(img)

	z_index = IsoUtils.depth_key(cell, size)
	queue_redraw()


func _footprint_corners() -> PackedVector2Array:
	return IsoUtils.footprint_corners(size)


func _draw() -> void:
	var data: Dictionary = GameData.get_building(building_id)
	if data.is_empty():
		return

	var top: Vector2 = _footprint_corners()[0]
	var right: Vector2 = _footprint_corners()[1]
	var bottom: Vector2 = _footprint_corners()[2]
	var left: Vector2 = _footprint_corners()[3]

	if is_under_construction and not is_ghost:
		var site := _load_shared_texture("res://assets/buildings/baustelle.png")
		if site != null:
			_draw_sprite_on_footprint(site, left, right, bottom, Color.WHITE)
			return
		_draw_iso_prism(data, top, right, bottom, left, Color(0.85, 0.6, 0.2))
		return

	if _texture != null:
		var tint := Color.WHITE
		if is_ghost:
			tint = Color(0.4, 1.0, 0.4, 0.6) if ghost_valid else Color(1.0, 0.3, 0.3, 0.6)
		_draw_sprite_on_footprint(_texture, left, right, bottom, tint)
		return

	if building_id == "strasse" and not is_ghost:
		draw_colored_polygon(_footprint_corners(), Color(0.38, 0.39, 0.42))
		return

	var base_color: Color = data["farbe"]
	if is_ghost:
		base_color = Color(0.3, 1.0, 0.3, 0.55) if ghost_valid else Color(1.0, 0.25, 0.25, 0.55)

	_draw_iso_prism(data, top, right, bottom, left, base_color)

	if not is_ghost and building_id != "strasse":
		var label: String = data.get("name", building_id)
		var center := (top + bottom) * 0.5 + Vector2(0.0, -data.get("hoehe", 24) * 0.5)
		draw_string(ThemeDB.fallback_font, center + Vector2(-40, 0),
				label, HORIZONTAL_ALIGNMENT_LEFT, 120, 10, Color.WHITE)


func _draw_iso_prism(data: Dictionary, top: Vector2, right: Vector2, bottom: Vector2,
		left: Vector2, base_color: Color) -> void:
	var height: float = data.get("hoehe", 24)
	var roof_color := base_color.lightened(0.15)
	var left_wall := base_color.darkened(0.25)
	var right_wall := base_color.darkened(0.45)

	if is_ghost:
		roof_color = base_color
		left_wall = base_color.darkened(0.15)
		right_wall = base_color.darkened(0.3)

	var up := Vector2(0.0, -height)

	draw_colored_polygon(PackedVector2Array([
		left, bottom, bottom + up, left + up,
	]), left_wall)
	draw_colored_polygon(PackedVector2Array([
		bottom, right, right + up, bottom + up,
	]), right_wall)
	draw_colored_polygon(PackedVector2Array([
		top + up, right + up, bottom + up, left + up,
	]), roof_color)

	var outline := Color(0.0, 0.0, 0.0, 0.35)
	draw_polyline(PackedVector2Array([
		top + up, right + up, bottom + up, left + up, top + up,
	]), outline, 1.5, true)
	draw_line(left, left + up, outline, 1.5)
	draw_line(bottom, bottom + up, outline, 1.5)
	draw_line(right, right + up, outline, 1.5)

	if height >= 36.0 and not is_ghost:
		var glow := Color(0.7, 1.0, 0.95, 0.8)
		var steps: int = int(height / 18.0)
		for i in range(1, steps):
			var y_offset := Vector2(0.0, -i * 18.0)
			draw_line(left + y_offset, bottom + y_offset, glow, 1.0)


func _draw_sprite_on_footprint(tex: Texture2D, left: Vector2, right: Vector2,
		bottom: Vector2, tint: Color) -> void:
	var dest_w := right.x - left.x
	var tex_size := tex.get_size()
	var dest_h := tex_size.y * (dest_w / tex_size.x)
	var dest := Rect2(left.x, bottom.y - dest_h, dest_w, dest_h)
	draw_texture_rect(tex, dest, false, tint)


static var _shared_textures := {}


func _load_shared_texture(path: String) -> Texture2D:
	if _shared_textures.has(path):
		return _shared_textures[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			tex = ImageTexture.create_from_image(img)
	_shared_textures[path] = tex
	return tex
