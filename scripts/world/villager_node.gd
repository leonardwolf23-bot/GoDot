class_name VillagerNode
extends Node2D
## Sichtbarer Bürger – läuft orthogonal, liefert Waren ins Lagerhaus.

const VILLAGER_ROOT := "res://assets/test/villager/"
const WALK_FPS := 10.0
const MOVE_SPEED := 64.0

const GRID_DELTA_TO_DIR := {
	Vector2i(1, 0): "east",
	Vector2i(-1, 0): "west",
	Vector2i(0, 1): "south",
	Vector2i(0, -1): "north",
}

signal arrived
signal delivery_finished(job: Dictionary)

var citizen_id: int = -1
var _grid: CityGrid = null
var _sprite: AnimatedSprite2D = null
var _badge: Sprite2D = null
var _cargo_icon: Sprite2D = null
var _path: Array[Vector2i] = []
var _path_index: int = 0
var _target_world: Vector2 = Vector2.ZERO
var _current_dir: String = "south"
var _is_moving: bool = false
var _profession: String = GameData.PROFESSION_VILLAGER

var _delivery_job: Dictionary = {}
var _delivery_active: bool = false
var _has_cargo: bool = false
var _pickup_cell: Vector2i = Vector2i.ZERO
var _dest_cell: Vector2i = Vector2i.ZERO

static var _shared_sprite_frames: SpriteFrames = null


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _get_sprite_frames()
	_sprite.scale = Vector2(0.55, 0.55)
	_sprite.offset = Vector2(0, -8)
	add_child(_sprite)
	_play_idle()

	_badge = Sprite2D.new()
	_badge.position = Vector2(0, -34)
	_badge.scale = Vector2(0.1, 0.1)
	_badge.visible = false
	add_child(_badge)

	_cargo_icon = Sprite2D.new()
	_cargo_icon.position = Vector2(14, -30)
	_cargo_icon.scale = Vector2(0.11, 0.11)
	_cargo_icon.visible = false
	add_child(_cargo_icon)


func setup(grid: CityGrid, p_citizen_id: int) -> void:
	_grid = grid
	citizen_id = p_citizen_id


func set_profession(profession: String) -> void:
	_profession = profession
	_update_badge()


func is_delivering() -> bool:
	return _delivery_active


func get_delivery_job() -> Dictionary:
	return _delivery_job


func start_delivery_job(job: Dictionary, pickup_cell: Vector2i, dest_cell: Vector2i) -> void:
	_delivery_job = job
	_pickup_cell = pickup_cell
	_dest_cell = dest_cell
	_delivery_active = true
	_has_cargo = false
	_cargo_icon.visible = false
	walk_to_cell(pickup_cell)


func on_delivery_arrived() -> void:
	if not _delivery_active or _delivery_job.is_empty():
		return

	if not _has_cargo:
		var res: String = str(_delivery_job.get("resource", ""))
		var src: Vector2i = _delivery_job.get("source_cell", Vector2i.ZERO)
		var taken: float = GameState.take_pending_from_building(
				src, res, _delivery_job.get("amount", 0.0))
		if taken <= 0.0:
			taken = _delivery_job.get("amount", 0.0)
		_delivery_job["amount"] = taken
		_set_cargo(res)
		_has_cargo = true
		walk_to_cell(_dest_cell)
		return

	_clear_cargo()
	var finished: Dictionary = _delivery_job
	_delivery_job = {}
	_delivery_active = false
	delivery_finished.emit(finished)


func _set_cargo(resource_id: String) -> void:
	var tex := _load_texture_safe(_resource_icon_path(resource_id))
	_cargo_icon.texture = tex
	_cargo_icon.visible = tex != null


func _clear_cargo() -> void:
	_has_cargo = false
	_cargo_icon.visible = false


func _resource_icon_path(resource_id: String) -> String:
	if resource_id in ["holz", "steine", "essen", "wasser", "brot", "tofu"]:
		return "res://assets/icons/%s.png" % resource_id
	if GameData.CROP_DATA.has(resource_id):
		return "res://assets/icons/essen.png"
	return "res://assets/icons/essen.png"


func _update_badge() -> void:
	match _profession:
		GameData.PROFESSION_BUILDER:
			_badge.texture = _load_texture_safe("res://assets/buildings/baustelle.png")
			_badge.visible = _badge.texture != null
		GameData.PROFESSION_FARMER:
			_badge.texture = _load_texture_safe("res://assets/icons/essen.png")
			_badge.visible = _badge.texture != null
		_:
			_badge.visible = false


func is_moving() -> bool:
	return _is_moving


func walk_path(path: Array[Vector2i]) -> void:
	if path.is_empty() or _grid == null:
		arrived.emit()
		return
	_path = path
	_path_index = 0
	_is_moving = true
	for i in _path.size():
		if _path[i] == _grid.world_to_cell(position):
			_path_index = i
			break
	if _path_index >= _path.size() - 1:
		_stop_moving()
		arrived.emit()
		return
	_path_index += 1
	_target_world = _grid.cell_to_world_center(_path[_path_index])
	_set_walk_direction(_path[_path_index] - _path[_path_index - 1])
	_play_walk()


func walk_to_cell(cell: Vector2i) -> void:
	var start := _grid.world_to_cell(position)
	var path := _grid.find_path_walkable(start, cell)
	if path.is_empty() and start != cell:
		position = _grid.cell_to_world_center(cell)
		_stop_moving()
		arrived.emit()
		return
	if path.is_empty():
		path = [start, cell]
	walk_path(path)


func _process(delta: float) -> void:
	if not _is_moving or _path.is_empty():
		return

	var to_target := _target_world - position
	if to_target.length() < 4.0:
		if _path_index >= _path.size() - 1:
			_stop_moving()
			arrived.emit()
			return
		_path_index += 1
		_target_world = _grid.cell_to_world_center(_path[_path_index])
		_set_walk_direction(_path[_path_index] - _path[_path_index - 1])
		return

	position += to_target.normalized() * MOVE_SPEED * delta
	z_index = int(position.y) + 50


func _stop_moving() -> void:
	_is_moving = false
	_path.clear()
	_play_idle()


func _set_walk_direction(grid_delta: Vector2i) -> void:
	var dir: String = GRID_DELTA_TO_DIR.get(grid_delta, _current_dir)
	if dir == _current_dir and _sprite.is_playing():
		return
	_current_dir = dir
	_play_walk()


func _play_walk() -> void:
	var anim_name: String = "walking_%s" % _current_dir.replace("-", "_")
	if _sprite.sprite_frames.has_animation(anim_name):
		_sprite.play(anim_name)


func _play_idle() -> void:
	_sprite.stop()
	var anim_name: String = "idle_%s" % _current_dir.replace("-", "_")
	if _sprite.sprite_frames.has_animation(anim_name):
		_sprite.animation = anim_name
		_sprite.frame = 0


static func _get_sprite_frames() -> SpriteFrames:
	if _shared_sprite_frames != null:
		return _shared_sprite_frames

	var frames := SpriteFrames.new()
	var directions: Array[String] = [
		"south", "south-east", "east", "north-east",
		"north", "north-west", "west", "south-west",
	]
	for dir in directions:
		var dir_key: String = dir.replace("-", "_")
		var walk_anim: String = "walking_%s" % dir_key
		frames.add_animation(walk_anim)
		frames.set_animation_speed(walk_anim, WALK_FPS)
		frames.set_animation_loop(walk_anim, true)
		for i in range(6):
			var frame_path: String = "%sVillager/animations/walking/%s/frame_%03d.png" \
					% [VILLAGER_ROOT, dir, i]
			var tex: Texture2D = _load_texture_safe(frame_path)
			if tex != null:
				frames.add_frame(walk_anim, tex)

		var idle_anim: String = "idle_%s" % dir_key
		frames.add_animation(idle_anim)
		frames.set_animation_speed(idle_anim, 1.0)
		frames.set_animation_loop(idle_anim, true)
		var idle_tex: Texture2D = _load_texture_safe("%sVillager/rotations/%s.png"
				% [VILLAGER_ROOT, dir])
		if idle_tex != null:
			frames.add_frame(idle_anim, idle_tex)

	_shared_sprite_frames = frames
	return frames


static func _load_texture_safe(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			return ImageTexture.create_from_image(img)
	return null
