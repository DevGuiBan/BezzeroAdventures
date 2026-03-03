extends CharacterBody2D

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D

@export var move_speed: float = 40.0
@export var move_distance: float = 40.0

@export var min_wait: float = 1.5
@export var max_wait: float = 4.0

var start_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	randomize()
	start_position = global_position
	sprite.flip_h = false
	_cycle()

func _cycle() -> void:
	while is_inside_tree():
		sprite.flip_h = false
		if not await _move_to(start_position + Vector2(-move_distance, 0.0)):
			return
		
		if not await _wait_time():
			return
		
		sprite.flip_h = true
		if not await _move_to(start_position):
			return
		
		if not await _wait_time():
			return


func _wait_time() -> bool:
	velocity = Vector2.ZERO
	
	var tree := get_tree()
	if tree == null:
		return false

	await tree.create_timer(randf_range(min_wait, max_wait)).timeout
	return is_inside_tree()


func _move_to(target: Vector2) -> bool:
	if not is_inside_tree():
		return false

	animation_player.play("walk_cow_left")
	
	while is_inside_tree() and global_position.distance_to(target) > 2:
		var dir: Vector2 = (target - global_position).normalized()
		velocity = dir * move_speed
		
		move_and_slide()

		var tree := get_tree()
		if tree == null:
			return false
		await tree.process_frame
	
	velocity = Vector2.ZERO
	return is_inside_tree()
