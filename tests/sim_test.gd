extends Node
## Automatischer Simulations-Test (ohne Grafik ausführbar)
## ========================================================
## Startet man diese Szene headless, wird die komplette Spiellogik
## durchgetestet: Bauen, Tages-Ticks, Forschung, Regionen, Speichern/Laden
## und die Grid-Platzierungsregeln.
##
## Ausführen im Terminal:
##   godot --headless --path . res://tests/sim_test.tscn
##
## Am Ende steht "ALLE TESTS BESTANDEN" oder eine Liste der Fehler.

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_test_new_game()
	_test_building_and_economy()
	_test_research()
	_test_research_duration()
	_test_new_buildings()
	_test_construction()
	_test_district_bonus()
	_test_health_and_vegan()
	_test_population_growth()
	_test_regions()
	_test_save_load()
	_test_grid_rules()
	_test_lose_condition()

	print("--------------------------------------------------")
	if _failures.is_empty():
		print("ALLE %d TESTS BESTANDEN ✓" % _checks)
		get_tree().quit(0)
	else:
		for f in _failures:
			print("FEHLER: %s" % f)
		print("%d von %d Tests fehlgeschlagen." % [_failures.size(), _checks])
		get_tree().quit(1)


## Kleine Hilfsfunktion: prüft eine Bedingung und merkt sich Fehler.
func check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  ok: %s" % description)
	else:
		_failures.append(description)
		print("  FEHLT: %s" % description)


# ---------------------------------------------------------------------------

func _test_new_game() -> void:
	print("[Test] Neues Spiel")
	GameState.new_game("vegan_gains")
	check(GameState.population == 20, "Start mit 20 Bürgern")
	check(GameState.vegan_share == 100.0, "Start mit 100 % veganem Anteil")
	check(GameState.year == 2040 and GameState.month == 1 and GameState.day == 1,
			"Start am 1. Januar 2040")
	check(GameState.get_date_string() == "1. Januar 2040", "Datums-Text korrekt")
	check(GameState.claimed_regions == ["berlin"], "Nur Berlin am Start")

	## Earthling Ed hat weniger Startkapital.
	GameState.new_game("earthling_ed")
	check(GameState.resources["satoshis"] == GameData.START_RESOURCES["satoshis"] - 300.0,
			"Earthling Ed: 300 Satoshis weniger Startkapital")


func _test_building_and_economy() -> void:
	print("[Test] Bauen und Wirtschaft")
	GameState.new_game("vegan_gains")
	GameState.register_starting_building("rathaus", Vector2i(10, 10))

	var money_before: float = GameState.resources["satoshis"]
	check(GameState.can_build("wohnmodul"), "Wohnmodul ist bezahlbar")
	check(GameState.register_building("wohnmodul", Vector2i(5, 5)),
			"Wohnmodul kann registriert werden")
	check(GameState.resources["satoshis"] == money_before - 150,
			"Baukosten wurden abgezogen")
	## Bauzeit: Direkt nach dem Bau ist es noch eine Baustelle.
	check(GameState.get_housing_capacity() == 25,
			"Baustelle zählt noch nicht als Wohnraum")

	## Gesperrtes Gebäude darf nicht baubar sein.
	check(not GameState.can_build("hydro_farm"),
			"Hydro-Farm ohne Forschung gesperrt")

	## Ein Tag Wirtschaft: Rathaus produziert, Bürger verbrauchen,
	## und die Baustelle wird fertig.
	var food_before: float = GameState.resources["essen"]
	GameState._advance_one_day()
	check(GameState.day == 2, "Kalender ist einen Tag weiter")
	check(GameState.get_housing_capacity() == 25 + 8,
			"Nach 1 Tag Bauzeit: Wohnraum = Rathaus (25) + Wohnmodul (8)")
	## Rathaus: +8 Essen, 20 Bürger: -1 je (x1.15 wegen Vegan Gains) = -23.
	check(GameState.resources["essen"] < food_before,
			"Essen sinkt ohne Farmen (Verbrauch > Produktion)")

	## Abriss erstattet die Hälfte.
	money_before = GameState.resources["satoshis"]
	GameState.unregister_building(Vector2i(5, 5))
	check(GameState.resources["satoshis"] == money_before + 75,
			"Abriss erstattet 50 % der Kosten")


func _test_research() -> void:
	print("[Test] Forschung")
	GameState.new_game("militante_veganerin")
	check(not ResearchManager.can_research("solarenergie"),
			"Forschung ohne Technikpunkte nicht möglich")

	GameState.resources["technikpunkte"] = 500.0
	check(ResearchManager.can_research("solarenergie"), "Solarenergie verfügbar")
	check(not ResearchManager.can_research("atomkraft"),
			"Atomkraft braucht erst Solarenergie (Voraussetzung)")

	check(ResearchManager.do_research("solarenergie"), "Solarenergie erforscht")
	check(ResearchManager.is_completed("solarenergie"), "Solarenergie als fertig markiert")
	check(GameState.can_build("solaranlage") or GameState.resources["satoshis"] >= 350,
			"Solaranlage jetzt freigeschaltet")
	check(ResearchManager.can_research("atomkraft"),
			"Atomkraft nach Solarenergie verfügbar")

	## Effekte: Straßenrabatt testen (transportwege dauert jetzt 3 Tage!).
	check(GameState.get_building_cost("strasse") == 10, "Straße kostet normal 10")
	GameState.resources["technikpunkte"] = 500.0
	ResearchManager.do_research("transportwege")
	check(GameState.active_research == "transportwege",
			"Transportwege läuft als aktive Forschung")
	check(GameState.get_building_cost("strasse") == 10,
			"Rabatt gilt erst NACH Abschluss der Forschung")
	for i in range(3):
		GameState._advance_one_day()
	check(ResearchManager.is_completed("transportwege"),
			"Transportwege nach 3 Tagen abgeschlossen")
	check(GameState.get_building_cost("strasse") == 5,
			"Straße kostet nach 'Transportwege' nur noch 5")


func _test_research_duration() -> void:
	print("[Test] Forschungsdauer")
	GameState.new_game("vegan_gains")
	GameState.resources["technikpunkte"] = 1000.0

	## Billige Forschung (20 TP) ist sofort fertig.
	check(GameData.get_research_duration("solarenergie") == 0,
			"Solarenergie hat Dauer 0 (sofort)")
	ResearchManager.do_research("solarenergie")
	check(ResearchManager.is_completed("solarenergie"),
			"Billige Forschung sofort abgeschlossen")
	check(GameState.active_research == "", "Keine laufende Forschung danach")

	## Teure Forschung (220 TP) dauert die maximalen 7 Tage.
	check(GameData.get_research_duration("endlager") == 7,
			"Endlager hat die Maximaldauer von 7 Tagen")

	## Nur EINE Forschung gleichzeitig.
	ResearchManager.do_research("atomkraft")  ## 180 TP -> 6 Tage
	check(GameState.active_research == "atomkraft", "Atomkraft läuft")
	check(not ResearchManager.can_research("wassergewinnung"),
			"Zweite Forschung gleichzeitig nicht möglich")
	for i in range(6):
		GameState._advance_one_day()
	check(ResearchManager.is_completed("atomkraft"),
			"Atomkraft nach 6 Tagen fertig")
	check(ResearchManager.can_research("wassergewinnung"),
			"Nach Abschluss ist das Labor wieder frei")


func _test_new_buildings() -> void:
	print("[Test] Neue Gebäude (Soja-Bauernhof, Spirulina-Farm)")
	GameState.new_game("vegan_gains")
	check(not GameData.get_building("soja_farm").is_empty(),
			"Soja-Bauernhof existiert in den Spieldaten")
	check(not GameData.get_building("spirulina_farm").is_empty(),
			"Spirulina-Indoor-Farm existiert in den Spieldaten")
	check(GameState.can_build("soja_farm"),
			"Soja-Bauernhof ist von Anfang an baubar")
	check(not GameState.can_build("spirulina_farm"),
			"Spirulina-Farm braucht erst Indoor-Farming-Forschung")
	GameState.completed_research = ["hydro_farming", "indoor_farming"]
	check(GameState.can_build("spirulina_farm"),
			"Spirulina-Farm nach Forschung baubar")


func _test_construction() -> void:
	print("[Test] Bauzeit (1 Tag)")
	GameState.new_game("vegan_gains")
	GameState.register_starting_building("rathaus", Vector2i(10, 10))

	## Straßen sind sofort fertig (sonst wäre Straßenziehen nervig).
	GameState.register_building("strasse", Vector2i(2, 2))
	check(GameState.buildings[-1]["bau_tage_uebrig"] == 0,
			"Straßen haben keine Bauzeit")

	## Gebäude brauchen 1 Tag und produzieren solange nichts.
	GameState.register_building("gemeinschaftsgarten", Vector2i(4, 4))
	check(GameState.buildings[-1]["bau_tage_uebrig"] == 1,
			"Gebäude starten mit 1 Tag Bauzeit")
	var completed_cells: Array = []
	GameState.building_completed.connect(func(cell): completed_cells.append(cell))
	GameState._advance_one_day()
	check(GameState.buildings[-1]["bau_tage_uebrig"] == 0,
			"Baustelle nach 1 Tag fertig")
	check(completed_cells.has(Vector2i(4, 4)),
			"building_completed-Signal wurde gesendet")


func _test_district_bonus() -> void:
	print("[Test] Bezirks-Boni")
	GameState.new_game("vegan_gains")
	## Zwei Wohnmodule direkt nebeneinander -> +10 % für beide.
	GameState.register_starting_building("wohnmodul", Vector2i(5, 5))
	GameState.register_starting_building("wohnmodul", Vector2i(6, 5))
	check(is_equal_approx(GameState.get_district_bonus_at(Vector2i(5, 5)), 0.1),
			"Wohnmodul mit 1 gleichem Nachbarn: +10 %")

	## Drittes und viertes Modul rund um (6,5) -> dort +30 % (Maximum).
	GameState.register_starting_building("wohnmodul", Vector2i(7, 5))
	GameState.register_starting_building("wohnmodul", Vector2i(6, 6))
	check(is_equal_approx(GameState.get_district_bonus_at(Vector2i(6, 5)), 0.3),
			"Wohnmodul mit 3 gleichen Nachbarn: +30 % (Maximum)")

	## Andere Kategorie daneben bringt NICHTS.
	GameState.register_starting_building("park", Vector2i(5, 4))
	check(is_equal_approx(GameState.get_district_bonus_at(Vector2i(5, 5)), 0.1),
			"Andere Kategorie (Park) zählt nicht als Bezirks-Nachbar")

	## Straßen geben nie einen Bonus.
	GameState.register_starting_building("strasse", Vector2i(10, 10))
	GameState.register_starting_building("strasse", Vector2i(11, 10))
	check(GameState.get_district_bonus_at(Vector2i(10, 10)) == 0.0,
			"Straßen bekommen keinen Bezirks-Bonus")


func _test_health_and_vegan() -> void:
	print("[Test] Gesundheit und veganer Anteil")
	GameState.new_game("vegan_gains")
	GameState.register_starting_building("rathaus", Vector2i(10, 10))

	## Mit gutem Setup sollte der vegane Anteil stabil bei 100 bleiben.
	for i in range(10):
		GameState._advance_one_day()
	check(GameState.vegan_share >= 99.0,
			"Veganer Anteil bleibt am Anfang stabil (ist %.1f)" % GameState.vegan_share)
	check(GameState.bmi > 15.0 and GameState.bmi < 35.0, "BMI in sinnvollem Bereich")

	## Hungersnot: Essen auf 0 zwingen -> veganer Anteil muss sinken.
	GameState.buildings = []  ## Keine Produktion mehr.
	GameState.resources["essen"] = 0.0
	GameState.resources["wasser"] = 0.0
	var share_before := GameState.vegan_share
	GameState._advance_one_day()
	check(GameState.vegan_share < share_before,
			"Veganer Anteil sinkt bei Hunger und Durst")


func _test_population_growth() -> void:
	print("[Test] Bevölkerungswachstum")
	GameState.new_game("earthling_ed")
	GameState.register_starting_building("rathaus", Vector2i(10, 10))
	## Ideale Bedingungen schaffen: viel Essen, Wasser, Platz.
	GameState.register_starting_building("oeko_turm", Vector2i(5, 5))
	GameState.resources["essen"] = 10000.0
	GameState.resources["wasser"] = 10000.0
	## Eine Farm, damit die Tagesbilanz beim Essen positiv ist.
	GameState.register_starting_building("gemeinschaftsgarten", Vector2i(3, 3))
	GameState.register_starting_building("gemeinschaftsgarten", Vector2i(3, 4))
	GameState.register_starting_building("gemeinschaftsgarten", Vector2i(3, 5))
	GameState.register_starting_building("gemeinschaftsgarten", Vector2i(3, 6))

	var pop_before := GameState.population
	for i in range(20):
		GameState._advance_one_day()
	check(GameState.population > pop_before,
			"Bevölkerung wächst bei guter Versorgung (%d -> %d)" % [pop_before, GameState.population])
	check(GameState.population <= GameState.get_housing_capacity(),
			"Bevölkerung überschreitet den Wohnraum nicht")


func _test_regions() -> void:
	print("[Test] Regionen")
	GameState.new_game("vegan_gains")
	var next := GameState.get_next_region()
	check(next["id"] == "brandenburg", "Nächste Region ist Brandenburg")
	check(not GameState.can_claim_next_region(),
			"Brandenburg ohne Geld/Bürger nicht einnehmbar")

	GameState.resources["satoshis"] = 99999.0
	GameState.population = 1000
	check(GameState.can_claim_next_region(), "Brandenburg jetzt einnehmbar")
	check(GameState.claim_next_region(), "Brandenburg eingenommen")
	check(GameState.claimed_regions.has("brandenburg"), "Brandenburg in der Liste")
	check(GameState.get_next_region()["id"] == "mecklenburg",
			"Danach folgt Mecklenburg-Vorpommern")


func _test_save_load() -> void:
	print("[Test] Speichern und Laden")
	GameState.new_game("militante_veganerin")
	GameState.register_starting_building("rathaus", Vector2i(10, 10))
	GameState.register_starting_building("wohnmodul", Vector2i(2, 3))
	GameState.resources["satoshis"] = 4242.0
	GameState.resources["technikpunkte"] = 500.0
	ResearchManager.do_research("solarenergie")
	## Eine laufende (mehrtägige) Forschung muss mitgespeichert werden.
	ResearchManager.do_research("stromnetze")  ## 100 TP -> 4 Tage
	GameState.population = 77
	GameState.vegan_share = 88.5

	check(SaveManager.save_game(), "Speichern erfolgreich")

	## Spielstand absichtlich "kaputt machen".
	GameState.new_game("vegan_gains")
	check(GameState.population == 20, "Neues Spiel hat den Zustand überschrieben")

	check(SaveManager.load_game(), "Laden erfolgreich")
	check(GameState.resources["satoshis"] == 4242.0, "Satoshis wiederhergestellt")
	check(GameState.population == 77, "Bevölkerung wiederhergestellt")
	check(is_equal_approx(GameState.vegan_share, 88.5), "Veganer Anteil wiederhergestellt")
	check(GameState.character_id == "militante_veganerin", "Charakter wiederhergestellt")
	check(GameState.completed_research.has("solarenergie"), "Forschung wiederhergestellt")
	check(GameState.active_research == "stromnetze",
			"Laufende Forschung wiederhergestellt")
	check(GameState.research_days_left == 4,
			"Verbleibende Forschungstage wiederhergestellt")
	check(GameState.buildings.size() == 2, "Beide Gebäude wiederhergestellt")
	check(GameState.buildings[1]["cell"] == Vector2i(2, 3),
			"Gebäude-Position als Vector2i wiederhergestellt")


func _test_grid_rules() -> void:
	print("[Test] Grid-Platzierungsregeln")
	GameState.new_game("vegan_gains")

	var grid := CityGrid.new()
	add_child(grid)
	grid.place_starting_buildings()

	var center: Vector2i = grid.get_center_cell()
	## Überlappung: auf dem Rathaus darf nichts gebaut werden.
	check(not grid.is_placement_valid("wohnmodul", center),
			"Kein Bau auf dem Rathaus möglich (Überlappung)")
	## Außerhalb der Karte: verboten.
	check(not grid.is_placement_valid("strasse", Vector2i(-5, -5)),
			"Kein Bau außerhalb der Karte")
	## Straßen müssen am Netz hängen: mitten im Nichts ist verboten.
	check(not grid.is_placement_valid("strasse", center + Vector2i(8, 8)),
			"Straße ohne Anschluss ans Netz verboten")
	## Direkt neben der Start-Straße (Reihe bei center + (-1..2, 2)): erlaubt.
	check(grid.is_placement_valid("strasse", center + Vector2i(3, 2)),
			"Straße mit Anschluss ans Netz erlaubt")
	## Direkt am Rathaus darf eine Straße immer beginnen.
	check(grid.is_placement_valid("strasse", center + Vector2i(-1, 0)),
			"Straße direkt am Rathaus erlaubt")
	## Wohnmodul neben der Start-Straße: erlaubt.
	check(grid.is_placement_valid("wohnmodul", center + Vector2i(0, 3)),
			"Wohnmodul direkt an der Start-Straße erlaubt")
	## Wohnmodul mitten im Nichts (keine Straße): verboten.
	check(not grid.is_placement_valid("wohnmodul", center + Vector2i(7, 7)),
			"Wohnmodul ohne Straßenanschluss verboten")

	## Iso-Mathematik: Hin- und Rückrechnung müssen zusammenpassen.
	var all_match := true
	for cell in [Vector2i(0, 0), Vector2i(3, 7), Vector2i(12, 4)]:
		var world: Vector2 = grid.cell_to_world(cell)
		## Mittelpunkt der Raute prüfen (Ecke wäre mehrdeutig).
		var back: Vector2i = grid.world_to_cell(world + Vector2(0, 16))
		if back != cell:
			all_match = false
	check(all_match, "Iso-Umrechnung Zelle -> Welt -> Zelle stimmt")

	grid.queue_free()


func _test_lose_condition() -> void:
	print("[Test] Niederlage")
	GameState.new_game("vegan_gains")
	GameState.vegan_share = 49.0
	GameState._check_win_lose()
	check(GameState.is_game_over, "Spiel verloren bei unter 50 % veganem Anteil")
