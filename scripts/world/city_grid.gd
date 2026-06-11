class_name CityGrid
extends Node2D
## CityGrid (Weltobjekt)
## =====================
## Das Herz des City-Builders: ein isometrisches Raster (Grid).
##
## Aufgaben:
##   - Boden zeichnen (Rauten-Raster in 2.5D)
##   - Mausposition -> Rasterzelle umrechnen
##   - Gebäude platzieren (mit Überlappungs- und Straßenprüfung)
##   - Visuelle Platzierungsvorschau (grüner/roter "Geist")
##   - Straßenbau per Ziehen mit gedrückter Maustaste
##   - Abriss-Modus
##
## WICHTIG: CityGrid verwaltet nur die WELT (Optik + Belegung).
## Geld abziehen, Regeln prüfen usw. macht GameState (Spiellogik).

## Halbe Kachelgröße (gleich wie in BuildingNode - 64x32-Pixel-Rauten).
const TILE_HALF_W := 32.0
const TILE_HALF_H := 16.0

## Die drei Maus-Modi des Spielers.
enum Mode { NONE, BUILD, DEMOLISH }

signal mode_changed(mode: int, building_id: String)
signal cell_hovered(cell: Vector2i)

var current_mode: int = Mode.NONE
var selected_building_id: String = ""

## Belegung: Dictionary von Zelle -> BuildingNode.
## Ein 2x2-Gebäude belegt 4 Einträge, die alle auf denselben Node zeigen.
var occupied: Dictionary = {}

## Straßenzellen als Dictionary (Zelle -> true) für schnelle Nachbar-Checks.
var roads: Dictionary = {}

## Der halbtransparente Vorschau-Geist.
var _ghost: BuildingNode = null

## Merkt sich, ob die linke Maustaste gedrückt ist (für Straßen-Ziehen).
var _dragging: bool = false


func _ready() -> void:
	## Bei neuen Regionen wird die Karte größer -> Boden neu zeichnen.
	GameState.region_claimed.connect(func(_id): queue_redraw())


# ---------------------------------------------------------------------------
# KARTENGRÖSSE - wächst mit jeder eingenommenen Region
# ---------------------------------------------------------------------------

## Kantenlänge der quadratischen Karte in Zellen.
func get_map_size() -> int:
	return 16 + 2 * GameState.claimed_regions.size()


## Liegt die Zelle innerhalb der aktuellen Karte?
func is_in_bounds(cell: Vector2i) -> bool:
	var s := get_map_size()
	return cell.x >= 0 and cell.y >= 0 and cell.x < s and cell.y < s


## Die Zelle in der Kartenmitte (dort steht das Rathaus).
func get_center_cell() -> Vector2i:
	var s := get_map_size()
	@warning_ignore("integer_division")
	return Vector2i(s / 2 - 1, s / 2 - 1)


# ---------------------------------------------------------------------------
# ISOMETRISCHE UMRECHNUNG (Zelle <-> Pixel)
# ---------------------------------------------------------------------------
## Die 2.5D-Optik entsteht durch diese Formel:
##   Bildschirm-x = (zelle.x - zelle.y) * 32
##   Bildschirm-y = (zelle.x + zelle.y) * 16
## Dadurch wird das quadratische Raster zu einem Rauten-Raster "gekippt".

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		(cell.x - cell.y) * TILE_HALF_W,
		(cell.x + cell.y) * TILE_HALF_H
	)


## Die Umkehrung: aus einer Pixelposition die Rasterzelle berechnen.
func world_to_cell(world_pos: Vector2) -> Vector2i:
	var fx := (world_pos.x / TILE_HALF_W + world_pos.y / TILE_HALF_H) / 2.0
	var fy := (world_pos.y / TILE_HALF_H - world_pos.x / TILE_HALF_W) / 2.0
	return Vector2i(int(floor(fx)), int(floor(fy)))


# ---------------------------------------------------------------------------
# BODEN ZEICHNEN
# ---------------------------------------------------------------------------

func _draw() -> void:
	var s := get_map_size()
	var grass_a := Color(0.36, 0.55, 0.36)
	var grass_b := Color(0.33, 0.52, 0.34)
	var line_color := Color(1, 1, 1, 0.06)

	for x in range(s):
		for y in range(s):
			var top := cell_to_world(Vector2i(x, y))
			var right := top + Vector2(TILE_HALF_W, TILE_HALF_H)
			var bottom := top + Vector2(0, TILE_HALF_H * 2)
			var left := top + Vector2(-TILE_HALF_W, TILE_HALF_H)
			## Schachbrett-Muster für bessere Lesbarkeit.
			var color := grass_a if (x + y) % 2 == 0 else grass_b
			draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), color)
			draw_polyline(PackedVector2Array([top, right, bottom, left, top]), line_color, 1.0)


# ---------------------------------------------------------------------------
# MODI (werden von der UI gesetzt)
# ---------------------------------------------------------------------------

## Baumodus starten - die UI ruft das auf, wenn ein Gebäude angeklickt wird.
func start_build_mode(building_id: String) -> void:
	current_mode = Mode.BUILD
	selected_building_id = building_id
	_create_ghost()
	mode_changed.emit(current_mode, building_id)


## Abrissmodus starten.
func start_demolish_mode() -> void:
	current_mode = Mode.DEMOLISH
	selected_building_id = ""
	_remove_ghost()
	mode_changed.emit(current_mode, "")


## Zurück zum normalen Mauszeiger.
func cancel_mode() -> void:
	current_mode = Mode.NONE
	selected_building_id = ""
	_dragging = false
	_remove_ghost()
	mode_changed.emit(current_mode, "")


# ---------------------------------------------------------------------------
# EINGABE
# ---------------------------------------------------------------------------
## _unhandled_input statt _input: Klicks auf UI-Buttons werden von der UI
## "verbraucht" und kommen hier gar nicht erst an. So baut man nicht aus
## Versehen ein Gebäude, wenn man einen Button drückt.

func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_game_over:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.pressed:
				_handle_click()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			## Rechtsklick bricht jeden Modus ab - das erwarten Spieler so.
			cancel_mode()

	elif event is InputEventMouseMotion:
		_update_ghost()
		var cell := world_to_cell(get_local_mouse_position())
		cell_hovered.emit(cell)
		## Straßen lassen sich "malen": Maustaste gedrückt halten und ziehen.
		if _dragging and current_mode == Mode.BUILD and selected_building_id == "strasse":
			_try_place_building(cell)

	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_mode()


func _handle_click() -> void:
	var cell := world_to_cell(get_local_mouse_position())
	match current_mode:
		Mode.BUILD:
			_try_place_building(cell)
		Mode.DEMOLISH:
			_try_demolish(cell)


# ---------------------------------------------------------------------------
# PLATZIERUNGSPRÜFUNG
# ---------------------------------------------------------------------------

## Prüft, ob ein Gebäude an dieser Zelle stehen DARF:
##   1. Alle Zellen innerhalb der Karte?
##   2. Keine Zelle schon belegt? (Überlappungsverbot)
##   3. Falls nötig: grenzt mindestens eine Zelle an eine Straße?
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

	if data["braucht_strasse"] and not _is_adjacent_to_road(cell, size):
		return false

	return true


## Grenzt die Grundfläche (cell, size) an mindestens eine Straße?
func _is_adjacent_to_road(cell: Vector2i, size: Vector2i) -> bool:
	## Wir prüfen den Ring aus Zellen direkt um die Grundfläche herum.
	for x in range(-1, size.x + 1):
		for y in range(-1, size.y + 1):
			## Zellen INNERHALB der Grundfläche überspringen.
			if x >= 0 and x < size.x and y >= 0 and y < size.y:
				continue
			if roads.has(cell + Vector2i(x, y)):
				return true
	return false


# ---------------------------------------------------------------------------
# BAUEN
# ---------------------------------------------------------------------------

func _try_place_building(cell: Vector2i) -> void:
	if selected_building_id == "":
		return
	if not is_placement_valid(selected_building_id, cell):
		return
	## Erst fragt die Welt die Spiellogik: "Darf gebaut werden?" (Geld etc.)
	if not GameState.register_building(selected_building_id, cell):
		GameState.notification.emit("Nicht genug Satoshis!")
		return
	_spawn_building_visual(selected_building_id, cell)
	_update_ghost()


## Erzeugt den sichtbaren Gebäude-Node und trägt die Belegung ein.
func _spawn_building_visual(building_id: String, cell: Vector2i) -> void:
	var node := BuildingNode.new()
	add_child(node)
	node.position = cell_to_world(cell)
	node.setup(building_id, cell)
	node.z_index = 10 + cell.x + cell.y  ## Hinten zuerst, vorne zuletzt zeichnen.

	var size: Vector2i = GameData.get_building(building_id)["groesse"]
	for x in range(size.x):
		for y in range(size.y):
			var c := cell + Vector2i(x, y)
			occupied[c] = node
			if building_id == "strasse":
				roads[c] = true


## Platziert das Start-Rathaus in der Kartenmitte (kostenlos)
## plus eine kleine Start-Straße davor.
func place_starting_buildings() -> void:
	var center := get_center_cell()
	GameState.register_starting_building("rathaus", center)
	_spawn_building_visual("rathaus", center)
	## Eine Straßenreihe südlich des Rathauses, damit sofort gebaut werden kann.
	for x in range(-1, 3):
		var road_cell := center + Vector2i(x, 2)
		GameState.register_starting_building("strasse", road_cell)
		_spawn_building_visual("strasse", road_cell)


# ---------------------------------------------------------------------------
# ABRISS
# ---------------------------------------------------------------------------

func _try_demolish(cell: Vector2i) -> void:
	if not occupied.has(cell):
		return
	var node: BuildingNode = occupied[cell]
	if node.building_id == "rathaus":
		GameState.notification.emit("Das Rathaus kann nicht abgerissen werden!")
		return

	## Spiellogik informieren (erstattet Geld, entfernt aus der Simulation).
	GameState.unregister_building(node.cell)

	## Alle belegten Zellen freigeben.
	for x in range(node.size.x):
		for y in range(node.size.y):
			var c: Vector2i = node.cell + Vector2i(x, y)
			occupied.erase(c)
			roads.erase(c)
	node.queue_free()


# ---------------------------------------------------------------------------
# PLATZIERUNGSVORSCHAU (der "Geist")
# ---------------------------------------------------------------------------

func _create_ghost() -> void:
	_remove_ghost()
	_ghost = BuildingNode.new()
	_ghost.is_ghost = true
	add_child(_ghost)
	_ghost.setup(selected_building_id, Vector2i.ZERO)
	_ghost.z_index = 4096  ## Immer über allen Gebäuden zeichnen.
	_update_ghost()


func _remove_ghost() -> void:
	if _ghost != null and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null


## Bewegt den Geist zur Mauszelle und färbt ihn grün (ok) oder rot (verboten).
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


# ---------------------------------------------------------------------------
# LADEN: Welt aus dem Spielstand wiederherstellen
# ---------------------------------------------------------------------------

## Löscht alle sichtbaren Gebäude und baut sie aus GameState.buildings neu auf.
## Wird nach dem Laden eines Spielstands aufgerufen.
func rebuild_from_state() -> void:
	cancel_mode()
	for node in get_children():
		if node is BuildingNode:
			node.queue_free()
	occupied.clear()
	roads.clear()
	for b in GameState.buildings:
		_spawn_building_visual(b["id"], b["cell"])
	queue_redraw()
