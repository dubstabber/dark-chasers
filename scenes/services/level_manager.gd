class_name LevelManager
extends Node

## Centralized scene flow service.
## All cross-scene transitions should route through this service.

signal transition_requested(scene_path: String, context: Dictionary)
signal transition_completed(scene_path: String)

var _last_transition_request: Dictionary = {}
var _level_host: Node = null


func register_level_host(host: Node) -> void:
	if host == null:
		push_warning("LevelManager: register_level_host called with null host")
		return
	_level_host = host


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
		Services.event_bus.emit(GameEventTypes.LEVEL_TRANSITION, {
			"scene_path": scene_path,
			"context": context_copy
		}, self)

	var err := _transition_via_host(scene_path)
	if err == ERR_UNAVAILABLE:
		push_warning("LevelManager: LevelHost is not registered/valid. Falling back to SceneTree.change_scene_to_file.")
		err = get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_warning("LevelManager: Failed to change scene to '%s' (err=%d)" % [scene_path, err])
		return err

	transition_completed.emit(scene_path)
	return OK


func get_last_transition_request() -> Dictionary:
	return _last_transition_request.duplicate(true)


func _transition_via_host(scene_path: String) -> Error:
	if not is_instance_valid(_level_host):
		_level_host = null
		return ERR_UNAVAILABLE

	var scene_resource := load(scene_path)
	if scene_resource == null:
		push_warning("LevelManager: Unable to load scene resource at '%s'" % scene_path)
		return ERR_CANT_OPEN
	if not (scene_resource is PackedScene):
		push_warning("LevelManager: Resource at '%s' is not a PackedScene" % scene_path)
		return ERR_FILE_UNRECOGNIZED

	for child in _level_host.get_children():
		child.queue_free()

	var scene_instance := (scene_resource as PackedScene).instantiate()
	if scene_instance == null:
		push_warning("LevelManager: Failed to instantiate scene '%s'" % scene_path)
		return ERR_CANT_CREATE

	_level_host.add_child(scene_instance)
	return OK
