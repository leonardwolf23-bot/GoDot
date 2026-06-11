class_name HUD
extends Control
## HUD (UI)
## ========
## Die Haupt-Benutzeroberfläche im Spiel. Sie wird komplett per Code
## aufgebaut (kein Gefummel im Editor nötig) und besteht aus:
##
##   - Obere Leiste: Ressourcen, Bevölkerung, veganer Anteil, Energie,
##     Datum und Geschwindigkeits-Buttons
##   - Rechte Leiste: Buttons für Forschung, Gesundheit, Deutschland,
##     Speichern und Hauptmenü
##   - Unten: das Baumenü (BuildMenu)
##   - Mitte: Panels (Forschung, Gesundheit, Regionen) und Meldungen
##   - Overlay: Sieg/Niederlage-Bildschirm
##
## Das HUD LIEST nur Werte aus GameState und reagiert auf dessen Signale.
## Es enthält selbst keinerlei Spiellogik.

var grid: CityGrid = null

## Labels der oberen Leiste.
var _labels := {}
var _speed_buttons: Array[Button] = []

## Panels.
var _build_menu: BuildMenu
var _research_panel: ResearchPanel
var _health_panel: HealthPanel
var _region_panel: RegionPanel

## Meldungs-Anzeige.
var _notification_label: Label
var _notification_timer: float = 0.0

## Krisen-Warnung (veganer Anteil unter 80 %).
var _crisis_label: Label

## Schwebender Info-Tooltip für Gebäude unter der Maus.
var _hover_panel: PanelContainer
var _hover_label: Label


## Wird von game.gd aufgerufen, BEVOR das HUD benutzt wird.
func setup(p_grid: CityGrid) -> void:
	grid = p_grid
	_build_menu.grid = grid
	grid.building_hovered.connect(_on_building_hovered)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	## Das HUD selbst soll Mausklicks NICHT blockieren -
	## nur seine sichtbaren Kinder (Buttons, Panels) tun das.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_create_top_bar()
	_create_side_buttons()
	_create_notification_label()
	_create_crisis_label()
	_create_hover_panel()

	_build_menu = BuildMenu.new()
	add_child(_build_menu)

	_research_panel = ResearchPanel.new()
	add_child(_research_panel)
	_health_panel = HealthPanel.new()
	add_child(_health_panel)
	_region_panel = RegionPanel.new()
	add_child(_region_panel)

	var game_over_screen := GameOverScreen.new()
	add_child(game_over_screen)

	## Signale verbinden: Die UI hält sich selbst aktuell.
	GameState.resources_changed.connect(_refresh_top_bar)
	GameState.population_changed.connect(_refresh_top_bar)
	GameState.day_passed.connect(_refresh_top_bar)
	GameState.vegan_share_changed.connect(func(_v): _refresh_top_bar())
	GameState.speed_changed.connect(func(_s): _refresh_speed_buttons())
	GameState.notification.connect(_show_notification)
	_refresh_top_bar()
	_refresh_speed_buttons()


# ---------------------------------------------------------------------------
# OBERE LEISTE
# ---------------------------------------------------------------------------

func _create_top_bar() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	add_child(panel)

	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 18)
	panel.add_child(bar)

	## Reihenfolge der Anzeigen in der Leiste.
	var entries := [
		["wasser", "Wasser"],
		["essen", "Essen"],
		["satoshis", "Satoshis"],
		["technikpunkte", "Technik"],
		["bevoelkerung", "Bevölkerung"],
		["energie", "Energie"],
		["vegan", "Vegan"],
		["datum", "Datum"],
	]
	for entry in entries:
		## Kleines Icon vor dem Wert (falls eine Icon-Datei existiert).
		var icon := _load_icon(entry[0])
		if icon != null:
			var icon_rect := TextureRect.new()
			icon_rect.texture = icon
			icon_rect.custom_minimum_size = Vector2(22, 22)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			bar.add_child(icon_rect)

		var label := Label.new()
		label.add_theme_font_size_override("font_size", 15)
		bar.add_child(label)
		_labels[entry[0]] = label

	## Geschwindigkeits-Buttons: Pause, 1x, 2x, 3x.
	var speeds := [["⏸", 0.0], ["1x", 1.0], ["2x", 2.0], ["3x", 3.0]]
	for s in speeds:
		var btn := Button.new()
		btn.text = s[0]
		btn.toggle_mode = true
		btn.pressed.connect(func(): GameState.set_speed(s[1]))
		bar.add_child(btn)
		_speed_buttons.append(btn)


func _refresh_top_bar() -> void:
	var r := GameState.resources
	if r.is_empty():
		return
	## Tages-Bilanz mit anzeigen, z.B. "Essen: 250 (+12)".
	var report := GameState.daily_report
	_labels["wasser"].text = "Wasser: %d (%+.0f)" % [r["wasser"], report["wasser"]]
	_labels["essen"].text = "Essen: %d (%+.0f)" % [r["essen"], report["essen"]]
	_labels["satoshis"].text = "₿ %d (%+.0f)" % [r["satoshis"], report["satoshis"]]
	_labels["technikpunkte"].text = "Technik: %d (%+.0f)" % [
		r["technikpunkte"], report["technikpunkte"]]
	_labels["bevoelkerung"].text = "Bürger: %d / %d" % [
		GameState.population, GameState.get_housing_capacity()]
	_labels["energie"].text = "Strom: %.0f / %.0f" % [
		report["energie_bedarf"], report["energie_leistung"]]
	_labels["datum"].text = GameState.get_date_string()

	## Veganer Anteil: Farbe zeigt den Zustand (grün/gelb/rot).
	var vegan_label: Label = _labels["vegan"]
	vegan_label.text = "Vegan: %.1f %%" % GameState.vegan_share
	if GameState.vegan_share >= GameData.VEGAN_CRISIS_THRESHOLD:
		vegan_label.add_theme_color_override("font_color", Color(0.5, 0.95, 0.55))
	elif GameState.vegan_share >= GameData.VEGAN_LOSE_THRESHOLD:
		vegan_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
	else:
		vegan_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))

	## Strom-Warnung rot einfärben.
	var energy_label: Label = _labels["energie"]
	if report["energie_bedarf"] > report["energie_leistung"]:
		energy_label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.3))
	else:
		energy_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

	_crisis_label.visible = GameState.vegan_share < GameData.VEGAN_CRISIS_THRESHOLD \
			and not GameState.is_game_over


func _refresh_speed_buttons() -> void:
	var speeds := [0.0, 1.0, 2.0, 3.0]
	for i in range(_speed_buttons.size()):
		_speed_buttons[i].button_pressed = is_equal_approx(GameState.game_speed, speeds[i])


# ---------------------------------------------------------------------------
# RECHTE BUTTON-LEISTE
# ---------------------------------------------------------------------------

func _create_side_buttons() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	vbox.position = Vector2(-180, 60)
	vbox.offset_left = -180.0
	vbox.offset_top = 60.0
	vbox.offset_right = -12.0
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	_add_side_button(vbox, "Forschung", func(): _research_panel.open())
	_add_side_button(vbox, "Gesundheit", func():
		_health_panel.visible = not _health_panel.visible)
	_add_side_button(vbox, "Deutschland", func(): _region_panel.open())
	_add_side_button(vbox, "Speichern", func(): SaveManager.save_game())
	_add_side_button(vbox, "Hauptmenü", func():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))


func _add_side_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(160, 38)
	btn.pressed.connect(callback)
	parent.add_child(btn)


# ---------------------------------------------------------------------------
# MELDUNGEN UND WARNUNGEN
# ---------------------------------------------------------------------------

func _create_notification_label() -> void:
	_notification_label = Label.new()
	_notification_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notification_label.position = Vector2(-300, 70)
	_notification_label.custom_minimum_size = Vector2(600, 0)
	_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notification_label.add_theme_font_size_override("font_size", 18)
	_notification_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	_notification_label.visible = false
	add_child(_notification_label)


func _create_crisis_label() -> void:
	_crisis_label = Label.new()
	_crisis_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_crisis_label.position = Vector2(-300, 44)
	_crisis_label.custom_minimum_size = Vector2(600, 0)
	_crisis_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crisis_label.text = "⚠ KRISE: Der vegane Anteil sinkt gefährlich! Unter 50 % ist das Spiel verloren!"
	_crisis_label.add_theme_font_size_override("font_size", 16)
	_crisis_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	_crisis_label.visible = false
	add_child(_crisis_label)


func _show_notification(text: String) -> void:
	_notification_label.text = text
	_notification_label.visible = true
	_notification_timer = 4.0  ## Meldung 4 Sekunden anzeigen.


# ---------------------------------------------------------------------------
# HOVER-TOOLTIP: Gebäude-Infos unter der Maus
# ---------------------------------------------------------------------------

func _create_hover_panel() -> void:
	_hover_panel = PanelContainer.new()
	_hover_panel.visible = false
	## Der Tooltip darf selbst keine Maus-Ereignisse abfangen,
	## sonst "flackert" er, sobald die Maus ihn berührt.
	_hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hover_panel)

	_hover_label = Label.new()
	_hover_label.add_theme_font_size_override("font_size", 14)
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_panel.add_child(_hover_label)


## Reagiert auf das Grid-Signal: Maus über Gebäude rein/raus.
func _on_building_hovered(info: Dictionary) -> void:
	if info.is_empty():
		_hover_panel.visible = false
		return
	_hover_label.text = _make_building_info_text(info["id"], info["cell"])
	_hover_panel.visible = true
	_position_hover_panel()


## Baut den Tooltip-Text: Was macht dieses Gebäude PRO TAG?
func _make_building_info_text(building_id: String, cell: Vector2i) -> String:
	var data: Dictionary = GameData.get_building(building_id)
	var lines: Array[String] = [data["name"]]

	## Bezirks-Bonus wirkt auf Produktion und Effekte.
	var bonus: float = GameState.get_district_bonus_at(cell)
	var mult := 1.0 + bonus

	var res_names := {
		"wasser": "Wasser", "essen": "Essen",
		"satoshis": "Satoshis", "technikpunkte": "Technikpunkte",
	}
	for res_name in data["produktion"]:
		lines.append("+%.1f %s/Tag" % [data["produktion"][res_name] * mult, res_names[res_name]])
	for res_name in data["verbrauch"]:
		lines.append("-%.1f %s/Tag" % [data["verbrauch"][res_name], res_names[res_name]])
	if data["wohnraum"] > 0:
		lines.append("Wohnraum: %d Bürger" % data["wohnraum"])
	if data["energie_bedarf"] > 0:
		lines.append("Strombedarf: %d" % data["energie_bedarf"])
	if data["energie_leistung"] > 0:
		lines.append("Stromleistung: +%d" % data["energie_leistung"])

	var effect_names := {
		"protein": "Protein", "b12": "Vitamin B12", "vitamin_d": "Vitamin D",
		"mental": "Mentale Gesundheit", "bmi": "BMI", "vegan": "Veganer Einfluss",
	}
	for key in data["effekte"]:
		var value: float = data["effekte"][key] * mult
		lines.append("%s%.1f %s" % ["+" if value > 0 else "", value, effect_names[key]])

	if bonus > 0.0:
		lines.append("Bezirks-Bonus: +%d %% (gleiche Nachbarn)" % int(round(bonus * 100)))

	return "\n".join(lines)


## Tooltip neben dem Mauszeiger platzieren (und am Bildschirmrand abfangen).
func _position_hover_panel() -> void:
	var mouse := get_viewport().get_mouse_position()
	var pos := mouse + Vector2(18, 18)
	var screen := get_viewport_rect().size
	pos.x = minf(pos.x, screen.x - _hover_panel.size.x - 8)
	pos.y = minf(pos.y, screen.y - _hover_panel.size.y - 8)
	_hover_panel.position = pos


## Lädt ein UI-Icon aus assets/icons/ (oder gibt null zurück).
func _load_icon(icon_name: String) -> Texture2D:
	var path := "res://assets/icons/%s.png" % icon_name
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			return ImageTexture.create_from_image(img)
	return null


func _process(delta: float) -> void:
	if _notification_timer > 0.0:
		_notification_timer -= delta
		if _notification_timer <= 0.0:
			_notification_label.visible = false
	## Tooltip folgt dem Mauszeiger.
	if _hover_panel.visible:
		_position_hover_panel()
