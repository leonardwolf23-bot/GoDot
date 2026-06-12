class_name VillagerManager
extends Node2D
## Verwaltet Dorfbewohner und weist Essen-Lieferungen über das Straßennetz zu.

const MAX_VILLAGERS := 4
const MAX_PENDING_JOBS := 8

var _grid: CityGrid = null
var _villagers: Array[VillagerNode] = []
var _job_queue: Array[Dictionary] = []


func setup(grid: CityGrid) -> void:
	_grid = grid
	if not GameState.day_passed.is_connected(_on_day_passed):
		GameState.day_passed.connect(_on_day_passed)
	if not GameState.building_completed.is_connected(_on_building_completed):
		GameState.building_completed.connect(_on_building_completed)

	call_deferred("_spawn_starting_villager")


func _spawn_starting_villager() -> void:
	if _grid == null:
		return
	var rathaus := _find_building("rathaus")
	if rathaus.is_empty():
		return
	var access := _grid.get_road_cells_adjacent_to_building(
			rathaus["cell"], rathaus["size"])
	if access.is_empty():
		return
	_spawn_villager_at(access[0])


func _spawn_villager_at(road_cell: Vector2i) -> VillagerNode:
	if _villagers.size() >= MAX_VILLAGERS:
		return null
	var villager := VillagerNode.new()
	add_child(villager)
	villager.setup(_grid)
	villager.position = _grid.cell_to_world(road_cell)
	villager.delivery_finished.connect(_on_villager_delivery_finished)
	_villagers.append(villager)
	return villager


func _on_day_passed() -> void:
	if GameState.daily_report.get("essen", 0.0) <= 0.0:
		return
	_schedule_food_deliveries(1)


func _on_building_completed(cell: Vector2i) -> void:
	for b in GameState.buildings:
		if b["cell"] == cell and (_is_food_source(b) or _is_food_destination(b)):
			_schedule_food_deliveries(1)
			return


func _schedule_food_deliveries(count: int) -> void:
	var sources := _get_food_sources()
	var destinations := _get_food_destinations()
	if sources.is_empty() or destinations.is_empty():
		return

	for i in range(count):
		if _job_queue.size() >= MAX_PENDING_JOBS:
			break
		var source: Dictionary = sources[i % sources.size()]
		var dest: Dictionary = _pick_best_destination(source, destinations)
		if dest.is_empty():
			continue
		_enqueue_food_job(source, dest)

	_process_queue()


func _enqueue_food_job(source: Dictionary, dest: Dictionary) -> void:
	var source_roads := _grid.get_road_cells_adjacent_to_building(
			source["cell"], source["size"])
	var dest_roads := _grid.get_road_cells_adjacent_to_building(
			dest["cell"], dest["size"])
	if source_roads.is_empty() or dest_roads.is_empty():
		return

	var route_path := _grid.find_road_path_between_buildings(
			source["cell"], source["size"],
			dest["cell"], dest["size"])
	if route_path.is_empty():
		return

	var pickup_cell: Vector2i = route_path[0]

	for job in _job_queue:
		if job.get("source_cell") == source["cell"] \
				and job.get("dest_cell") == dest["cell"]:
			return

	_job_queue.append({
		"resource": "essen",
		"source_id": source["id"],
		"source_cell": source["cell"],
		"dest_id": dest["id"],
		"dest_cell": dest["cell"],
		"route_path": route_path,
		"pickup_cell": pickup_cell,
	})


func _process_queue() -> void:
	while not _job_queue.is_empty():
		var villager := _get_idle_villager()
		if villager == null:
			if _villagers.size() < MAX_VILLAGERS:
				var spawn_cell: Vector2i = _job_queue[0]["route_path"][0]
				villager = _spawn_villager_at(spawn_cell)
			if villager == null:
				break

		var job: Dictionary = _job_queue.pop_front()
		var full_path := _build_villager_path(villager, job)
		if full_path.is_empty():
			continue
		villager.start_delivery(job, full_path, job["pickup_cell"])


func _build_villager_path(villager: VillagerNode, job: Dictionary) -> Array[Vector2i]:
	var route: Array[Vector2i] = job["route_path"]
	var start_cell := _grid.world_to_cell(villager.position)
	if not _grid.roads.has(start_cell):
		start_cell = route[0]

	if start_cell == route[0]:
		return route

	var to_source := _grid.find_path_on_roads(start_cell, route[0])
	if to_source.is_empty():
		return route

	var combined: Array[Vector2i] = to_source.duplicate()
	for i in range(1, route.size()):
		combined.append(route[i])
	return combined


func _get_idle_villager() -> VillagerNode:
	for v in _villagers:
		if is_instance_valid(v) and v.is_available():
			return v
	return null


func _on_villager_delivery_finished(job: Dictionary) -> void:
	if job.is_empty():
		return
	var dest_name: String = GameData.get_building(job.get("dest_id", "")).get("name", "")
	if dest_name != "":
		GameState.notification.emit("Essen geliefert: %s" % dest_name)
	_process_queue()


func _get_food_sources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for b in GameState.buildings:
		if not _is_built(b):
			continue
		if not _is_food_source(b):
			continue
		var data: Dictionary = GameData.get_building(b["id"])
		var size: Vector2i = data["groesse"]
		if _grid.get_road_cells_adjacent_to_building(b["cell"], size).is_empty():
			continue
		result.append({
			"id": b["id"],
			"cell": b["cell"],
			"size": size,
		})
	return result


func _get_food_destinations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for b in GameState.buildings:
		if not _is_built(b):
			continue
		if not _is_food_destination(b):
			continue
		var data: Dictionary = GameData.get_building(b["id"])
		var size: Vector2i = data["groesse"]
		if _grid.get_road_cells_adjacent_to_building(b["cell"], size).is_empty():
			continue
		result.append({
			"id": b["id"],
			"cell": b["cell"],
			"size": size,
		})
	return result


func _pick_best_destination(source: Dictionary,
		destinations: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var best_len := 999999
	for dest in destinations:
		if dest["cell"] == source["cell"]:
			continue
		var path := _grid.find_road_path_between_buildings(
				source["cell"], source["size"],
				dest["cell"], dest["size"])
		if path.is_empty():
			continue
		if path.size() < best_len:
			best_len = path.size()
			best = dest
	return best


func _is_food_source(b: Dictionary) -> bool:
	if b["id"] == "rathaus" or b["id"] == "strasse":
		return false
	var data: Dictionary = GameData.get_building(b["id"])
	return data.get("produktion", {}).get("essen", 0.0) > 0.0


func _is_food_destination(b: Dictionary) -> bool:
	if b["id"] == "strasse":
		return false
	var data: Dictionary = GameData.get_building(b["id"])
	if data.get("verbrauch", {}).get("essen", 0.0) > 0.0:
		return true
	return b["id"] == "rathaus"


func _is_built(b: Dictionary) -> bool:
	return b.get("bau_tage_uebrig", 0) <= 0


func _find_building(building_id: String) -> Dictionary:
	for b in GameState.buildings:
		if b["id"] == building_id:
			var data: Dictionary = GameData.get_building(b["id"])
			return {
				"id": b["id"],
				"cell": b["cell"],
				"size": data["groesse"],
			}
	return {}
