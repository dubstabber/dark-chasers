class_name LevelManager
extends Node

## Centralized scene flow service.
## All cross-scene transitions should route through this service.
##
## Transition context schema (guideline):
## - spawn_id: StringName|String (optional) - identifier to select a player spawn marker in destination level
## - from_map: String (optional) - source map identifier
## - from_teleport: NodePath|String (optional) - teleport node path that initiated transition
## - reason: String (optional) - human-readable reason/event for transition
## - startup: bool (optional) - true when transition is part of initial boot
## - triggering_body_name: String (optional) - metadata only; do NOT pass live Node references
##
## IMPORTANT: Only serializable metadata should be passed in context.
## Objects (Nodes/Resources), Callables, and Signals are stripped for safety.

signal transition_requested(scene_path: String, context: Dictionary)
signal transition_completed(scene_path: String)

var _last_transition_request: Dictionary = {}
var _level_host: Node = null


func register_level_host(host: Node) -> void:
	if host == null:
		push_warning("LevelManager: register_level_host called with null host")
		return
	_level_host = host


func request_level_transition_scene(scene: PackedScene, context: Dictionary = {}) -> Error:
	if scene == null:
		push_warning("LevelManager: request_level_transition_scene called with null scene")
		return ERR_INVALID_PARAMETER
	if scene.resource_path == "":
		push_warning("LevelManager: request_level_transition_scene requires a PackedScene with a valid resource_path")
		return ERR_INVALID_PARAMETER
	return request_level_transition(scene.resource_path, context)


func request_level_transition(scene_path: String, context: Dictionary = {}) -> Error:
	if scene_path == "":
		push_warning("LevelManager: scene_path is empty")
		return ERR_INVALID_PARAMETER

	var context_copy := _sanitize_transition_context(context)
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

	# Transitions are often requested from physics callbacks (e.g. Area3D.body_entered).
	# Removing CollisionObjects during a physics callback is not allowed.
	# Defer the actual scene swap to idle when we're inside the physics frame.
	if Engine.is_in_physics_frame():
		call_deferred("_execute_transition", scene_path)
		return OK

	return _execute_transition(scene_path)


func _execute_transition(scene_path: String) -> Error:
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


func _sanitize_transition_context(context: Dictionary) -> Dictionary:
	# Deep sanitize to avoid carrying Object references across transitions.
	var sanitized: Variant = _sanitize_variant(context)
	if sanitized is Dictionary:
		return sanitized
	return {}


func _sanitize_variant(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out := {}
			for k in (value as Dictionary).keys():
				var v: Variant = (value as Dictionary)[k]
				var sv: Variant = _sanitize_variant(v)
				if sv == null:
					continue
				out[k] = sv
			return out
		TYPE_ARRAY:
			var out_arr: Array = []
			for item in (value as Array):
				var si: Variant = _sanitize_variant(item)
				if si == null:
					continue
				out_arr.append(si)
			return out_arr
		TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL:
			return null
		_:
			return value


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
		_level_host.remove_child(child)
		child.queue_free()

	var scene_instance := (scene_resource as PackedScene).instantiate()
	if scene_instance == null:
		push_warning("LevelManager: Failed to instantiate scene '%s'" % scene_path)
		return ERR_CANT_CREATE

	_level_host.add_child(scene_instance)
	return OK
