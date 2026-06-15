class_name RegionPanel
extends PanelContainer
## RegionPanel (UI)
## ================
## Das "Deutschland"-Fenster: zeigt alle Bundesländer, welche schon
## eingenommen wurden und was die nächste Region kostet.
## Hier nimmt der Spieler Schritt für Schritt ganz Deutschland ein.

var _list: VBoxContainer
var _claim_button: Button


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(480, 620)

	var vbox := VBoxContainer.new()
	add_child(vbox)

	var title := Label.new()
	title.text = "Deutschland einnehmen"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(460, 460)
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	_claim_button = Button.new()
	_claim_button.custom_minimum_size = Vector2(0, 44)
	_claim_button.pressed.connect(func():
		GameState.claim_next_region()
		_refresh())
	vbox.add_child(_claim_button)

	var close := Button.new()
	close.text = "Schließen"
	close.pressed.connect(func(): visible = false)
	vbox.add_child(close)

	GameState.resources_changed.connect(_refresh_button_only)
	GameState.population_changed.connect(_refresh_button_only)
	_refresh()


func open() -> void:
	visible = true
	_refresh()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()

	for region in GameData.REGIONS:
		var row := Label.new()
		var claimed: bool = GameState.claimed_regions.has(region["id"])
		if claimed:
			row.text = "✓ %s (eingenommen)" % region["name"]
			row.add_theme_color_override("font_color", Color(0.5, 0.9, 0.55))
		else:
			row.text = "✗ %s - %d ₿, mind. %d Bürger" % [
				region["name"], region["kosten"], region["min_bevoelkerung"],
			]
			row.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		_list.add_child(row)

	_refresh_button_only()


func _refresh_button_only() -> void:
	if not visible:
		return
	var next_region := GameState.get_next_region()
	if next_region.is_empty():
		_claim_button.text = "Ganz Deutschland ist eingenommen!"
		_claim_button.disabled = true
	else:
		_claim_button.text = "%s einnehmen (%d ₿, mind. %d Bürger)" % [
			next_region["name"], next_region["kosten"], next_region["min_bevoelkerung"],
		]
		_claim_button.disabled = not GameState.can_claim_next_region()
