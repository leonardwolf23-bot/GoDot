class_name CityGrid
extends Node2D
## Isometrisches Grid mit Godot TileMapLayer (64×32).
## Boden: Textur wenn vorhanden, sonst rotes X. Gebäude: grünes X.

const TILE_WIDTH := 64
const TILE_HEIGHT := 32
const MAP_SIZE := 20
const GRASS_PATH := "res://assets/tiles/grass.png"

signal build_mode_changed(building_id: String)

var selected_building_id: String = ""
var occupied: Dictionary = {}

var _layer: TileMapLayer = null
var _grass_texture: Texture2D = null
var _has_grass_tile := false
var _ghost: BuildingNode = null
var _source_id := 0


func _ready() -> void:
	_setup_tilemap()
	_fill_terrain()
	set_process_unhandled_input(true)


func _setup_tilemap() -> void:
	_layer = TileMapLayer.new()
	_layer.name = "GroundLayer"
	add_child(_layer)

	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tile_set.tile_size = Vector2i(TILE_WIDTH, TILE_HEIGHT)

	_grass_texture = _load_fresh(GRASS_PATH)
	if _grass_texture != null:
		var atlas := TileSetAtlasSource.new()
		atlas.texture = _grass_texture
		atlas.texture_region_size = Vector2i(TILE_WIDTH, TILE_HEIGHT)
		atlas.create_tile(Vector2i(0, 0))
		_source_id = tile_set.add_source(atlas)
		_has_grass_tile = true

	_layer.tile_set = tile_set


func _fill_terrain() -> void:
	if not _has_grass_tile:
		return
	_layer.clear()
	for x in range(MAP_SIZE):
		for y in range(MAP_SIZE):
			_layer.set_cell(Vector2i(x, y), _source_id, Vector2i(0, 0))


func map_to_local(cell: Vector2i) -> Vector2:
	return _layer.map_to_local(cell) if _layer else Vector2.ZERO


func local_to_map(pos: Vector2) -> Vector2i:
	return _layer.local_to_map(pos) if _layer else Vector2i.ZERO


func is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_SIZE and cell.y < MAP_SIZE


func get_center_cell() -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(MAP_SIZE / 2, MAP_SIZE / 2)


func start_build_mode(building_id: String) -> void:
	if not BuildingData.get_building(building_id):
		return
	selected_building_id = building_id
	_create_ghost()
	build_mode_changed.emit(building_id)


func cancel_build_mode() -> void:
	selected_building_id = ""
	_remove_ghost()
	build_mode_changed.emit("")


func is_placement_valid(building_id: String, cell: Vector2i) -> bool:
	var data := BuildingData.get_building(building_id)
	if data.is_empty():
		return false
	var size: Vector2i = data["size"]
	for x in range(size.x):
		for y in range(size.y):
			var c := cell + Vector2i(x, y)
			if not is_in_bounds(c) or occupied.has(c):
				return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if selected_building_id != "":
			_try_place(get_local_mouse_position())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cancel_build_mode()
	elif event is InputEventMouseMotion:
		_update_ghost()
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				start_build_mode("haus_1x1")
			KEY_2:
				start_build_mode("haus_2x2")
			KEY_3:
				start_build_mode("haus_3x3")
			KEY_ESCAPE:
				cancel_build_mode()


func _try_place(local_pos: Vector2) -> void:
	var cell := local_to_map(local_pos)
	if not is_placement_valid(selected_building_id, cell):
		return
	_spawn_building(selected_building_id, cell)
	_update_ghost()


func _spawn_building(building_id: String, cell: Vector2i) -> void:
	var node := BuildingNode.new()
	add_child(node)
	node.setup(_layer, building_id, cell)
	node.position = map_to_local(cell)
	var size: Vector2i = BuildingData.get_building(building_id)["size"]
	for x in range(size.x):
		for y in range(size.y):
			occupied[cell + Vector2i(x, y)] = node


func _create_ghost() -> void:
	_remove_ghost()
	_ghost = BuildingNode.new()
	_ghost.is_ghost = true
	add_child(_ghost)
	_ghost.setup(_layer, selected_building_id, Vector2i.ZERO)
	_ghost.z_index = 4096
	_update_ghost()


func _remove_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


func _update_ghost() -> void:
	if _ghost == null:
		return
	var cell := local_to_map(get_local_mouse_position())
	_ghost.position = map_to_local(cell)
	_ghost.cell = cell
	var valid := is_placement_valid(selected_building_id, cell)
	if valid != _ghost.ghost_valid:
		_ghost.ghost_valid = valid
		_ghost.queue_redraw()


func _draw() -> void:
	if _has_grass_tile:
		return
	for x in range(MAP_SIZE):
		for y in range(MAP_SIZE):
			_draw_red_x_at_cell(Vector2i(x, y))


func _draw_red_x_at_cell(cell: Vector2i) -> void:
	var center := map_to_local(cell)
	var hw := TILE_WIDTH * 0.25
	var hh := TILE_HEIGHT * 0.35
	var tl := center + Vector2(-hw, -hh)
	var br := center + Vector2(hw, hh)
	var col := Color(0.95, 0.15, 0.15, 0.9)
	draw_line(tl, br, col, 2.5)
	draw_line(Vector2(br.x, tl.y), Vector2(tl.x, br.y), col, 2.5)


func _load_fresh(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)
