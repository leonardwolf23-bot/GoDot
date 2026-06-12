class_name VillagerNode
extends Node2D
## Ein Dorfbewohner, der über Straßen läuft und Lieferungen transportiert.

const VILLAGER_ROOT := "res://assets/test/villager/"
const WALK_FPS := 10.0
const MOVE_SPEED := 52.0

## Iso-Rasterbewegung -> 8 PixelLab-Richtungen.
const GRID_DELTA_TO_DIR := {
	Vector2i(1, 0): "south-east",
	Vector2i(-1, 0): "north-west",
	Vector2i(0, 1): "south-west",
	Vector2i(0, -1): "north-east",
}

signal delivery_finished(job: Dictionary)

var _grid: CityGrid = null
var _sprite: AnimatedSprite2D = null
var _cargo_icon: Sprite2D = null
var _path: Array[Vector2i] = []
var _path_index: int = 0
var _pickup_index: int = -1
var _target_world: Vector2 = Vector2.ZERO
var _current_dir: String = "south"
var _is_busy: bool = false
var _active_job: Dictionary = {}

static var _shared_sprite_frames: SpriteFrames = null


func _ready() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _get_sprite_frames()
	_sprite.scale = Vector2(0.55, 0.55)
	_sprite.offset = Vector2(0, -8)
	add_child(_sprite)
	_play_idle()

	_cargo_icon = Sprite2D.new()
	_cargo_icon.visible = false
	_cargo_icon.position = Vector2(0, -28)
	_cargo_icon.scale = Vector2(0.12, 0.12)
	var food_tex := _load_texture_safe("res://assets/icons/essen.png")
	if food_tex != null:
		_cargo_icon.texture = food_tex
	add_child(_cargo_icon)


func setup(grid: CityGrid) -> void:
	_grid = grid


func is_available() -> bool:
	return not _is_busy


func start_delivery(job: Dictionary, path: Array[Vector2i],
		pickup_cell: Vector2i = Vector2i(-1, -1)) -> void:
	if path.is_empty() or _grid == null:
		delivery_finished.emit(job)
		return

	_active_job = job
	_path = path
	_path_index = 0
	_pickup_index = -1
	for i in path.size():
		if path[i] == pickup_cell:
			_pickup_index = i
			break

	_is_busy = true
	_path_index = 0
	for i in _path.size():
		if _path[i] == _grid.world_to_cell(position):
			_path_index = i
			break
	_cargo_icon.visible = _pickup_index >= 0 and _path_index >= _pickup_index

	if _path_index >= _path.size() - 1:
		_finish_delivery()
		return

	_path_index += 1
	_target_world = _grid.cell_to_world(_path[_path_index])
	_set_walk_direction(_path[_path_index] - _path[_path_index - 1])
	_play_walk()
	_update_depth()


func _process(delta: float) -> void:
	if not _is_busy or _path.is_empty():
		return

	var to_target := _target_world - position
	if to_target.length() < 3.0:
		if _path_index >= _path.size() - 1:
			_finish_delivery()
			return
		if _pickup_index == _path_index:
			_cargo_icon.visible = true
		_path_index += 1
		_target_world = _grid.cell_to_world(_path[_path_index])
		_set_walk_direction(_path[_path_index] - _path[_path_index - 1])
		return

	position += to_target.normalized() * MOVE_SPEED * delta
	_update_depth()


func _finish_delivery() -> void:
	_is_busy = false
	_cargo_icon.visible = false
	_path.clear()
	_play_idle()
	var finished_job := _active_job
	_active_job = {}
	delivery_finished.emit(finished_job)


func _set_walk_direction(grid_delta: Vector2i) -> void:
	var dir: String = GRID_DELTA_TO_DIR.get(grid_delta, _current_dir)
	if dir == _current_dir and _sprite.is_playing():
		return
	_current_dir = dir
	_play_walk()


func _play_walk() -> void:
	var anim_name := "walking_%s" % _current_dir.replace("-", "_")
	if _sprite.sprite_frames.has_animation(anim_name):
		_sprite.play(anim_name)


func _play_idle() -> void:
	_sprite.stop()
	var anim_name := "idle_%s" % _current_dir.replace("-", "_")
	if _sprite.sprite_frames.has_animation(anim_name):
		_sprite.animation = anim_name
		_sprite.frame = 0


func _update_depth() -> void:
	z_index = int(position.y) + 40


static func _get_sprite_frames() -> SpriteFrames:
	if _shared_sprite_frames != null:
		return _shared_sprite_frames

	var frames := SpriteFrames.new()
	var directions := [
		"south", "south-east", "east", "north-east",
		"north", "north-west", "west", "south-west",
	]
	for dir in directions:
		var dir_key := dir.replace("-", "_")

		var walk_anim := "walking_%s" % dir_key
		frames.add_animation(walk_anim)
		frames.set_animation_speed(walk_anim, WALK_FPS)
		frames.set_animation_loop(walk_anim, true)
		for i in range(6):
			var frame_path := "%sVillager/animations/walking/%s/frame_%03d.png" \
					% [VILLAGER_ROOT, dir, i]
			var tex := _load_texture_safe(frame_path)
			if tex != null:
				frames.add_frame(walk_anim, tex)

		var idle_anim := "idle_%s" % dir_key
		frames.add_animation(idle_anim)
		frames.set_animation_speed(idle_anim, 1.0)
		frames.set_animation_loop(idle_anim, true)
		var idle_tex := _load_texture_safe("%sVillager/rotations/%s.png"
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
