extends CharacterBody2D
class_name Character

const ATTACK_ACTION := &"attack"
const DASH_ACTION := &"dash"
const BLEND_IDLE := "parameters/idle/blend_position"
const BLEND_WALK := "parameters/walk/blend_position"
const BLEND_ATTACK := "parameters/attack/blend_position"
const LIVES_META_KEY := "player_lives"
const CONTROLS_HINT_PENDING_META_KEY := "controls_hint_pending"
const CONTROLS_HINT_TEXT := "WASD/Setas: mover   Q/Clique: ataque   Shift: dash"
const MAX_LIVES := 3
const HUD_SCENE_PATH := "res://ui/scenes/main_hud.tscn"

var is_dead: bool = false
var _state_machine
var _is_attacking: bool = false
var _is_dashing: bool = false
var _dash_direction: Vector2 = Vector2.DOWN
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_afterimage_left: float = 0.0
var _dash_invulnerable: bool = false
var _current_health: int = 0
var _can_take_damage: bool = true
@onready var _sprite: Sprite2D = $Sprite2D

var _lives_layer: CanvasLayer = null
var _lives_panel: HBoxContainer = null
var _heart_slots: Array[TextureRect] = []
var _heart_full_texture: Texture2D = null
var _heart_empty_texture: Texture2D = null
var _name_label: Label = null
var _menu_button: Button = null
var _controls_hint_label: Label = null

@export_category("Variables")
@export var _move_speed: float = 84.0
@export var _max_health: int = 100
@export var _attack_damage: int = 18
@export var _invulnerability_time: float = 0.4
@export var _dash_speed: float = 280.0
@export var _dash_duration: float = 0.15
@export var _dash_cooldown: float = 0.9
@export var _dash_afterimage_interval: float = 0.03

@export var _acceleration: float = 0.4
@export var _friction: float = 0.4

@export_category("Objects")
@export var _animation_tree: AnimationTree = null
@export var _attack_timer: Timer = null
@export var _health_bar: ProgressBar = null

func _ready() -> void:
	if _animation_tree == null or _attack_timer == null:
		push_error("Character: configure _animation_tree e _attack_timer no inspetor.")
		set_physics_process(false)
		return

	_animation_tree.active = true
	_state_machine = _animation_tree["parameters/playback"]
	_current_health = _max_health
	_sync_health_bar()

	var tree := get_tree()
	if tree != null and not tree.has_meta(LIVES_META_KEY):
		tree.set_meta(LIVES_META_KEY, MAX_LIVES)

	_ensure_lives_ui()
	_update_lives_ui()
	_ensure_name_label()
	_update_name_label()
	_show_controls_hint_if_needed()

func _ensure_lives_ui() -> void:
	if _lives_layer != null and is_instance_valid(_lives_layer):
		return

	_heart_full_texture = _build_texture_from_pattern(
		[
			"........",
			".xx..xx.",
			"xxxxxxxx",
			"xxxxxxxx",
			".xxxxxx.",
			"..xxxx..",
			"...xx...",
			"........"
		],
		Color(0.97, 0.2, 0.3, 1.0)
	)

	_heart_empty_texture = _build_texture_from_pattern(
		[
			"........",
			".xx..xx.",
			"x......x",
			"x......x",
			".x....x.",
			"..x..x..",
			"...xx...",
			"........"
		],
		Color(0.45, 0.18, 0.22, 1.0)
	)

	_lives_layer = CanvasLayer.new()
	_lives_layer.layer = 20

	_lives_panel = HBoxContainer.new()
	_lives_panel.anchor_left = 0.0
	_lives_panel.anchor_top = 0.0
	_lives_panel.anchor_right = 0.0
	_lives_panel.anchor_bottom = 0.0
	_lives_panel.offset_left = 10.0
	_lives_panel.offset_top = 8.0
	_lives_panel.offset_right = 140.0
	_lives_panel.offset_bottom = 32.0
	_lives_panel.add_theme_constant_override("separation", 3)

	_heart_slots.clear()
	for _i in range(MAX_LIVES):
		var heart := TextureRect.new()
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_SCALE
		heart.custom_minimum_size = Vector2(18, 18)
		heart.texture = _heart_full_texture
		_lives_panel.add_child(heart)
		_heart_slots.append(heart)

	_menu_button = Button.new()
	_menu_button.text = "Menu"
	_menu_button.anchor_left = 1.0
	_menu_button.anchor_top = 0.0
	_menu_button.anchor_right = 1.0
	_menu_button.anchor_bottom = 0.0
	_menu_button.offset_left = -54.0
	_menu_button.offset_top = 8.0
	_menu_button.offset_right = -8.0
	_menu_button.offset_bottom = 24.0
	_menu_button.add_theme_font_size_override("font_size", 9)
	_menu_button.pressed.connect(_on_menu_button_pressed)

	add_child(_lives_layer)
	_lives_layer.add_child(_lives_panel)
	_lives_layer.add_child(_menu_button)

func _on_menu_button_pressed() -> void:
	var tree := get_tree()
	if tree == null:
		return

	tree.change_scene_to_file(HUD_SCENE_PATH)

func _build_texture_from_pattern(pattern: Array[String], color: Color) -> Texture2D:
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	for y in range(min(8, pattern.size())):
		var row := pattern[y]
		for x in range(min(8, row.length())):
			if row[x] != ".":
				image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)

func _ensure_name_label() -> void:
	if _name_label != null and is_instance_valid(_name_label):
		return

	_name_label = Label.new()
	_name_label.position = Vector2(-20, -46)
	_name_label.size = Vector2(40, 10)
	_name_label.clip_text = false
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var pixel_font := SystemFont.new()
	pixel_font.font_names = PackedStringArray(["monospace", "DejaVu Sans Mono", "Noto Sans Mono"])
	_name_label.add_theme_font_override("font", pixel_font)
	_name_label.add_theme_font_size_override("font_size", 6)
	_name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.82, 1.0))
	_name_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 1.0))
	_name_label.add_theme_constant_override("outline_size", 0)
	add_child(_name_label)

func _update_name_label() -> void:
	if _name_label == null:
		return

	var tree := get_tree()
	if tree == null:
		return

	var player_name: String = str(tree.get_meta("player_name", "Jogador"))
	if player_name.is_empty():
		player_name = "Jogador"

	_name_label.text = player_name

func _show_controls_hint_if_needed() -> void:
	var tree := get_tree()
	if tree == null:
		return

	if not bool(tree.get_meta(CONTROLS_HINT_PENDING_META_KEY, false)):
		return

	tree.remove_meta(CONTROLS_HINT_PENDING_META_KEY)

	if _lives_layer == null or not is_instance_valid(_lives_layer):
		return

	_controls_hint_label = Label.new()
	_controls_hint_label.text = CONTROLS_HINT_TEXT
	_controls_hint_label.anchor_left = 0.5
	_controls_hint_label.anchor_top = 1.0
	_controls_hint_label.anchor_right = 0.5
	_controls_hint_label.anchor_bottom = 1.0
	_controls_hint_label.offset_left = -175.0
	_controls_hint_label.offset_top = -28.0
	_controls_hint_label.offset_right = 175.0
	_controls_hint_label.offset_bottom = -8.0
	_controls_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_controls_hint_label.add_theme_font_size_override("font_size", 12)
	_controls_hint_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_controls_hint_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_controls_hint_label.add_theme_constant_override("outline_size", 3)
	_lives_layer.add_child(_controls_hint_label)

	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(_controls_hint_label, "modulate:a", 0.0, 0.8)
	tween.finished.connect(func() -> void:
		if _controls_hint_label != null and is_instance_valid(_controls_hint_label):
			_controls_hint_label.queue_free()
			_controls_hint_label = null
	)

func _update_lives_ui() -> void:
	if _lives_panel == null or _heart_slots.is_empty():
		return

	var tree := get_tree()
	if tree == null:
		return

	var current_lives := int(tree.get_meta(LIVES_META_KEY, MAX_LIVES))
	for i in range(_heart_slots.size()):
		var heart := _heart_slots[i]
		heart.texture = _heart_full_texture if i < current_lives else _heart_empty_texture

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if _lives_panel == null or not is_instance_valid(_lives_panel):
		_ensure_lives_ui()
		_update_lives_ui()

	if _name_label == null or not is_instance_valid(_name_label):
		_ensure_name_label()
		_update_name_label()

	_update_dash_timers(delta)
	_try_dash()

	if _is_dashing:
		_process_dash(delta)
	else:
		_move()
		_attack()
	
	_animate()
	move_and_slide()

func _update_dash_timers(delta: float) -> void:
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = max(0.0, _dash_cooldown_left - delta)

func _try_dash() -> void:
	if _is_attacking or _is_dashing:
		return

	if _dash_cooldown_left > 0.0:
		return

	if not Input.is_action_just_pressed(DASH_ACTION):
		return

	var direction := _get_input_direction()

	if direction == Vector2.ZERO:
		direction = _animation_tree[BLEND_IDLE]

	if direction == Vector2.ZERO:
		direction = Vector2.DOWN

	_dash_direction = direction.normalized()
	_dash_time_left = _dash_duration
	_dash_cooldown_left = _dash_cooldown
	_dash_afterimage_left = 0.0
	_is_dashing = true
	_dash_invulnerable = true
	_play_dash_burst()

func _get_input_direction() -> Vector2:
	return Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

func _process_dash(delta: float) -> void:
	_dash_time_left -= delta

	_set_blend_direction(_dash_direction)

	velocity = _dash_direction * _dash_speed

	_dash_afterimage_left -= delta
	if _dash_afterimage_left <= 0.0:
		_dash_afterimage_left = _dash_afterimage_interval
		_spawn_dash_afterimage()

	if _dash_time_left <= 0.0:
		_is_dashing = false
		_dash_invulnerable = false

func _play_dash_burst() -> void:
	if _sprite == null:
		return

	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(0.65, 1.0, 1.0, 1.0), 0.05)
	tween.parallel().tween_property(_sprite, "scale", Vector2(1.3, 1.3), 0.05)
	tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)
	tween.parallel().tween_property(_sprite, "scale", Vector2.ONE, 0.12)

func _spawn_dash_afterimage() -> void:
	if _sprite == null:
		return

	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return

	var ghost := Sprite2D.new()
	ghost.texture = _sprite.texture
	ghost.hframes = _sprite.hframes
	ghost.vframes = _sprite.vframes
	ghost.frame = _sprite.frame
	ghost.flip_h = _sprite.flip_h
	ghost.global_position = _sprite.global_position
	ghost.scale = _sprite.scale
	ghost.modulate = Color(0.55, 0.95, 1.0, 0.55)
	ghost.z_index = _sprite.z_index - 1

	tree.current_scene.add_child(ghost)

	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate", Color(0.55, 0.95, 1.0, 0.0), 0.14)
	tween.parallel().tween_property(ghost, "scale", ghost.scale * 0.85, 0.14)
	tween.finished.connect(ghost.queue_free)

func _set_blend_direction(direction: Vector2) -> void:
	_animation_tree[BLEND_IDLE] = direction
	_animation_tree[BLEND_WALK] = direction
	_animation_tree[BLEND_ATTACK] = direction
	
func _move() -> void:
	var direction := _get_input_direction()
	var target_velocity := direction.normalized() * _move_speed

	if direction != Vector2.ZERO:
		_set_blend_direction(direction)
		velocity.x = lerp(velocity.x, target_velocity.x, _acceleration)
		velocity.y = lerp(velocity.y, target_velocity.y, _acceleration)
		return

	velocity.x = lerp(velocity.x, 0.0, _friction)
	velocity.y = lerp(velocity.y, 0.0, _friction)

func _attack() -> void:
	if Input.is_action_just_pressed(ATTACK_ACTION) and not _is_attacking:
		set_physics_process(false)
		_attack_timer.start()
		_is_attacking = true

func _animate() -> void:
	if _is_dashing:
		_state_machine.travel("walk")
		return

	if _is_attacking:
		_state_machine.travel("attack")
		return
		
	if velocity.length() > 10:
		_state_machine.travel("walk")
		return
		
	_state_machine.travel("idle")

func _on_attack_timer_timeout() -> void:
	set_physics_process(true)
	_is_attacking = false


func _on_attack_area_body_entered(_body: Node) -> void:
	if _body.is_in_group("enemy") and _body.has_method("update_health"):
		_body.update_health(_attack_damage)

func update_health(_damage: int = 1) -> void:
	if is_dead or not _can_take_damage or _dash_invulnerable:
		return

	_current_health = max(0, _current_health - _damage)
	_sync_health_bar()

	if _current_health <= 0:
		die()
		return

	if _invulnerability_time > 0:
		_can_take_damage = false
		await get_tree().create_timer(_invulnerability_time).timeout
		if not is_dead:
			_can_take_damage = true

func heal(amount: int = 1) -> void:
	if is_dead or amount <= 0:
		return

	_current_health = min(_max_health, _current_health + amount)
	_sync_health_bar()

func _sync_health_bar() -> void:
	if _health_bar == null:
		return

	_health_bar.max_value = float(_max_health)
	_health_bar.value = float(_current_health)

func die() -> void:
	is_dead = true
	_current_health = 0
	_sync_health_bar()
	_state_machine.travel("death")
	await get_tree().create_timer(1.0).timeout

	var tree := get_tree()
	if tree == null:
		return

	var current_lives := int(tree.get_meta(LIVES_META_KEY, MAX_LIVES))
	current_lives -= 1
	tree.set_meta(LIVES_META_KEY, current_lives)
	_update_lives_ui()

	if current_lives > 0:
		tree.reload_current_scene()
		return

	tree.set_meta(LIVES_META_KEY, MAX_LIVES)
	tree.change_scene_to_file(HUD_SCENE_PATH)
