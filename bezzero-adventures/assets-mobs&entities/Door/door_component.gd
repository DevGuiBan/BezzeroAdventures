extends Area2D
class_name DoorComponent2

const SOFT_PIANO_STREAM := preload("res://softpiano.ogg")
const DUNGEON_STREAM := preload("res://assets-mobs&entities/Slime&Skeleton/dungeon.ogg")
const SOFT_PIANO_PLAYER_NAME := "SoftPianoAudioPlayer"
const DUNGEON_PLAYER_NAME := "DungeonAudioPlayer"
const DUNGEON_STATE_META_KEY := "is_player_in_dungeon"
const WOLF_DEFEATED_META_KEY := "wolf_defeated"
const DUNGEON_VOLUME_DB := -12.0

@export_category("Variables")
@export var _teleport_position: Vector2

func _on_body_entered(body: Node) -> void:
	if not (body is Character):
		return

	if not _can_use_door():
		return

	body.global_position = _teleport_position
	_toggle_music_by_dungeon_state()

func _can_use_door() -> bool:
	var tree := get_tree()
	if tree == null:
		return false

	return bool(tree.get_meta(WOLF_DEFEATED_META_KEY, false))

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

func _toggle_music_by_dungeon_state() -> void:
	var tree := get_tree()
	if tree == null:
		return

	var is_in_dungeon := bool(tree.get_meta(DUNGEON_STATE_META_KEY, false))
	is_in_dungeon = not is_in_dungeon
	tree.set_meta(DUNGEON_STATE_META_KEY, is_in_dungeon)

	var soft_piano_player := _get_or_create_music_player(SOFT_PIANO_PLAYER_NAME, SOFT_PIANO_STREAM)
	var dungeon_player := _get_or_create_music_player(DUNGEON_PLAYER_NAME, DUNGEON_STREAM)

	if soft_piano_player == null or dungeon_player == null:
		return

	dungeon_player.volume_db = DUNGEON_VOLUME_DB

	if is_in_dungeon:
		if soft_piano_player.playing:
			soft_piano_player.stop()
		if not dungeon_player.playing:
			dungeon_player.play()
		return

	if dungeon_player.playing:
		dungeon_player.stop()

	if not soft_piano_player.playing:
		soft_piano_player.play()
