extends CharacterBody2D
class_name skeleton

const BONES_DAMAGE_STREAM := preload("res://assets-mobs&entities/Slime&Skeleton/bones.ogg")
const SKELETON_KILLS_META_KEY := "skeleton_kills"
const SKELETON_ENDING_DONE_META_KEY := "skeleton_ending_done"
const TARGET_SCENE_META_KEY := "target_scene_after_cutscene"
const CUTSCENE_VIDEO_PATH_META_KEY := "cutscene_video_path"
const INTRO_VIDEO_SCENE_PATH := "res://cutscene/video_intro.tscn"
const SKELETON_ENDING_VIDEO_PATH := "res://cutscene/video3.ogv"
const MENU_SCENE_PATH := "res://ui/scenes/main_hud.tscn"
const INITIAL_TIMESTAMP_MS := -1_000_000_000

var _is_dead: bool = false
var _player_ref: Character = null
var _last_direction := Vector2.DOWN
var _current_health: int = 0
var _last_attack_time_ms: int = INITIAL_TIMESTAMP_MS
var _bones_damage_player: AudioStreamPlayer2D = null
var _should_start_ending_cutscene: bool = false
var _death_cutscene_started: bool = false

@export_category("Variables")
@export var _max_health: int = 100
@export var _attack_damage: int = 15
@export var _attack_range: float = 20.0
@export var _attack_cooldown: float = 0.6
@export var _move_speed: float = 35.0

@export_category("Objects")
@export var _animation: AnimationPlayer = null
@export var _health_bar: ProgressBar = null

func _ready() -> void:
	_current_health = _max_health
	_sync_health_bar()
	_ensure_bones_damage_player()
	_ensure_skeleton_progress_meta()

func _ensure_skeleton_progress_meta() -> void:
	var tree := get_tree()
	if tree == null:
		return

	if not tree.has_meta(SKELETON_KILLS_META_KEY):
		tree.set_meta(SKELETON_KILLS_META_KEY, 0)

	if not tree.has_meta(SKELETON_ENDING_DONE_META_KEY):
		tree.set_meta(SKELETON_ENDING_DONE_META_KEY, false)

func _ensure_bones_damage_player() -> void:
	if _bones_damage_player != null and is_instance_valid(_bones_damage_player):
		return

	_bones_damage_player = AudioStreamPlayer2D.new()
	_bones_damage_player.name = "BonesDamageSfxPlayer"
	_bones_damage_player.stream = BONES_DAMAGE_STREAM
	_bones_damage_player.volume_db = -6.0
	_bones_damage_player.max_distance = 240.0
	add_child(_bones_damage_player)

func _play_bones_damage_sfx() -> void:
	if _bones_damage_player == null or not is_instance_valid(_bones_damage_player):
		_ensure_bones_damage_player()

	if _bones_damage_player == null:
		return

	if _bones_damage_player.playing:
		_bones_damage_player.stop()

	_bones_damage_player.play()

func _on_detection_area_body_entered(body: Node) -> void:
	if body.is_in_group("character"):
		_player_ref = body as Character

func _on_detection_area_body_exited(body: Node) -> void:
	if body.is_in_group("character"):
		_player_ref = null

func _physics_process(_delta: float) -> void:
	if _is_dead:
		return

	if _player_ref != null:
		if _player_ref.is_dead:
			velocity = Vector2.ZERO
		else:
			var direction := global_position.direction_to(_player_ref.global_position)
			var distance := global_position.distance_to(_player_ref.global_position)

			if distance <= _attack_range:
				_try_attack_player()

			velocity = direction * _move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_animate()

func _animate() -> void:
	if _is_dead:
		_animation.play("idle_dead")
		return

	if velocity.length() > 1:
		_last_direction = velocity.normalized()

	var direction := _last_direction

	if velocity.length() < 1:
		_play_idle_animation(direction)
		return

	_play_walk_animation(direction)

func _play_idle_animation(dir: Vector2) -> void:
	if abs(dir.y) > abs(dir.x):
		if dir.y < 0:
			_animation.play("idle_back")
		else:
			_animation.play("idle_front")
		return

	if dir.x < 0:
		_animation.play("idle_left")
	else:
		_animation.play("idle_right")

func _play_walk_animation(dir: Vector2) -> void:
	if abs(dir.y) > abs(dir.x):
		if dir.y < 0:
			_animation.play("walk_back")
		else:
			_animation.play("walk_front")
		return

	if dir.x < 0:
		_animation.play("walk_left")
	else:
		_animation.play("walk_right")

func _try_attack_player() -> void:
	var cooldown_ms: int = int(_attack_cooldown * 1000.0)
	var current_time_ms: int = Time.get_ticks_msec()

	if current_time_ms - _last_attack_time_ms < cooldown_ms:
		return

	_last_attack_time_ms = current_time_ms

	if _player_ref != null and _player_ref.has_method("update_health"):
		_player_ref.update_health(_attack_damage)

func update_health(_damage: int = 1) -> void:
	if _is_dead:
		return

	if _damage > 0:
		_play_bones_damage_sfx()

	_current_health = max(0, _current_health - _damage)
	_sync_health_bar()

	if _current_health <= 0:
		_die()

func _sync_health_bar() -> void:
	if _health_bar == null:
		return

	_health_bar.max_value = float(_max_health)
	_health_bar.value = float(_current_health)

func _die() -> void:
	_is_dead = true
	_current_health = 0
	_sync_health_bar()
	_animation.play("idle_dead")

	var tree := get_tree()
	if tree == null:
		return

	if bool(tree.get_meta(SKELETON_ENDING_DONE_META_KEY, false)):
		return

	var kills := int(tree.get_meta(SKELETON_KILLS_META_KEY, 0)) + 1
	tree.set_meta(SKELETON_KILLS_META_KEY, kills)

	if kills >= 3:
		_should_start_ending_cutscene = true
		tree.set_meta(SKELETON_ENDING_DONE_META_KEY, true)

func _on_animation_finished(_anim_name: String) -> void:
	if _is_dead:
		if _should_start_ending_cutscene:
			_start_ending_cutscene()
			return

		queue_free()

func _start_ending_cutscene() -> void:
	if _death_cutscene_started:
		return

	_death_cutscene_started = true
	var tree := get_tree()
	if tree == null:
		queue_free()
		return

	tree.set_meta(TARGET_SCENE_META_KEY, MENU_SCENE_PATH)
	tree.set_meta(CUTSCENE_VIDEO_PATH_META_KEY, SKELETON_ENDING_VIDEO_PATH)
	tree.change_scene_to_file(INTRO_VIDEO_SCENE_PATH)
