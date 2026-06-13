extends Node2D

@onready var grid: CityGrid = $CityGrid
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	camera.position = grid.map_to_local(grid.get_center_cell())
	grid.build_mode_changed.connect(_on_build_mode_changed)


func _on_build_mode_changed(building_id: String) -> void:
	var hud: Control = $UI/HUD
	if hud.has_method("update_selection"):
		hud.update_selection(building_id)
