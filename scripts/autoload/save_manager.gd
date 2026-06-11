extends Node
## SaveManager (Autoload / Singleton)
## ===================================
## Speichert und lädt den Spielstand als JSON-Datei.
##
## "user://" ist ein spezieller Godot-Pfad, der auf jedem Betriebssystem
## automatisch im richtigen Benutzerordner landet:
##   - Windows: %APPDATA%\Godot\app_userdata\Vegane Stadt 2040\
##   - Linux:   ~/.local/share/godot/app_userdata/Vegane Stadt 2040/
##
## Wichtig: NIE in "res://" speichern - das ist im fertigen Spiel
## schreibgeschützt!

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 1

signal game_saved
signal game_loaded


## Gibt es überhaupt einen Spielstand?
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Speichert den aktuellen Spielstand. Gibt true bei Erfolg zurück.
func save_game() -> bool:
	var data := GameState.to_save_dict()
	data["save_version"] = SAVE_VERSION

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		## Falls etwas schiefgeht (z.B. kein Speicherplatz), nicht abstürzen,
		## sondern den Fehler sauber melden.
		push_error("Speichern fehlgeschlagen: %s" % FileAccess.get_open_error())
		return false

	## JSON.stringify mit "\t" erzeugt eine schön lesbare Datei -
	## praktisch zum Debuggen.
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	game_saved.emit()
	GameState.notification.emit("Spiel gespeichert.")
	return true


## Lädt den Spielstand. Gibt true bei Erfolg zurück.
func load_game() -> bool:
	if not has_save():
		push_warning("Kein Spielstand vorhanden.")
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Laden fehlgeschlagen: %s" % FileAccess.get_open_error())
		return false

	var text := file.get_as_text()
	file.close()

	## JSON kann kaputt sein (z.B. abgebrochener Speichervorgang) -
	## deshalb prüfen wir das Ergebnis, bevor wir es benutzen.
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		push_error("Spielstand-Datei ist beschädigt.")
		return false

	GameState.from_save_dict(parsed)
	ResearchManager.invalidate_cache()
	game_loaded.emit()
	return true


## Löscht den Spielstand (z.B. für "Neues Spiel" Bestätigung).
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
