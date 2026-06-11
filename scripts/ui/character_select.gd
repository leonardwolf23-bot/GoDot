extends Control
## CharacterSelect (UI)
## ====================
## Die Charakterauswahl vor Spielbeginn. Zeigt für jeden Landeschef
## eine Karte mit Name, Beschreibung, Boni und Nachteilen.
## Ein Klick auf "Wählen" startet das neue Spiel mit diesem Charakter.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.11, 0.14)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Wähle deinen Landeschef"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.45, 0.95, 0.6))
	vbox.add_child(title)

	## Die Karten nebeneinander.
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 24)
	vbox.add_child(cards)

	for character_id in GameData.CHARACTERS:
		cards.add_child(_make_character_card(character_id))

	var back := Button.new()
	back.text = "Zurück"
	back.custom_minimum_size = Vector2(200, 44)
	back.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	vbox.add_child(back)


func _make_character_card(character_id: String) -> Control:
	var data := GameData.get_character(character_id)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(360, 420)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	card.add_child(inner)

	var name_label := Label.new()
	name_label.text = data["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 22)
	inner.add_child(name_label)

	var desc := Label.new()
	desc.text = data["beschreibung"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	inner.add_child(desc)

	var boni_header := Label.new()
	boni_header.text = "Boni:"
	boni_header.add_theme_color_override("font_color", Color(0.5, 0.9, 0.55))
	inner.add_child(boni_header)

	for bonus in data["boni"]:
		var line := Label.new()
		line.text = "+ %s" % bonus
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 13)
		inner.add_child(line)

	var malus_header := Label.new()
	malus_header.text = "Nachteile:"
	malus_header.add_theme_color_override("font_color", Color(0.95, 0.5, 0.45))
	inner.add_child(malus_header)

	for malus in data["nachteile"]:
		var line := Label.new()
		line.text = "- %s" % malus
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 13)
		inner.add_child(line)

	## Abstandshalter drückt den Wählen-Button nach unten.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(spacer)

	var choose := Button.new()
	choose.text = "Wählen"
	choose.custom_minimum_size = Vector2(0, 44)
	choose.pressed.connect(_on_character_chosen.bind(character_id))
	inner.add_child(choose)

	return card


func _on_character_chosen(character_id: String) -> void:
	## Hier startet das eigentliche Spiel: GameState zurücksetzen und los.
	GameState.new_game(character_id)
	get_tree().change_scene_to_file("res://scenes/game.tscn")
