class_name CityGrid
extends Node2D
## CityGrid – isometrisches 64×32-Raster (klassische Iso-Projektion, Atlas-Boden).

enum Mode { NONE, BUILD, DEMOLISH, FARM_PAINT }

enum TerrainTile {
	GRASS,
	RIVER,
	ROAD,
	TREE,
	ROCK,
	DIRT,
}

const ATLAS_PATH := "res://assets/tiles/iso/terrain_atlas.png"
const TILE_PATHS := {
	TerrainTile.GRASS: "res://assets/tiles/iso/grass.png",
	TerrainTile.RIVER: "res://assets/tiles/iso/river.png",
	TerrainTile.ROAD: "res://assets/tiles/iso/road.png",
	TerrainTile.TREE: "res://assets/tiles/iso/tree.png",
	TerrainTile.ROCK: "res://assets/tiles/iso/rock.png",
	TerrainTile.DIRT: "res://assets/tiles/iso/dirt.png",
}
const GROUND_OVERSCAN := 4

signal mode_changed(mode: int, building_id: String)
signal cell_hovered(cell: Vector2i)
signal building_hovered(info: Dictionary)
signal building_clicked(info: Dictionary)
signal terrain_changed

var current_mode: int = Mode.NONE
var selected_building_id: String = ""
var farm_paint_farm_cell: Vector2i = Vector2i(-1, -1)
var farm_paint_crop: String = ""

var occupied: Dictionary = {}
var roads: Dictionary = {}
## Zelle -> "grass", "river", "tree", "rock"
var terrain: Dictionary = {}

var _ghost: BuildingNode = null
var _dragging: bool = false
var _hovered_building: BuildingNode = null
var _terrain_atlas: Texture2D = null
var _terrain_textures: Array[Texture2D] = []


func _ready() -> void:
	GameState.region_claimed.connect(func(_id): _refresh_terrain_tiles())
	GameState.building_completed.connect(_on_building_completed)
	GameState.farm_fields_changed.connect(func(_c): queue_redraw())
	_load_terrain_textures()
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func _load_terrain_textures() -> void:
	_terrain_textures.clear()
	_terrain_atlas = _load_texture_fresh(ATLAS_PATH)
	for tile_id in TerrainTile.size():
		var path: String = TILE_PATHS.get(tile_id, "")
		var tex := _load_texture_fresh(path) if path != "" else null
		if tex == null and _terrain_atlas != null:
			var atlas_img := _terrain_atlas.get_image()
			if atlas_img != null and not atlas_img.is_empty():
				var region := atlas_img.get_region(Rect2i(
						tile_id * IsoUtils.TILE_WIDTH, 0,
						IsoUtils.TILE_WIDTH, IsoUtils.TILE_HEIGHT))
				tex = ImageTexture.create_from_image(region)
		_terrain_textures.append(tex)


## Lädt PNGs immer frisch von der Festplatte (umgeht Godots Resource-Cache).
func _load_texture_fresh(path: String) -> Texture2D:
	var global_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(global_path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _load_texture(path: String) -> Texture2D:
	return _load_texture_fresh(path)


func get_map_size() -> int:
	return 24 + 2 * GameState.claimed_regions.size()


func is_in_bounds(cell: Vector2i) -> bool:
	var s := get_map_size()
	return cell.x >= 0 and cell.y >= 0 and cell.x < s and cell.y < s


func get_center_cell() -> Vector2i:
	var s := get_map_size()
	@warning_ignore("integer_division")
	return Vector2i(s / 2 - 1, s / 2 - 1)


func cell_to_world(cell: Vector2i) -> Vector2:
	return IsoUtils.cell_to_world(cell)


func cell_to_world_center(cell: Vector2i) -> Vector2:
	return IsoUtils.cell_to_world_center(cell)


func world_to_cell(world_pos: Vector2) -> Vector2i:
	return IsoUtils.world_to_cell(world_pos)


func generate_terrain() -> void:
	terrain.clear()
	var s := get_map_size()
	for y in range(s):
		terrain[Vector2i(0, y)] = "river"
		terrain[Vector2i(1, y)] = "river"

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count := int(s * s * 0.06)
	for _i in range(count):
		var c := Vector2i(rng.randi_range(3, s - 1), rng.randi_range(0, s - 1))
		if terrain.has(c) or occupied.has(c):
			continue
		terrain[c] = "tree" if rng.randf() > 0.45 else "rock"
	_refresh_terrain_tiles()
	terrain_changed.emit()


func get_terrain(cell: Vector2i) -> String:
	return terrain.get(cell, "grass")


func is_terrain_blocking(cell: Vector2i) -> bool:
	var t: String = get_terrain(cell)
	return t == "river" or t == "tree" or t == "rock"


func is_walkable(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	if occupied.has(cell):
		var node: BuildingNode = occupied[cell]
		if node != null and node.building_id != "strasse":
			return false
	return not is_terrain_blocking(cell)


func _terrain_to_tile_id(t: String) -> int:
	match t:
		"river":
			return TerrainTile.RIVER
		"tree":
			return TerrainTile.TREE
		"rock":
			return TerrainTile.ROCK
		_:
			return TerrainTile.GRASS


func _cell_to_tile_id(cell: Vector2i) -> int:
	if roads.has(cell):
		return TerrainTile.ROAD
	return _terrain_to_tile_id(get_terrain(cell))


func _refresh_terrain_tiles() -> void:
	_load_terrain_textures()
	queue_redraw()


func _cell_diamond(cell: Vector2i) -> PackedVector2Array:
	var top := cell_to_world(cell)
	var hw := IsoUtils.half_w()
	var hh := IsoUtils.half_h()
	return PackedVector2Array([
		top,
		top + Vector2(hw, hh),
		top + Vector2(0.0, hh * 2.0),
		top + Vector2(-hw, hh),
	])


func _draw() -> void:
	_draw_terrain()
	_draw_farm_fields()

	if current_mode != Mode.NONE:
		var s := get_map_size()
		var line_color := Color(0.0, 0.0, 0.0, 0.18)
		for x in range(s):
			for y in range(s):
				draw_polyline(_cell_diamond(Vector2i(x, y)), line_color, 1.0, true)


func _draw_terrain() -> void:
	var s := get_map_size()
	var pad := GROUND_OVERSCAN
	for x in range(-pad, s + pad):
		for y in range(-pad, s + pad):
			var c := Vector2i(x, y)
			var tile_id := TerrainTile.GRASS
			if x < 0 or y < 0 or x >= s or y >= s:
				tile_id = TerrainTile.DIRT
			else:
				tile_id = _cell_to_tile_id(c)
			var pos := IsoUtils.terrain_texture_pos(c)
			var tex: Texture2D = null
			if tile_id >= 0 and tile_id < _terrain_textures.size():
				tex = _terrain_textures[tile_id]
			if tex != null:
				draw_texture_rect(tex,
						Rect2(pos, Vector2(IsoUtils.TILE_WIDTH, IsoUtils.TILE_HEIGHT)), false)
			else:
				if tile_id == TerrainTile.GRASS and c == Vector2i.ZERO:
					push_warning("Gras-Textur nicht geladen – zeichne grünen Platzhalter. Pfad: %s"
							% TILE_PATHS[TerrainTile.GRASS])
				draw_colored_polygon(_cell_diamond(c), _fallback_terrain_color(tile_id))


func _fallback_terrain_color(tile_id: int) -> Color:
	match tile_id:
		TerrainTile.RIVER:
			return Color(0.22, 0.48, 0.88)
		TerrainTile.ROAD:
			return Color(0.42, 0.43, 0.46)
		TerrainTile.TREE:
			return Color(0.42, 0.68, 0.32)
		TerrainTile.ROCK:
			return Color(0.5, 0.52, 0.48)
		TerrainTile.DIRT:
			return Color(0.55, 0.45, 0.35)
		_:
			return Color(0.72, 0.78, 0.62)


func _draw_farm_fields() -> void:
	for b in GameState.buildings:
		if not b.has("farm_fields"):
			continue
		for f in b["farm_fields"]:
			var fc := Vector2i(int(f["x"]), int(f["y"]))
			var crop: String = str(f.get("crop", ""))
			if crop == "":
				continue
			var pts := _cell_diamond(fc)
			var col: Color = GameData.get_crop_color(crop)
			draw_colored_polygon(pts, col.darkened(0.08))
			draw_polyline(pts, col.lightened(0.12), 2.0, true)
			var label: String = GameData.get_crop_name(crop).substr(0, 3)
			var center := cell_to_world_center(fc)
			draw_string(ThemeDB.fallback_font, center + Vector2(-10, 4),
					label, HORIZONTAL_ALIGNMENT_LEFT, 28, 9, Color(0.1, 0.1, 0.1, 0.85))


func start_build_mode(building_id: String) -> void:
	current_mode = Mode.BUILD
	selected_building_id = building_id
	_clear_hover()
	_create_ghost()
	queue_redraw()
	mode_changed.emit(current_mode, building_id)


func start_demolish_mode() -> void:
	current_mode = Mode.DEMOLISH
	selected_building_id = ""
	_clear_hover()
	_remove_ghost()
	queue_redraw()
	mode_changed.emit(current_mode, "")


func _clear_hover() -> void:
	if _hovered_building != null:
		_hovered_building = null
		building_hovered.emit({})


func cancel_mode() -> void:
	current_mode = Mode.NONE
	selected_building_id = ""
	farm_paint_farm_cell = Vector2i(-1, -1)
	farm_paint_crop = ""
	_dragging = false
	_remove_ghost()
	queue_redraw()
	mode_changed.emit(current_mode, "")


func start_farm_paint_mode(farm_cell: Vector2i, crop_id: String) -> void:
	current_mode = Mode.FARM_PAINT
	farm_paint_farm_cell = farm_cell
	farm_paint_crop = crop_id
	selected_building_id = ""
	_clear_hover()
	_remove_ghost()
	queue_redraw()
	mode_changed.emit(current_mode, crop_id)


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_game_over:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.pressed:
				_handle_click()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			cancel_mode()

	elif event is InputEventMouseMotion:
		_update_ghost()
		var cell := world_to_cell(get_local_mouse_position())
		cell_hovered.emit(cell)
		_update_hover(cell)
		if _dragging and current_mode == Mode.BUILD and selected_building_id == "strasse":
			_try_place_building(cell)
		if _dragging and current_mode == Mode.FARM_PAINT:
			_try_paint_farm_field(cell)

	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_mode()


func _update_hover(cell: Vector2i) -> void:
	var found: BuildingNode = null
	if current_mode == Mode.NONE and occupied.has(cell):
		found = occupied[cell]
	if found == _hovered_building:
		return
	_hovered_building = found
	if found == null:
		var crop: String = GameState.get_farm_field_crop_at(cell)
		if crop != "":
			building_hovered.emit({
				"id": "farm_field",
				"cell": cell,
				"crop": crop,
			})
		else:
			building_hovered.emit({})
	else:
		building_hovered.emit({"id": found.building_id, "cell": found.cell})


func _handle_click() -> void:
	var cell := world_to_cell(get_local_mouse_position())
	match current_mode:
		Mode.BUILD:
			_try_place_building(cell)
		Mode.DEMOLISH:
			_try_demolish(cell)
		Mode.FARM_PAINT:
			_try_paint_farm_field(cell)
		Mode.NONE:
			if occupied.has(cell):
				var node: BuildingNode = occupied[cell]
				building_clicked.emit({"id": node.building_id, "cell": node.cell})


func is_placement_valid(building_id: String, cell: Vector2i) -> bool:
	var data := GameData.get_building(building_id)
	if data.is_empty():
		return false
	var size: Vector2i = data["groesse"]

	for x in range(size.x):
		for y in range(size.y):
			var check := cell + Vector2i(x, y)
			if not is_in_bounds(check):
				return false
			if occupied.has(check):
				return false
			if is_terrain_blocking(check):
				return false

	if building_id == "strasse":
		return _has_orthogonal_road_neighbor(cell)

	if data.get("braucht_strasse", false) and not _is_adjacent_to_road(cell, size):
		return false

	if data.get("braucht_fluss", false) and not _is_adjacent_to_terrain(cell, size, "river"):
		return false

	return true


func _has_orthogonal_road_neighbor(cell: Vector2i) -> bool:
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor: Vector2i = cell + offset
		if roads.has(neighbor):
			return true
		if occupied.has(neighbor) and occupied[neighbor].building_id == "rathaus":
			return true
	return false


func _is_adjacent_to_road(cell: Vector2i, size: Vector2i) -> bool:
	for x in range(-1, size.x + 1):
		for y in range(-1, size.y + 1):
			if x >= 0 and x < size.x and y >= 0 and y < size.y:
				continue
			if roads.has(cell + Vector2i(x, y)):
				return true
	return false


func _is_adjacent_to_terrain(cell: Vector2i, size: Vector2i, terrain_id: String) -> bool:
	for x in range(-1, size.x + 1):
		for y in range(-1, size.y + 1):
			if x >= 0 and x < size.x and y >= 0 and y < size.y:
				continue
			if get_terrain(cell + Vector2i(x, y)) == terrain_id:
				return true
	return false


func _try_place_building(cell: Vector2i) -> void:
	if selected_building_id == "":
		return
	if not is_placement_valid(selected_building_id, cell):
		return
	if not GameState.register_building(selected_building_id, cell):
		GameState.notification.emit("Nicht genug Satoshis!")
		return
	var under_construction := selected_building_id != "strasse"
	_spawn_building_visual(selected_building_id, cell, under_construction)
	_update_ghost()


func _spawn_building_visual(building_id: String, cell: Vector2i,
		under_construction: bool = false) -> void:
	var node := BuildingNode.new()
	add_child(node)
	node.position = cell_to_world(cell)
	node.is_under_construction = under_construction
	node.setup(building_id, cell)

	var size: Vector2i = GameData.get_building(building_id)["groesse"]
	if building_id == "strasse":
		node.z_index = 5 + int(node.position.y) + size.y
	else:
		node.z_index = 10 + int(node.position.y) + size.y

	for x in range(size.x):
		for y in range(size.y):
			var c := cell + Vector2i(x, y)
			occupied[c] = node
			if building_id == "strasse":
				roads[c] = true
				terrain.erase(c)
	_refresh_terrain_tiles()


func _on_building_completed(cell: Vector2i) -> void:
	if not occupied.has(cell):
		return
	var node: BuildingNode = occupied[cell]
	node.is_under_construction = false
	node.queue_redraw()


func place_starting_buildings() -> void:
	generate_terrain()
	var center := get_center_cell()
	var rathaus_size: Vector2i = GameData.get_building("rathaus")["groesse"]
	GameState.register_starting_building("rathaus", center)
	_spawn_building_visual("rathaus", center)
	for x in range(-1, rathaus_size.x + 1):
		var road_cell := center + Vector2i(x, rathaus_size.y)
		GameState.register_starting_building("strasse", road_cell)
		_spawn_building_visual("strasse", road_cell)


func _try_demolish(cell: Vector2i) -> void:
	if terrain.has(cell):
		var t: String = terrain[cell]
		if t == "tree":
			GameState.queue_world_pickup(cell, "holz", 8.0)
		elif t == "rock":
			GameState.queue_world_pickup(cell, "steine", 6.0)
		terrain.erase(cell)
		_refresh_terrain_tiles()
		terrain_changed.emit()
		return

	if not occupied.has(cell):
		return
	var node: BuildingNode = occupied[cell]
	if node.building_id == "rathaus":
		GameState.notification.emit("Das Rathaus kann nicht abgerissen werden!")
		return

	GameState.unregister_building(node.cell)
	for x in range(node.size.x):
		for y in range(node.size.y):
			var c: Vector2i = node.cell + Vector2i(x, y)
			occupied.erase(c)
			roads.erase(c)
	node.queue_free()
	_refresh_terrain_tiles()


func _create_ghost() -> void:
	_remove_ghost()
	_ghost = BuildingNode.new()
	_ghost.is_ghost = true
	add_child(_ghost)
	_ghost.setup(selected_building_id, Vector2i.ZERO)
	_ghost.z_index = 4096
	_update_ghost()


func _remove_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


func _update_ghost() -> void:
	if _ghost == null or not is_instance_valid(_ghost):
		return
	var cell := world_to_cell(get_local_mouse_position())
	_ghost.position = cell_to_world(cell)
	_ghost.cell = cell
	var valid := is_placement_valid(selected_building_id, cell) \
			and GameState.can_build(selected_building_id)
	if valid != _ghost.ghost_valid:
		_ghost.ghost_valid = valid
		_ghost.queue_redraw()


func rebuild_from_state() -> void:
	cancel_mode()
	_clear_hover()
	for node in get_children():
		if node is BuildingNode:
			node.queue_free()
	occupied.clear()
	roads.clear()
	generate_terrain()
	for b in GameState.buildings:
		_spawn_building_visual(b["id"], b["cell"], b.get("bau_tage_uebrig", 0) > 0)
	queue_redraw()


# ---------------------------------------------------------------------------
# PFADFINDUNG
# ---------------------------------------------------------------------------

const _CARDINAL: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]


func get_road_cells_adjacent_to_building(building_cell: Vector2i,
		building_size: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(-1, building_size.x + 1):
		for y in range(-1, building_size.y + 1):
			if x >= 0 and x < building_size.x and y >= 0 and y < building_size.y:
				continue
			var c: Vector2i = building_cell + Vector2i(x, y)
			if roads.has(c):
				result.append(c)
	return result


func find_path_on_roads(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	return _find_path(start, goal, true)


func find_path_walkable(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	return _find_path(start, goal, false)


func _find_path(start: Vector2i, goal: Vector2i, roads_only: bool) -> Array[Vector2i]:
	if roads_only:
		if not roads.has(start) or not roads.has(goal):
			return []
	else:
		if not is_walkable(start) or not is_walkable(goal):
			return []
	if start == goal:
		return [start]

	var queue: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var head := 0

	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for offset in _CARDINAL:
			var next: Vector2i = current + offset
			if came_from.has(next):
				continue
			if roads_only:
				if not roads.has(next):
					continue
			elif not is_walkable(next):
				continue
			came_from[next] = current
			if next == goal:
				return _reconstruct_path(came_from, start, goal)
			queue.append(next)
	return []


func _reconstruct_path(came_from: Dictionary, start: Vector2i,
		goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current: Vector2i = goal
	while true:
		path.push_front(current)
		if current == start:
			break
		current = came_from[current]
	return path


func find_road_path_between_buildings(from_cell: Vector2i, from_size: Vector2i,
		to_cell: Vector2i, to_size: Vector2i) -> Array[Vector2i]:
	var from_roads := get_road_cells_adjacent_to_building(from_cell, from_size)
	var to_roads := get_road_cells_adjacent_to_building(to_cell, to_size)
	if from_roads.is_empty() or to_roads.is_empty():
		return []

	var best_path: Array[Vector2i] = []
	var best_len := 999999
	for fr in from_roads:
		for tr in to_roads:
			var path := find_path_on_roads(fr, tr)
			if path.size() > 0 and path.size() < best_len:
				best_len = path.size()
				best_path = path
	return best_path


func is_valid_farm_field_cell(farm_cell: Vector2i, field_cell: Vector2i) -> bool:
	if not is_in_bounds(field_cell):
		return false
	if occupied.has(field_cell):
		return false
	if is_terrain_blocking(field_cell):
		return false
	if roads.has(field_cell):
		return false

	var farm_b := GameState.get_farm_building(farm_cell)
	if farm_b.is_empty():
		return false
	var origin: Vector2i = farm_b["cell"]
	var size: Vector2i = farm_b["size"]

	var min_dist := 9999
	for x in range(size.x):
		for y in range(size.y):
			var fp: Vector2i = origin + Vector2i(x, y)
			var d: int = absi(field_cell.x - fp.x) + absi(field_cell.y - fp.y)
			min_dist = mini(min_dist, d)
	if min_dist > GameData.FARM_FIELD_MAX_DISTANCE:
		return false
	if min_dist == 0:
		return false
	return true


func _try_paint_farm_field(cell: Vector2i) -> void:
	if farm_paint_farm_cell == Vector2i(-1, -1) or farm_paint_crop == "":
		return
	if not is_valid_farm_field_cell(farm_paint_farm_cell, cell):
		return
	GameState.toggle_farm_field(farm_paint_farm_cell, cell, farm_paint_crop)
	queue_redraw()


func get_map_entry_position(edge: String) -> Vector2:
	var s := get_map_size()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	match edge:
		"west":
			return cell_to_world_center(Vector2i(-2, rng.randi_range(0, s - 1)))
		"east":
			return cell_to_world_center(Vector2i(s, rng.randi_range(0, s - 1)))
		"north":
			return cell_to_world_center(Vector2i(rng.randi_range(0, s - 1), -2))
		_:
			return cell_to_world_center(Vector2i(rng.randi_range(0, s - 1), s))
