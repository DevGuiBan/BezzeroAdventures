extends CharacterBody2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

@export var move_speed: float = 30.0
@export var move_distance: float = 20.0

@export var min_wait: float = 1.5
@export var max_wait: float = 4.0

var start_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	randomize()
	start_position = global_position
	_play_random_cycle()


func _play_random_cycle() -> void:
	while is_inside_tree():
		if not await _idle_time():
			return

		var direction: int = 1 if randf() < 0.5 else -1

		if not await _move_to(start_position + Vector2(move_distance * direction, 0.0)):
			return
		if not await _idle_time():
			return
		if not await _move_to(start_position):
			return


func _idle_time() -> bool:
	var tree := get_tree()
	if tree == null:
		return false

	await tree.create_timer(randf_range(min_wait, max_wait)).timeout
	return is_inside_tree()


func _move_to(target: Vector2) -> bool:
	if not is_inside_tree():
		return false

	animation_player.pause()

	while is_inside_tree() and global_position.distance_to(target) > 2:
		var dir: Vector2 = (target - global_position).normalized()
		velocity = dir * move_speed
		
		if dir.x != 0:
			sprite.flip_h = dir.x > 0
		
		move_and_slide()

		var tree := get_tree()
		if tree == null:
			return false
		await tree.process_frame
	
	velocity = Vector2.ZERO
	
	if is_inside_tree():
		animation_player.play("idle_chiken")

	return is_inside_tree()
