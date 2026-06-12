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
## Maus schwebt über einem Gebäude (oder verlässt es: leeres Dictionary).
## info = {"id": ..., "cell": ...} - das HUD baut daraus den Tooltip.
signal building_hovered(info: Dictionary)

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

## Über welchem Gebäude die Maus gerade schwebt (für den Hover-Tooltip).
var _hovered_building: BuildingNode = null

## Boden-Texturen: EINE durchgehende, nahtlose Textur pro Bereich.
## Früher bestand der Boden aus tausenden Einzel-Kacheln - deren minimale
## Helligkeitsunterschiede erzeugten ein sichtbares Rauten-Muster.
## Jetzt wird der Boden als EINE große Fläche mit wiederholender Textur
## gezeichnet: keine Kachelgrenzen -> kein Muster.
var _pavement_base: Texture2D = null
var _grass_base: Texture2D = null

## Wie viele Zellen Boden ÜBER den Kartenrand hinaus gezeichnet werden,
## damit die Welt randlos wirkt (dort kann man nicht bauen).
const GROUND_OVERSCAN := 30

## Nach wie vielen Welt-Pixeln sich die Bodentextur wiederholt.
const GROUND_TEX_SCALE := 230.0


func _ready() -> void:
	## Bei neuen Regionen wird die Karte größer -> Boden neu zeichnen.
	GameState.region_claimed.connect(func(_id): queue_redraw())
	## Fertiggestellte Baustellen optisch in echte Gebäude verwandeln.
	GameState.building_completed.connect(_on_building_completed)
	## WICHTIG: Texturen über die Polygon-Ränder hinaus wiederholen lassen
	## (sonst würde die Bodentextur nur einmal gezeichnet statt gekachelt).
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	## Boden-Texturen laden (mit Fallback auf Flächenfarben, falls sie fehlen).
	_pavement_base = _load_texture("res://assets/tiles/pavement_base.png")
	_grass_base = _load_texture("res://assets/tiles/grass_base.png")


## Lädt eine Textur - auch wenn Godot sie noch nicht importiert hat.
func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			return ImageTexture.create_from_image(img)
	return null


# ---------------------------------------------------------------------------
# KARTENGRÖSSE - wächst mit jeder eingenommenen Region
# ---------------------------------------------------------------------------

## Kantenlänge der quadratischen Karte in Zellen.
func get_map_size() -> int:
	return 24 + 2 * GameState.claimed_regions.size()


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

	## Der Boden wird weit ÜBER den Kartenrand hinaus gezeichnet, damit die
	## Welt kein sichtbares Ende hat:
	##   - Umland (zuerst, liegt unten) = helles Gras
	##   - Stadtgebiet (darüber)        = helles Pflaster (hier darf gebaut werden)
	## Beide Flächen sind je EIN großes Polygon mit durchlaufender Textur.
	_draw_ground_diamond(-GROUND_OVERSCAN, s + GROUND_OVERSCAN, _grass_base,
			Color(0.88, 0.94, 0.86), Color(0.58, 0.74, 0.48))
	_draw_ground_diamond(0, s, _pavement_base,
			Color.WHITE, Color(0.78, 0.76, 0.72))

	## Das Bau-Raster wird NUR im Bau-/Abrissmodus eingeblendet -
	## im normalen Spiel bleibt der Boden schön sauber.
	if current_mode != Mode.NONE:
		var line_color := Color(0.0, 0.0, 0.0, 0.18)
		for x in range(s):
			for y in range(s):
				var top := cell_to_world(Vector2i(x, y))
				var right := top + Vector2(TILE_HALF_W, TILE_HALF_H)
				var bottom := top + Vector2(0, TILE_HALF_H * 2)
				var left := top + Vector2(-TILE_HALF_W, TILE_HALF_H)
				draw_polyline(PackedVector2Array([top, right, bottom, left, top]),
						line_color, 1.0)


## Zeichnet eine große Boden-Raute von Zelle (from,from) bis (to,to)
## als EIN Polygon mit nahtlos wiederholender Textur.
func _draw_ground_diamond(from: int, to: int, texture: Texture2D,
		tint: Color, fallback_color: Color) -> void:
	## Die vier Eckpunkte der Gesamtfläche in Weltkoordinaten.
	var points := PackedVector2Array([
		cell_to_world(Vector2i(from, from)),   ## obere Ecke
		cell_to_world(Vector2i(to, from)),     ## rechte Ecke
		cell_to_world(Vector2i(to, to)),       ## untere Ecke
		cell_to_world(Vector2i(from, to)),     ## linke Ecke
	])

	if texture == null:
		draw_colored_polygon(points, fallback_color)
		return

	## UV-Koordinaten = Weltposition geteilt durch die Wiederholgröße.
	## Werte über 1.0 lassen die Textur dank TEXTURE_REPEAT_ENABLED kacheln -
	## EINE fortlaufende Fläche, keine sichtbaren Einzelkacheln.
	var uvs := PackedVector2Array()
	for p in points:
		uvs.append(p / GROUND_TEX_SCALE)
	var colors := PackedColorArray([tint, tint, tint, tint])
	draw_polygon(points, colors, uvs, texture)


# ---------------------------------------------------------------------------
# MODI (werden von der UI gesetzt)
# ---------------------------------------------------------------------------

## Baumodus starten - die UI ruft das auf, wenn ein Gebäude angeklickt wird.
func start_build_mode(building_id: String) -> void:
	current_mode = Mode.BUILD
	selected_building_id = building_id
	_clear_hover()
	_create_ghost()
	queue_redraw()  ## Bau-Raster einblenden.
	mode_changed.emit(current_mode, building_id)


## Abrissmodus starten.
func start_demolish_mode() -> void:
	current_mode = Mode.DEMOLISH
	selected_building_id = ""
	_clear_hover()
	_remove_ghost()
	queue_redraw()  ## Bau-Raster einblenden.
	mode_changed.emit(current_mode, "")


## Hover-Tooltip ausblenden (z.B. beim Wechsel in den Baumodus).
func _clear_hover() -> void:
	if _hovered_building != null:
		_hovered_building = null
		building_hovered.emit({})


## Zurück zum normalen Mauszeiger.
func cancel_mode() -> void:
	current_mode = Mode.NONE
	selected_building_id = ""
	_dragging = false
	_remove_ghost()
	queue_redraw()  ## Bau-Raster wieder ausblenden.
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
		_update_hover(cell)
		## Straßen lassen sich "malen": Maustaste gedrückt halten und ziehen.
		if _dragging and current_mode == Mode.BUILD and selected_building_id == "strasse":
			_try_place_building(cell)

	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_mode()


## Prüft, ob unter der Maus ein Gebäude liegt, und meldet Änderungen
## ans HUD (das den Info-Tooltip anzeigt). Nur im normalen Modus -
## beim Bauen oder Abreißen wäre der Tooltip im Weg.
func _update_hover(cell: Vector2i) -> void:
	var found: BuildingNode = null
	if current_mode == Mode.NONE and occupied.has(cell):
		found = occupied[cell]
	if found == _hovered_building:
		return  ## Nichts geändert -> kein unnötiges Signal.
	_hovered_building = found
	if found == null:
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


# ---------------------------------------------------------------------------
# PLATZIERUNGSPRÜFUNG
# ---------------------------------------------------------------------------

## Prüft, ob ein Gebäude an dieser Zelle stehen DARF:
##   1. Alle Zellen innerhalb der Karte?
##   2. Keine Zelle schon belegt? (Überlappungsverbot)
##   3. Falls nötig: grenzt mindestens eine Zelle an eine Straße?
##   4. Straßen selbst: müssen am bestehenden Straßennetz anschließen!
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

	## Straßen dürfen nicht "irgendwo" stehen: Sie müssen DIREKT (oben,
	## unten, links oder rechts - nicht diagonal) an eine bestehende
	## Straße anschließen. So entsteht ein zusammenhängendes Netz,
	## das am Rathaus beginnt.
	if building_id == "strasse":
		return _has_orthogonal_road_neighbor(cell)

	if data["braucht_strasse"] and not _is_adjacent_to_road(cell, size):
		return false

	return true


## Hat die Zelle direkt (nicht diagonal) eine Straße als Nachbar?
## Ausnahme: Direkt am Rathaus darf immer eine Straße beginnen - so kann
## das Netz nie komplett "aussterben", selbst wenn alles abgerissen wurde.
func _has_orthogonal_road_neighbor(cell: Vector2i) -> bool:
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var neighbor: Vector2i = cell + offset
		if roads.has(neighbor):
			return true
		if occupied.has(neighbor) and occupied[neighbor].building_id == "rathaus":
			return true
	return false


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
	## Neue Gebäude starten als Baustelle (Straßen sind sofort fertig).
	var under_construction := selected_building_id != "strasse"
	_spawn_building_visual(selected_building_id, cell, under_construction)
	_update_ghost()


## Erzeugt den sichtbaren Gebäude-Node und trägt die Belegung ein.
func _spawn_building_visual(building_id: String, cell: Vector2i,
		under_construction: bool = false) -> void:
	var node := BuildingNode.new()
	add_child(node)
	node.position = cell_to_world(cell)
	node.is_under_construction = under_construction
	node.setup(building_id, cell)

	var size: Vector2i = GameData.get_building(building_id)["groesse"]

	## Zeichenreihenfolge (z_index):
	##   - Straßen sind flach und liegen IMMER unter den Gebäuden (z = 5).
	##     Sonst würden später gebaute Straßen hohe Gebäude überlappen!
	##   - Gebäude sortieren nach ihrer VORDERSTEN Ecke (cell + size),
	##     damit auch 2x2-Gebäude wie das Rathaus korrekt verdeckt werden.
	if building_id == "strasse":
		node.z_index = 5
	else:
		node.z_index = 10 + (cell.x + size.x - 1) + (cell.y + size.y - 1)

	for x in range(size.x):
		for y in range(size.y):
			var c := cell + Vector2i(x, y)
			occupied[c] = node
			if building_id == "strasse":
				roads[c] = true

	## Angrenzende Straßen müssen ihre "Arme" neu zeichnen,
	## damit das Straßenband nahtlos zusammenwächst.
	if building_id == "strasse":
		_redraw_adjacent_roads(cell)


## Zeichnet alle Straßen rund um eine Zelle neu (für nahtlose Übergänge).
func _redraw_adjacent_roads(cell: Vector2i) -> void:
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = cell + offset
		if roads.has(n) and occupied.has(n):
			occupied[n].queue_redraw()


## Eine Baustelle ist fertig geworden: Sprite auf das echte Gebäude umschalten.
func _on_building_completed(cell: Vector2i) -> void:
	if not occupied.has(cell):
		return
	var node: BuildingNode = occupied[cell]
	node.is_under_construction = false
	node.queue_redraw()


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
	var was_road := node.building_id == "strasse"
	for x in range(node.size.x):
		for y in range(node.size.y):
			var c: Vector2i = node.cell + Vector2i(x, y)
			occupied.erase(c)
			roads.erase(c)
			if was_road:
				_redraw_adjacent_roads(c)
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
	_clear_hover()
	for node in get_children():
		if node is BuildingNode:
			node.queue_free()
	occupied.clear()
	roads.clear()
	for b in GameState.buildings:
		## Noch nicht fertige Gebäude als Baustelle wiederherstellen.
		_spawn_building_visual(b["id"], b["cell"], b.get("bau_tage_uebrig", 0) > 0)
	queue_redraw()


# ---------------------------------------------------------------------------
# STRASSEN-PFADFINDUNG (für Dorfbewohner / Lieferungen)
# ---------------------------------------------------------------------------

const _ROAD_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]


## Straßenzellen direkt neben einer Gebäude-Grundfläche.
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


## Kürzester Weg nur über Straßen (BFS). Leeres Array = kein Weg.
func find_path_on_roads(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	if not roads.has(start) or not roads.has(goal):
		return []
	if start == goal:
		return [start]

	var queue: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: start}
	var head := 0

	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for offset in _ROAD_OFFSETS:
			var next: Vector2i = current + offset
			if not roads.has(next) or came_from.has(next):
				continue
			came_from[next] = current
			if next == goal:
				return _reconstruct_road_path(came_from, start, goal)
			queue.append(next)

	return []


func _reconstruct_road_path(came_from: Dictionary, start: Vector2i,
		goal: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current: Vector2i = goal
	while true:
		path.push_front(current)
		if current == start:
			break
		current = came_from[current]
	return path


## Bester Straßenweg zwischen zwei Gebäuden (kürzeste Route über angrenzende Straßen).
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
