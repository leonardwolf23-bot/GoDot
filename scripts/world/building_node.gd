class_name BuildingNode
extends Node2D
## Gebäude-Darstellung im isometrischen 64×32-Raster.

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


func _footprint_size() -> Vector2:
	return IsoUtils.footprint_size(size)


func _draw() -> void:
	var data: Dictionary = GameData.get_building(building_id)
	if data.is_empty():
		return

	var fp := _footprint_size()

	if is_under_construction and not is_ghost:
		var site := _load_shared_texture("res://assets/buildings/baustelle.png")
		if site != null:
			_draw_sprite_in_footprint(site, Color.WHITE)
			return
		_draw_footprint_fill(Color(0.85, 0.6, 0.2))
		return

	if _texture != null:
		var tint := Color.WHITE
		if is_ghost:
			tint = Color(0.4, 1.0, 0.4, 0.6) if ghost_valid else Color(1.0, 0.3, 0.3, 0.6)
		_draw_sprite_in_footprint(_texture, tint)
		return

	if building_id == "strasse" and not is_ghost:
		_draw_footprint_fill(Color(0.38, 0.39, 0.42))
		return

	var base_color: Color = data["farbe"]
	if is_ghost:
		base_color = Color(0.3, 1.0, 0.3, 0.55) if ghost_valid else Color(1.0, 0.25, 0.25, 0.55)

	_draw_footprint_fill(base_color.darkened(0.15))
	var pts := IsoUtils.footprint_polygon_local(size)
	draw_colored_polygon(pts, base_color)
	draw_polyline(pts, base_color.lightened(0.15), 2.0, true)

	if not is_ghost and building_id != "strasse":
		var label: String = data.get("name", building_id)
		var center := Vector2(fp.x * 0.5, fp.y * 0.45)
		draw_string(ThemeDB.fallback_font, center + Vector2(-fp.x * 0.35, 0),
				label, HORIZONTAL_ALIGNMENT_LEFT, int(fp.x * 0.9), 10, Color.WHITE)


func _draw_footprint_fill(color: Color) -> void:
	draw_colored_polygon(IsoUtils.footprint_polygon_local(size), color)


func _draw_sprite_in_footprint(tex: Texture2D, tint: Color) -> void:
	var fp := _footprint_size()
	var tex_size := tex.get_size()
	var dest_w := fp.x
	var dest_h := tex_size.y * (dest_w / tex_size.x)
	var dest := Rect2(0.0, fp.y - dest_h, dest_w, dest_h)
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
