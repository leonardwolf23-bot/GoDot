extends Control
## MainMenu (UI)
## =============
## Das Hauptmenü - die erste Szene des Spiels.
##   - Neues Spiel  -> Charakterauswahl
##   - Spiel laden  -> Spielstand laden und direkt ins Spiel
##   - Beenden      -> Spiel schließen
##
## Das Menü wird per Code aufgebaut, damit keine Editor-Schritte nötig sind.


func _ready() -> void:
	## Falls man aus einem laufenden Spiel zurückkommt: Simulation anhalten.
	GameState.set_speed(0.0)

	set_anchors_preset(Control.PRESET_FULL_RECT)

	## Hintergrund.
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.11, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "VEGANE STADT 2040"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(0.45, 0.95, 0.6))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Baue die vegane Hauptstadt der Zukunft und nimm ganz Deutschland ein."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.8, 0.75))
	vbox.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	_add_button(vbox, "Neues Spiel", _on_new_game)

	var load_button := _add_button(vbox, "Spiel laden", _on_load_game)
	## Laden nur anbieten, wenn es überhaupt einen Spielstand gibt.
	load_button.disabled = not SaveManager.has_save()

	_add_button(vbox, "Beenden", func(): get_tree().quit())


func _add_button(parent: VBoxContainer, text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(320, 52)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


func _on_new_game() -> void:
	get_tree().change_scene_to_file("res://scenes/character_select.tscn")


func _on_load_game() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/game.tscn")
