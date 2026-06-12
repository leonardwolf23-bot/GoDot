class_name BuildingNode
extends Node2D
## Gebäude-Darstellung im orthogonalen 64×64-Raster.

const TILE_SIZE := 64.0

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

	z_index = int(position.y) + size.y
	queue_redraw()


func _draw() -> void:
	var data: Dictionary = GameData.get_building(building_id)
	if data.is_empty():
		return

	var footprint := Rect2(0, 0, size.x * TILE_SIZE, size.y * TILE_SIZE)

	if is_under_construction and not is_ghost:
		var site := _load_shared_texture("res://assets/buildings/baustelle.png")
		if site != null:
			draw_texture_rect(site, footprint, false, Color.WHITE)
			return
		draw_rect(footprint, Color(0.85, 0.6, 0.2))
		return

	if _texture != null:
		var tint := Color.WHITE
		if is_ghost:
			tint = Color(0.4, 1.0, 0.4, 0.6) if ghost_valid else Color(1.0, 0.3, 0.3, 0.6)
		draw_texture_rect(_texture, footprint, false, tint)
		return

	if building_id == "strasse" and not is_ghost:
		draw_rect(footprint, Color(0.38, 0.39, 0.42))
		return

	var base_color: Color = data["farbe"]
	if is_ghost:
		base_color = Color(0.3, 1.0, 0.3, 0.55) if ghost_valid else Color(1.0, 0.25, 0.25, 0.55)

	draw_rect(footprint, base_color.darkened(0.15))
	draw_rect(footprint, base_color, false, 2.0)

	var label: String = data.get("name", building_id)
	if not is_ghost and size.x * size.y >= 2:
		draw_string(ThemeDB.fallback_font, Vector2(6, 18), label,
				HORIZONTAL_ALIGNMENT_LEFT, int(footprint.size.x) - 8, 11, Color.WHITE)


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
