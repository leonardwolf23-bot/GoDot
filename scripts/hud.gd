extends Control

@onready var grid: CityGrid = get_node("/root/Main/CityGrid")
@onready var _status: Label = $Panel/VBox/StatusLabel


func _ready() -> void:
	var row := $Panel/VBox/ButtonRow
	for i in range(BuildingData.get_all_ids().size()):
		var id: String = BuildingData.get_all_ids()[i]
		var btn: Button = row.get_child(i) as Button
		if btn:
			btn.text = BuildingData.get_building(id)["name"]
			btn.pressed.connect(func(): grid.start_build_mode(id))
	$Panel/VBox/CancelButton.pressed.connect(func(): grid.cancel_build_mode())
	update_selection("")


func update_selection(building_id: String) -> void:
	if building_id == "":
		_status.text = "Taste 1/2/3 = Gebäude wählen | Linksklick = platzieren | Rechtsklick = abbrechen"
	else:
		_status.text = "Bauen: %s | Linksklick platzieren | Rechtsklick abbrechen" \
				% BuildingData.get_building(building_id)["name"]
