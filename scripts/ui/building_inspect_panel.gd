class_name BuildingInspectPanel
extends PanelContainer
## Klick auf Farm: separate Felder pro Kultur markieren (Weizen, Hafer, …).

var _grid: CityGrid = null
var _target_cell: Vector2i = Vector2i(-1, -1)
var _title: Label
var _stats: Label
var _crop_grid: GridContainer


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER_LEFT)
	offset_left = 12
	offset_right = 320
	offset_top = 120
	offset_bottom = 420

	var vbox := VBoxContainer.new()
	add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_title)

	var hint := Label.new()
	hint.text = "Kultur wählen, dann Felder auf der Karte malen.\nNochmal klicken = Feld entfernen."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	vbox.add_child(hint)

	_stats = Label.new()
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_stats)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 180)
	vbox.add_child(scroll)

	_crop_grid = GridContainer.new()
	_crop_grid.columns = 2
	scroll.add_child(_crop_grid)

	var clear_btn := Button.new()
	clear_btn.text = "Alle Felder leeren"
	clear_btn.pressed.connect(_on_clear_pressed)
	vbox.add_child(clear_btn)

	var close_btn := Button.new()
	close_btn.text = "Schließen"
	close_btn.pressed.connect(hide)
	vbox.add_child(close_btn)


func setup(grid: CityGrid) -> void:
	_grid = grid
	if not GameState.farm_fields_changed.is_connected(_on_fields_changed):
		GameState.farm_fields_changed.connect(_on_fields_changed)


func _on_fields_changed(farm_cell: Vector2i) -> void:
	if visible and farm_cell == _target_cell:
		_refresh_stats()


func open_for_building(building_id: String, cell: Vector2i) -> void:
	var data: Dictionary = GameData.get_building(building_id)
	if not data.get("ist_farm", false):
		return

	_target_cell = cell
	_title.text = data["name"]
	_rebuild_crop_buttons(data.get("farm_kulturen", []))
	_refresh_stats()
	visible = true


func _rebuild_crop_buttons(crops: Array) -> void:
	for child in _crop_grid.get_children():
		child.queue_free()

	for crop_id in crops:
		var crop: String = str(crop_id)
		var btn := Button.new()
		btn.text = "%s malen" % GameData.get_crop_name(crop)
		btn.custom_minimum_size = Vector2(140, 36)
		var col: Color = GameData.get_crop_color(crop)
		btn.modulate = Color(col.r * 1.1 + 0.15, col.g * 1.1 + 0.15, col.b * 1.1 + 0.15)
		btn.pressed.connect(_on_crop_paint_pressed.bind(crop))
		_crop_grid.add_child(btn)


func _refresh_stats() -> void:
	var counts: Dictionary = GameState.get_farm_field_counts(_target_cell)
	if counts.is_empty():
		_stats.text = "Felder: noch keine markiert (max. %d)" % GameData.FARM_MAX_FIELDS
		return
	var lines: PackedStringArray = PackedStringArray(["Felder pro Kultur:"])
	var total := 0
	for crop in counts:
		lines.append("  %s: %d" % [GameData.get_crop_name(str(crop)), int(counts[crop])])
		total += int(counts[crop])
	lines.append("Gesamt: %d / %d" % [total, GameData.FARM_MAX_FIELDS])
	var farm := GameState.get_farm_building(_target_cell)
	if not farm.is_empty() and farm.has("pending_delivery"):
		var pending: Array[String] = []
		for res_name in farm["pending_delivery"]:
			var amt: float = farm["pending_delivery"][res_name]
			if amt > 0.05:
				pending.append("  %s: %.1f (wartet auf Abholung)" % [
					GameData.get_resource_label(str(res_name)), amt])
		if not pending.is_empty():
			lines.append("Ausstehende Lieferung:")
			lines.append_array(pending)
	_stats.text = "\n".join(lines)


func _on_crop_paint_pressed(crop_id: String) -> void:
	if _grid == null or _target_cell == Vector2i(-1, -1):
		return
	_grid.start_farm_paint_mode(_target_cell, crop_id)
	GameState.notification.emit("%s-Felder malen: Karte anklicken"
			% GameData.get_crop_name(crop_id))
	visible = false


func _on_clear_pressed() -> void:
	GameState.clear_farm_fields(_target_cell)
	_refresh_stats()
	if _grid != null:
		_grid.queue_redraw()
