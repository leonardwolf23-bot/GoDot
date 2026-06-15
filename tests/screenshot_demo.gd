extends Node2D
## Entwicklungs-Werkzeug: baut eine Demo-Stadt auf und speichert einen
## Screenshot nach user://screenshot_demo.png. Headless mit Xvfb ausführbar:
##   xvfb-run godot --path . res://tests/screenshot_demo.tscn

func _ready() -> void:
	GameState.new_game("vegan_gains")
	GameState.set_speed(0.0)

	## Hintergrundbild wie in der echten Spiel-Szene.
	var bg_path := "res://assets/backgrounds/horizon.jpg"
	if ResourceLoader.exists(bg_path) or FileAccess.file_exists(bg_path):
		var layer := CanvasLayer.new()
		layer.layer = -10
		add_child(layer)
		var rect := TextureRect.new()
		var tex: Texture2D
		if ResourceLoader.exists(bg_path):
			tex = load(bg_path)
		else:
			tex = ImageTexture.create_from_image(
					Image.load_from_file(ProjectSettings.globalize_path(bg_path)))
		rect.texture = tex
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		layer.add_child(rect)

	var grid := CityGrid.new()
	add_child(grid)
	## Karte künstlich vergrößern für die Demo.
	GameState.claimed_regions = ["berlin", "brandenburg", "mecklenburg", "sachsen"]
	grid.place_starting_buildings()

	var center: Vector2i = grid.get_center_cell()

	## Straßennetz: drei Querstraßen, zwei Längsstraßen.
	## (Als Start-Layout direkt platziert, ohne die Netz-Anschlussregel.)
	for x in range(-6, 8):
		_demo_place_road(grid, center + Vector2i(x, 2))
		_demo_place_road(grid, center + Vector2i(x, 5))
		_demo_place_road(grid, center + Vector2i(x, -2))
	for y in range(-2, 6):
		_demo_place_road(grid, center + Vector2i(-6, y))
		_demo_place_road(grid, center + Vector2i(7, y))

	## Gebäude-Vielfalt entlang der Straßen.
	var row_a := ["wohnmodul", "oeko_turm", "veganer_markt", "gemeinschaftsgarten",
			"fitnessstudio", "b12_klinik", "park"]
	for i in range(row_a.size()):
		_demo_place(grid, row_a[i], center + Vector2i(-5 + i, 3))

	var row_b := ["hydro_farm", "indoor_farm", "protein_labor", "kaese_manufaktur",
			"fleischersatz_fabrik", "food_court", "kulturzentrum",
			"soja_farm", "spirulina_farm"]
	for i in range(row_b.size()):
		_demo_place(grid, row_b[i], center + Vector2i(-5 + i, 6))

	var row_c := ["forschungslabor", "gesundheitszentrum", "sonnen_therapiezentrum",
			"handelszentrum", "bildungszentrum", "solaranlage", "wasserwerk",
			"regenwassersammler"]
	for i in range(row_c.size()):
		_demo_place(grid, row_c[i], center + Vector2i(-5 + i, -3) + Vector2i(0, -1) * 0)

	## Die großen 2x2-Gebäude.
	_demo_place(grid, "universitaet", center + Vector2i(4, 3))
	_demo_place(grid, "arkologie", center + Vector2i(-5, 0))
	_demo_place(grid, "einkaufshalle", center + Vector2i(-2, 0))
	_demo_place(grid, "auto_farm", center + Vector2i(1, 0))
	_demo_place(grid, "atomkraftwerk", center + Vector2i(4, 0))

	## Eine Baustelle zeigen (Gebäude im Bau, 1 Tag Bauzeit).
	GameState.register_starting_building("oeko_turm", center + Vector2i(3, 6))
	GameState.buildings[-1]["bau_tage_uebrig"] = 1
	grid._spawn_building_visual("oeko_turm", center + Vector2i(3, 6), true)

	var cam := Camera2D.new()
	add_child(cam)
	cam.position = grid.cell_to_world(center + Vector2i(0, 2))
	cam.zoom = Vector2(1.5, 1.5)
	cam.make_current()

	## Ein paar Frames rendern lassen, dann Screenshot speichern.
	for i in range(5):
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://screenshot_demo.png")
	print("Screenshot gespeichert: ", ProjectSettings.globalize_path("user://screenshot_demo.png"))
	get_tree().quit(0)


## Platziert ohne Kosten (reine Demo).
func _demo_place(grid: CityGrid, id: String, cell: Vector2i) -> void:
	if not grid.is_placement_valid(id, cell):
		return
	GameState.register_starting_building(id, cell)
	grid._spawn_building_visual(id, cell)


## Straßen fürs Demo-Layout: nur Überlappung prüfen, Netzregel überspringen.
func _demo_place_road(grid: CityGrid, cell: Vector2i) -> void:
	if grid.occupied.has(cell) or not grid.is_in_bounds(cell):
		return
	GameState.register_starting_building("strasse", cell)
	grid._spawn_building_visual("strasse", cell)
