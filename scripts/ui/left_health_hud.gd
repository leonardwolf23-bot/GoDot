class_name LeftHealthHud
extends Control
## Linkes Gesundheits-HUD (Holzleiste mit Balken für Vegan/Gesundheit etc.).

const TEXTURE_PATH := "res://assets/ui/left_health_hud.png"
const REF_SIZE := Vector2(200.0, 780.0)

## Balken-Positionen relativ zur Referenzgrafik (x, y, w, h als Anteil 0–1).
const BAR_LAYOUT := [
	{"key": "gesund", "rect": Rect2(0.36, 0.175, 0.56, 0.022)},
	{"key": "protein", "rect": Rect2(0.36, 0.252, 0.56, 0.022)},
	{"key": "fette", "rect": Rect2(0.36, 0.329, 0.56, 0.022)},
	{"key": "carbs", "rect": Rect2(0.36, 0.406, 0.56, 0.022)},
	{"key": "b12", "rect": Rect2(0.36, 0.483, 0.56, 0.022)},
	{"key": "vitamin_d", "rect": Rect2(0.36, 0.560, 0.56, 0.022)},
	{"key": "mental", "rect": Rect2(0.36, 0.637, 0.56, 0.022)},
]

var _background: TextureRect = null
var _bars: Dictionary = {}
var _vegan_value: Label = null
var _panel_width: float = REF_SIZE.x


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_LEFT_WIDE)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = int(REF_SIZE.x)
	offset_bottom = 0.0

	_background = TextureRect.new()
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var tex := _load_texture(TEXTURE_PATH)
	if tex != null:
		_background.texture = tex
	add_child(_background)

	_vegan_value = Label.new()
	_vegan_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vegan_value.add_theme_font_size_override("font_size", 14)
	_vegan_value.add_theme_color_override("font_color", Color(0.55, 0.95, 0.5))
	add_child(_vegan_value)

	for entry in BAR_LAYOUT:
		var bar := ProgressBar.new()
		bar.min_value = 0.0
		bar.max_value = 100.0
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bar)
		_bars[str(entry["key"])] = bar

	call_deferred("_update_layout")
	get_viewport().size_changed.connect(func(): call_deferred("_update_layout"))

	GameState.health_changed.connect(_refresh)
	GameState.vegan_share_changed.connect(func(_v): _refresh())
	call_deferred("_refresh")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_update_layout")


func _update_layout() -> void:
	var viewport_h: float = get_viewport_rect().size.y
	var tex_size: Vector2 = REF_SIZE
	if _background.texture != null:
		tex_size = _background.texture.get_size()

	var scale: float = minf(1.0, viewport_h / tex_size.y)
	_panel_width = tex_size.x * scale
	var panel_h: float = tex_size.y * scale

	offset_right = int(_panel_width)
	_background.position = Vector2.ZERO
	_background.size = Vector2(_panel_width, panel_h)

	_vegan_value.position = Vector2(_panel_width * 0.18, panel_h * 0.038)
	_vegan_value.size = Vector2(_panel_width * 0.64, panel_h * 0.05)

	for entry in BAR_LAYOUT:
		var key: String = str(entry["key"])
		if not _bars.has(key):
			continue
		var r: Rect2 = entry["rect"]
		var bar: ProgressBar = _bars[key]
		bar.position = Vector2(_panel_width * r.position.x, panel_h * r.position.y)
		bar.size = Vector2(_panel_width * r.size.x, maxf(8.0, panel_h * r.size.y))


func get_panel_width() -> float:
	return _panel_width


func _refresh() -> void:
	_vegan_value.text = "%.0f %%" % GameState.vegan_share

	var values := {
		"gesund": _average_health(),
		"protein": GameState.protein,
		"fette": _placeholder_fats(),
		"carbs": _placeholder_carbs(),
		"b12": GameState.b12,
		"vitamin_d": GameState.vitamin_d,
		"mental": GameState.mental,
	}
	for key in _bars:
		var bar: ProgressBar = _bars[key]
		var val: float = values.get(key, 80.0)
		bar.value = val
		_tint_bar(bar, val)


func _average_health() -> float:
	return (GameState.protein + GameState.b12 + GameState.vitamin_d + GameState.mental) / 4.0


## Platzhalter bis Fett-/Kohlenhydrat-Simulation existiert.
func _placeholder_fats() -> float:
	return clampf(70.0 + (GameState.bmi - 23.0) * -4.0, 35.0, 95.0)


func _placeholder_carbs() -> float:
	return clampf(65.0 + GameState.daily_report.get("essen", 0.0) * 0.4, 30.0, 100.0)


func _tint_bar(bar: ProgressBar, value: float) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	if value >= 70.0:
		style.bg_color = Color(0.25, 0.72, 0.35)
	elif value >= 50.0:
		style.bg_color = Color(0.82, 0.72, 0.25)
	else:
		style.bg_color = Color(0.82, 0.28, 0.25)
	bar.add_theme_stylebox_override("fill", style)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.05, 0.06)
	bar.add_theme_stylebox_override("background", bg)


static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			return ImageTexture.create_from_image(img)
	return null
