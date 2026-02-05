class_name RoomPathingComponent
extends Node

## Handles room-based BFS pathfinding for enemies.
## Extracts the transition graph traversal logic from enemy.gd.

signal path_found(transitions: Array)
signal path_not_found()

var _enemy_context: Node = null


func _ready() -> void:
	_enemy_context = EnemyContext


func find_path_to_room(from_room: String, to_room: String) -> Array:
	var transition_graph := _get_transition_graph()
	var enemy_exceptions := _get_enemy_exceptions()
	
	if transition_graph.is_empty():
		path_not_found.emit()
		return []
	
	if from_room == to_room:
		path_found.emit([])
		return []
	
	var visited_rooms := []
	var queue := [[from_room]]
	
	while queue:
		var path = queue.pop_front()
		var current_room = path[-1]
		
		if current_room == to_room:
			var transitions := []
			for i in range(1, path.size(), 2):
				transitions.append(path[i])
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
	
	path_not_found.emit()
	return []


func _get_transition_graph() -> Dictionary:
	# EnemyContext is a known autoload; no fallback needed
	return _enemy_context.get_transition_graph()


func _get_enemy_exceptions() -> Array:
	# EnemyContext is a known autoload; no fallback needed
	return _enemy_context.get_enemy_exceptions()
