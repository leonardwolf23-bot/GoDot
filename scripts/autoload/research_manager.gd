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

## Zwischenspeicher (Cache) für die aufsummierten Effekte.
## Wird nur neu berechnet, wenn sich etwas ändert - das spart Rechenzeit.
var _effects_cache := {}
var _cache_dirty := true


## Ist die Forschung bereits abgeschlossen?
func is_completed(research_id: String) -> bool:
	return GameState.completed_research.has(research_id)


## Kann die Forschung gerade gekauft werden?
## Bedingungen: noch nicht erforscht, Voraussetzung erfüllt, genug Punkte.
func can_research(research_id: String) -> bool:
	var data := GameData.get_research(research_id)
	if data.is_empty() or is_completed(research_id):
		return false
	var requirement: String = data["voraussetzung"]
	if requirement != "" and not is_completed(requirement):
		return false
	return GameState.resources["technikpunkte"] >= data["kosten"]


## Kauft eine Forschung. Gibt true zurück, wenn es geklappt hat.
func do_research(research_id: String) -> bool:
	if not can_research(research_id):
		return false
	var data := GameData.get_research(research_id)
	GameState.resources["technikpunkte"] -= data["kosten"]
	GameState.on_research_completed(research_id)
	_cache_dirty = true
	GameState.resources_changed.emit()
	research_completed.emit(research_id)
	GameState.notification.emit("Forschung abgeschlossen: %s" % data["name"])
	return true


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
