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
signal building_completed(cell: Vector2i)   ## Baustelle fertig geworden.
signal region_claimed(region_id: String)
signal research_completed_state(research_id: String)
signal game_over(victory: bool, reason: String)
signal speed_changed(new_speed: float)
signal notification(text: String)     ## Kurze Meldung für den Spieler.
signal citizens_changed               ## Bürgerliste / Berufe haben sich geändert.
signal farm_fields_changed(farm_cell: Vector2i)
signal delivery_queue_changed

# ---------------------------------------------------------------------------
# SPIELZUSTAND (alles, was gespeichert werden muss)
# ---------------------------------------------------------------------------

## Aktuelle Ressourcen. Wird bei new_game() aus GameData kopiert.
var resources := {}

## Kalender.
var day: int = 1
var month: int = 1
var year: int = 2040

## Bevölkerung (= Anzahl lebender Bürger).
var population: int = 30

## Jeder Bürger: id, profession, work_cell, housing_cell, days_since_meal, hunger_days.
var citizens: Array = []
var _next_citizen_id: int = 1

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

## Gerade laufende Forschung ("" = keine) und wie viele Tage sie noch braucht.
var active_research: String = ""
var research_days_left: int = 0

## Spielgeschwindigkeit: 0 = Pause, 1 = normal, 2 = schnell, 3 = sehr schnell.
var game_speed: float = 1.0

## true sobald das Spiel gewonnen oder verloren wurde.
var is_game_over: bool = false

# ---------------------------------------------------------------------------
# INTERNE WERTE (werden NICHT gespeichert, sondern berechnet)
# ---------------------------------------------------------------------------

var _day_timer: float = 0.0            ## Zählt Sekunden bis zum nächsten Tag.
var _victory_stable_days: int = 0      ## Wie lange die Siegbedingungen schon halten.

## Belegungs-Index für die Bezirks-Boni: Zelle -> Index in buildings.
## Wird nur neu aufgebaut, wenn sich die Gebäudeliste ändert (Cache).
var _occupancy: Dictionary = {}
var _occupancy_dirty: bool = true

## Tages-Bilanz für die UI (was wurde zuletzt produziert/verbraucht?).
var daily_report := {
	"wasser": 0.0, "essen": 0.0, "holz": 0.0, "steine": 0.0,
	"satoshis": 0.0, "technikpunkte": 0.0,
	"energie_bedarf": 0.0, "energie_leistung": 0.0,
}

## Lieferaufträge: Villager holen Ware ab und bringen sie ins Lagerhaus.
var delivery_queue: Array = []
var _next_delivery_id: int = 1

# ---------------------------------------------------------------------------
# SPIELSTART
# ---------------------------------------------------------------------------

func _ready() -> void:
	## Sicherheitsnetz: Falls die Spiel-Szene direkt gestartet wird
	## (z.B. mit F6 im Editor), ohne dass new_game() lief, gibt es trotzdem
	## gültige Startwerte und keinen Absturz.
	if resources.is_empty():
		resources = GameData.START_RESOURCES.duplicate(true)
	else:
		for key in GameData.START_RESOURCES:
			if not resources.has(key):
				resources[key] = GameData.START_RESOURCES[key]


## Startet ein komplett neues Spiel mit dem gewählten Charakter.
func new_game(chosen_character_id: String) -> void:
	character_id = chosen_character_id
	resources = GameData.START_RESOURCES.duplicate(true)
	day = GameData.START_DATE["tag"]
	month = GameData.START_DATE["monat"]
	year = GameData.START_DATE["jahr"]
	vegan_share = GameData.START_VEGAN_SHARE
	_init_citizens(GameData.START_POPULATION)
	protein = 80.0
	b12 = 80.0
	vitamin_d = 80.0
	mental = 80.0
	bmi = 23.0
	buildings = []
	claimed_regions = ["berlin"]
	completed_research = []
	active_research = ""
	research_days_left = 0
	game_speed = 1.0
	is_game_over = false
	_day_timer = 0.0
	_victory_stable_days = 0
	_occupancy_dirty = true

	## Charakter-Bonus auf das Startkapital anwenden.
	var mods := _get_character_mods()
	resources["satoshis"] += mods.get("start_satoshis_bonus", 0.0)

	resources_changed.emit()
	population_changed.emit()
	health_changed.emit()
	vegan_share_changed.emit(vegan_share)
	citizens_changed.emit()


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
	_advance_construction()
	_simulate_economy()
	_simulate_citizen_needs()
	_simulate_health()
	_simulate_vegan_share()
	_simulate_population_growth()
	_check_win_lose()
	day_passed.emit()
	resources_changed.emit()
	health_changed.emit()


## Schritt 0: Baustellen weiterbauen. Jedes Gebäude braucht 1 Tag Bauzeit
## (Straßen sind sofort fertig). Während des Baus produziert es nichts,
## bietet keinen Wohnraum und hat keine Effekte.
func _advance_construction() -> void:
	for b in buildings:
		if b.get("bau_tage_uebrig", 0) > 0:
			if not has_builder_at_site(b["cell"]):
				continue
			b["bau_tage_uebrig"] -= 1
			if b["bau_tage_uebrig"] <= 0:
				release_workers_at_building(b["cell"])
				if GameData.get_building(b["id"]).get("ist_farm", false):
					assign_farmer_to_building(b["cell"])
				building_completed.emit(b["cell"])
				notification.emit("%s fertiggestellt!"
						% GameData.get_building(b["id"])["name"])


## Ist das Gebäude fertig gebaut (und zählt damit für die Simulation)?
func _is_built(b: Dictionary) -> bool:
	return b.get("bau_tage_uebrig", 0) <= 0


## Schritt 1: Produktion, Verbrauch, Steuern, Energie.
func _simulate_economy() -> void:
	var mods := _get_character_mods()
	var research_fx := ResearchManager.get_combined_effects()

	# --- Energie zuerst: Wie gut sind die Gebäude versorgt? -----------------
	var energy_supply := 0.0
	var energy_demand := 0.0
	for b in buildings:
		if not _is_built(b):
			continue  ## Baustellen zählen noch nicht.
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
	var produced := _fresh_resource_delta()
	var production_mult: float = 1.0 + research_fx.get("produktions_mult", 0.0)

	for b in buildings:
		if not _is_built(b):
			continue  ## Baustellen produzieren noch nichts.
		var data: Dictionary = GameData.get_building(b["id"])
		## Bezirks-Bonus: gleiche Kategorie nebeneinander = mehr Leistung.
		var district_mult: float = 1.0 + get_district_bonus(b)
		for res_name in data["produktion"]:
			var amount: float = data["produktion"][res_name] * efficiency \
					* production_mult * district_mult
			if res_name == "technikpunkte":
				amount *= mods.get("technik_mult", 1.0)
			produced[res_name] += amount
		for res_name in data["verbrauch"]:
			var need: float = data["verbrauch"][res_name]
			_withdraw_resource(res_name, need)
			produced[res_name] -= need

	_simulate_farm_field_harvest(efficiency, production_mult)
	_simulate_processing_buildings(produced, efficiency, production_mult)

	# --- Bürger: Steuern zahlen, Wasser und Essen verbrauchen ---------------
	produced["satoshis"] += population * GameData.TAX_PER_CITIZEN
	produced["wasser"] -= _withdraw_resource("wasser",
			population * GameData.WATER_PER_CITIZEN)
	produced["essen"] -= _withdraw_resource("essen",
			population * GameData.FOOD_PER_CITIZEN * mods.get("essens_verbrauch_mult", 1.0))

	# --- Bilanz anwenden (Ressourcen können nicht unter 0 fallen) -----------
	for res_name in produced:
		if not resources.has(res_name):
			resources[res_name] = 0.0
		if not daily_report.has(res_name):
			daily_report[res_name] = 0.0
		daily_report[res_name] = produced[res_name]
		resources[res_name] = maxf(0.0, resources[res_name] + produced[res_name])

	_schedule_warehouse_deliveries()


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
	add_new_citizens(growth)


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
	if resources["satoshis"] < get_building_cost(building_id):
		return false
	var mats: Dictionary = GameData.get_build_materials(building_id)
	for mat in mats:
		if get_total_stored(mat) < mats[mat]:
			return false
	return true


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
	var mats: Dictionary = GameData.get_build_materials(building_id)
	for mat in mats:
		_withdraw_resource(mat, mats[mat])
	var entry := {
		"id": building_id,
		"cell": cell,
		"size": data["groesse"],
		"bau_tage_uebrig": 0 if building_id == "strasse" else GameData.CONSTRUCTION_DAYS,
	}
	if data.get("ist_farm", false):
		entry["farm_fields"] = []
	if not data.get("verarbeitung", {}).is_empty() or data.get("ist_farm", false):
		entry["pending_delivery"] = {}
	if data.get("ist_lager", false):
		entry["storage"] = {}
	if building_id != "strasse" and entry["bau_tage_uebrig"] > 0:
		assign_builder_to_construction(cell)
	buildings.append(entry)
	_occupancy_dirty = true
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
		"bau_tage_uebrig": 0,  ## Startgebäude stehen sofort.
	})
	_occupancy_dirty = true


## Entfernt ein Gebäude (Abriss) und erstattet einen Teil der Kosten.
func unregister_building(cell: Vector2i) -> void:
	for i in range(buildings.size()):
		if buildings[i]["cell"] == cell:
			var data := GameData.get_building(buildings[i]["id"])
			if data["baubar"]:
				resources["satoshis"] += data["kosten"] * GameData.DEMOLISH_REFUND
			release_workers_at_building(cell)
			buildings.remove_at(i)
			_occupancy_dirty = true
			resources_changed.emit()
			return


## Gesamter Wohnraum aller FERTIGEN Gebäude.
func get_housing_capacity() -> int:
	var total := 0
	for b in buildings:
		if _is_built(b):
			total += GameData.get_building(b["id"])["wohnraum"]
	return total


## Summiert die Gesundheits-Effekte aller Gebäude
## (Gesundheitsgebäude werden je nach Charakter verstärkt,
## Bezirks-Boni verstärken die Effekte zusätzlich).
func _sum_building_effects() -> Dictionary:
	var mods := _get_character_mods()
	var health_mult: float = mods.get("gesundheits_gebaeude_mult", 1.0)
	var fx := {"protein": 0.0, "b12": 0.0, "vitamin_d": 0.0, "mental": 0.0, "bmi": 0.0, "vegan": 0.0}
	for b in buildings:
		if not _is_built(b):
			continue  ## Baustellen haben noch keine Wirkung.
		var data: Dictionary = GameData.get_building(b["id"])
		var mult: float = health_mult if data["kategorie"] == "gesundheit" else 1.0
		mult *= 1.0 + get_district_bonus(b)
		for key in data["effekte"]:
			fx[key] += data["effekte"][key] * mult
	return fx


# ---------------------------------------------------------------------------
# BEZIRKS-BONI ("Bezirke belohnen")
# ---------------------------------------------------------------------------
## Gebäude derselben Kategorie, die DIREKT aneinander grenzen (oben, unten,
## links, rechts - nicht diagonal), verstärken sich gegenseitig:
##   +10 % Produktion und Effekte pro gleichartigem Nachbarn, maximal +30 %.
## Wer also ein Wohnviertel, einen Farm-Bezirk oder eine Klinik-Meile baut,
## wird dafür belohnt. Straßen zählen nicht.

## Baut den Belegungs-Index neu auf (Zelle -> Gebäude-Index).
func _rebuild_occupancy() -> void:
	_occupancy.clear()
	for i in range(buildings.size()):
		var b: Dictionary = buildings[i]
		for x in range(b["size"].x):
			for y in range(b["size"].y):
				_occupancy[b["cell"] + Vector2i(x, y)] = i
	_occupancy_dirty = false


## Liefert den Bezirks-Bonus eines Gebäudes als Faktor (0.0 bis 0.3).
func get_district_bonus(building: Dictionary) -> float:
	var data := GameData.get_building(building["id"])
	if data.is_empty() or data["kategorie"] == "strasse":
		return 0.0
	if _occupancy_dirty:
		_rebuild_occupancy()

	var cell: Vector2i = building["cell"]
	var size: Vector2i = building["size"]

	## Alle Zellen sammeln, die SEITLICH an die Grundfläche grenzen.
	var neighbor_cells: Array = []
	for x in range(size.x):
		neighbor_cells.append(cell + Vector2i(x, -1))
		neighbor_cells.append(cell + Vector2i(x, size.y))
	for y in range(size.y):
		neighbor_cells.append(cell + Vector2i(-1, y))
		neighbor_cells.append(cell + Vector2i(size.x, y))

	## Verschiedene Nachbar-Gebäude derselben Kategorie zählen.
	var counted: Dictionary = {}
	for nc in neighbor_cells:
		if not _occupancy.has(nc):
			continue
		var idx: int = _occupancy[nc]
		if counted.has(idx) or buildings[idx] == building:
			continue
		if not _is_built(buildings[idx]):
			continue  ## Baustellen zählen erst, wenn sie fertig sind.
		var neighbor_data := GameData.get_building(buildings[idx]["id"])
		if neighbor_data["kategorie"] == data["kategorie"]:
			counted[idx] = true

	return minf(0.3, counted.size() * 0.1)


## Bonus-Abfrage für die UI (Hover-Tooltip): per Zelle statt per Gebäude.
func get_district_bonus_at(cell: Vector2i) -> float:
	if _occupancy_dirty:
		_rebuild_occupancy()
	if not _occupancy.has(cell):
		return 0.0
	return get_district_bonus(buildings[_occupancy[cell]])


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
# BÜRGER UND BERUFE
# ---------------------------------------------------------------------------

func _fresh_resource_delta() -> Dictionary:
	var delta := {}
	for key in resources:
		delta[key] = 0.0
	for key in ["wasser", "essen", "holz", "steine", "satoshis", "technikpunkte"]:
		if not delta.has(key):
			delta[key] = 0.0
	return delta


func add_resource(res_name: String, amount: float) -> void:
	if not resources.has(res_name):
		resources[res_name] = 0.0
	resources[res_name] += amount
	resources_changed.emit()


func _new_citizen_dict() -> Dictionary:
	var c := {
		"id": _next_citizen_id,
		"profession": GameData.PROFESSION_VILLAGER,
		"work_cell": Vector2i(-1, -1),
		"housing_cell": Vector2i(-1, -1),
		"days_since_meal": 0,
		"hunger_days": 0,
	}
	_next_citizen_id += 1
	return c


func _init_citizens(count: int) -> void:
	citizens.clear()
	_next_citizen_id = 1
	for _i in range(count):
		citizens.append(_new_citizen_dict())
	population = citizens.size()
	citizens_changed.emit()


func add_new_citizens(count: int) -> void:
	for _i in range(count):
		citizens.append(_new_citizen_dict())
	population = citizens.size()
	population_changed.emit()
	citizens_changed.emit()


func remove_citizen(citizen_id: int) -> void:
	for i in range(citizens.size()):
		if citizens[i]["id"] == citizen_id:
			citizens.remove_at(i)
			population = citizens.size()
			population_changed.emit()
			citizens_changed.emit()
			return


func get_citizen(citizen_id: int) -> Dictionary:
	for c in citizens:
		if c["id"] == citizen_id:
			return c
	return {}


func get_idle_villagers() -> Array:
	var result: Array = []
	for c in citizens:
		if c["profession"] == GameData.PROFESSION_VILLAGER \
				and c["work_cell"] == Vector2i(-1, -1):
			result.append(c)
	return result


func train_builder() -> bool:
	for c in citizens:
		if c["profession"] == GameData.PROFESSION_VILLAGER:
			c["profession"] = GameData.PROFESSION_BUILDER
			c["work_cell"] = Vector2i(-1, -1)
			c["days_since_meal"] = 0
			citizens_changed.emit()
			notification.emit("Neuer Bauarbeiter ausgebildet!")
			_assign_builder_to_nearest_site()
			return true
	notification.emit("Kein freier Bürger für die Ausbildung.")
	return false


func assign_farmer_to_building(cell: Vector2i) -> bool:
	for c in citizens:
		if c["profession"] == GameData.PROFESSION_VILLAGER \
				and c["work_cell"] == Vector2i(-1, -1):
			c["profession"] = GameData.PROFESSION_FARMER
			c["work_cell"] = cell
			citizens_changed.emit()
			return true
	return false


func assign_builder_to_construction(cell: Vector2i) -> bool:
	for c in citizens:
		if c["profession"] == GameData.PROFESSION_BUILDER \
				and c["work_cell"] == Vector2i(-1, -1):
			c["work_cell"] = cell
			citizens_changed.emit()
			return true
	return false


func _assign_builder_to_nearest_site() -> void:
	for b in buildings:
		if b.get("bau_tage_uebrig", 0) > 0:
			if assign_builder_to_construction(b["cell"]):
				return


func release_workers_at_building(cell: Vector2i) -> void:
	for c in citizens:
		if c["work_cell"] == cell:
			if c["profession"] == GameData.PROFESSION_FARMER \
					or c["profession"] == GameData.PROFESSION_BUILDER:
				c["profession"] = GameData.PROFESSION_VILLAGER
			c["work_cell"] = Vector2i(-1, -1)
	citizens_changed.emit()


func has_builder_at_site(cell: Vector2i) -> bool:
	for c in citizens:
		if c["profession"] == GameData.PROFESSION_BUILDER and c["work_cell"] == cell:
			return true
	return false


func feed_builder(citizen_id: int) -> void:
	var c := get_citizen(citizen_id)
	if c.is_empty():
		return
	c["days_since_meal"] = 0
	citizens_changed.emit()


func assign_housing(citizen_id: int, housing_cell: Vector2i) -> void:
	var c := get_citizen(citizen_id)
	if c.is_empty():
		return
	c["housing_cell"] = housing_cell
	c["hunger_days"] = 0
	citizens_changed.emit()


func get_building_at_cell(cell: Vector2i) -> Dictionary:
	for b in buildings:
		var size: Vector2i = b["size"]
		for x in range(size.x):
			for y in range(size.y):
				if b["cell"] + Vector2i(x, y) == cell:
					return b
	return {}


func get_farm_building(farm_origin_cell: Vector2i) -> Dictionary:
	for b in buildings:
		if b["cell"] == farm_origin_cell:
			var data: Dictionary = GameData.get_building(b["id"])
			if data.get("ist_farm", false):
				return b
	return {}


func get_farm_field_crop_at(cell: Vector2i) -> String:
	for b in buildings:
		if not b.has("farm_fields"):
			continue
		for f in b["farm_fields"]:
			if int(f["x"]) == cell.x and int(f["y"]) == cell.y:
				return str(f.get("crop", ""))
	return ""


func get_farm_field_counts(farm_origin_cell: Vector2i) -> Dictionary:
	var counts := {}
	var b := get_farm_building(farm_origin_cell)
	if b.is_empty() or not b.has("farm_fields"):
		return counts
	for f in b["farm_fields"]:
		var crop: String = str(f.get("crop", ""))
		if crop == "":
			continue
		counts[crop] = int(counts.get(crop, 0)) + 1
	return counts


func toggle_farm_field(farm_origin_cell: Vector2i, field_cell: Vector2i,
		crop_id: String) -> bool:
	var b := get_farm_building(farm_origin_cell)
	if b.is_empty():
		return false
	var allowed: Array = GameData.get_building(b["id"]).get("farm_kulturen", [])
	if crop_id not in allowed:
		return false

	if not b.has("farm_fields"):
		b["farm_fields"] = []

	for i in range(b["farm_fields"].size()):
		var f: Dictionary = b["farm_fields"][i]
		if int(f["x"]) == field_cell.x and int(f["y"]) == field_cell.y:
			if str(f.get("crop", "")) == crop_id:
				b["farm_fields"].remove_at(i)
				farm_fields_changed.emit(farm_origin_cell)
				return true
			b["farm_fields"][i] = {"x": field_cell.x, "y": field_cell.y, "crop": crop_id}
			farm_fields_changed.emit(farm_origin_cell)
			return true

	if b["farm_fields"].size() >= GameData.FARM_MAX_FIELDS:
		notification.emit("Maximal %d Felder pro Hof!" % GameData.FARM_MAX_FIELDS)
		return false

	b["farm_fields"].append({"x": field_cell.x, "y": field_cell.y, "crop": crop_id})
	farm_fields_changed.emit(farm_origin_cell)
	return true


func clear_farm_fields(farm_origin_cell: Vector2i) -> void:
	var b := get_farm_building(farm_origin_cell)
	if b.is_empty():
		return
	b["farm_fields"] = []
	farm_fields_changed.emit(farm_origin_cell)
	notification.emit("Alle Felder geleert.")


func _simulate_farm_field_harvest(efficiency: float, production_mult: float) -> void:
	for b in buildings:
		if not _is_built(b):
			continue
		if not b.has("farm_fields"):
			continue
		if not b.has("pending_delivery"):
			b["pending_delivery"] = {}
		var district_mult: float = 1.0 + get_district_bonus(b)
		for f in b["farm_fields"]:
			var crop: String = str(f.get("crop", ""))
			if crop == "" or not GameData.CROP_DATA.has(crop):
				continue
			var amount: float = GameData.get_crop_yield(crop) * efficiency \
					* production_mult * district_mult
			b["pending_delivery"][crop] = b["pending_delivery"].get(crop, 0.0) + amount
			if not daily_report.has(crop):
				daily_report[crop] = 0.0
			daily_report[crop] += amount


func _simulate_processing_buildings(produced: Dictionary, efficiency: float,
		production_mult: float) -> void:
	for b in buildings:
		if not _is_built(b):
			continue
		var data: Dictionary = GameData.get_building(b["id"])
		var inputs: Dictionary = data.get("verarbeitung", {})
		if inputs.is_empty():
			continue
		var district_mult: float = 1.0 + get_district_bonus(b)
		var can_run := true
		for res_name in inputs:
			if get_total_stored(res_name) < inputs[res_name] * district_mult:
				can_run = false
				break
		if not can_run:
			continue
		for res_name in inputs:
			_withdraw_resource(res_name, inputs[res_name] * district_mult)
		if not b.has("pending_delivery"):
			b["pending_delivery"] = {}
		for res_name in data["produktion"]:
			var amount: float = data["produktion"][res_name] * efficiency \
					* production_mult * district_mult
			if GameData.is_storable(res_name) and _has_lagerhaus():
				b["pending_delivery"][res_name] = b["pending_delivery"].get(res_name, 0.0) + amount
				if not daily_report.has(res_name):
					daily_report[res_name] = 0.0
				daily_report[res_name] += amount
			else:
				produced[res_name] = produced.get(res_name, 0.0) + amount
				if not daily_report.has(res_name):
					daily_report[res_name] = 0.0
				daily_report[res_name] += amount


# ---------------------------------------------------------------------------
# LAGERHAUS & LIEFERUNGEN
# ---------------------------------------------------------------------------

func _has_lagerhaus() -> bool:
	for b in buildings:
		if b["id"] == "lagerhaus" and _is_built(b):
			return true
	return false


func get_total_stored(res_name: String) -> float:
	var total: float = resources.get(res_name, 0.0)
	for b in buildings:
		if b["id"] != "lagerhaus" or not _is_built(b):
			continue
		if b.has("storage"):
			total += b["storage"].get(res_name, 0.0)
	return total


func get_warehouse_totals() -> Dictionary:
	var totals := {}
	for b in buildings:
		if b["id"] != "lagerhaus" or not _is_built(b):
			continue
		if not b.has("storage"):
			continue
		for res_name in b["storage"]:
			totals[res_name] = totals.get(res_name, 0.0) + b["storage"][res_name]
	return totals


## Öffentliche Variante für UI und Villager (Lager zuerst, dann global).
func withdraw_resource(res_name: String, amount: float) -> float:
	return _withdraw_resource(res_name, amount)


func _withdraw_resource(res_name: String, amount: float) -> float:
	var left: float = amount
	for b in buildings:
		if left <= 0.0:
			break
		if b["id"] != "lagerhaus" or not _is_built(b):
			continue
		if not b.has("storage"):
			b["storage"] = {}
		var stored: float = b["storage"].get(res_name, 0.0)
		var take: float = minf(left, stored)
		if take > 0.0:
			b["storage"][res_name] = stored - take
			left -= take
	if left > 0.0:
		var global_amt: float = resources.get(res_name, 0.0)
		var take: float = minf(left, global_amt)
		resources[res_name] = global_amt - take
		left -= take
	return amount - left


func get_nearest_lagerhaus_with_space(from_cell: Vector2i, res_name: String,
		_amount: float) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := 999999
	for b in buildings:
		if b["id"] != "lagerhaus" or not _is_built(b):
			continue
		if not b.has("storage"):
			b["storage"] = {}
		var cur: float = b["storage"].get(res_name, 0.0)
		if cur >= GameData.LAGERHAUS_CAPACITY:
			continue
		var d: int = absi(from_cell.x - b["cell"].x) + absi(from_cell.y - b["cell"].y)
		if d < best_dist:
			best_dist = d
			best = b
	return best


func deposit_to_lager(lager_cell: Vector2i, res_name: String, amount: float) -> float:
	for b in buildings:
		if b["cell"] != lager_cell or b["id"] != "lagerhaus":
			continue
		if not b.has("storage"):
			b["storage"] = {}
		var cur: float = b["storage"].get(res_name, 0.0)
		var free: float = maxf(0.0, GameData.LAGERHAUS_CAPACITY - cur)
		var add: float = minf(amount, free)
		if add > 0.0:
			b["storage"][res_name] = cur + add
			resources_changed.emit()
		return add
	return 0.0


func _deposit_to_nearest_lager(from_cell: Vector2i, res_name: String,
		amount: float) -> float:
	var lager: Dictionary = get_nearest_lagerhaus_with_space(from_cell, res_name, amount)
	if lager.is_empty():
		add_resource(res_name, amount)
		return amount
	return deposit_to_lager(lager["cell"], res_name, amount)


func enqueue_delivery(source_cell: Vector2i, dest_cell: Vector2i,
		resource: String, amount: float) -> void:
	delivery_queue.append({
		"id": _next_delivery_id,
		"source_cell": source_cell,
		"dest_cell": dest_cell,
		"resource": resource,
		"amount": amount,
	})
	_next_delivery_id += 1
	delivery_queue_changed.emit()


func queue_world_pickup(pickup_cell: Vector2i, resource: String, amount: float) -> void:
	if not _has_lagerhaus():
		add_resource(resource, amount)
		return
	var lager: Dictionary = get_nearest_lagerhaus_with_space(
			pickup_cell, resource, amount)
	if lager.is_empty():
		add_resource(resource, amount)
		return
	enqueue_delivery(pickup_cell, lager["cell"], resource, amount)


func pop_delivery_job() -> Dictionary:
	if delivery_queue.is_empty():
		return {}
	var job: Dictionary = delivery_queue[0]
	delivery_queue.remove_at(0)
	delivery_queue_changed.emit()
	return job


func complete_delivery(job: Dictionary) -> void:
	if job.is_empty():
		return
	var deposited: float = deposit_to_lager(job["dest_cell"], job["resource"],
			job["amount"])
	var overflow: float = job["amount"] - deposited
	if overflow > 0.0:
		add_resource(job["resource"], overflow)
	if deposited > 0.0:
		notification.emit("%s ins Lagerhaus: +%.0f" % [
			GameData.get_resource_label(job["resource"]), deposited])


func _schedule_warehouse_deliveries() -> void:
	for b in buildings:
		if not b.has("pending_delivery"):
			continue
		for res_name in b["pending_delivery"].keys():
			var amt: float = b["pending_delivery"][res_name]
			while amt > 0.5:
				var batch: float = minf(amt, 6.0)
				if not _has_lagerhaus():
					add_resource(res_name, batch)
					amt -= batch
					continue
				var lager: Dictionary = get_nearest_lagerhaus_with_space(
						b["cell"], res_name, batch)
				if lager.is_empty():
					add_resource(res_name, batch)
					amt -= batch
					continue
				enqueue_delivery(b["cell"], lager["cell"], res_name, batch)
				amt -= batch
			b["pending_delivery"][res_name] = 0.0


func take_pending_from_building(building_cell: Vector2i, resource: String,
		amount: float) -> float:
	for b in buildings:
		if b["cell"] != building_cell or not b.has("pending_delivery"):
			continue
		var avail: float = b["pending_delivery"].get(resource, 0.0)
		var take: float = minf(amount, avail)
		b["pending_delivery"][resource] = avail - take
		return take
	return 0.0


func _simulate_citizen_needs() -> void:
	var to_remove: Array[int] = []
	for c in citizens:
		if c["profession"] == GameData.PROFESSION_BUILDER:
			c["days_since_meal"] += 1
			if c["days_since_meal"] > GameData.BUILDER_STARVE_DAYS:
				to_remove.append(c["id"])
				notification.emit("Ein Bauarbeiter ist verhungert!")
		elif c["housing_cell"] != Vector2i(-1, -1):
			c["hunger_days"] = 0
			c["days_since_meal"] = 0
		else:
			if resources.get("essen", 0.0) <= 0.0:
				c["hunger_days"] += 1
				if c["hunger_days"] > 14:
					to_remove.append(c["id"])
					notification.emit("Ein obdachloser Bürger ist verhungert!")
			else:
				c["hunger_days"] = 0
	for cid in to_remove:
		remove_citizen(cid)


# ---------------------------------------------------------------------------
# SPEICHERN / LADEN - Daten rein und raus
# ---------------------------------------------------------------------------

## Packt den kompletten Spielstand in ein Dictionary (für SaveManager).
func to_save_dict() -> Dictionary:
	var building_list: Array = []
	for b in buildings:
		var saved := {
			"id": b["id"],
			"cell_x": b["cell"].x,
			"cell_y": b["cell"].y,
			"bau_tage_uebrig": b.get("bau_tage_uebrig", 0),
		}
		if b.has("farm_fields"):
			saved["farm_fields"] = b["farm_fields"].duplicate(true)
		if b.has("pending_delivery"):
			saved["pending_delivery"] = b["pending_delivery"].duplicate(true)
		if b.has("storage"):
			saved["storage"] = b["storage"].duplicate(true)
		building_list.append(saved)

	var delivery_list: Array = []
	for job in delivery_queue:
		delivery_list.append({
			"id": job["id"],
			"source_x": job["source_cell"].x,
			"source_y": job["source_cell"].y,
			"dest_x": job["dest_cell"].x,
			"dest_y": job["dest_cell"].y,
			"resource": job["resource"],
			"amount": job["amount"],
		})

	var citizen_list: Array = []
	for c in citizens:
		citizen_list.append({
			"id": c["id"],
			"profession": c["profession"],
			"work_x": c["work_cell"].x,
			"work_y": c["work_cell"].y,
			"housing_x": c["housing_cell"].x,
			"housing_y": c["housing_cell"].y,
			"days_since_meal": c.get("days_since_meal", 0),
			"hunger_days": c.get("hunger_days", 0),
		})

	return {
		"resources": resources.duplicate(true),
		"day": day, "month": month, "year": year,
		"population": population,
		"citizens": citizen_list,
		"next_citizen_id": _next_citizen_id,
		"protein": protein, "b12": b12, "vitamin_d": vitamin_d,
		"mental": mental, "bmi": bmi,
		"vegan_share": vegan_share,
		"character_id": character_id,
		"buildings": building_list,
		"claimed_regions": claimed_regions.duplicate(),
		"completed_research": completed_research.duplicate(),
		"active_research": active_research,
		"research_days_left": research_days_left,
		"delivery_queue": delivery_list,
		"next_delivery_id": _next_delivery_id,
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
	## .get() mit Standardwert: So lassen sich auch ÄLTERE Spielstände laden,
	## die diese Felder noch nicht hatten.
	active_research = data.get("active_research", "")
	research_days_left = int(data.get("research_days_left", 0))
	buildings = []
	for b in data["buildings"]:
		var building_data := GameData.get_building(b["id"])
		var entry := {
			"id": b["id"],
			"cell": Vector2i(int(b["cell_x"]), int(b["cell_y"])),
			"size": building_data["groesse"],
			"bau_tage_uebrig": int(b.get("bau_tage_uebrig", 0)),
		}
		if b.has("farm_fields"):
			entry["farm_fields"] = b["farm_fields"]
		elif GameData.get_building(b["id"]).get("ist_farm", false):
			entry["farm_fields"] = []
		if b.has("pending_delivery"):
			entry["pending_delivery"] = b["pending_delivery"]
		if b.has("storage"):
			entry["storage"] = b["storage"]
		elif b["id"] == "lagerhaus":
			entry["storage"] = {}
		buildings.append(entry)

	delivery_queue = []
	_next_delivery_id = int(data.get("next_delivery_id", 1))
	if data.has("delivery_queue"):
		for job in data["delivery_queue"]:
			delivery_queue.append({
				"id": int(job["id"]),
				"source_cell": Vector2i(int(job["source_x"]), int(job["source_y"])),
				"dest_cell": Vector2i(int(job["dest_x"]), int(job["dest_y"])),
				"resource": job["resource"],
				"amount": job["amount"],
			})

	citizens = []
	_next_citizen_id = int(data.get("next_citizen_id", 1))
	if data.has("citizens"):
		for c in data["citizens"]:
			citizens.append({
				"id": int(c["id"]),
				"profession": c["profession"],
				"work_cell": Vector2i(int(c["work_x"]), int(c["work_y"])),
				"housing_cell": Vector2i(int(c["housing_x"]), int(c["housing_y"])),
				"days_since_meal": int(c.get("days_since_meal", 0)),
				"hunger_days": int(c.get("hunger_days", 0)),
			})
	else:
		_init_citizens(population)
	population = citizens.size()

	is_game_over = false
	game_speed = 1.0
	_day_timer = 0.0
	_victory_stable_days = 0
	_occupancy_dirty = true
	resources_changed.emit()
	population_changed.emit()
	health_changed.emit()
	vegan_share_changed.emit(vegan_share)
	citizens_changed.emit()
