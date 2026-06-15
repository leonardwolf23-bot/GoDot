class_name BottomHudBar
extends Control
## Unteres Spiel-HUD mit Grafik und klickbaren Bereichen links.
## In der Mitte werden Build-, Forschungs- und Hilfe-Inhalte eingeblendet.

const TEXTURE_PATH := "res://assets/ui/bottom_hud.png"
const REF_SIZE := Vector2(1000.0, 150.0)

## Anteil der Leiste (0–1), linker Rand bis rechter Inhaltsrand.
const CONTENT_RECT_NORM := Rect2(0.155, 0.07, 0.69, 0.86)

## Navigations-Buttons: y-Position und Höhe als Anteil der Leistenhöhe.
const NAV_BUTTONS := [
	{"id": "research", "label": "Research", "y": 0.07, "h": 0.19},
	{"id": "build", "label": "Build", "y": 0.28, "h": 0.19},
	{"id": "main_menu", "label": "Main Menu", "y": 0.49, "h": 0.19},
	{"id": "mechanics", "label": "Game Mechanics", "y": 0.70, "h": 0.19},
]

signal panel_changed(panel_id: String)

var content_slot: Control = null

var _bar_frame: Control = null
var _background: TextureRect = null
var _nav_layer: Control = null
var _active_panel: String = "build"
var _bar_size: Vector2 = REF_SIZE
var _main_menu_confirm: ConfirmationDialog = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_top = -int(REF_SIZE.y)
	offset_bottom = 0.0

	_bar_frame = Control.new()
	_bar_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bar_frame)

	_background = TextureRect.new()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var tex := _load_texture(TEXTURE_PATH)
	if tex != null:
		_background.texture = tex
		_bar_size = tex.get_size()
	else:
		_bar_size = REF_SIZE
	_bar_frame.add_child(_background)

	_nav_layer = Control.new()
	_nav_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_frame.add_child(_nav_layer)

	content_slot = Control.new()
	content_slot.name = "ContentSlot"
	content_slot.mouse_filter = Control.MOUSE_FILTER_PASS
	_bar_frame.add_child(content_slot)

	for nav in NAV_BUTTONS:
		_create_nav_button(str(nav["id"]), str(nav["label"]), float(nav["y"]), float(nav["h"]))

	_main_menu_confirm = ConfirmationDialog.new()
	_main_menu_confirm.title = "Hauptmenü"
	_main_menu_confirm.dialog_text = "Wirklich zum Hauptmenü zurück?\nUngespeicherter Fortschritt geht verloren."
	_main_menu_confirm.ok_button_text = "Ja, verlassen"
	_main_menu_confirm.cancel_button_text = "Abbrechen"
	_main_menu_confirm.confirmed.connect(_go_to_main_menu)
	add_child(_main_menu_confirm)

	call_deferred("_update_layout")
	get_viewport().size_changed.connect(_update_layout)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_update_layout")


func add_panel(panel_id: String, panel: Control) -> void:
	panel.set_meta("panel_id", panel_id)
	panel.visible = panel_id == _active_panel
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_slot.add_child(panel)


func show_panel(panel_id: String) -> void:
	if panel_id == "main_menu":
		_main_menu_confirm.popup_centered()
		return
	if panel_id == _active_panel and panel_id != "build":
		panel_id = "build"
	_active_panel = panel_id
	for child in content_slot.get_children():
		child.visible = str(child.get_meta("panel_id", "")) == panel_id
	panel_changed.emit(panel_id)


func get_bar_height() -> float:
	if _bar_frame != null and _bar_frame.size.y > 0.0:
		return _bar_frame.size.y
	return _bar_size.y


func _create_nav_button(panel_id: String, label: String, y_norm: float, h_norm: float) -> void:
	var btn := Button.new()
	btn.name = "Nav_%s" % panel_id
	btn.flat = true
	btn.text = ""
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = label
	btn.set_meta("y_norm", y_norm)
	btn.set_meta("h_norm", h_norm)
	btn.pressed.connect(_on_nav_pressed.bind(panel_id))
	_nav_layer.add_child(btn)


func _on_nav_pressed(panel_id: String) -> void:
	if panel_id == _active_panel and panel_id != "main_menu":
		show_panel("build")
		return
	show_panel(panel_id)


func _go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _update_layout() -> void:
	if _bar_frame == null:
		return

	var viewport_w: float = get_viewport_rect().size.x
	var bar_w: float = minf(viewport_w * 0.98, _bar_size.x)
	var bar_h: float = bar_w * _bar_size.y / _bar_size.x

	_bar_frame.position = Vector2((viewport_w - bar_w) * 0.5, 0.0)
	_bar_frame.size = Vector2(bar_w, bar_h)
	_background.position = Vector2.ZERO
	_background.size = _bar_frame.size

	var content := CONTENT_RECT_NORM
	content_slot.position = Vector2(bar_w * content.position.x, bar_h * content.position.y)
	content_slot.size = Vector2(bar_w * content.size.x, bar_h * content.size.y)

	for child in _nav_layer.get_children():
		if not child is Button:
			continue
		var y_n: float = child.get_meta("y_norm")
		var h_n: float = child.get_meta("h_norm")
		child.position = Vector2(bar_w * 0.01, bar_h * y_n)
		child.size = Vector2(bar_w * 0.14, bar_h * h_n)


static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			return ImageTexture.create_from_image(img)
	return null
