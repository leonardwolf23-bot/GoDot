extends Node
## GameData (Autoload / Singleton)
## ================================
## Diese Datei ist die zentrale "Datenbank" des Spiels.
## Hier stehen NUR Daten und kleine Hilfsfunktionen – KEINE Spiellogik!
##
## Warum? Saubere Trennung:
##   - GameData  = WAS es im Spiel gibt (Gebäude, Forschung, Charaktere, ...)
##   - GameState = WIE der aktuelle Spielstand aussieht (Simulation)
##
## Vorteil: Balancing-Änderungen (Kosten, Produktion, ...) macht man nur hier,
## ohne irgendwo anders Code anfassen zu müssen.

# ---------------------------------------------------------------------------
# ALLGEMEINES BALANCING
# ---------------------------------------------------------------------------

## Wie viele ECHTE Sekunden ein Spieltag bei Geschwindigkeit 1x dauert.
const SECONDS_PER_DAY: float = 5.0

## Startwerte eines neuen Spiels.
const START_RESOURCES := {
	"wasser": 200.0,
	"essen": 200.0,
	"satoshis": 1200.0,
	"technikpunkte": 0.0,
}
const START_POPULATION: int = 20
const START_VEGAN_SHARE: float = 100.0
const START_DATE := {"tag": 1, "monat": 1, "jahr": 2040}

## Verbrauch PRO BÜRGER und PRO TAG.
const WATER_PER_CITIZEN: float = 1.0
const FOOD_PER_CITIZEN: float = 1.0
## Steuereinnahmen PRO BÜRGER und PRO TAG (in Satoshis).
const TAX_PER_CITIZEN: float = 2.0

## Monatslängen für den Kalender (vereinfacht, ohne Schaltjahre).
const MONTH_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
const MONTH_NAMES := [
	"Januar", "Februar", "März", "April", "Mai", "Juni",
	"Juli", "August", "September", "Oktober", "November", "Dezember",
]

## Veganer Anteil: Grenzen für Niederlage und Krise.
const VEGAN_LOSE_THRESHOLD: float = 50.0
const VEGAN_CRISIS_THRESHOLD: float = 80.0

## Wie viel man beim Abriss eines Gebäudes zurückbekommt (50 %).
const DEMOLISH_REFUND: float = 0.5

# ---------------------------------------------------------------------------
# GEBÄUDE
# ---------------------------------------------------------------------------
## Jedes Gebäude ist ein Dictionary mit folgenden Feldern:
##   name              - Anzeigename
##   beschreibung      - Tooltip-Text
##   kategorie         - "strasse", "wohnen", "wasser", "essen", "wirtschaft",
##                       "forschung", "gesundheit", "freizeit", "energie"
##   kosten            - Baukosten in Satoshis
##   groesse           - Grundfläche in Rasterzellen (Vector2i)
##   farbe             - Farbe für die 2.5D-Darstellung
##   hoehe             - visuelle Höhe in Pixeln (für den Iso-Quader)
##   wohnraum          - wie viele Bürger hier wohnen können
##   produktion        - was das Gebäude PRO TAG produziert
##   verbrauch         - was das Gebäude PRO TAG verbraucht
##   energie_bedarf    - wie viel Strom das Gebäude braucht (Kapazität)
##   energie_leistung  - wie viel Strom das Gebäude liefert (Kapazität)
##   effekte           - Einfluss auf Gesundheitswerte (Punkte, siehe GameState)
##                       Schlüssel: protein, b12, vitamin_d, mental, bmi, vegan
##   forschung_noetig  - ID der Forschung, die das Gebäude freischaltet ("" = keine)
##   braucht_strasse   - true = muss neben einer Straße stehen
##   baubar            - false = kann nicht vom Spieler gebaut werden (Rathaus)

const BUILDINGS := {
	"rathaus": {
		"name": "Futuristisches Rathaus",
		"beschreibung": "Das Herz deiner Stadt. Liefert Grundversorgung, Strom und Wohnraum.",
		"kategorie": "wirtschaft",
		"kosten": 0,
		"groesse": Vector2i(2, 2),
		"farbe": Color(0.35, 0.85, 0.95),
		"hoehe": 72,
		"wohnraum": 25,
		"produktion": {"wasser": 10.0, "essen": 8.0, "satoshis": 15.0, "technikpunkte": 1.0},
		"verbrauch": {},
		"energie_bedarf": 0,
		"energie_leistung": 30,
		"effekte": {},
		"forschung_noetig": "",
		"braucht_strasse": false,
		"baubar": false,
	},
	"strasse": {
		"name": "Straße",
		"beschreibung": "Verbindet Gebäude. Fast alle Gebäude müssen an einer Straße stehen.",
		"kategorie": "strasse",
		"kosten": 10,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.45, 0.47, 0.52),
		"hoehe": 2,
		"wohnraum": 0,
		"produktion": {},
		"verbrauch": {},
		"energie_bedarf": 0,
		"energie_leistung": 0,
		"effekte": {},
		"forschung_noetig": "",
		"braucht_strasse": false,
		"baubar": true,
	},
	# ----------------------------- WOHNEN ---------------------------------
	"wohnmodul": {
		"name": "Wohnmodul",
		"beschreibung": "Kompaktes, nachhaltiges Wohnhaus für 8 Bürger.",
		"kategorie": "wohnen",
		"kosten": 150,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.55, 0.78, 0.62),
		"hoehe": 36,
		"wohnraum": 8,
		"produktion": {},
		"verbrauch": {},
		"energie_bedarf": 2,
		"energie_leistung": 0,
		"effekte": {},
		"forschung_noetig": "",
		"braucht_strasse": true,
		"baubar": true,
	},
	"oeko_turm": {
		"name": "Öko-Wohnturm",
		"beschreibung": "Begrünter Hochbau für 24 Bürger.",
		"kategorie": "wohnen",
		"kosten": 550,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.36, 0.68, 0.5),
		"hoehe": 64,
		"wohnraum": 24,
		"produktion": {},
		"verbrauch": {},
		"energie_bedarf": 5,
		"energie_leistung": 0,
		"effekte": {},
		"forschung_noetig": "",
		"braucht_strasse": true,
		"baubar": true,
	},
	"arkologie": {
		"name": "Arkologie",
		"beschreibung": "Riesiger, autarker Wohnkomplex für 60 Bürger.",
		"kategorie": "wohnen",
		"kosten": 2200,
		"groesse": Vector2i(2, 2),
		"farbe": Color(0.28, 0.6, 0.66),
		"hoehe": 96,
		"wohnraum": 60,
		"produktion": {},
		"verbrauch": {},
		"energie_bedarf": 15,
		"energie_leistung": 0,
		"effekte": {"mental": 1.0},
		"forschung_noetig": "lebensqualitaet",
		"braucht_strasse": true,
		"baubar": true,
	},
	# ----------------------------- WASSER ---------------------------------
	"regenwassersammler": {
		"name": "Regenwassersammler",
		"beschreibung": "Sammelt und filtert Regenwasser (+10 Wasser/Tag).",
		"kategorie": "wasser",
		"kosten": 120,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.4, 0.62, 0.9),
		"hoehe": 24,
		"wohnraum": 0,
		"produktion": {"wasser": 10.0},
		"verbrauch": {},
		"energie_bedarf": 1,
		"energie_leistung": 0,
		"effekte": {},
		"forschung_noetig": "",
		"braucht_strasse": true,
		"baubar": true,
	},
	"wasserwerk": {
		"name": "Nachhaltiges Wasserwerk",
		"beschreibung": "Hochmoderne Wassergewinnung (+40 Wasser/Tag).",
		"kategorie": "wasser",
		"kosten": 650,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.25, 0.5, 0.85),
		"hoehe": 40,
		"wohnraum": 0,
		"produktion": {"wasser": 40.0},
		"verbrauch": {},
		"energie_bedarf": 6,
		"energie_leistung": 0,
		"effekte": {},
		"forschung_noetig": "wassergewinnung",
		"braucht_strasse": true,
		"baubar": true,
	},
	# ----------------------------- ESSEN ----------------------------------
	"gemeinschaftsgarten": {
		"name": "Gemeinschaftsgarten",
		"beschreibung": "Frisches Gemüse für alle (+8 Essen/Tag, -2 Wasser/Tag).",
		"kategorie": "essen",
		"kosten": 100,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.45, 0.8, 0.35),
		"hoehe": 10,
		"wohnraum": 0,
		"produktion": {"essen": 8.0},
		"verbrauch": {"wasser": 2.0},
		"energie_bedarf": 0,
		"energie_leistung": 0,
		"effekte": {"protein": 0.5, "mental": 0.5},
		"forschung_noetig": "",
		"braucht_strasse": true,
		"baubar": true,
	},
	"hydro_farm": {
		"name": "Hydro-Farm",
		"beschreibung": "Wassersparende Hydrokultur (+20 Essen/Tag).",
		"kategorie": "essen",
		"kosten": 420,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.35, 0.85, 0.55),
		"hoehe": 28,
		"wohnraum": 0,
		"produktion": {"essen": 20.0},
		"verbrauch": {"wasser": 4.0},
		"energie_bedarf": 4,
		"energie_leistung": 0,
		"effekte": {"protein": 1.0},
		"forschung_noetig": "hydro_farming",
		"braucht_strasse": true,
		"baubar": true,
	},
	"indoor_farm": {
		"name": "Indoor-Vertikalfarm",
		"beschreibung": "Mehrstöckige Farm mit LED-Licht (+45 Essen/Tag).",
		"kategorie": "essen",
		"kosten": 950,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.25, 0.75, 0.45),
		"hoehe": 56,
		"wohnraum": 0,
		"produktion": {"essen": 45.0},
		"verbrauch": {"wasser": 6.0},
		"energie_bedarf": 10,
		"energie_leistung": 0,
		"effekte": {"protein": 1.5},
		"forschung_noetig": "indoor_farming",
		"braucht_strasse": true,
		"baubar": true,
	},
	"auto_farm": {
		"name": "Automatisierte Urbanfarm",
		"beschreibung": "Vollautomatische Lebensmittelproduktion (+90 Essen/Tag).",
		"kategorie": "essen",
		"kosten": 1900,
		"groesse": Vector2i(2, 2),
		"farbe": Color(0.18, 0.68, 0.4),
		"hoehe": 48,
		"wohnraum": 0,
		"produktion": {"essen": 90.0},
		"verbrauch": {"wasser": 10.0},
		"energie_bedarf": 16,
		"energie_leistung": 0,
		"effekte": {"protein": 2.0},
		"forschung_noetig": "auto_farms",
		"braucht_strasse": true,
		"baubar": true,
	},
	"protein_labor": {
		"name": "Protein-Labor",
		"beschreibung": "Erzeugt hochwertige vegane Proteinquellen.",
		"kategorie": "essen",
		"kosten": 750,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.85, 0.75, 0.35),
		"hoehe": 40,
		"wohnraum": 0,
		"produktion": {"essen": 10.0},
		"verbrauch": {"wasser": 2.0},
		"energie_bedarf": 6,
		"energie_leistung": 0,
		"effekte": {"protein": 4.0},
		"forschung_noetig": "protein_quellen",
		"braucht_strasse": true,
		"baubar": true,
	},
	"fleischersatz_fabrik": {
		"name": "Fleischersatz-Fabrik",
		"beschreibung": "Produziert täuschend echten Fleischersatz. Stärkt den veganen Anteil, erhöht aber den BMI leicht.",
		"kategorie": "essen",
		"kosten": 1100,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.85, 0.5, 0.4),
		"hoehe": 44,
		"wohnraum": 0,
		"produktion": {"essen": 25.0},
		"verbrauch": {"wasser": 3.0},
		"energie_bedarf": 8,
		"energie_leistung": 0,
		"effekte": {"protein": 2.5, "bmi": 1.0, "vegan": 1.0},
		"forschung_noetig": "fleischersatz",
		"braucht_strasse": true,
		"baubar": true,
	},
	"kaese_manufaktur": {
		"name": "Käseersatz-Manufaktur",
		"beschreibung": "Veganer Käse, der wie echter Käse schmeckt. Großer Schub für den veganen Anteil!",
		"kategorie": "essen",
		"kosten": 1100,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.95, 0.85, 0.45),
		"hoehe": 40,
		"wohnraum": 0,
		"produktion": {"essen": 15.0},
		"verbrauch": {"wasser": 3.0},
		"energie_bedarf": 8,
		"energie_leistung": 0,
		"effekte": {"bmi": 0.5, "vegan": 2.0, "mental": 1.0},
		"forschung_noetig": "kaeseersatz",
		"braucht_strasse": true,
		"baubar": true,
	},
	# --------------------------- WIRTSCHAFT --------------------------------
	"veganer_markt": {
		"name": "Veganer Markt",
		"beschreibung": "Lokaler Handel bringt Satoshis (+25/Tag).",
		"kategorie": "wirtschaft",
		"kosten": 300,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.9, 0.65, 0.3),
		"hoehe": 28,
		"wohnraum": 0,
		"produktion": {"satoshis": 25.0},
		"verbrauch": {},
		"energie_bedarf": 3,
		"energie_leistung": 0,
		"effekte": {},
		"forschung_noetig": "",
		"braucht_strasse": true,
		"baubar": true,
	},
	"handelszentrum": {
		"name": "Handelszentrum",
		"beschreibung": "Digitale Börse für vegane Produkte (+90 Satoshis/Tag).",
		"kategorie": "wirtschaft",
		"kosten": 1300,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.95, 0.55, 0.25),
		"hoehe": 60,
		"wohnraum": 0,
		"produktion": {"satoshis": 90.0},
		"verbrauch": {},
		"energie_bedarf": 10,
		"energie_leistung": 0,
		"effekte": {},
		"forschung_noetig": "",
		"braucht_strasse": true,
		"baubar": true,
	},
	# ---------------------------- FORSCHUNG --------------------------------
	"forschungslabor": {
		"name": "Forschungslabor",
		"beschreibung": "Erzeugt Technikpunkte (+5/Tag).",
		"kategorie": "forschung",
		"kosten": 500,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.7, 0.5, 0.9),
		"hoehe": 44,
		"wohnraum": 0,
		"produktion": {"technikpunkte": 5.0},
		"verbrauch": {},
		"energie_bedarf": 6,
		"energie_leistung": 0,
		"effekte": {},
		"forschung_noetig": "",
		"braucht_strasse": true,
		"baubar": true,
	},
	"universitaet": {
		"name": "Vegane Universität",
		"beschreibung": "Spitzenforschung (+15 Technikpunkte/Tag) und Bildung.",
		"kategorie": "forschung",
		"kosten": 1600,
		"groesse": Vector2i(2, 2),
		"farbe": Color(0.55, 0.4, 0.85),
		"hoehe": 56,
		"wohnraum": 0,
		"produktion": {"technikpunkte": 15.0},
		"verbrauch": {},
		"energie_bedarf": 12,
		"energie_leistung": 0,
		"effekte": {"mental": 1.0, "vegan": 0.5},
		"forschung_noetig": "",
		"braucht_strasse": true,
		"baubar": true,
	},
	# ---------------------------- GESUNDHEIT -------------------------------
	"gesundheitszentrum": {
		"name": "Gesundheitszentrum",
		"beschreibung": "Medizinische Rundumversorgung: B12, Vitamin D und Vorsorge.",
		"kategorie": "gesundheit",
		"kosten": 850,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.95, 0.95, 0.95),
		"hoehe": 40,
		"wohnraum": 0,
		"produktion": {},
		"verbrauch": {},
		"energie_bedarf": 6,
		"energie_leistung": 0,
		"effekte": {"b12": 3.0, "vitamin_d": 3.0, "mental": 2.0},
		"forschung_noetig": "gesundheitszentren",
		"braucht_strasse": true,
		"baubar": true,
	},
	"b12_klinik": {
		"name": "B12-Klinik",
		"beschreibung": "Spezialisiert auf optimale Vitamin-B12-Versorgung.",
		"kategorie": "gesundheit",
		"kosten": 650,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.9, 0.4, 0.5),
		"hoehe": 36,
		"wohnraum": 0,
		"produktion": {},
		"verbrauch": {},
		"energie_bedarf": 4,
		"energie_leistung": 0,
		"effekte": {"b12": 6.0},
		"forschung_noetig": "b12_optimierung",
		"braucht_strasse": true,
		"baubar": true,
	},
	"sonnen_therapiezentrum": {
		"name": "Sonnen-Therapiezentrum",
		"beschreibung": "Lichttherapie und Vitamin-D-Programme für alle Bürger.",
		"kategorie": "gesundheit",
		"kosten": 650,
		"groesse": Vector2i(1, 1),
		"farbe": Color(1.0, 0.85, 0.4),
		"hoehe": 32,
		"wohnraum": 0,
		"produktion": {},
		"verbrauch": {},
		"energie_bedarf": 5,
		"energie_leistung": 0,
		"effekte": {"vitamin_d": 6.0, "mental": 1.0},
		"forschung_noetig": "vitamin_d_programme",
		"braucht_strasse": true,
		"baubar": true,
	},
	"fitnessstudio": {
		"name": "Veganes Fitnessstudio",
		"beschreibung": "Senkt den Durchschnitts-BMI und hebt die Stimmung.",
		"kategorie": "gesundheit",
		"kosten": 420,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.4, 0.85, 0.85),
		"hoehe": 30,
		"wohnraum": 0,
		"produktion": {},
		"verbrauch": {},
		"energie_bedarf": 4,
		"energie_leistung": 0,
		"effekte": {"bmi": -1.5, "mental": 1.0, "protein": 0.5},
		"forschung_noetig": "",
		"braucht_strasse": true,
		"baubar": true,
	},
	# ----------------------------- FREIZEIT --------------------------------
	"park": {
		"name": "Stadtpark",
		"beschreibung": "Grüne Oase: verbessert mentale Gesundheit und Vitamin D.",
		"kategorie": "freizeit",
		"kosten": 80,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.3, 0.7, 0.3),
		"hoehe": 8,
		"wohnraum": 0,
		"produktion": {},
		"verbrauch": {},
		"energie_bedarf": 0,
		"energie_leistung": 0,
		"effekte": {"mental": 3.0, "vitamin_d": 1.0},
		"forschung_noetig": "",
		"braucht_strasse": false,
		"baubar": true,
	},
	"kulturzentrum": {
		"name": "Kulturzentrum",
		"beschreibung": "Theater, Musik und vegane Kochkurse.",
		"kategorie": "freizeit",
		"kosten": 750,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.8, 0.45, 0.75),
		"hoehe": 44,
		"wohnraum": 0,
		"produktion": {},
		"verbrauch": {},
		"energie_bedarf": 5,
		"energie_leistung": 0,
		"effekte": {"mental": 5.0, "vegan": 1.0},
		"forschung_noetig": "freizeit_kultur",
		"braucht_strasse": true,
		"baubar": true,
	},
	"food_court": {
		"name": "Veganer Food Court",
		"beschreibung": "Streetfood-Paradies. Macht glücklich, erhöht aber den BMI leicht.",
		"kategorie": "freizeit",
		"kosten": 650,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.95, 0.6, 0.5),
		"hoehe": 30,
		"wohnraum": 0,
		"produktion": {"satoshis": 20.0},
		"verbrauch": {"essen": 5.0},
		"energie_bedarf": 5,
		"energie_leistung": 0,
		"effekte": {"mental": 4.0, "vegan": 2.0, "bmi": 1.0},
		"forschung_noetig": "food_courts",
		"braucht_strasse": true,
		"baubar": true,
	},
	"einkaufshalle": {
		"name": "Große Einkaufshalle",
		"beschreibung": "Riesige Halle voller veganer Restaurants und Läden.",
		"kategorie": "freizeit",
		"kosten": 2600,
		"groesse": Vector2i(2, 2),
		"farbe": Color(0.9, 0.5, 0.6),
		"hoehe": 52,
		"wohnraum": 0,
		"produktion": {"satoshis": 120.0},
		"verbrauch": {"essen": 10.0},
		"energie_bedarf": 14,
		"energie_leistung": 0,
		"effekte": {"mental": 6.0, "vegan": 3.0, "bmi": 1.0},
		"forschung_noetig": "einkaufshallen",
		"braucht_strasse": true,
		"baubar": true,
	},
	"bildungszentrum": {
		"name": "Bildungszentrum",
		"beschreibung": "Kampagnen und Kurse rund um Veganismus. Stärkt den veganen Anteil stark.",
		"kategorie": "freizeit",
		"kosten": 950,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.5, 0.85, 0.65),
		"hoehe": 38,
		"wohnraum": 0,
		"produktion": {},
		"verbrauch": {},
		"energie_bedarf": 5,
		"energie_leistung": 0,
		"effekte": {"vegan": 4.0, "mental": 1.0},
		"forschung_noetig": "bildungskampagnen",
		"braucht_strasse": true,
		"baubar": true,
	},
	# ------------------------------ ENERGIE --------------------------------
	"solaranlage": {
		"name": "Solaranlage",
		"beschreibung": "Saubere Energie aus Sonnenlicht (+15 Strom).",
		"kategorie": "energie",
		"kosten": 350,
		"groesse": Vector2i(1, 1),
		"farbe": Color(0.25, 0.35, 0.6),
		"hoehe": 12,
		"wohnraum": 0,
		"produktion": {},
		"verbrauch": {},
		"energie_bedarf": 0,
		"energie_leistung": 15,
		"effekte": {},
		"forschung_noetig": "solarenergie",
		"braucht_strasse": true,
		"baubar": true,
	},
	"atomkraftwerk": {
		"name": "Klimaneutrales Atomkraftwerk",
		"beschreibung": "Riesige, saubere Energiemenge (+120 Strom).",
		"kategorie": "energie",
		"kosten": 3200,
		"groesse": Vector2i(2, 2),
		"farbe": Color(0.6, 0.65, 0.7),
		"hoehe": 80,
		"wohnraum": 0,
		"produktion": {},
		"verbrauch": {"wasser": 10.0},
		"energie_bedarf": 0,
		"energie_leistung": 120,
		"effekte": {},
		"forschung_noetig": "atomkraft",
		"braucht_strasse": true,
		"baubar": true,
	},
}

## Reihenfolge der Kategorien im Baumenü.
const BUILD_CATEGORIES := [
	{"id": "strasse", "name": "Straßen"},
	{"id": "wohnen", "name": "Wohnen"},
	{"id": "wasser", "name": "Wasser"},
	{"id": "essen", "name": "Essen"},
	{"id": "wirtschaft", "name": "Wirtschaft"},
	{"id": "forschung", "name": "Forschung"},
	{"id": "gesundheit", "name": "Gesundheit"},
	{"id": "freizeit", "name": "Freizeit"},
	{"id": "energie", "name": "Energie"},
]

# ---------------------------------------------------------------------------
# FORSCHUNG
# ---------------------------------------------------------------------------
## Jede Forschung hat:
##   name / beschreibung - Anzeige
##   kategorie           - "landwirtschaft", "gesellschaft", "gesundheit", "energie"
##   kosten              - Technikpunkte
##   voraussetzung       - ID einer anderen Forschung ("" = keine)
##   schaltet_frei       - Gebäude-ID, die freigeschaltet wird ("" = keine)
##   effekte             - dauerhafte Boni auf die Simulation:
##       protein_bonus, b12_bonus, vitamin_d_bonus, mental_bonus  (flache Punkte)
##       bmi_delta         (verschiebt den Ziel-BMI, negativ = gesünder)
##       vegan_bonus       (täglicher Bonus auf den veganen Anteil)
##       produktions_mult  (z.B. 0.05 = +5 % Gesamtproduktion)
##       energie_spar_mult (z.B. 0.15 = -15 % Strombedarf)
##       strassen_rabatt   (z.B. 0.5 = Straßen kosten 50 % weniger)

const RESEARCH := {
	# ------------------- Landwirtschaft und Ernährung ----------------------
	"hydro_farming": {
		"name": "Aqua- / Hydro-Farming",
		"beschreibung": "Schaltet die wassersparende Hydro-Farm frei.",
		"kategorie": "landwirtschaft",
		"kosten": 25,
		"voraussetzung": "",
		"schaltet_frei": "hydro_farm",
		"effekte": {},
	},
	"indoor_farming": {
		"name": "Indoor Farming",
		"beschreibung": "Schaltet die Indoor-Vertikalfarm frei.",
		"kategorie": "landwirtschaft",
		"kosten": 60,
		"voraussetzung": "hydro_farming",
		"schaltet_frei": "indoor_farm",
		"effekte": {},
	},
	"auto_farms": {
		"name": "Automatisierte Urbanfarmen",
		"beschreibung": "Schaltet die vollautomatische Urbanfarm frei.",
		"kategorie": "landwirtschaft",
		"kosten": 140,
		"voraussetzung": "indoor_farming",
		"schaltet_frei": "auto_farm",
		"effekte": {"produktions_mult": 0.05},
	},
	"protein_quellen": {
		"name": "Verbesserte vegane Proteinquellen",
		"beschreibung": "Schaltet das Protein-Labor frei und verbessert die Proteinversorgung dauerhaft.",
		"kategorie": "landwirtschaft",
		"kosten": 50,
		"voraussetzung": "",
		"schaltet_frei": "protein_labor",
		"effekte": {"protein_bonus": 8.0},
	},
	"fleischersatz": {
		"name": "Bessere Fleischersatzprodukte",
		"beschreibung": "Schaltet die Fleischersatz-Fabrik frei und stärkt den veganen Anteil.",
		"kategorie": "landwirtschaft",
		"kosten": 90,
		"voraussetzung": "protein_quellen",
		"schaltet_frei": "fleischersatz_fabrik",
		"effekte": {"vegan_bonus": 0.1},
	},
	"kaeseersatz": {
		"name": "Echter Käseersatz",
		"beschreibung": "Der Durchbruch: veganer Käse, der schmeckt wie das Original! Schaltet die Käseersatz-Manufaktur frei.",
		"kategorie": "landwirtschaft",
		"kosten": 160,
		"voraussetzung": "fleischersatz",
		"schaltet_frei": "kaese_manufaktur",
		"effekte": {"vegan_bonus": 0.2, "mental_bonus": 3.0},
	},
	"gesunde_ernaehrung": {
		"name": "Gesündere vegane Ernährung",
		"beschreibung": "Vollwertige Rezepte senken den BMI und verbessern die Proteinversorgung.",
		"kategorie": "landwirtschaft",
		"kosten": 70,
		"voraussetzung": "",
		"schaltet_frei": "",
		"effekte": {"bmi_delta": -1.0, "protein_bonus": 5.0},
	},
	"bmi_balancing": {
		"name": "BMI-Balancing",
		"beschreibung": "Ernährungsforschung stabilisiert den Durchschnitts-BMI.",
		"kategorie": "landwirtschaft",
		"kosten": 130,
		"voraussetzung": "gesunde_ernaehrung",
		"schaltet_frei": "",
		"effekte": {"bmi_delta": -1.5},
	},
	# ------------------- Gesellschaft und Zufriedenheit ---------------------
	"food_courts": {
		"name": "Vegane Food Courts",
		"beschreibung": "Schaltet den veganen Food Court frei.",
		"kategorie": "gesellschaft",
		"kosten": 40,
		"voraussetzung": "",
		"schaltet_frei": "food_court",
		"effekte": {},
	},
	"einkaufshallen": {
		"name": "Große Einkaufshallen",
		"beschreibung": "Schaltet die große Einkaufshalle mit vielen veganen Restaurants frei.",
		"kategorie": "gesellschaft",
		"kosten": 120,
		"voraussetzung": "food_courts",
		"schaltet_frei": "einkaufshalle",
		"effekte": {},
	},
	"freizeit_kultur": {
		"name": "Freizeit- und Kulturangebote",
		"beschreibung": "Schaltet das Kulturzentrum frei.",
		"kategorie": "gesellschaft",
		"kosten": 50,
		"voraussetzung": "",
		"schaltet_frei": "kulturzentrum",
		"effekte": {"mental_bonus": 2.0},
	},
	"bildungskampagnen": {
		"name": "Bildungskampagnen für Veganismus",
		"beschreibung": "Schaltet das Bildungszentrum frei und stärkt den veganen Anteil.",
		"kategorie": "gesellschaft",
		"kosten": 80,
		"voraussetzung": "",
		"schaltet_frei": "bildungszentrum",
		"effekte": {"vegan_bonus": 0.1},
	},
	"lebensqualitaet": {
		"name": "Bessere Lebensqualität",
		"beschreibung": "Stadtweite Verbesserungen. Schaltet die Arkologie frei.",
		"kategorie": "gesellschaft",
		"kosten": 150,
		"voraussetzung": "freizeit_kultur",
		"schaltet_frei": "arkologie",
		"effekte": {"mental_bonus": 5.0},
	},
	# ----------------------------- Gesundheit ------------------------------
	"b12_optimierung": {
		"name": "B12-Optimierung",
		"beschreibung": "Schaltet die B12-Klinik frei und verbessert die B12-Versorgung dauerhaft.",
		"kategorie": "gesundheit",
		"kosten": 45,
		"voraussetzung": "",
		"schaltet_frei": "b12_klinik",
		"effekte": {"b12_bonus": 10.0},
	},
	"vitamin_d_programme": {
		"name": "Vitamin-D-Programme",
		"beschreibung": "Schaltet das Sonnen-Therapiezentrum frei und verbessert Vitamin D dauerhaft.",
		"kategorie": "gesundheit",
		"kosten": 45,
		"voraussetzung": "",
		"schaltet_frei": "sonnen_therapiezentrum",
		"effekte": {"vitamin_d_bonus": 10.0},
	},
	"gesundheitszentren": {
		"name": "Gesundheitszentren",
		"beschreibung": "Schaltet das Gesundheitszentrum frei.",
		"kategorie": "gesundheit",
		"kosten": 90,
		"voraussetzung": "",
		"schaltet_frei": "gesundheitszentrum",
		"effekte": {},
	},
	"mentale_programme": {
		"name": "Mentale Gesundheitsprogramme",
		"beschreibung": "Therapie- und Achtsamkeitsprogramme für die ganze Stadt.",
		"kategorie": "gesundheit",
		"kosten": 130,
		"voraussetzung": "gesundheitszentren",
		"schaltet_frei": "",
		"effekte": {"mental_bonus": 8.0},
	},
	# ------------------------ Energie und Infrastruktur ---------------------
	"solarenergie": {
		"name": "Solarenergie",
		"beschreibung": "Schaltet die Solaranlage frei.",
		"kategorie": "energie",
		"kosten": 20,
		"voraussetzung": "",
		"schaltet_frei": "solaranlage",
		"effekte": {},
	},
	"atomkraft": {
		"name": "Klimaneutrale Atomkraft",
		"beschreibung": "Schaltet das klimaneutrale Atomkraftwerk frei.",
		"kategorie": "energie",
		"kosten": 180,
		"voraussetzung": "solarenergie",
		"schaltet_frei": "atomkraftwerk",
		"effekte": {},
	},
	"endlager": {
		"name": "Sicheres Endlager",
		"beschreibung": "Atomkraft ohne schlechtes Gewissen: +5 % Gesamtproduktion.",
		"kategorie": "energie",
		"kosten": 220,
		"voraussetzung": "atomkraft",
		"schaltet_frei": "",
		"effekte": {"produktions_mult": 0.05},
	},
	"wassergewinnung": {
		"name": "Nachhaltige Wassergewinnung",
		"beschreibung": "Schaltet das nachhaltige Wasserwerk frei.",
		"kategorie": "energie",
		"kosten": 60,
		"voraussetzung": "",
		"schaltet_frei": "wasserwerk",
		"effekte": {},
	},
	"stromnetze": {
		"name": "Effiziente Stromnetze",
		"beschreibung": "Alle Gebäude verbrauchen 15 % weniger Strom.",
		"kategorie": "energie",
		"kosten": 100,
		"voraussetzung": "solarenergie",
		"schaltet_frei": "",
		"effekte": {"energie_spar_mult": 0.15},
	},
	"transportwege": {
		"name": "Bessere Straßen und Transportwege",
		"beschreibung": "Straßen kosten 50 % weniger, Gesamtproduktion +5 %.",
		"kategorie": "energie",
		"kosten": 80,
		"voraussetzung": "",
		"schaltet_frei": "",
		"effekte": {"strassen_rabatt": 0.5, "produktions_mult": 0.05},
	},
}

const RESEARCH_CATEGORIES := [
	{"id": "landwirtschaft", "name": "Landwirtschaft & Ernährung"},
	{"id": "gesellschaft", "name": "Gesellschaft & Zufriedenheit"},
	{"id": "gesundheit", "name": "Gesundheit"},
	{"id": "energie", "name": "Energie & Infrastruktur"},
]

# ---------------------------------------------------------------------------
# STARTCHARAKTERE / LANDESCHEFS
# ---------------------------------------------------------------------------
## Modifikatoren (alle optional):
##   vegan_verlust_mult     - multipliziert NEGATIVE Veränderungen des veganen
##                            Anteils (0.5 = sinkt nur halb so schnell)
##   vegan_gebaeude_mult    - multipliziert den Vegan-Effekt von Gebäuden
##   protein_bonus, mental_bonus, gesundheits_bonus - flache Boni auf Zielwerte
##   gesundheits_gebaeude_mult - multipliziert Effekte von Gesundheitsgebäuden
##   essens_verbrauch_mult  - multipliziert den Essensverbrauch der Bürger
##   technik_mult           - multipliziert die Technikpunkte-Produktion
##   start_satoshis_bonus   - wird zu den Start-Satoshis addiert (auch negativ)
##   mangel_mental_mult     - multipliziert Mental-Strafen bei Knappheit

const CHARACTERS := {
	"militante_veganerin": {
		"name": "Die Militante Veganerin",
		"beschreibung": "Kompromisslose Aktivistin mit enormem Einfluss.",
		"boni": [
			"Veganer Anteil sinkt nur halb so schnell",
			"Bildungs- und Vegan-Kampagnen sind 50 % effektiver",
		],
		"nachteile": [
			"Bei Essens- oder Wasserknappheit leidet die Stimmung doppelt so stark",
		],
		"modifikatoren": {
			"vegan_verlust_mult": 0.5,
			"vegan_gebaeude_mult": 1.5,
			"mangel_mental_mult": 2.0,
		},
	},
	"vegan_gains": {
		"name": "Vegan Gains",
		"beschreibung": "Fitness-Influencer mit Fokus auf Kraft und Gesundheit.",
		"boni": [
			"+10 Proteinversorgung dauerhaft",
			"+5 auf alle Gesundheits-Zielwerte",
			"Gesundheits- und Fitnessgebäude sind 50 % effektiver",
		],
		"nachteile": [
			"Bürger essen 15 % mehr (höherer Essensverbrauch)",
		],
		"modifikatoren": {
			"protein_bonus": 10.0,
			"gesundheits_bonus": 5.0,
			"gesundheits_gebaeude_mult": 1.5,
			"essens_verbrauch_mult": 1.15,
		},
	},
	"earthling_ed": {
		"name": "Earthling Ed",
		"beschreibung": "Ruhiger, überzeugender Redner und Pädagoge.",
		"boni": [
			"+10 mentale Gesundheit dauerhaft",
			"Veganer Anteil sinkt 25 % langsamer",
		],
		"nachteile": [
			"Forschung ist 15 % langsamer",
			"300 Satoshis weniger Startkapital",
		],
		"modifikatoren": {
			"mental_bonus": 10.0,
			"vegan_verlust_mult": 0.75,
			"technik_mult": 0.85,
			"start_satoshis_bonus": -300.0,
		},
	},
}

# ---------------------------------------------------------------------------
# REGIONEN (BUNDESLÄNDER)
# ---------------------------------------------------------------------------
## Deutschland wird Region für Region eingenommen.
## Jede Region braucht: Satoshis + eine Mindestbevölkerung.
## Jede neue Region vergrößert außerdem das bebaubare Stadtgebiet.

const REGIONS := [
	{"id": "berlin", "name": "Berlin", "kosten": 0, "min_bevoelkerung": 0},
	{"id": "brandenburg", "name": "Brandenburg", "kosten": 1500, "min_bevoelkerung": 40},
	{"id": "mecklenburg", "name": "Mecklenburg-Vorpommern", "kosten": 2200, "min_bevoelkerung": 60},
	{"id": "sachsen", "name": "Sachsen", "kosten": 3000, "min_bevoelkerung": 80},
	{"id": "sachsen_anhalt", "name": "Sachsen-Anhalt", "kosten": 3800, "min_bevoelkerung": 100},
	{"id": "thueringen", "name": "Thüringen", "kosten": 4600, "min_bevoelkerung": 120},
	{"id": "schleswig", "name": "Schleswig-Holstein", "kosten": 5500, "min_bevoelkerung": 150},
	{"id": "hamburg", "name": "Hamburg", "kosten": 6500, "min_bevoelkerung": 180},
	{"id": "bremen", "name": "Bremen", "kosten": 7500, "min_bevoelkerung": 210},
	{"id": "niedersachsen", "name": "Niedersachsen", "kosten": 9000, "min_bevoelkerung": 250},
	{"id": "hessen", "name": "Hessen", "kosten": 10500, "min_bevoelkerung": 300},
	{"id": "rheinland_pfalz", "name": "Rheinland-Pfalz", "kosten": 12000, "min_bevoelkerung": 350},
	{"id": "saarland", "name": "Saarland", "kosten": 13500, "min_bevoelkerung": 400},
	{"id": "nrw", "name": "Nordrhein-Westfalen", "kosten": 16000, "min_bevoelkerung": 460},
	{"id": "baden_wuerttemberg", "name": "Baden-Württemberg", "kosten": 19000, "min_bevoelkerung": 530},
	{"id": "bayern", "name": "Bayern", "kosten": 23000, "min_bevoelkerung": 600},
]

# ---------------------------------------------------------------------------
# HILFSFUNKTIONEN (reine Daten-Abfragen)
# ---------------------------------------------------------------------------

## Liefert die Daten eines Gebäudes (oder ein leeres Dictionary).
func get_building(building_id: String) -> Dictionary:
	return BUILDINGS.get(building_id, {})


## Liefert die Daten einer Forschung (oder ein leeres Dictionary).
func get_research(research_id: String) -> Dictionary:
	return RESEARCH.get(research_id, {})


## Liefert die Daten eines Charakters (oder ein leeres Dictionary).
func get_character(character_id: String) -> Dictionary:
	return CHARACTERS.get(character_id, {})


## Liefert alle vom Spieler baubaren Gebäude einer Kategorie.
func get_buildings_in_category(category: String) -> Array:
	var result: Array = []
	for id in BUILDINGS:
		var data: Dictionary = BUILDINGS[id]
		if data["kategorie"] == category and data["baubar"]:
			result.append(id)
	result.sort_custom(func(a, b): return BUILDINGS[a]["kosten"] < BUILDINGS[b]["kosten"])
	return result


## Liefert alle Forschungen einer Kategorie, billigste zuerst.
func get_research_in_category(category: String) -> Array:
	var result: Array = []
	for id in RESEARCH:
		if RESEARCH[id]["kategorie"] == category:
			result.append(id)
	result.sort_custom(func(a, b): return RESEARCH[a]["kosten"] < RESEARCH[b]["kosten"])
	return result
