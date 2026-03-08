class_name RoomPathingComponent
extends Node

## Handles room-based BFS pathfinding for enemies.
## Extracts the transition graph traversal logic from enemy.gd.

signal path_found(transitions: Array)
signal path_not_found()

var _enemy_context: Node = null
var _path_cache: Dictionary = {}
var _cache_version := 0


func _ready() -> void:
	if _enemy_context == null:
		_enemy_context = _resolve_enemy_context_from_services()
	_connect_enemy_context()


func _exit_tree() -> void:
	_disconnect_enemy_context()


func set_enemy_context(context: Node) -> void:
	if _enemy_context == context:
		return
	_disconnect_enemy_context()
	_enemy_context = context
	_connect_enemy_context()
	invalidate_cached_paths()


func find_path_to_room(from_room: String, to_room: String) -> Array:
	var transition_graph := _get_transition_graph()
	var enemy_exceptions := _get_enemy_exceptions()
	
	if transition_graph.is_empty():
		path_not_found.emit()
		return []
	
	if from_room == to_room:
		path_found.emit([])
		return []

	var cache_key := _make_cache_key(from_room, to_room)
	if _path_cache.has(cache_key):
		return _emit_cached_result(_path_cache[cache_key])
	
	var visited_rooms := []
	var queue := [[from_room]]
	
	while queue:
		var path = queue.pop_front()
		var current_room = path[-1]
		
		if current_room == to_room:
			var transitions := []
			for i in range(1, path.size(), 2):
				transitions.append(path[i])
				_path_cache[cache_key] = {"found": true, "transitions": transitions.duplicate()}
			path_found.emit(transitions)
			return transitions
		
		if current_room not in visited_rooms:
			visited_rooms.append(current_room)
			
			if current_room not in transition_graph:
				continue
			
			for transition_point in transition_graph[current_room].keys():
				if transition_point in enemy_exceptions:
					continue
				
				var next_room = transition_graph[current_room][transition_point]
				if next_room not in visited_rooms:
					var new_path = path.duplicate()
					new_path.append(transition_point)
					new_path.append(next_room)
					queue.append(new_path)
	
	_path_cache[cache_key] = {"found": false, "transitions": []}
	path_not_found.emit()
	return []


func invalidate_cached_paths() -> void:
	_path_cache.clear()
	_cache_version += 1


func get_cache_entry_count() -> int:
	return _path_cache.size()


func get_cache_version() -> int:
	return _cache_version


func _get_transition_graph() -> Dictionary:
	if _enemy_context == null:
		return {}
	return _enemy_context.get_transition_graph()


func _get_enemy_exceptions() -> Array:
	if _enemy_context == null:
		return []
	return _enemy_context.get_enemy_exceptions()


func _resolve_enemy_context_from_services() -> Node:
	var services := get_node_or_null("/root/Services")
	if services == null:
		return null
	return services.get("enemy_context") as Node


func _connect_enemy_context() -> void:
	if _enemy_context and _enemy_context.has_signal("transitions_changed"):
		var callback := Callable(self, "_on_transitions_changed")
		if not _enemy_context.transitions_changed.is_connected(callback):
			_enemy_context.transitions_changed.connect(callback)


func _disconnect_enemy_context() -> void:
	if _enemy_context and _enemy_context.has_signal("transitions_changed"):
		var callback := Callable(self, "_on_transitions_changed")
		if _enemy_context.transitions_changed.is_connected(callback):
			_enemy_context.transitions_changed.disconnect(callback)


func _on_transitions_changed(_transitions_node: Node3D) -> void:
	invalidate_cached_paths()


func _make_cache_key(from_room: String, to_room: String) -> String:
	return "%s->%s" % [from_room, to_room]


func _emit_cached_result(cached_result: Dictionary) -> Array:
	var transitions: Array = cached_result.get("transitions", []).duplicate()
	if cached_result.get("found", false):
		path_found.emit(transitions)
	else:
		path_not_found.emit()
	return transitions
