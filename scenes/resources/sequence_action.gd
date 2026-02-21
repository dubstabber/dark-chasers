class_name SequenceAction
extends RefCounted

## A single action within a sequence.
## Used by SequenceDirector to execute timed scripted sequences.
## Access via: const SequenceAction = preload("res://scenes/resources/sequence_action.gd")

enum Type {
	WAIT,
	BLOCK_PLAYER,
	UNBLOCK_PLAYER,
	CAMERA_CUT,
	CAMERA_RESTORE,
	PLAY_SOUND,
	SHOW_TEXT,
	HIDE_TEXT,
	SPAWN_ENEMY,
	PLAY_MUSIC,
	STOP_MUSIC,
	CUSTOM,
}

var action_type: int = Type.WAIT
var duration: float = 0.0
var target_players: Array = []
var camera: Camera3D = null
var sound: AudioStream = null
var sound_source: Node = null
var position: Vector3 = Vector3.ZERO
var volume_db: float = -25.0
var text: String = ""
var enemy_scene: PackedScene = null
var spawn_position: Vector3 = Vector3.ZERO
var spawn_room: String = ""
var target_player: Node = null
var custom_callable: Callable = Callable()


static func wait(seconds: float) -> RefCounted:
	var action = preload("res://scenes/resources/sequence_action.gd").new()
	action.action_type = Type.WAIT
	action.duration = seconds
	return action


static func block_players(players: Array = []) -> RefCounted:
	var action = preload("res://scenes/resources/sequence_action.gd").new()
	action.action_type = Type.BLOCK_PLAYER
	action.target_players = players
	return action


static func unblock_players(players: Array = []) -> RefCounted:
	var action = preload("res://scenes/resources/sequence_action.gd").new()
	action.action_type = Type.UNBLOCK_PLAYER
	action.target_players = players
	return action


static func camera_cut(cam: Camera3D) -> RefCounted:
	var action = preload("res://scenes/resources/sequence_action.gd").new()
	action.action_type = Type.CAMERA_CUT
	action.camera = cam
	return action


static func camera_restore() -> RefCounted:
	var action = preload("res://scenes/resources/sequence_action.gd").new()
	action.action_type = Type.CAMERA_RESTORE
	return action


static func play_sound(stream: AudioStream, source: Node = null, pos: Vector3 = Vector3.ZERO, volume: float = -25.0) -> RefCounted:
	var action = preload("res://scenes/resources/sequence_action.gd").new()
	action.action_type = Type.PLAY_SOUND
	action.sound = stream
	action.sound_source = source
	action.position = pos
	action.volume_db = volume
	return action


static func show_text(message: String, display_duration: float = 3.0) -> RefCounted:
	var action = preload("res://scenes/resources/sequence_action.gd").new()
	action.action_type = Type.SHOW_TEXT
	action.text = message
	action.duration = display_duration
	return action


static func hide_text() -> RefCounted:
	var action = preload("res://scenes/resources/sequence_action.gd").new()
	action.action_type = Type.HIDE_TEXT
	return action


static func spawn_enemy(scene: PackedScene, pos: Vector3, room: String = "", target: Node = null) -> RefCounted:
	var action = preload("res://scenes/resources/sequence_action.gd").new()
	action.action_type = Type.SPAWN_ENEMY
	action.enemy_scene = scene
	action.spawn_position = pos
	action.spawn_room = room
	action.target_player = target
	return action


static func play_music(stream: AudioStream, volume: float = -5.0) -> RefCounted:
	var action = preload("res://scenes/resources/sequence_action.gd").new()
	action.action_type = Type.PLAY_MUSIC
	action.sound = stream
	action.volume_db = volume
	return action


static func stop_music() -> RefCounted:
	var action = preload("res://scenes/resources/sequence_action.gd").new()
	action.action_type = Type.STOP_MUSIC
	return action


static func custom(callable: Callable) -> RefCounted:
	var action = preload("res://scenes/resources/sequence_action.gd").new()
	action.action_type = Type.CUSTOM
	action.custom_callable = callable
	return action
