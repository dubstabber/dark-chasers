extends RefCounted

const SequenceActionScript = preload("res://scenes/resources/sequence_action.gd")

## Container for a sequence of actions.
## Used by SequenceDirector to manage timed scripted sequences.
## Access via: const SequenceData = preload("res://scenes/resources/sequence_data.gd")

var id: StringName = &""
var actions: Array = []
var cleanup_actions: Array = []
var skippable: bool = true


func _init(p_id: StringName = &"") -> void:
	id = p_id


func add_action(action: RefCounted) -> RefCounted:
	actions.append(action)
	return self


func add_cleanup(action: RefCounted) -> RefCounted:
	cleanup_actions.append(action)
	return self


func set_skippable(can_skip: bool) -> RefCounted:
	skippable = can_skip
	return self


# Convenience builder methods
func wait(seconds: float) -> RefCounted:
	return add_action(SequenceActionScript.wait(seconds))


func block_players(players: Array[Node] = []) -> RefCounted:
	return add_action(SequenceActionScript.block_players(players))


func unblock_players(players: Array[Node] = []) -> RefCounted:
	return add_action(SequenceActionScript.unblock_players(players))


func camera_cut(cam: Camera3D) -> RefCounted:
	return add_action(SequenceActionScript.camera_cut(cam))


func camera_restore() -> RefCounted:
	return add_action(SequenceActionScript.camera_restore())


func play_sound(stream: AudioStream, source: Node = null, pos: Vector3 = Vector3.ZERO, volume: float = -25.0) -> RefCounted:
	return add_action(SequenceActionScript.play_sound(stream, source, pos, volume))


func show_text(message: String, display_duration: float = 3.0) -> RefCounted:
	return add_action(SequenceActionScript.show_text(message, display_duration))


func hide_text() -> RefCounted:
	return add_action(SequenceActionScript.hide_text())


func spawn_enemy(scene: PackedScene, pos: Vector3, room: String = "", target: Node = null) -> RefCounted:
	return add_action(SequenceActionScript.spawn_enemy(scene, pos, room, target))


func play_music(stream: AudioStream, volume: float = -5.0) -> RefCounted:
	return add_action(SequenceActionScript.play_music(stream, volume))


func stop_music() -> RefCounted:
	return add_action(SequenceActionScript.stop_music())


func custom(callable: Callable) -> RefCounted:
	return add_action(SequenceActionScript.custom(callable))


# Static factory
static func create(sequence_id: StringName) -> RefCounted:
	return preload("res://scenes/resources/sequence_data.gd").new(sequence_id)
