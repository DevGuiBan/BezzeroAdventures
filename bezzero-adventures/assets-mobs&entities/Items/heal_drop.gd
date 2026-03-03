extends Area2D
class_name HealDrop

@export var heal_amount: int = 45
@export var bob_amplitude: float = 2.5
@export var bob_speed: float = 5.0

var _elapsed: float = 0.0
var _base_y: float = 0.0
var _is_collected: bool = false

func _ready() -> void:
	_base_y = global_position.y
	body_entered.connect(_on_body_entered)
	scale = Vector2.ONE

func _process(delta: float) -> void:
	_elapsed += delta
	global_position.y = _base_y + sin(_elapsed * bob_speed) * bob_amplitude

func _on_body_entered(body: Node) -> void:
	if _is_collected or body == null:
		return

	if not body.has_method("heal"):
		return

	_is_collected = true
	body.heal(heal_amount)

	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.25, 1.25), 0.08)
	tween.parallel().tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.08)
	tween.finished.connect(queue_free)
