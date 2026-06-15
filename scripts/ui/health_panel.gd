class_name HealthPanel
extends PanelContainer
## HealthPanel (UI)
## ================
## Zeigt alle Gesundheits- und Wohlstandswerte der Bevölkerung:
##   Proteinversorgung, Vitamin B12, Vitamin D, mentale Gesundheit (als
##   Fortschrittsbalken 0-100) und den Durchschnitts-BMI als Zahl.
##
## Aktualisiert sich automatisch über das health_changed-Signal.

var _bars := {}          ## Wertname -> ProgressBar
var _bmi_label: Label
var _hint_label: Label


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(460, 0)

	var vbox := VBoxContainer.new()
	add_child(vbox)

	var title := Label.new()
	title.text = "Gesundheit der Bevölkerung"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	_add_bar(vbox, "protein", "Proteinversorgung")
	_add_bar(vbox, "b12", "Vitamin B12")
	_add_bar(vbox, "vitamin_d", "Vitamin D")
	_add_bar(vbox, "mental", "Mentale Gesundheit")

	_bmi_label = Label.new()
	_bmi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bmi_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_bmi_label)

	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	vbox.add_child(_hint_label)

	var close := Button.new()
	close.text = "Schließen"
	close.pressed.connect(func(): visible = false)
	vbox.add_child(close)

	GameState.health_changed.connect(_refresh)
	_refresh()


func _add_bar(parent: VBoxContainer, key: String, label_text: String) -> void:
	var label := Label.new()
	label.text = label_text
	parent.add_child(label)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.custom_minimum_size = Vector2(420, 24)
	parent.add_child(bar)
	_bars[key] = bar


func _refresh() -> void:
	_bars["protein"].value = GameState.protein
	_bars["b12"].value = GameState.b12
	_bars["vitamin_d"].value = GameState.vitamin_d
	_bars["mental"].value = GameState.mental

	## Balken einfärben: grün = gut, gelb = mittel, rot = kritisch.
	for key in _bars:
		var bar: ProgressBar = _bars[key]
		var style := StyleBoxFlat.new()
		if bar.value >= 70.0:
			style.bg_color = Color(0.3, 0.75, 0.4)
		elif bar.value >= 50.0:
			style.bg_color = Color(0.85, 0.75, 0.3)
		else:
			style.bg_color = Color(0.85, 0.3, 0.3)
		bar.add_theme_stylebox_override("fill", style)

	var bmi := GameState.bmi
	var bmi_rating := "gesund"
	if bmi > 28.0:
		bmi_rating = "stark erhöht!"
	elif bmi > 25.0:
		bmi_rating = "erhöht"
	elif bmi < 18.5:
		bmi_rating = "zu niedrig!"
	_bmi_label.text = "Durchschnitts-BMI: %.1f (%s)" % [bmi, bmi_rating]

	## Hilfreiche Hinweise je nach Schwachstelle.
	var hints: Array[String] = []
	if GameState.protein < 60.0:
		hints.append("Tipp: Protein-Labore und Farmen verbessern die Proteinversorgung.")
	if GameState.b12 < 60.0:
		hints.append("Tipp: Erforsche B12-Optimierung und baue B12-Kliniken.")
	if GameState.vitamin_d < 60.0:
		hints.append("Tipp: Parks und Sonnen-Therapiezentren liefern Vitamin D.")
	if GameState.mental < 60.0:
		hints.append("Tipp: Parks, Kultur und Food Courts heben die Stimmung.")
	if bmi > 26.0:
		hints.append("Tipp: Fitnessstudios und BMI-Forschung senken den BMI.")
	_hint_label.text = "\n".join(hints)
