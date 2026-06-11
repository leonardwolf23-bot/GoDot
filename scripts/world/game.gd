extends Node2D
## Game (Wurzel der Spiel-Szene)
## =============================
## Verbindet beim Start die Welt mit dem Spielstand:
##   - Neues Spiel  -> Rathaus + Startstraße in die Kartenmitte setzen
##   - Geladenes Spiel -> alle Gebäude aus dem Spielstand wieder aufbauen
## Außerdem wird die Kamera auf das Rathaus zentriert.

@onready var grid: CityGrid = $CityGrid
@onready var camera: Camera2D = $Camera
@onready var hud: HUD = $UI/HUD


func _ready() -> void:
	## Futuristisches Hintergrundbild hinter der ganzen Welt
	## (statt der schwarzen Leere am Bildschirmrand).
	_create_background()

	## Dem HUD sagen, mit welchem Grid es zusammenarbeitet
	## (das Baumenü muss dem Grid Bau-Befehle geben können).
	hud.setup(grid)

	if GameState.buildings.is_empty():
		## Frisches Spiel: Startgebäude platzieren.
		grid.place_starting_buildings()
	else:
		## Geladenes Spiel: Welt aus den Daten wieder aufbauen.
		grid.rebuild_from_state()

	## Kamera auf die Kartenmitte (Rathaus) setzen.
	camera.position = grid.cell_to_world(grid.get_center_cell())
	## Simulation läuft ab jetzt.
	GameState.set_speed(1.0)


## Erzeugt eine Hintergrund-Ebene mit dem Skyline-Bild. Sie liegt auf einem
## CanvasLayer mit negativer Nummer und wird daher HINTER der Welt gezeichnet.
## CanvasLayer bewegen sich nicht mit der Kamera - das Bild bleibt also wie
## ein Himmel im Hintergrund stehen, egal wohin man scrollt.
func _create_background() -> void:
	var path := "res://assets/backgrounds/horizon.jpg"
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			texture = ImageTexture.create_from_image(img)
	if texture == null:
		return  ## Kein Bild vorhanden -> einfach die Hintergrundfarbe behalten.

	var layer := CanvasLayer.new()
	layer.layer = -10  ## Hinter allem anderen.
	add_child(layer)

	var rect := TextureRect.new()
	rect.texture = texture
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	## Bild bildschirmfüllend skalieren, Seitenverhältnis beibehalten.
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
