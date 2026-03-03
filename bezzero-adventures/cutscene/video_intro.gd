extends Control

const TARGET_SCENE_META_KEY := "target_scene_after_cutscene"
const CUTSCENE_VIDEO_PATH_META_KEY := "cutscene_video_path"

@export_file("*.tscn") var fallback_scene_path: String = "res://levels/scenes/test_level.tscn"
@export_file("*.ogv", "*.ogg", "*.webm", "*.mp4") var video_path: String = "res://cutscene/video1.ogv"
@export var fade_in_duration: float = 1.5
@export var fade_out_duration: float = 1.5
@onready var video_player: VideoStreamPlayer = $VideoStreamPlayer
@onready var fade_overlay: ColorRect = $FadeOverlay

var _is_exiting: bool = false

func _ready() -> void:
	var tree := get_tree()
	if tree.has_meta(TARGET_SCENE_META_KEY):
		fallback_scene_path = str(tree.get_meta(TARGET_SCENE_META_KEY, fallback_scene_path))
		tree.remove_meta(TARGET_SCENE_META_KEY)

	if tree.has_meta(CUTSCENE_VIDEO_PATH_META_KEY):
		video_path = str(tree.get_meta(CUTSCENE_VIDEO_PATH_META_KEY, video_path))
		tree.remove_meta(CUTSCENE_VIDEO_PATH_META_KEY)

	var resolved_video_path := _resolve_video_path()
	if resolved_video_path.is_empty() or not ResourceLoader.exists(resolved_video_path, "VideoStream"):
		_go_to_game()
		return

	var stream := load(resolved_video_path) as VideoStream
	if stream == null:
		_go_to_game()
		return

	fade_overlay.modulate.a = 1.0
	video_player.stream = stream
	video_player.finished.connect(_on_video_finished)
	video_player.play()
	_fade_in()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_go_to_game()
	elif event is InputEventMouseButton and event.pressed:
		_go_to_game()

func _on_video_finished() -> void:
	_go_to_game()

func _go_to_game() -> void:
	if _is_exiting:
		return

	_is_exiting = true
	if fade_overlay != null and is_instance_valid(fade_overlay):
		await _fade_out()

	if get_tree().current_scene != self:
		return
	get_tree().change_scene_to_file(fallback_scene_path)

func _fade_in() -> void:
	if fade_overlay == null or not is_instance_valid(fade_overlay):
		return

	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 0.0, max(0.0, fade_in_duration))

func _fade_out() -> void:
	if fade_overlay == null or not is_instance_valid(fade_overlay):
		return

	var tween := create_tween()
	tween.tween_property(fade_overlay, "modulate:a", 1.0, max(0.0, fade_out_duration))
	await tween.finished

func _resolve_video_path() -> String:
	if ResourceLoader.exists(video_path, "VideoStream"):
		return video_path

	var base_path := video_path.get_basename()
	var dynamic_candidates := [
		base_path + ".ogv",
		base_path + ".ogg",
		base_path + ".webm",
		base_path + ".mp4"
	]

	for candidate in dynamic_candidates:
		if ResourceLoader.exists(candidate, "VideoStream"):
			return candidate

	var candidates := [
		"res://cutscene/video1.ogv",
		"res://cutscene/video1.ogg",
		"res://cutscene/video1.webm",
		"res://cutscene/video1.mp4"
	]

	for candidate in candidates:
		if ResourceLoader.exists(candidate, "VideoStream"):
			return candidate

	return ""
