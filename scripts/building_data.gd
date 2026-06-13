extends Node
## Statische Gebäude-Definitionen für den Minimal-Prototyp.

const BUILDINGS := {
	"haus_1x1": {
		"name": "Haus 1×1",
		"size": Vector2i(1, 1),
	},
	"haus_2x2": {
		"name": "Haus 2×2",
		"size": Vector2i(2, 2),
	},
	"haus_3x3": {
		"name": "Haus 3×3",
		"size": Vector2i(3, 3),
	},
}


func get_building(id: String) -> Dictionary:
	return BUILDINGS.get(id, {})


func get_all_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in BUILDINGS:
		ids.append(key)
	return ids
