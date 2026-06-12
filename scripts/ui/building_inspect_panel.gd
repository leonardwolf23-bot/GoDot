class_name BuildingInspectPanel
extends PanelContainer
## Klick auf Farm-Gebäude: Kultur per Dropdown wählen.

var _grid: CityGrid = null
var _target_cell: Vector2i = Vector2i(-1, -1)
var _title: Label
var _crop_select: OptionButton


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -160
	offset_right = 160
	offset_top = -80
	offset_bottom = 80

	var vbox := VBoxContainer.new()
	add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)

	_crop_select = OptionButton.new()
	vbox.add_child(_crop_select)

	var close_btn := Button.new()
	close_btn.text = "Schließen"
	close_btn.pressed.connect(hide)
	vbox.add_child(close_btn)

	_crop_select.item_selected.connect(_on_crop_selected)


func setup(grid: CityGrid) -> void:
	_grid = grid


func open_for_building(building_id: String, cell: Vector2i) -> void:
	var data: Dictionary = GameData.get_building(building_id)
	if not data.get("ist_farm", false):
		return

	_target_cell = cell
	_title.text = data["name"]
	_crop_select.clear()
	var crops: Array = data.get("farm_kulturen", [])
	for i in range(crops.size()):
		_crop_select.add_item(str(crops[i]), i)

	var b := GameState.get_building_at_cell(cell)
	if b.has("farm_crops") and not b["farm_crops"].is_empty():
		var current: String = b["farm_crops"][0]
		var idx := crops.find(current)
		if idx >= 0:
			_crop_select.select(idx)

	visible = true


func _on_crop_selected(index: int) -> void:
	if _target_cell == Vector2i(-1, -1):
		return
	var crop: String = _crop_select.get_item_text(index)
	GameState.set_farm_crop(_target_cell, crop)
