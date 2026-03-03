extends CharacterBody2D
class_name lobisomen

const HEAL_DROP_SCENE := preload("res://assets-mobs&entities/Items/heal_drop.tscn")
const BOSS_FIGHT_STREAM := preload("res://assets-mobs&entities/lobisomen/bossfiggt.ogg")
const WOLF_DAMAGE_STREAM := preload("res://assets-mobs&entities/lobisomen/wolfdamage.ogg")
const SOFT_PIANO_STREAM := preload("res://softpiano.ogg")
const BOSS_MUSIC_PLAYER_NAME := "BossFightAudioPlayer"
const SOFT_PIANO_PLAYER_NAME := "SoftPianoAudioPlayer"
const WOLF_DEFEATED_META_KEY := "wolf_defeated"
const TARGET_SCENE_META_KEY := "target_scene_after_cutscene"
const CUTSCENE_VIDEO_PATH_META_KEY := "cutscene_video_path"
const INTRO_VIDEO_SCENE_PATH := "res://cutscene/video_intro.tscn"
const WOLF_DEATH_VIDEO_PATH := "res://cutscene/video2.ogv"
const MS_PER_SECOND := 1000.0
const INITIAL_TIMESTAMP_MS := -1_000_000_000

var _is_dead: bool = false
var _player_ref = null
var _last_direction := Vector2.DOWN
var _current_health: int = 0
var _last_attack_time_ms: int = INITIAL_TIMESTAMP_MS
var _last_special_attack_time_ms: int = INITIAL_TIMESTAMP_MS
var _last_teleport_time_ms: int = INITIAL_TIMESTAMP_MS
var _is_teleporting: bool = false
var _is_casting_special: bool = false
var _has_aggro: bool = false
var _did_drop_heal: bool = false
var _did_show_fight_text: bool = false
var _death_cutscene_started: bool = false
var _phase: int = 1
var _vulnerable_until_ms: int = -1
var _wolf_damage_player: AudioStreamPlayer2D = null

@export_category("Variables")
@export var _max_health: int = 300
@export var _move_speed: float = 45.0
@export var _attack_damage: int = 11
@export var _attack_range: float = 22.0
@export var _attack_cooldown: float = 0.7

@export var _special_attack_damage: int = 22
@export var _special_attack_range: float = 28.0
@export var _special_attack_cooldown: float = 4.0
@export var _special_cast_time: float = 0.45
@export var _teleport_trigger_distance: float = 120.0
@export var _teleport_to_player_distance: float = 20.0
@export var _teleport_cooldown: float = 2.5
@export var _drop_heal_on_death: bool = true
@export var _phase_2_threshold: float = 0.65
@export var _phase_3_threshold: float = 0.30
@export var _vulnerability_after_special: float = 0.8
@export var _vulnerability_after_teleport: float = 0.4
@export var _vulnerable_speed_multiplier: float = 0.52
@export var _fight_intro_text: String = "O LOBISOME"
@export var _fight_intro_hold_time: float = 1.0
@export var _fight_intro_fade_time: float = 2.2

@export_category("Objects")
@export var _sprite: Sprite2D = null
@export var _animation: AnimationPlayer = null
@export var _health_bar: ProgressBar = null

func _ready() -> void:
	_current_health = _max_health
	_sync_health_bar()
	_ensure_wolf_damage_player()

	var tree := get_tree()
	if tree != null:
		if bool(tree.get_meta(WOLF_DEFEATED_META_KEY, false)):
			call_deferred("queue_free")
			return

		if not tree.has_meta(WOLF_DEFEATED_META_KEY):
			tree.set_meta(WOLF_DEFEATED_META_KEY, false)

func _ensure_wolf_damage_player() -> void:
	if _wolf_damage_player != null and is_instance_valid(_wolf_damage_player):
		return

	_wolf_damage_player = AudioStreamPlayer2D.new()
	_wolf_damage_player.name = "WolfDamageSfxPlayer"
	_wolf_damage_player.stream = WOLF_DAMAGE_STREAM
	_wolf_damage_player.volume_db = -5.0
	_wolf_damage_player.max_distance = 260.0
	add_child(_wolf_damage_player)

func _play_wolf_damage_sfx() -> void:
	if _wolf_damage_player == null or not is_instance_valid(_wolf_damage_player):
		_ensure_wolf_damage_player()

	if _wolf_damage_player == null:
		return

	if _wolf_damage_player.playing:
		_wolf_damage_player.stop()

	_wolf_damage_player.play()

func _get_or_create_music_player(player_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null

	var player := tree.current_scene.get_node_or_null(player_name) as AudioStreamPlayer
	if player == null:
		player = AudioStreamPlayer.new()
		player.name = player_name
		tree.current_scene.add_child(player)

	if player.stream != stream:
		player.stream = stream

	return player

func _start_boss_fight_audio() -> void:
	var soft_piano_player := _get_or_create_music_player(SOFT_PIANO_PLAYER_NAME, SOFT_PIANO_STREAM)
	if soft_piano_player != null and soft_piano_player.playing:
		soft_piano_player.stop()

	var boss_player := _get_or_create_music_player(BOSS_MUSIC_PLAYER_NAME, BOSS_FIGHT_STREAM)
	if boss_player != null:
		boss_player.volume_db = -18.0
		if not boss_player.playing:
			boss_player.play()

func _stop_boss_fight_audio() -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return

	var boss_player := tree.current_scene.get_node_or_null(BOSS_MUSIC_PLAYER_NAME) as AudioStreamPlayer
	if boss_player != null and boss_player.playing:
		boss_player.stop()

func _play_soft_piano_music() -> void:
	var soft_piano_player := _get_or_create_music_player(SOFT_PIANO_PLAYER_NAME, SOFT_PIANO_STREAM)
	if soft_piano_player != null and not soft_piano_player.playing:
		soft_piano_player.play()

func _on_detection_area_body_entered(body: Node) -> void:
	if body.is_in_group("character"):
		_player_ref = body
		if not _has_aggro:
			_has_aggro = true
			_start_boss_fight_audio()
			_show_fight_intro_text()
			return

		_has_aggro = true

func _on_detection_area_body_exited(body: Node) -> void:
	if body == _player_ref:
		_player_ref = null

func _physics_process(_delta: float) -> void:
	if _is_dead:
		return

	if _player_ref != null and not is_instance_valid(_player_ref):
		_player_ref = null

	if _has_aggro and _player_ref == null:
		var tree := get_tree()
		if tree != null:
			_player_ref = tree.get_first_node_in_group("character")

	if _is_teleporting:
		velocity = Vector2.ZERO
		_animate()
		return

	if _is_casting_special:
		velocity = Vector2.ZERO
		_animate()
		return

	if _has_aggro and _player_ref != null:
		if _player_ref.is_dead:
			velocity = Vector2.ZERO
		else:
			var direction := global_position.direction_to(_player_ref.global_position)
			var distance := global_position.distance_to(_player_ref.global_position)
			_last_direction = direction
			_update_phase()

			if _try_teleport_near_player(distance, direction):
				velocity = Vector2.ZERO
				_animate()
				return

			if distance <= _special_attack_range and not _is_vulnerable_now():
				_try_special_attack()

			if distance <= _attack_range and not _is_vulnerable_now():
				_try_attack_player()

			var speed := _move_speed * _get_phase_speed_multiplier()
			if _is_vulnerable_now():
				speed *= _vulnerable_speed_multiplier

			velocity = direction * speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()
	_animate()

func _animate() -> void:
	if _is_dead:
		_play_dead_animation()
		return

	_play_walk_animation(_last_direction)

func _try_attack_player() -> void:
	if not _is_cooldown_ready(_last_attack_time_ms, _get_phase_attack_cooldown()):
		return

	_last_attack_time_ms = Time.get_ticks_msec()

	if _player_ref != null and _player_ref.has_method("update_health"):
		_player_ref.update_health(_attack_damage)

func _try_special_attack() -> void:
	if _is_casting_special:
		return

	if not _is_cooldown_ready(_last_special_attack_time_ms, _get_phase_special_cooldown()):
		return

	_last_special_attack_time_ms = Time.get_ticks_msec()
	_start_special_cast()

func _start_special_cast() -> void:
	if _is_dead:
		return

	_is_casting_special = true
	_play_special_charge_effect()
	await get_tree().create_timer(_special_cast_time).timeout

	if _is_dead:
		_is_casting_special = false
		return

	if _player_ref != null and _player_ref.has_method("update_health"):
		var distance := global_position.distance_to(_player_ref.global_position)
		if distance <= _special_attack_range + 8.0:
			_player_ref.update_health(_special_attack_damage)
			_play_special_effect()

	_set_vulnerable_window(_vulnerability_after_special)
	_is_casting_special = false

func _try_teleport_near_player(distance: float, direction: Vector2) -> bool:
	if distance < _teleport_trigger_distance:
		return false

	if not _is_cooldown_ready(_last_teleport_time_ms, _get_phase_teleport_cooldown()):
		return false

	if _player_ref == null:
		return false

	_last_teleport_time_ms = Time.get_ticks_msec()
	_is_teleporting = true

	var teleport_direction := direction
	if teleport_direction == Vector2.ZERO:
		teleport_direction = Vector2.RIGHT

	var target_position: Vector2 = _player_ref.global_position - teleport_direction.normalized() * _teleport_to_player_distance
	_play_teleport_effect(target_position)
	return true

func _update_phase() -> void:
	if _max_health <= 0:
		return

	var health_ratio := float(_current_health) / float(_max_health)
	var next_phase := 1

	if health_ratio <= _phase_3_threshold:
		next_phase = 3
	elif health_ratio <= _phase_2_threshold:
		next_phase = 2

	if next_phase == _phase:
		return

	_phase = next_phase

func _get_phase_speed_multiplier() -> float:
	match _phase:
		2:
			return 1.15
		3:
			return 1.3
		_:
			return 1.0

func _get_phase_attack_cooldown() -> float:
	match _phase:
		2:
			return _attack_cooldown * 0.88
		3:
			return _attack_cooldown * 0.72
		_:
			return _attack_cooldown

func _get_phase_special_cooldown() -> float:
	match _phase:
		2:
			return _special_attack_cooldown * 0.82
		3:
			return _special_attack_cooldown * 0.62
		_:
			return _special_attack_cooldown

func _get_phase_teleport_cooldown() -> float:
	match _phase:
		2:
			return _teleport_cooldown * 0.90
		3:
			return _teleport_cooldown * 0.75
		_:
			return _teleport_cooldown

func _set_vulnerable_window(duration_sec: float) -> void:
	_vulnerable_until_ms = Time.get_ticks_msec() + int(duration_sec * MS_PER_SECOND)

func _is_vulnerable_now() -> bool:
	return Time.get_ticks_msec() < _vulnerable_until_ms

func _is_cooldown_ready(last_time_ms: int, cooldown_sec: float) -> bool:
	var cooldown_ms := int(cooldown_sec * MS_PER_SECOND)
	var current_time_ms := Time.get_ticks_msec()
	return current_time_ms - last_time_ms >= cooldown_ms

func _play_teleport_effect(target_position: Vector2) -> void:
	if _sprite == null:
		global_position = target_position
		_is_teleporting = false
		return

	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(0.8, 0.3, 1.0, 0.0), 0.1)
	tween.parallel().tween_property(_sprite, "scale", Vector2(0.65, 0.65), 0.1)
	tween.tween_callback(Callable(self, "_apply_teleport_position").bind(target_position))
	tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)
	tween.parallel().tween_property(_sprite, "scale", Vector2.ONE, 0.12)
	tween.finished.connect(_on_teleport_finished)

func _apply_teleport_position(target_position: Vector2) -> void:
	global_position = target_position

func _on_teleport_finished() -> void:
	_is_teleporting = false
	_set_vulnerable_window(_vulnerability_after_teleport)

func _play_special_charge_effect() -> void:
	if _sprite == null:
		return

	var _tween := create_tween()
	_tween.tween_property(_sprite, "modulate", Color(1.0, 0.7, 0.2, 1.0), 0.12)
	_tween.parallel().tween_property(_sprite, "scale", Vector2(1.12, 1.12), 0.12)
	_tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)
	_tween.parallel().tween_property(_sprite, "scale", Vector2.ONE, 0.12)

func _play_special_effect() -> void:
	if _sprite == null:
		return

	var _tween := create_tween()
	_tween.tween_property(_sprite, "modulate", Color(1.0, 0.35, 0.35, 1.0), 0.08)
	_tween.parallel().tween_property(_sprite, "scale", Vector2(1.2, 1.2), 0.08)
	_tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.18)
	_tween.parallel().tween_property(_sprite, "scale", Vector2.ONE, 0.18)

func _play_walk_animation(direction: Vector2) -> void:
	if abs(direction.y) > abs(direction.x):
		if direction.y < 0:
			_animation.play("walk_up")
		else:
			_animation.play("walk_down")
		return

	if direction.x < 0:
		_animation.play("walk_left")
	else:
		_animation.play("walk_right")

func update_health(_damage: int = 1) -> void:
	if _is_dead:
		return

	if _damage > 0:
		_play_wolf_damage_sfx()

	_current_health = max(0, _current_health - _damage)
	_sync_health_bar()

	if _current_health <= 0:
		_die()

func _sync_health_bar() -> void:
	if _health_bar == null:
		return

	_health_bar.max_value = float(_max_health)
	_health_bar.value = float(_current_health)

func _play_dead_animation() -> void:
	if abs(_last_direction.y) > abs(_last_direction.x):
		if _last_direction.y < 0:
			_animation.play("dead_up")
		else:
			_animation.play("dead_down")
	else:
		if _last_direction.x < 0:
			_animation.play("dead_left")
		else:
			_animation.play("dead_right")

func _die() -> void:
	_is_dead = true
	_current_health = 0
	_sync_health_bar()
	velocity = Vector2.ZERO
	var tree := get_tree()
	if tree != null:
		tree.set_meta(WOLF_DEFEATED_META_KEY, true)
	_stop_boss_fight_audio()
	_play_soft_piano_music()
	_play_dead_animation()
	_spawn_heal_drop()

func _spawn_heal_drop() -> void:
	if not _drop_heal_on_death or _did_drop_heal:
		return

	_did_drop_heal = true
	call_deferred("_spawn_heal_drop_deferred", global_position)

func _spawn_heal_drop_deferred(spawn_position: Vector2) -> void:
	var tree := get_tree()
	if tree == null:
		return

	var parent_node := tree.current_scene
	if parent_node == null:
		parent_node = get_parent()

	if parent_node == null:
		return

	var drop := HEAL_DROP_SCENE.instantiate() as Node2D
	if drop == null:
		return

	parent_node.add_child(drop)
	drop.global_position = spawn_position

func _show_fight_intro_text() -> void:
	if _did_show_fight_text:
		return

	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return

	_did_show_fight_text = true
	_show_fight_banner(_fight_intro_text, _fight_intro_hold_time, _fight_intro_fade_time)

func _show_fight_banner(text: String, hold_time: float, fade_time: float) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return

	var layer := CanvasLayer.new()
	layer.layer = 50

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 0.0
	label.offset_left = 0.0
	label.offset_top = 16.0
	label.offset_right = 0.0
	label.offset_bottom = 52.0
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.03, 1.0))
	label.add_theme_constant_override("outline_size", 6)
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)

	tree.current_scene.add_child(layer)
	layer.add_child(label)

	var tween := layer.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.35)
	tween.tween_interval(hold_time)
	tween.tween_property(label, "modulate:a", 0.0, fade_time)
	tween.finished.connect(layer.queue_free)

func _on_animation_finished(_anim_name: String) -> void:
	if _is_dead:
		_start_death_cutscene()

func _start_death_cutscene() -> void:
	if _death_cutscene_started:
		return

	_death_cutscene_started = true
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		queue_free()
		return

	var current_scene_path := String(tree.current_scene.scene_file_path)
	if current_scene_path.is_empty():
		queue_free()
		return

	tree.set_meta(TARGET_SCENE_META_KEY, current_scene_path)
	tree.set_meta(CUTSCENE_VIDEO_PATH_META_KEY, WOLF_DEATH_VIDEO_PATH)
	tree.change_scene_to_file(INTRO_VIDEO_SCENE_PATH)
