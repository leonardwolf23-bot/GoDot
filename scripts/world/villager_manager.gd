class_name VillagerManager
extends Node2D
## Spawnt einen Villager pro Bürger und steuert Berufe / Bewegung.

var _grid: CityGrid = null
var _nodes: Dictionary = {}  # citizen_id -> VillagerNode
var _pending_arrivals: Array[int] = []


func setup(grid: CityGrid) -> void:
	_grid = grid
	GameState.citizens_changed.connect(_sync_citizens)
	GameState.population_changed.connect(_on_population_changed)
	GameState.building_registered.connect(_on_building_registered)
	GameState.day_passed.connect(_on_day_passed)
	call_deferred("_sync_citizens")


func _sync_citizens() -> void:
	var alive_ids: Dictionary = {}
	for c in GameState.citizens:
		alive_ids[c["id"]] = true
		if not _nodes.has(c["id"]):
			_spawn_node_for_citizen(c)
		else:
			var node: VillagerNode = _nodes[c["id"]]
			node.set_profession(c["profession"])

	for cid in _nodes.keys():
		if not alive_ids.has(cid):
			var old: VillagerNode = _nodes[cid]
			if is_instance_valid(old):
				old.queue_free()
			_nodes.erase(cid)

	_update_all_jobs()


func _spawn_node_for_citizen(c: Dictionary) -> void:
	var node := VillagerNode.new()
	add_child(node)
	node.setup(_grid, c["id"])
	node.set_profession(c["profession"])
	node.arrived.connect(_on_villager_arrived.bind(c["id"]))

	var s := _grid.get_map_size()
	var rng := RandomNumberGenerator.new()
	rng.seed = c["id"] * 7919
	var cell := Vector2i(
			rng.randi_range(3, s - 2),
			rng.randi_range(1, s - 2)
	)
	if _grid.is_walkable(cell):
		node.position = _grid.cell_to_world_center(cell)
	else:
		node.position = _grid.cell_to_world_center(_grid.get_center_cell() + Vector2i(2, 3))

	_nodes[c["id"]] = node


func _on_population_changed() -> void:
	for c in GameState.citizens:
		if not _nodes.has(c["id"]):
			_pending_arrivals.append(c["id"])
	_sync_citizens()
	call_deferred("_process_arrivals")


func _process_arrivals() -> void:
	for cid in _pending_arrivals.duplicate():
		if not _nodes.has(cid):
			continue
		var node: VillagerNode = _nodes[cid]
		var edges: Array[String] = ["west", "east", "north", "south"]
		node.position = _grid.get_map_entry_position(edges[randi() % edges.size()])
		var housing := _find_free_housing_cell()
		if housing != Vector2i(-1, -1):
			GameState.assign_housing(cid, housing)
			node.walk_to_cell(housing)
		_pending_arrivals.erase(cid)


func _find_free_housing_cell() -> Vector2i:
	for b in GameState.buildings:
		if b.get("bau_tage_uebrig", 0) > 0:
			continue
		var data: Dictionary = GameData.get_building(b["id"])
		if data.get("wohnraum", 0) <= 0:
			continue
		var housed := 0
		for c in GameState.citizens:
			if c["housing_cell"] == b["cell"]:
				housed += 1
		if housed < data["wohnraum"]:
			return b["cell"] + Vector2i(0, data["groesse"].y)
	return Vector2i(-1, -1)


func _on_building_registered(building_id: String) -> void:
	if building_id == "strasse":
		return
	call_deferred("_update_all_jobs")


func _on_day_passed() -> void:
	_update_all_jobs()


func _update_all_jobs() -> void:
	for c in GameState.citizens:
		if not _nodes.has(c["id"]):
			continue
		var node: VillagerNode = _nodes[c["id"]]
		if node.is_moving():
			continue

		match c["profession"]:
			GameData.PROFESSION_BUILDER:
				_update_builder(c, node)
			GameData.PROFESSION_FARMER:
				_update_farmer(c, node)
			_:
				_update_villager(c, node)


func _update_builder(c: Dictionary, node: VillagerNode) -> void:
	if c["days_since_meal"] > GameData.BUILDER_HUNGER_DAYS:
		var food_cell := _find_food_building_cell()
		if food_cell != Vector2i(-1, -1):
			node.walk_to_cell(food_cell)
			return

	if c["work_cell"] != Vector2i(-1, -1):
		var site := c["work_cell"]
		var b := GameState.get_building_at_cell(site)
		if not b.is_empty() and b.get("bau_tage_uebrig", 0) > 0:
			node.position = _grid.cell_to_world_center(site + Vector2i(0, 1))
			return

	c["work_cell"] = Vector2i(-1, -1)
	for b in GameState.buildings:
		if b.get("bau_tage_uebrig", 0) > 0:
			if GameState.assign_builder_to_construction(b["cell"]):
				node.walk_to_cell(b["cell"] + Vector2i(0, 1))
				return


func _update_farmer(c: Dictionary, node: VillagerNode) -> void:
	if c["work_cell"] == Vector2i(-1, -1):
		return
	var farm := c["work_cell"]
	var data: Dictionary = GameData.get_building(
			GameState.get_building_at_cell(farm).get("id", ""))
	if data.is_empty():
		return
	node.position = _grid.cell_to_world_center(farm + Vector2i(0, data["groesse"].y))


func _update_villager(_c: Dictionary, node: VillagerNode) -> void:
	if node.position.distance_to(_grid.cell_to_world_center(_grid.get_center_cell())) > 800:
		node.walk_to_cell(_grid.get_center_cell() + Vector2i(2, 2))


func _find_food_building_cell() -> Vector2i:
	for b in GameState.buildings:
		if b.get("bau_tage_uebrig", 0) > 0:
			continue
		var data: Dictionary = GameData.get_building(b["id"])
		if data.get("verbrauch", {}).get("essen", 0.0) > 0.0 \
				or b["id"] == "food_court" or b["id"] == "rathaus":
			return b["cell"] + Vector2i(0, 1)
	return Vector2i(-1, -1)


func _on_villager_arrived(citizen_id: int) -> void:
	var c := GameState.get_citizen(citizen_id)
	if c.is_empty():
		return
	if c["profession"] == GameData.PROFESSION_BUILDER \
			and c["days_since_meal"] > GameData.BUILDER_HUNGER_DAYS:
		if resources_has_food():
			GameState.feed_builder(citizen_id)
			GameState.add_resource("essen", -2.0)


func resources_has_food() -> bool:
	return GameState.resources.get("essen", 0.0) > 0.0
