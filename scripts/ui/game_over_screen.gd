class_name GameOverScreen
extends ColorRect
## GameOverScreen (UI)
## ===================
## Vollbild-Overlay für Sieg oder Niederlage.
## Wird vom game_over-Signal des GameState ausgelöst.

var _title: Label
var _message: Label


func _ready() -> void:
	visible = false
	## Dunkler Vollbild-Hintergrund.
	color = Color(0.0, 0.0, 0.0, 0.75)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	## Klicks "schlucken", damit man nicht hinter dem Overlay weiterbaut.
	mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(_title)

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_message)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	var menu_button := Button.new()
	menu_button.text = "Zurück zum Hauptmenü"
	menu_button.custom_minimum_size = Vector2(280, 48)
	menu_button.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	vbox.add_child(menu_button)

	GameState.game_over.connect(_on_game_over)


func _on_game_over(victory: bool, reason: String) -> void:
	visible = true
	if victory:
		_title.text = "SIEG!"
		_title.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))
	else:
		_title.text = "NIEDERLAGE"
		_title.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	_message.text = reason
