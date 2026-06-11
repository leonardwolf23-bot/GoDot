extends Node
## GameState (Autoload / Singleton)
## ================================
## Das "Gehirn" des Spiels. Hier lebt die GESAMTE Simulation:
##   - Ressourcen (Wasser, Essen, Satoshis, Technikpunkte)
##   - Tages- und Kalender-Timer
##   - Bevölkerung und Wachstum
##   - Gesundheitswerte (Protein, B12, Vitamin D, BMI, mentale Gesundheit)
##   - Veganer Anteil
##   - Regionen (Bundesländer) und Sieg/Niederlage
##
## Die UI liest NUR Werte von hier und reagiert auf Signale.
## Die Welt (Grid) meldet NUR "Gebäude gebaut/abgerissen" hierher.
## So bleiben Spiellogik, UI und Weltobjekte sauber getrennt.

# ---------------------------------------------------------------------------
# SIGNALE - damit die UI automatisch aktuell bleibt
# ---------------------------------------------------------------------------
## Ein Signal ist wie eine Rundfunk-Durchsage: GameState ruft "Tag vorbei!"
## und alle UI-Elemente, die zuhören (connect), aktualisieren sich selbst.

signal day_passed                      ## Ein Spieltag ist vergangen.
signal resources_changed               ## Ressourcen haben sich geändert.
signal population_changed              ## Bevölkerung hat sich geändert.
signal health_changed                  ## Gesundheitswerte haben sich geändert.
signal vegan_share_changed(value: float)
signal building_registered(building_id: String)
signal region_claimed(region_id: String)
signal research_completed_state(research_id: String)
signal game_over(victory: bool, reason: String)
signal speed_changed(new_speed: float)
signal notification(text: String)     ## Kurze Meldung für den Spieler.

# ---------------------------------------------------------------------------
# SPIELZUSTAND (alles, was gespeichert werden muss)
# ---------------------------------------------------------------------------

## Aktuelle Ressourcen. Wird bei new_game() aus GameData kopiert.
var resources := {}

## Kalender.
var day: int = 1
var month: int = 1
var year: int = 2040

## Bevölkerung.
var population: int = 20

## Gesundheitswerte: alle von 0 bis 100 (höher = besser), außer BMI.
var protein: float = 80.0
var b12: float = 80.0
var vitamin_d: float = 80.0
var mental: float = 80.0
var bmi: float = 23.0          ## Durchschnitts-BMI, gesund: 20 bis 25.

## Veganer Anteil in Prozent (Start: 100).
var vegan_share: float = 100.0

## Gewählter Charakter (ID aus GameData.CHARACTERS).
var character_id: String = ""

## Liste aller gebauten Gebäude (die "logische" Stadt).
## Jeder Eintrag: {"id": "wohnmodul", "cell": Vector2i(3,4), "size": Vector2i(1,1)}
var buildings: Array = []

## Bereits eingenommene Regionen (IDs aus GameData.REGIONS).
var claimed_regions: Array = ["berlin"]

## Abgeschlossene Forschungen (wird vom ResearchManager gepflegt,
## liegt aber hier, damit Speichern/Laden zentral bleibt).
var completed_research: Array = []

## Spielgeschwindigkeit: 0 = Pause, 1 = normal, 2 = schnell, 3 = sehr schnell.
var game_speed: float = 1.0

## true sobald das Spiel gewonnen oder verloren wurde.
var is_game_over: bool = false

# ---------------------------------------------------------------------------
# INTERNE WERTE (werden NICHT gespeichert, sondern berechnet)
# ---------------------------------------------------------------------------

var _day_timer: float = 0.0            ## Zählt Sekunden bis zum nächsten Tag.
var _victory_stable_days: int = 0      ## Wie lange die Siegbedingungen schon halten.

## Tages-Bilanz für die UI (was wurde zuletzt produziert/verbraucht?).
var daily_report := {
	"wasser": 0.0, "essen": 0.0, "satoshis": 0.0, "technikpunkte": 0.0,
	"energie_bedarf": 0.0, "energie_leistung": 0.0,
}

# ---------------------------------------------------------------------------
# SPIELSTART
# ---------------------------------------------------------------------------

func _ready() -> void:
	## Sicherheitsnetz: Falls die Spiel-Szene direkt gestartet wird
	## (z.B. mit F6 im Editor), ohne dass new_game() lief, gibt es trotzdem
	## gültige Startwerte und keinen Absturz.
	if resources.is_empty():
		resources = GameData.START_RESOURCES.duplicate(true)


## Startet ein komplett neues Spiel mit dem gewählten Charakter.
func new_game(chosen_character_id: String) -> void:
	character_id = chosen_character_id
	resources = GameData.START_RESOURCES.duplicate(true)
	day = GameData.START_DATE["tag"]
	month = GameData.START_DATE["monat"]
	year = GameData.START_DATE["jahr"]
	population = GameData.START_POPULATION
	vegan_share = GameData.START_VEGAN_SHARE
	protein = 80.0
	b12 = 80.0
	vitamin_d = 80.0
	mental = 80.0
	bmi = 23.0
	buildings = []
	claimed_regions = ["berlin"]
	completed_research = []
	game_speed = 1.0
	is_game_over = false
	_day_timer = 0.0
	_victory_stable_days = 0

	## Charakter-Bonus auf das Startkapital anwenden.
	var mods := _get_character_mods()
	resources["satoshis"] += mods.get("start_satoshis_bonus", 0.0)

	resources_changed.emit()
	population_changed.emit()
	health_changed.emit()
	vegan_share_changed.emit(vegan_share)


# ---------------------------------------------------------------------------
# ZEITSYSTEM - der Tages- und Kalender-Timer
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if is_game_over or game_speed <= 0.0:
		return
	## delta = Sekunden seit dem letzten Frame.
	## Bei Geschwindigkeit 2x vergeht die Spielzeit doppelt so schnell.
	_day_timer += delta * game_speed
	while _day_timer >= GameData.SECONDS_PER_DAY:
		_day_timer -= GameData.SECONDS_PER_DAY
		_advance_one_day()


## Setzt die Spielgeschwindigkeit (0 = Pause).
func set_speed(speed: float) -> void:
	game_speed = clampf(speed, 0.0, 3.0)
	speed_changed.emit(game_speed)


## Schaltet den Kalender einen Tag weiter (inkl. Monat/Jahr).
func _advance_calendar() -> void:
	day += 1
	var days_in_month: int = GameData.MONTH_DAYS[month - 1]
	if day > days_in_month:
		day = 1
		month += 1
		if month > 12:
			month = 1
			year += 1


## Liefert das Datum als schönen Text, z.B. "14. März 2041".
func get_date_string() -> String:
	return "%d. %s %d" % [day, GameData.MONTH_NAMES[month - 1], year]


# ---------------------------------------------------------------------------
# DER TAGES-TICK - hier passiert die gesamte Simulation
# ---------------------------------------------------------------------------

func _advance_one_day() -> void:
	_advance_calendar()
	_simulate_economy()
	_simulate_health()
	_simulate_vegan_share()
	_simulate_population_growth()
	_check_win_lose()
	day_passed.emit()
	resources_changed.emit()
	health_changed.emit()


## Schritt 1: Produktion, Verbrauch, Steuern, Energie.
func _simulate_economy() -> void:
	var mods := _get_character_mods()
	var research_fx := ResearchManager.get_combined_effects()

	# --- Energie zuerst: Wie gut sind die Gebäude versorgt? -----------------
	var energy_supply := 0.0
	var energy_demand := 0.0
	for b in buildings:
		var data: Dictionary = GameData.get_building(b["id"])
		energy_supply += data["energie_leistung"]
		energy_demand += data["energie_bedarf"]
	## Forschung "Effiziente Stromnetze" senkt den Bedarf.
	energy_demand *= (1.0 - research_fx.get("energie_spar_mult", 0.0))

	## Effizienz: 1.0 = volle Leistung. Bei Strommangel arbeiten Gebäude
	## langsamer (aber nie unter 40 %, damit es kein Todesstrudel wird).
	var efficiency := 1.0
	if energy_demand > energy_supply and energy_demand > 0.0:
		efficiency = maxf(0.4, energy_supply / energy_demand)

	daily_report["energie_bedarf"] = energy_demand
	daily_report["energie_leistung"] = energy_supply

	# --- Produktion und Gebäude-Verbrauch ----------------------------------
	var produced := {"wasser": 0.0, "essen": 0.0, "satoshis": 0.0, "technikpunkte": 0.0}
	var production_mult: float = 1.0 + research_fx.get("produktions_mult", 0.0)

	for b in buildings:
		var data: Dictionary = GameData.get_building(b["id"])
		for res_name in data["produktion"]:
			var amount: float = data["produktion"][res_name] * efficiency * production_mult
			if res_name == "technikpunkte":
				amount *= mods.get("technik_mult", 1.0)
			produced[res_name] += amount
		for res_name in data["verbrauch"]:
			produced[res_name] -= data["verbrauch"][res_name]

	# --- Bürger: Steuern zahlen, Wasser und Essen verbrauchen ---------------
	produced["satoshis"] += population * GameData.TAX_PER_CITIZEN
	produced["wasser"] -= population * GameData.WATER_PER_CITIZEN
	produced["essen"] -= population * GameData.FOOD_PER_CITIZEN \
			* mods.get("essens_verbrauch_mult", 1.0)

	# --- Bilanz anwenden (Ressourcen können nicht unter 0 fallen) -----------
	for res_name in produced:
		daily_report[res_name] = produced[res_name]
		resources[res_name] = maxf(0.0, resources[res_name] + produced[res_name])


## Schritt 2: Gesundheitswerte langsam Richtung Zielwert bewegen.
## Die ZIELWERTE ergeben sich aus Gebäuden, Forschung und Charakter.
## Die AKTUELLEN Werte nähern sich jeden Tag um 10 % an (= träge Simulation,
## damit sich Änderungen organisch anfühlen statt sprunghaft).
func _simulate_health() -> void:
	var mods := _get_character_mods()
	var research_fx := ResearchManager.get_combined_effects()
	var fx := _sum_building_effects()

	## Basiswerte ohne jede Hilfe. Bei wachsender Stadt reichen die
	## Basiswerte nicht mehr - pro 25 Bürger sinkt die Basis um 5 Punkte.
	## Dadurch braucht eine große Stadt aktiv Gesundheits-Infrastruktur.
	var pressure: float = population / 25.0 * 5.0
	var gesund_bonus: float = mods.get("gesundheits_bonus", 0.0)

	var protein_target: float = 70.0 - pressure + fx["protein"] \
			+ research_fx.get("protein_bonus", 0.0) \
			+ mods.get("protein_bonus", 0.0) + gesund_bonus
	var b12_target: float = 60.0 - pressure + fx["b12"] \
			+ research_fx.get("b12_bonus", 0.0) + gesund_bonus
	var vitd_target: float = 60.0 - pressure + fx["vitamin_d"] \
			+ research_fx.get("vitamin_d_bonus", 0.0) + gesund_bonus
	var mental_target: float = 70.0 - pressure + fx["mental"] \
			+ research_fx.get("mental_bonus", 0.0) \
			+ mods.get("mental_bonus", 0.0)

	# --- Mentale Strafen bei Knappheit und Überbevölkerung ------------------
	var mangel_mult: float = mods.get("mangel_mental_mult", 1.0)
	if resources["essen"] <= 0.0:
		mental_target -= 25.0 * mangel_mult
	if resources["wasser"] <= 0.0:
		mental_target -= 25.0 * mangel_mult
	if population > get_housing_capacity():
		mental_target -= 15.0  ## Überbevölkerung: Menschen ohne Wohnung.
	if vegan_share < GameData.VEGAN_CRISIS_THRESHOLD:
		mental_target -= 10.0  ## Krisenstimmung in der Stadt.

	## BMI: Basis 23, Gebäude (Fast Food etc.) treiben ihn hoch,
	## Fitness und Ernährungsforschung senken ihn.
	var bmi_target: float = 23.0 + fx["bmi"] * 0.8 + research_fx.get("bmi_delta", 0.0)
	bmi_target = clampf(bmi_target, 17.0, 35.0)

	## Träge Annäherung: jeden Tag 10 % des Abstands zum Ziel aufholen.
	protein = clampf(lerpf(protein, clampf(protein_target, 0.0, 100.0), 0.1), 0.0, 100.0)
	b12 = clampf(lerpf(b12, clampf(b12_target, 0.0, 100.0), 0.1), 0.0, 100.0)
	vitamin_d = clampf(lerpf(vitamin_d, clampf(vitd_target, 0.0, 100.0), 0.1), 0.0, 100.0)
	mental = clampf(lerpf(mental, clampf(mental_target, 0.0, 100.0), 0.1), 0.0, 100.0)
	bmi = lerpf(bmi, bmi_target, 0.1)


## Schritt 3: Veganer Anteil steigt oder sinkt - das Herzstück des Spiels.
func _simulate_vegan_share() -> void:
	var mods := _get_character_mods()
	var research_fx := ResearchManager.get_combined_effects()
	var fx := _sum_building_effects()

	var delta := 0.0

	# --- Negative Einflüsse --------------------------------------------------
	if resources["essen"] <= 0.0:
		delta -= 1.0          ## Hunger ist der schnellste Weg zurück zum Fleisch.
	if resources["wasser"] <= 0.0:
		delta -= 0.8
	if protein < 50.0:
		delta -= 0.3
	if b12 < 50.0:
		delta -= 0.3
	if vitamin_d < 50.0:
		delta -= 0.2
	if mental < 40.0:
		delta -= 0.4
	if bmi > 28.0 or bmi < 18.5:
		delta -= 0.2          ## Ungesunde Stadt = unglaubwürdige Botschaft.
	if completed_research.is_empty() and population > 60:
		delta -= 0.2          ## Ohne Innovation wird Veganismus unattraktiv.

	# --- Positive Einflüsse --------------------------------------------------
	var vegan_building_fx: float = fx["vegan"] * mods.get("vegan_gebaeude_mult", 1.0)
	delta += vegan_building_fx * 0.05
	delta += research_fx.get("vegan_bonus", 0.0)
	if protein >= 70.0 and b12 >= 70.0 and vitamin_d >= 70.0:
		delta += 0.15         ## Top-Gesundheit überzeugt alle.
	if mental >= 75.0:
		delta += 0.1

	# --- Charakter: negative Veränderungen abmildern -------------------------
	if delta < 0.0:
		delta *= mods.get("vegan_verlust_mult", 1.0)

	vegan_share = clampf(vegan_share + delta, 0.0, 100.0)
	vegan_share_changed.emit(vegan_share)


## Schritt 4: Bevölkerungswachstum - automatisch und organisch.
func _simulate_population_growth() -> void:
	var capacity := get_housing_capacity()
	var free_homes := capacity - population
	if free_homes <= 0:
		return  ## Keine freien Wohnungen, kein Wachstum.

	## Bedingungen laut Spieldesign:
	var food_surplus: bool = daily_report["essen"] > 0.0 and resources["essen"] > population * 2.0
	var water_ok: bool = resources["wasser"] > population * 1.0
	var health_ok: bool = protein >= 50.0 and b12 >= 50.0 and vitamin_d >= 50.0
	var mental_ok: bool = mental >= 50.0

	if not (food_surplus and water_ok and health_ok and mental_ok):
		return

	## Wachstum: 2 % der Bevölkerung pro Tag (mindestens 1 Person),
	## aber nie mehr als die freien Wohnungen.
	var growth: int = clampi(int(ceil(population * 0.02)), 1, free_homes)
	population += growth
	population_changed.emit()


# ---------------------------------------------------------------------------
# SIEG UND NIEDERLAGE
# ---------------------------------------------------------------------------

func _check_win_lose() -> void:
	if is_game_over:
		return

	# --- Niederlage: veganer Anteil unter 50 % -------------------------------
	if vegan_share < GameData.VEGAN_LOSE_THRESHOLD:
		is_game_over = true
		set_speed(0.0)
		game_over.emit(false, "Der vegane Anteil ist unter 50 % gefallen.\nDeutschland is(s)t wieder Currywurst. Du hast verloren.")
		return

	# --- Sieg: alle Bedingungen müssen 7 Tage am Stück halten ----------------
	var all_regions: bool = claimed_regions.size() >= GameData.REGIONS.size()
	var vegan_full: bool = vegan_share >= 100.0
	var supplied: bool = resources["essen"] > 0.0 and resources["wasser"] > 0.0 \
			and daily_report["essen"] >= 0.0 and daily_report["wasser"] >= 0.0
	var stable: bool = mental >= 60.0 and protein >= 60.0 and b12 >= 60.0 \
			and vitamin_d >= 60.0 and population <= get_housing_capacity()

	if all_regions and vegan_full and supplied and stable:
		_victory_stable_days += 1
		if _victory_stable_days >= 7:
			is_game_over = true
			set_speed(0.0)
			game_over.emit(true, "Ganz Deutschland ist vegan!\n100 % veganer Anteil, alle Regionen vereint, die Stadt blüht.\nDU HAST GEWONNEN!")
	else:
		_victory_stable_days = 0


# ---------------------------------------------------------------------------
# GEBÄUDE-VERWALTUNG (wird vom Grid aufgerufen)
# ---------------------------------------------------------------------------

## Prüft, ob ein Gebäude bezahlbar und freigeschaltet ist.
func can_build(building_id: String) -> bool:
	var data := GameData.get_building(building_id)
	if data.is_empty() or not data["baubar"]:
		return false
	if data["forschung_noetig"] != "" \
			and not completed_research.has(data["forschung_noetig"]):
		return false
	return resources["satoshis"] >= get_building_cost(building_id)


## Liefert die tatsächlichen Kosten (inkl. Forschungs-Rabatten).
func get_building_cost(building_id: String) -> int:
	var data := GameData.get_building(building_id)
	if data.is_empty():
		return 0
	var cost: float = data["kosten"]
	if building_id == "strasse":
		var research_fx := ResearchManager.get_combined_effects()
		cost *= (1.0 - research_fx.get("strassen_rabatt", 0.0))
	return int(round(cost))


## Registriert ein neu gebautes Gebäude und zieht die Kosten ab.
## Gibt true zurück, wenn alles geklappt hat.
func register_building(building_id: String, cell: Vector2i) -> bool:
	if not can_build(building_id):
		return false
	var data := GameData.get_building(building_id)
	resources["satoshis"] -= get_building_cost(building_id)
	buildings.append({
		"id": building_id,
		"cell": cell,
		"size": data["groesse"],
	})
	resources_changed.emit()
	building_registered.emit(building_id)
	return true


## Registriert das Start-Rathaus (kostenlos, wird automatisch platziert).
func register_starting_building(building_id: String, cell: Vector2i) -> void:
	var data := GameData.get_building(building_id)
	buildings.append({
		"id": building_id,
		"cell": cell,
		"size": data["groesse"],
	})


## Entfernt ein Gebäude (Abriss) und erstattet einen Teil der Kosten.
func unregister_building(cell: Vector2i) -> void:
	for i in range(buildings.size()):
		if buildings[i]["cell"] == cell:
			var data := GameData.get_building(buildings[i]["id"])
			if data["baubar"]:  ## Das Rathaus gibt es nicht zurück.
				resources["satoshis"] += data["kosten"] * GameData.DEMOLISH_REFUND
			buildings.remove_at(i)
			resources_changed.emit()
			return


## Gesamter Wohnraum aller Gebäude.
func get_housing_capacity() -> int:
	var total := 0
	for b in buildings:
		total += GameData.get_building(b["id"])["wohnraum"]
	return total


## Summiert die Gesundheits-Effekte aller Gebäude
## (Gesundheitsgebäude werden je nach Charakter verstärkt).
func _sum_building_effects() -> Dictionary:
	var mods := _get_character_mods()
	var health_mult: float = mods.get("gesundheits_gebaeude_mult", 1.0)
	var fx := {"protein": 0.0, "b12": 0.0, "vitamin_d": 0.0, "mental": 0.0, "bmi": 0.0, "vegan": 0.0}
	for b in buildings:
		var data: Dictionary = GameData.get_building(b["id"])
		var mult: float = health_mult if data["kategorie"] == "gesundheit" else 1.0
		for key in data["effekte"]:
			fx[key] += data["effekte"][key] * mult
	return fx


# ---------------------------------------------------------------------------
# REGIONEN (Deutschland einnehmen)
# ---------------------------------------------------------------------------

## Liefert die nächste noch nicht eingenommene Region (oder {}).
func get_next_region() -> Dictionary:
	for region in GameData.REGIONS:
		if not claimed_regions.has(region["id"]):
			return region
	return {}


## Prüft, ob die nächste Region eingenommen werden kann.
func can_claim_next_region() -> bool:
	var region := get_next_region()
	if region.is_empty():
		return false
	return resources["satoshis"] >= region["kosten"] \
			and population >= region["min_bevoelkerung"]


## Nimmt die nächste Region ein (kostet Satoshis).
func claim_next_region() -> bool:
	if not can_claim_next_region():
		return false
	var region := get_next_region()
	resources["satoshis"] -= region["kosten"]
	claimed_regions.append(region["id"])
	resources_changed.emit()
	region_claimed.emit(region["id"])
	notification.emit("%s wurde eingenommen! (%d/%d Regionen)" % [
		region["name"], claimed_regions.size(), GameData.REGIONS.size()
	])
	return true


# ---------------------------------------------------------------------------
# HILFSFUNKTIONEN
# ---------------------------------------------------------------------------

## Liefert die Modifikatoren des gewählten Charakters.
func _get_character_mods() -> Dictionary:
	var character := GameData.get_character(character_id)
	if character.is_empty():
		return {}
	return character["modifikatoren"]


## Wird vom ResearchManager gerufen, wenn eine Forschung fertig ist.
func on_research_completed(research_id: String) -> void:
	if not completed_research.has(research_id):
		completed_research.append(research_id)
	research_completed_state.emit(research_id)


# ---------------------------------------------------------------------------
# SPEICHERN / LADEN - Daten rein und raus
# ---------------------------------------------------------------------------

## Packt den kompletten Spielstand in ein Dictionary (für SaveManager).
func to_save_dict() -> Dictionary:
	var building_list: Array = []
	for b in buildings:
		building_list.append({
			"id": b["id"],
			## Vector2i lässt sich nicht direkt als JSON speichern,
			## deshalb zerlegen wir ihn in x und y.
			"cell_x": b["cell"].x,
			"cell_y": b["cell"].y,
		})
	return {
		"resources": resources.duplicate(true),
		"day": day, "month": month, "year": year,
		"population": population,
		"protein": protein, "b12": b12, "vitamin_d": vitamin_d,
		"mental": mental, "bmi": bmi,
		"vegan_share": vegan_share,
		"character_id": character_id,
		"buildings": building_list,
		"claimed_regions": claimed_regions.duplicate(),
		"completed_research": completed_research.duplicate(),
	}


## Stellt den Spielstand aus einem Dictionary wieder her.
func from_save_dict(data: Dictionary) -> void:
	resources = data["resources"].duplicate(true)
	day = int(data["day"])
	month = int(data["month"])
	year = int(data["year"])
	population = int(data["population"])
	protein = data["protein"]
	b12 = data["b12"]
	vitamin_d = data["vitamin_d"]
	mental = data["mental"]
	bmi = data["bmi"]
	vegan_share = data["vegan_share"]
	character_id = data["character_id"]
	claimed_regions = data["claimed_regions"].duplicate()
	completed_research = data["completed_research"].duplicate()
	buildings = []
	for b in data["buildings"]:
		var building_data := GameData.get_building(b["id"])
		buildings.append({
			"id": b["id"],
			"cell": Vector2i(int(b["cell_x"]), int(b["cell_y"])),
			"size": building_data["groesse"],
		})
	is_game_over = false
	game_speed = 1.0
	_day_timer = 0.0
	_victory_stable_days = 0
	resources_changed.emit()
	population_changed.emit()
	health_changed.emit()
	vegan_share_changed.emit(vegan_share)
