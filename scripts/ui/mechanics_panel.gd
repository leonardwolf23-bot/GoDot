class_name MechanicsPanel
extends Control
## Kurze Spielmechanik-Hilfe im unteren HUD (Game Mechanics).

func _ready() -> void:
	set_meta("panel_id", "mechanics")
	visible = false
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.88))
	label.text = """• Linksklick: Gebäude platzieren / Felder malen
• Rechtsklick: Bau- oder Abrissmodus abbrechen
• Straßen verbinden fast alle Gebäude mit dem Netz
• Lagerhaus: Überschuss wird von Bürgern eingelagert
• Holzfäller +20 Holz/Tag, Steinmetz +20 Steine/Tag
• 1 Tag = 10 Sekunden bei Geschwindigkeit 1x
• Veganer Anteil unter 50 % = Niederlage"""
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(label)
