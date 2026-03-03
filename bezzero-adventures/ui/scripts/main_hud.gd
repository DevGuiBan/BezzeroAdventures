extends Control

@export_file("*.tscn") var next_scene_path: String = "res://levels/scenes/test_level.tscn"
@export_file("*.tscn") var intro_video_scene_path: String = "res://cutscene/video_intro.tscn"
const LIVES_META_KEY := "player_lives"
const PLAYER_NAME_META_KEY := "player_name"
const TARGET_SCENE_META_KEY := "target_scene_after_cutscene"
const CONTROLS_HINT_PENDING_META_KEY := "controls_hint_pending"
const WOLF_DEFEATED_META_KEY := "wolf_defeated"
const SKELETON_KILLS_META_KEY := "skeleton_kills"
const SKELETON_ENDING_DONE_META_KEY := "skeleton_ending_done"
const MAX_LIVES := 3

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var exit_button: Button = $CenterContainer/VBoxContainer/ExitButton
@onready var setup_box: VBoxContainer = $CenterContainer/VBoxContainer/SetupBox
@onready var back_button: Button = $BackButton
@onready var name_input: LineEdit = $CenterContainer/VBoxContainer/SetupBox/NameInput
@onready var start_button: Button = $CenterContainer/VBoxContainer/SetupBox/StartButton
@onready var feedback_label: Label = $CenterContainer/VBoxContainer/SetupBox/FeedbackLabel

func _ready() -> void:
	setup_box.visible = false
	feedback_label.visible = false
	back_button.visible = false

func _on_play_button_pressed() -> void:
	play_button.visible = false
	exit_button.visible = false
	setup_box.visible = true
	back_button.visible = true
	feedback_label.visible = false
	name_input.grab_focus()

func _on_back_button_pressed() -> void:
	setup_box.visible = false
	feedback_label.visible = false
	play_button.visible = true
	exit_button.visible = true
	back_button.visible = false
	back_button.release_focus()

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_start_button_pressed() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		feedback_label.text = "Digite seu nome para iniciar"
		feedback_label.visible = true
		return

	_start_game_flow(player_name)

func _on_name_input_text_submitted(_new_text: String) -> void:
	_on_start_button_pressed()

func _start_game_flow(player_name: String) -> void:
	feedback_label.visible = false
	back_button.visible = false
	get_tree().set_meta(PLAYER_NAME_META_KEY, player_name)
	get_tree().set_meta(LIVES_META_KEY, MAX_LIVES)
	get_tree().set_meta(WOLF_DEFEATED_META_KEY, false)
	get_tree().set_meta(SKELETON_KILLS_META_KEY, 0)
	get_tree().set_meta(SKELETON_ENDING_DONE_META_KEY, false)
	get_tree().set_meta(CONTROLS_HINT_PENDING_META_KEY, true)
	get_tree().set_meta(TARGET_SCENE_META_KEY, next_scene_path)
	get_tree().change_scene_to_file(intro_video_scene_path)
