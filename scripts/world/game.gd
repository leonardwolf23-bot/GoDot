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
