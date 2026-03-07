class_name EnemyTransitionComponent
extends Node

## Manages room-to-room transitions for an enemy. Handles pathfinding across
## rooms via transition points, and executing the actual teleport when reached.

var _owner_enemy: Enemy = null
var _enemy_context: Node = null
var _nav_component: EnemyNavigationComponent = null
var _motor_component: EnemyMotorComponent = null
var _disappear_zone_component: EnemyDisappearZoneComponent = null
var _room_pathing_component: RoomPathingComponent = null

var map_transitions: Node3D = null
var pending_transition_name: String = ""


func _ready() -> void:
	_owner_enemy = owner as Enemy
	_enemy_context = Services.enemy_context
	if _enemy_context:
		map_transitions = _enemy_context.get_transitions_node()



func setup(nav_component: EnemyNavigationComponent, motor_component: EnemyMotorComponent, disappear_zone_component: EnemyDisappearZoneComponent, room_pathing_component: RoomPathingComponent = null) -> void:
	_nav_component = nav_component
	_motor_component = motor_component
	_disappear_zone_component = disappear_zone_component
	_room_pathing_component = room_pathing_component


func makepath() -> void:
	# Retry finding map_transitions if null (handles timing with Level._ready())
	if not is_instance_valid(map_transitions) and _enemy_context:
		map_transitions = _enemy_context.get_transitions_node()

	var target = _owner_enemy.current_target
	if target:
		if is_target_in_same_room(target):
			pending_transition_name = ""
			_set_nav_target(target.global_position)
		elif map_transitions:
			var path_to_player = _find_path_to_player()
			if path_to_player and not path_to_player.is_empty():
				var transition_point = path_to_player[0]
				pending_transition_name = transition_point
				var trans_node = map_transitions.get_node(transition_point)
				_set_nav_target(trans_node.global_position)
			else:
				# No valid path found; fall back to direct navigation
				pending_transition_name = ""
				_set_nav_target(target.global_position)
		else:
			pending_transition_name = ""
	elif not _owner_enemy.waypoints.is_empty():
		pending_transition_name = ""
		_set_nav_target(_owner_enemy.waypoints[0])


func has_pending_transition() -> bool:
	return pending_transition_name != ""


func is_target_in_same_room(target: Node3D = null) -> bool:
	if not _owner_enemy:
		return true

	if target == null:
		target = _owner_enemy.current_target
	if target == null:
		return false

	var enemy_room := _get_room_name(_owner_enemy)
	if enemy_room == "":
		return true

	var target_room := _get_room_name(target)
	if target_room == "":
		return true

	return target_room == enemy_room


func handle_target_reached() -> bool:
	## Returns true if a transition was handled (caller should skip normal target_reached logic).
	if pending_transition_name == "" or not map_transitions:
		return false

	var transition_name := pending_transition_name
	pending_transition_name = ""

	var transition_node = map_transitions.get_node_or_null(transition_name)
	if transition_node:
		_execute_transition(transition_node)
	else:
		Services.utils.debug_warning("Enemy: transition_node not found: %s" % transition_name)
	return true


func _find_path_to_player() -> Array:
	var target = _owner_enemy.current_target
	if not target:
		return []

	if _room_pathing_component:
		var target_room := _get_room_name(target)
		if target_room == "":
			return []
		return _room_pathing_component.find_path_to_room(_owner_enemy.current_room, target_room)

	push_warning("EnemyTransitionComponent: No room pathing component found")
	return []


func _execute_transition(transition_node: Node3D) -> void:
	# Check for disappear zones before transitioning
	if _disappear_zone_component and _disappear_zone_component.check_overlap_immediate():
		return

	if not _enemy_context:
		return

	var transition_graph = _enemy_context.get_transition_graph()
	if transition_graph.is_empty():
		return

	var transition_name = transition_node.name

	if _owner_enemy.current_room not in transition_graph:
		return

	if transition_name not in transition_graph[_owner_enemy.current_room]:
		return

	# Find the marker (spawn point) within the transition
	var marker: Marker3D = null
	for child in transition_node.get_children():
		if child.is_in_group("spawn_point"):
			marker = child
			break

	if not marker:
		push_warning("Enemy._execute_transition: No spawn_point marker found in %s" % transition_name)
		return

	# Execute the transition
	var to_room = transition_graph[_owner_enemy.current_room][transition_name]
	_owner_enemy.current_room = to_room
	_owner_enemy.global_position = marker.global_position
	_reset_post_transition_motion_state()
	_owner_enemy.makepath()

	# Restart pathfinding with short delay
	_owner_enemy.restart_pathfinding(0.1)



func _reset_post_transition_motion_state() -> void:
	if not _owner_enemy:
		return

	_owner_enemy.velocity = Vector3.ZERO
	_owner_enemy.direction = Vector3.ZERO
	if _motor_component:
		_motor_component.direction = Vector3.ZERO
		_motor_component.jump_speed = 0.0

	if _nav_component:
		_nav_component.handle_owner_teleported()

	if not _owner_enemy.is_flying:
		_owner_enemy.apply_floor_snap()


func _set_nav_target(pos: Vector3) -> void:
	if _nav_component:
		_nav_component.set_target(pos)


func _get_room_name(node: Object) -> String:
	if node == null:
		return ""

	for property in node.get_property_list():
		if String(property.get("name", "")) == "current_room":
			var room_value = node.get("current_room")
			return "" if room_value == null else String(room_value)

	return ""
