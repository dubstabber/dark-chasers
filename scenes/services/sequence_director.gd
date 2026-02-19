class_name SequenceDirector
extends Node

const SequenceDataScript = preload("res://scenes/resources/sequence_data.gd")
const SequenceActionScript = preload("res://scenes/resources/sequence_action.gd")
const GameEventTypesScript = preload("res://scenes/resources/game_event_types.gd")

## Sequence Director for managing timed scripted sequences.
## Replaces hand-rolled await timer chains in room scripts.
##
## Usage:
##   - Add as autoload named "SequenceDirector" in Project Settings
##   - Create sequences with SequenceBuilder or SequenceAction arrays
##   - Play with play_sequence() or queue_sequence()

signal sequence_started(sequence_id: StringName)
signal sequence_ended(sequence_id: StringName)
signal sequence_step_completed(sequence_id: StringName, step_index: int)
signal sequence_skipped(sequence_id: StringName)

var _current_sequence: RefCounted = null
var _sequence_queue: Array[RefCounted] = []
var _is_playing: bool = false
var _can_skip: bool = true
var _current_step: int = 0


func is_playing() -> bool:
	return _is_playing


func get_current_sequence_id() -> StringName:
	if _current_sequence:
		return _current_sequence.id
	return &""


func play_sequence(sequence: RefCounted) -> void:
	if _is_playing:
		_cancel_current()
	
	_current_sequence = sequence
	_is_playing = true
	_current_step = 0
	_can_skip = sequence.skippable
	
	sequence_started.emit(sequence.id)
	Services.event_bus.emit(GameEventTypesScript.SEQUENCE_STARTED, {"sequence_id": sequence.id})
	
	await _execute_sequence()


func queue_sequence(sequence: RefCounted) -> void:
	if _is_playing:
		_sequence_queue.append(sequence)
	else:
		play_sequence(sequence)


func skip_current() -> void:
	if _is_playing and _can_skip and _current_sequence:
		sequence_skipped.emit(_current_sequence.id)
		_end_current()


func cancel_current() -> void:
	if _is_playing:
		_cancel_current()


func _cancel_current() -> void:
	if _current_sequence:
		_end_current()


func _end_current() -> void:
	if not _current_sequence:
		return
	
	var ended_id: StringName = _current_sequence.id
	
	# Execute cleanup actions
	for action in _current_sequence.cleanup_actions:
		await _execute_action(action)
	
	_current_sequence = null
	_is_playing = false
	_current_step = 0
	
	sequence_ended.emit(ended_id)
	Services.event_bus.emit(GameEventTypesScript.SEQUENCE_ENDED, {"sequence_id": ended_id})
	
	# Play next queued sequence
	if not _sequence_queue.is_empty():
		var next: RefCounted = _sequence_queue.pop_front()
		play_sequence(next)


func _execute_sequence() -> void:
	if not _current_sequence:
		return
	
	for i in _current_sequence.actions.size():
		if not _is_playing:
			return
		
		_current_step = i
		var action: RefCounted = _current_sequence.actions[i]
		await _execute_action(action)
		
		sequence_step_completed.emit(_current_sequence.id, i)
		Services.event_bus.emit(GameEventTypesScript.SEQUENCE_STEP, {
			"sequence_id": _current_sequence.id,
			"step_index": i
		})
	
	_end_current()


func _execute_action(action: RefCounted) -> void:
	match action.action_type:
		SequenceActionScript.Type.WAIT:
			await get_tree().create_timer(action.duration).timeout
		
		SequenceActionScript.Type.BLOCK_PLAYER:
			_block_players(action.target_players)
		
		SequenceActionScript.Type.UNBLOCK_PLAYER:
			_unblock_players(action.target_players)
		
		SequenceActionScript.Type.CAMERA_CUT:
			if action.camera:
				Services.camera_manager.set_active_camera(action.camera)
		
		SequenceActionScript.Type.CAMERA_RESTORE:
			_restore_player_cameras()
		
		SequenceActionScript.Type.PLAY_SOUND:
			if action.sound:
				Services.utils.play_sound(action.sound, action.sound_source, action.position, action.volume_db)
		
		SequenceActionScript.Type.SHOW_TEXT:
			_show_event_text(action.text, action.duration)
		
		SequenceActionScript.Type.HIDE_TEXT:
			_hide_event_text()
		
		SequenceActionScript.Type.SPAWN_ENEMY:
			_spawn_enemy(action)
		
		SequenceActionScript.Type.PLAY_MUSIC:
			_play_music(action)
		
		SequenceActionScript.Type.STOP_MUSIC:
			_stop_music()
		
		SequenceActionScript.Type.CUSTOM:
			if action.custom_callable.is_valid():
				var result = action.custom_callable.call()
				if result is Signal:
					await result


func _block_players(targets: Array[Node]) -> void:
	var players := _get_players(targets)
	for player in players:
		if player is Player:
			player.blocked_movement = true
	Services.event_bus.emit(GameEventTypesScript.PLAYER_BLOCKED, {"players": players})


func _unblock_players(targets: Array[Node]) -> void:
	var players := _get_players(targets)
	for player in players:
		if player is Player:
			player.blocked_movement = false
	Services.event_bus.emit(GameEventTypesScript.PLAYER_UNBLOCKED, {"players": players})


func _get_players(targets: Array[Node]) -> Array[Node]:
	if not targets.is_empty():
		return targets
	return Array(Services.enemy_context.get_players(), TYPE_OBJECT, &"Node", null)


func _restore_player_cameras() -> void:
	var players = Services.enemy_context.get_players()
	for player in players:
		if player is Player and player.camera_3d:
			Services.camera_manager.set_active_camera(player.camera_3d)
			break


func _show_event_text(text: String, duration: float) -> void:
	var hud = Services.world_context.get_hud()
	if hud:
		hud.show_event_text(text, false, duration)


func _hide_event_text() -> void:
	var hud = Services.world_context.get_hud()
	if hud:
		hud.hide_event_text()


func _spawn_enemy(action: RefCounted) -> void:
	if not action.enemy_scene:
		return
	
	var enemies_node = Services.world_context.get_enemies_node()
	if not enemies_node:
		return
	
	var enemy = action.enemy_scene.instantiate()
	enemies_node.add_child(enemy)
	
	if action.spawn_position != Vector3.ZERO:
		enemy.position = action.spawn_position
	if not action.spawn_room.is_empty():
		enemy.current_room = action.spawn_room
	if action.target_player:
		enemy.current_target = action.target_player


func _play_music(action: RefCounted) -> void:
	var level = Services.world_context.get_level_node()
	if not level:
		return
	
	var music_player = level.get_node_or_null("GlobalMusic")
	if music_player and action.sound:
		music_player.stream = action.sound
		music_player.volume_db = action.volume_db
		music_player.play()


func _stop_music() -> void:
	var level = Services.world_context.get_level_node()
	if not level:
		return
	
	var music_player = level.get_node_or_null("GlobalMusic")
	if music_player:
		music_player.stop()
