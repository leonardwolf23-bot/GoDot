extends Node
## ResearchManager (Autoload / Singleton)
## =======================================
## Verwaltet das Forschungssystem:
##   - Welche Forschung ist verfügbar / abgeschlossen?
##   - Forschung kaufen (kostet Technikpunkte)
##   - Alle dauerhaften Forschungs-Boni aufsummieren
##
## Die abgeschlossenen Forschungen selbst liegen in
## GameState.completed_research, damit Speichern/Laden zentral bleibt.

signal research_completed(research_id: String)
signal research_started(research_id: String)

## Zwischenspeicher (Cache) für die aufsummierten Effekte.
## Wird nur neu berechnet, wenn sich etwas ändert - das spart Rechenzeit.
var _effects_cache := {}
var _cache_dirty := true


func _ready() -> void:
	## Jeden Spieltag prüfen, ob die laufende Forschung fertig geworden ist.
	GameState.day_passed.connect(_on_day_passed)


## Ist die Forschung bereits abgeschlossen?
func is_completed(research_id: String) -> bool:
	return GameState.completed_research.has(research_id)


## Läuft gerade eine Forschung (und welche)?
func get_active_research() -> String:
	return GameState.active_research


## Kann die Forschung gerade gestartet werden?
## Bedingungen: noch nicht erforscht, keine andere Forschung läuft,
## Voraussetzung erfüllt, genug Technikpunkte.
func can_research(research_id: String) -> bool:
	var data := GameData.get_research(research_id)
	if data.is_empty() or is_completed(research_id):
		return false
	if GameState.active_research != "":
		return false  ## Es kann immer nur EINE Forschung gleichzeitig laufen.
	var requirement: String = data["voraussetzung"]
	if requirement != "" and not is_completed(requirement):
		return false
	return GameState.resources["technikpunkte"] >= data["kosten"]


## Startet eine Forschung. Die Technikpunkte werden sofort bezahlt.
## Dauer 0 Tage -> sofort fertig, sonst läuft sie im Hintergrund weiter.
## Gibt true zurück, wenn es geklappt hat.
func do_research(research_id: String) -> bool:
	if not can_research(research_id):
		return false
	var data := GameData.get_research(research_id)
	GameState.resources["technikpunkte"] -= data["kosten"]

	var duration := GameData.get_research_duration(research_id)
	if duration <= 0:
		_complete_research(research_id)
	else:
		GameState.active_research = research_id
		GameState.research_days_left = duration
		research_started.emit(research_id)
		GameState.notification.emit("Forschung gestartet: %s (%d Tage)" % [
			data["name"], duration])

	GameState.resources_changed.emit()
	return true


## Wird einmal pro Spieltag aufgerufen: Forschungs-Fortschritt.
func _on_day_passed() -> void:
	if GameState.active_research == "":
		return
	GameState.research_days_left -= 1
	if GameState.research_days_left <= 0:
		var finished := GameState.active_research
		GameState.active_research = ""
		GameState.research_days_left = 0
		_complete_research(finished)


## Schließt eine Forschung endgültig ab (Boni aktiv, Gebäude frei).
func _complete_research(research_id: String) -> void:
	GameState.on_research_completed(research_id)
	_cache_dirty = true
	research_completed.emit(research_id)
	GameState.notification.emit("Forschung abgeschlossen: %s"
			% GameData.get_research(research_id)["name"])


## Summiert die Effekte ALLER abgeschlossenen Forschungen auf.
## Beispiel-Ergebnis: {"protein_bonus": 13.0, "produktions_mult": 0.1}
func get_combined_effects() -> Dictionary:
	if not _cache_dirty:
		return _effects_cache
	_effects_cache = {}
	for research_id in GameState.completed_research:
		var data := GameData.get_research(research_id)
		if data.is_empty():
			continue
		for key in data["effekte"]:
			_effects_cache[key] = _effects_cache.get(key, 0.0) + data["effekte"][key]
	_cache_dirty = false
	return _effects_cache


## Muss nach dem Laden eines Spielstands gerufen werden,
## damit der Cache neu berechnet wird.
func invalidate_cache() -> void:
	_cache_dirty = true
