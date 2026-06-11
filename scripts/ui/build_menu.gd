class_name BuildMenu
extends PanelContainer
## BuildMenu (UI)
## ==============
## Das Baumenü am unteren Bildschirmrand.
##   - Oben: eine Reihe Kategorie-Buttons (Straßen, Wohnen, Essen, ...)
##   - Unten: die Gebäude der gewählten Kategorie + Abriss-Button
##
## Das Menü kennt KEINE Bauregeln - es sagt dem CityGrid nur,
## welches Gebäude der Spieler bauen möchte.

var grid: CityGrid = null   ## Wird vom HUD gesetzt.

## Meldet dem HUD, dass die Maus über einem Gebäude-Button schwebt
## (text = Infotext) bzw. ihn wieder verlassen hat (text = "").
## Das HUD zeigt daraufhin seinen dunklen Info-Kasten an - der bleibt
## sichtbar, solange die Maus auf dem Button liegt.
signal info_hovered(text: String)

var _category_bar: HBoxContainer
var _building_bar: HBoxContainer
var _active_category: String = "strasse"


func _ready() -> void:
	## Layout: das gesamte Menü unten mittig andocken.
	set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	offset_top = -118.0

	var vbox := VBoxContainer.new()
	add_child(vbox)

	_category_bar = HBoxContainer.new()
	_category_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_category_bar)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 64)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_building_bar = HBoxContainer.new()
	_building_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_building_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(_building_bar)

	_build_category_buttons()
	_refresh_building_buttons()

	## Buttons aktualisieren, wenn sich Geld oder Forschung ändert
	## (damit "zu teuer" / "gesperrt" immer stimmt).
	GameState.resources_changed.connect(_refresh_building_buttons)
	GameState.research_completed_state.connect(func(_id): _refresh_building_buttons())


func _build_category_buttons() -> void:
	for category in GameData.BUILD_CATEGORIES:
		var btn := Button.new()
		btn.text = category["name"]
		btn.toggle_mode = false
		## .bind() hängt das Argument an den Funktionsaufruf an -
		## so weiß der Klick-Handler, welche Kategorie gemeint ist.
		btn.pressed.connect(_on_category_pressed.bind(category["id"]))
		_category_bar.add_child(btn)

	## Extra-Button: Abrissmodus.
	var demolish := Button.new()
	demolish.text = "Abriss"
	demolish.modulate = Color(1.0, 0.6, 0.6)
	demolish.pressed.connect(func():
		if grid != null:
			grid.start_demolish_mode())
	_category_bar.add_child(demolish)


func _on_category_pressed(category_id: String) -> void:
	_active_category = category_id
	_refresh_building_buttons()


## Baut die Gebäude-Buttons der aktiven Kategorie neu auf.
func _refresh_building_buttons() -> void:
	if GameState.resources.is_empty():
		return  ## Spiel wurde noch nicht initialisiert.
	## Alte Buttons entfernen (und einen evtl. offenen Info-Kasten schließen).
	info_hovered.emit("")
	for child in _building_bar.get_children():
		child.queue_free()

	for building_id in GameData.get_buildings_in_category(_active_category):
		var data: Dictionary = GameData.get_building(building_id)
		var btn := Button.new()
		var cost: int = GameState.get_building_cost(building_id)
		btn.text = "%s\n%d ₿" % [data["name"], cost]
		btn.custom_minimum_size = Vector2(150, 56)
		## Eigener Info-Kasten statt Godot-Tooltip: erscheint sofort,
		## ist dunkel hinterlegt und bleibt, solange die Maus drauf liegt.
		btn.mouse_entered.connect(func():
			info_hovered.emit(_make_tooltip(building_id)))
		btn.mouse_exited.connect(func():
			info_hovered.emit(""))

		## Gesperrt durch fehlende Forschung?
		var research_id: String = data["forschung_noetig"]
		if research_id != "" and not GameState.completed_research.has(research_id):
			btn.disabled = true
			btn.text = "%s\n[Forschung nötig]" % data["name"]
		elif GameState.resources["satoshis"] < cost:
			btn.disabled = true  ## Zu teuer - ausgegraut, aber sichtbar.

		btn.pressed.connect(_on_building_pressed.bind(building_id))
		_building_bar.add_child(btn)


func _on_building_pressed(building_id: String) -> void:
	if grid != null:
		grid.start_build_mode(building_id)


## Baut einen hilfreichen Tooltip-Text aus den Gebäudedaten zusammen.
func _make_tooltip(building_id: String) -> String:
	var data: Dictionary = GameData.get_building(building_id)
	var lines: Array[String] = [data["beschreibung"]]
	if data["wohnraum"] > 0:
		lines.append("Wohnraum: %d Bürger" % data["wohnraum"])
	for res_name in data["produktion"]:
		lines.append("+%.0f %s/Tag" % [data["produktion"][res_name], res_name.capitalize()])
	for res_name in data["verbrauch"]:
		lines.append("-%.0f %s/Tag" % [data["verbrauch"][res_name], res_name.capitalize()])
	if data["energie_bedarf"] > 0:
		lines.append("Strombedarf: %d" % data["energie_bedarf"])
	if data["energie_leistung"] > 0:
		lines.append("Stromleistung: +%d" % data["energie_leistung"])
	var effect_names := {
		"protein": "Protein", "b12": "Vitamin B12", "vitamin_d": "Vitamin D",
		"mental": "Mentale Gesundheit", "bmi": "BMI", "vegan": "Veganer Einfluss",
	}
	for key in data["effekte"]:
		var value: float = data["effekte"][key]
		lines.append("%s%s %.1f" % ["+" if value > 0 else "", effect_names[key], value])
	if data["braucht_strasse"]:
		lines.append("Muss an einer Straße stehen.")
	return "\n".join(lines)
