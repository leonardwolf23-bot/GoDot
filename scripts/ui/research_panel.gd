class_name ResearchPanel
extends PanelContainer
## ResearchPanel (UI)
## ==================
## Das Forschungsfenster. Zeigt alle Forschungen nach Kategorien sortiert.
## Jede Forschung ist ein Button:
##   - grün/normal  = kann erforscht werden
##   - ausgegraut   = zu teuer oder Voraussetzung fehlt
##   - "Erforscht"  = bereits abgeschlossen
##
## Das Panel ist standardmäßig unsichtbar und wird vom HUD ein-/ausgeblendet.

var _list: VBoxContainer


func _ready() -> void:
	visible = false
	## Mittig auf dem Bildschirm, feste Größe.
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(640, 600)

	var vbox := VBoxContainer.new()
	add_child(vbox)

	var title := Label.new()
	title.text = "Forschung"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(620, 500)
	vbox.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var close := Button.new()
	close.text = "Schließen"
	close.pressed.connect(func(): visible = false)
	vbox.add_child(close)

	_refresh()
	GameState.resources_changed.connect(_refresh)
	ResearchManager.research_completed.connect(func(_id): _refresh())
	## Täglich aktualisieren, damit der "noch X Tage"-Countdown stimmt.
	GameState.day_passed.connect(_refresh)


## Baut die komplette Forschungsliste neu auf.
## Bei der überschaubaren Anzahl an Forschungen ist das völlig schnell genug.
func _refresh() -> void:
	if not visible:
		return  ## Unsichtbare Panels nicht unnötig aktualisieren.
	_rebuild_list()


## Beim Öffnen einmal aktualisieren.
func open() -> void:
	visible = true
	_rebuild_list()


func _rebuild_list() -> void:
	for child in _list.get_children():
		child.queue_free()

	for category in GameData.RESEARCH_CATEGORIES:
		var header := Label.new()
		header.text = category["name"]
		header.add_theme_font_size_override("font_size", 18)
		header.add_theme_color_override("font_color", Color(0.6, 0.9, 0.7))
		_list.add_child(header)

		for research_id in GameData.get_research_in_category(category["id"]):
			_list.add_child(_make_research_row(research_id))


func _make_research_row(research_id: String) -> Control:
	var data := GameData.get_research(research_id)
	var row := HBoxContainer.new()

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = data["name"]
	info.add_child(name_label)

	var desc := Label.new()
	desc.text = data["beschreibung"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	info.add_child(desc)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(190, 0)

	if ResearchManager.is_completed(research_id):
		btn.text = "Erforscht ✓"
		btn.disabled = true
	elif GameState.active_research == research_id:
		## Diese Forschung läuft gerade - Countdown anzeigen.
		btn.text = "Läuft... noch %d Tag(e)" % GameState.research_days_left
		btn.disabled = true
		btn.modulate = Color(0.6, 0.9, 1.0)
	else:
		## Kosten UND Dauer anzeigen, damit man planen kann.
		var duration := GameData.get_research_duration(research_id)
		var duration_text := "sofort" if duration <= 0 else "%d Tag(e)" % duration
		btn.text = "%d TP / %s" % [data["kosten"], duration_text]

		var requirement: String = data["voraussetzung"]
		if requirement != "" and not ResearchManager.is_completed(requirement):
			btn.text = "Benötigt: %s" % GameData.get_research(requirement)["name"]
			btn.disabled = true
		elif GameState.active_research != "":
			btn.disabled = true  ## Es läuft schon eine andere Forschung.
			btn.tooltip_text = "Es kann nur eine Forschung gleichzeitig laufen."
		elif not ResearchManager.can_research(research_id):
			btn.disabled = true  ## Zu wenig Technikpunkte.
		btn.pressed.connect(func():
			ResearchManager.do_research(research_id))

	row.add_child(btn)
	return row
