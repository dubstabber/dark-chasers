class_name LevelManager
extends Node

const GameEventTypesScript = preload("res://scenes/resources/game_event_types.gd")

## Centralized scene flow service.
## All cross-scene transitions should route through this service.

signal transition_requested(scene_path: String, context: Dictionary)
signal transition_completed(scene_path: String)

var _last_transition_request: Dictionary = {}


func request_level_transition(scene_path: String, context: Dictionary = {}) -> Error:
	if scene_path == "":
		push_warning("LevelManager: scene_path is empty")
		return ERR_INVALID_PARAMETER

	var context_copy := context.duplicate(true)
	_last_transition_request = {
		"scene_path": scene_path,
		"context": context_copy,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}

	transition_requested.emit(scene_path, context_copy)
	if Services and Services.event_bus:
		Services.event_bus.emit(GameEventTypesScript.LEVEL_TRANSITION, {
			"scene_path": scene_path,
			"context": context_copy
		}, self)

	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_warning("LevelManager: Failed to change scene to '%s' (err=%d)" % [scene_path, err])
		return err

	transition_completed.emit(scene_path)
	return OK


func get_last_transition_request() -> Dictionary:
	return _last_transition_request.duplicate(true)
