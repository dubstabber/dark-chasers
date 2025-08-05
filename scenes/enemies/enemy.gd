class_name Enemy extends CharacterBody3D

@export var current_room: String
@export var disappear_zones: Array[Area3D]
@export var is_wandering := false
@export var chase_player := true
@export var can_open_door := true
@export var speed: float = 7.0
@export var accel: float = 10.0
@export var debug_prints := false

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var players: Node3D
var current_target: CharacterBody3D
var waypoints: Array
var jump_speed := 0.0
var direction: Vector3
var map_transitions: Node3D
var ground_type: String
var moving_state := "idle"
var is_flying := false
var is_killed := false

@onready var nav = $NavigationAgent3D
@onready var find_path_timer = $Timers/FindPathTimer
@onready var wandering_timer = $Timers/WanderingTimer
@onready var graphics = $Graphics
@onready var interaction_ray = $Interaction


func _ready():
	players = get_parent().get_node("%Players")
	map_transitions = get_parent().get_node_or_null("%Transitions")
	for disappear_zone in disappear_zones:
		disappear_zone.connect("body_entered", _on_disappear_area)


func _physics_process(delta):
	if not is_on_floor() and not is_flying:
		velocity.y -= gravity * delta
	if not is_killed:
		if not current_target and chase_player:
			check_targets()
		if current_target or not waypoints.is_empty():
			var next_pos = nav.get_next_path_position()
			# Only use horizontal movement for ground-based enemies to prevent Y drift
			var horizontal_direction = Vector3(next_pos.x - global_position.x, 0, next_pos.z - global_position.z).normalized()
			direction = horizontal_direction
			# Preserve Y velocity for gravity/jumping, only lerp X and Z components
			var target_velocity = horizontal_direction * (speed + jump_speed)
			velocity.x = lerp(velocity.x, target_velocity.x, accel * delta)
			velocity.z = lerp(velocity.z, target_velocity.z, accel * delta)
			if current_target and current_target.has_method("is_dead") and current_target.is_dead():
				current_target = null
				velocity = Vector3.ZERO
				# Reset timer to be more responsive when looking for new targets
				find_path_timer.wait_time = 0.1
			if is_on_floor() or is_flying:
				look_forward()
		elif is_wandering:
			if wandering_timer.is_stopped():
				wandering_timer.start()
			# Check for wall collision during wandering
			if debug_prints:
				print("Checking wall collision during wandering...")
			if _check_wall_collision():
				if debug_prints:
					print("Wall collision detected! Changing direction...")
				_change_wandering_direction()
			# Apply same horizontal-only movement for wandering
			var target_velocity = direction * (speed + jump_speed)
			velocity.x = lerp(velocity.x, target_velocity.x, accel * delta)
			velocity.z = lerp(velocity.z, target_velocity.z, accel * delta)
			if is_on_floor() or is_flying:
				look_forward()
		else:
			velocity = Vector3.ZERO
	
	move_and_slide()


func look_forward() -> void:
	if velocity:
		rotation.y = atan2(velocity.x, velocity.z) + PI


func check_targets() -> void:
	if players:
		var space_state = get_world_3d().direct_space_state
		for target in players.get_children():
			var params = PhysicsRayQueryParameters3D.new()
			params.from = global_position
			params.to = target.camera_3d.global_position
			params.exclude = [self]
			params.collision_mask = collision_mask
			var result = space_state.intersect_ray(params)
			if (
				result
				and result.collider.is_in_group("player")
				and not (target.has_method("is_dead") and target.is_dead())
			):
				var was_target_null = current_target == null
				current_target = result.collider
				# Immediately calculate path when target is first detected to eliminate delay
				if was_target_null:
					makepath()
					if debug_prints:
						print("Enemy detected new target, immediately calculating path")


func makepath() -> void:
	if current_target:
		if current_target.current_room == current_room or not current_room:
			nav.target_position = current_target.global_position
		elif map_transitions:
			var transition_point = find_path_to_player()[0]
			nav.target_position = map_transitions.get_node(transition_point).global_position
	elif not waypoints.is_empty():
		nav.target_position = waypoints[0]


func find_path_to_player():
	var visitedRooms = []
	var queue = [[current_room]]

	while queue:
		var path = queue.pop_front()
		var c_room = path[-1]

		if c_room == current_target.current_room:
			var transitions = []
			for i in range(1, path.size(), 2):
				transitions.append(path[i])
			return transitions
		if c_room not in visitedRooms:
			visitedRooms.append(c_room)
			for transitionPoint in map_transitions.map_transitions[c_room].keys():
				var nextRoom = map_transitions.map_transitions[c_room][transitionPoint]
				if "enemy_exceptions" in map_transitions and transitionPoint in map_transitions.enemy_exceptions:
					continue
				if nextRoom not in visitedRooms:
					var new_path = path.duplicate()
					new_path.append(transitionPoint)
					new_path.append(nextRoom)
					queue.append(new_path)
	return null


func add_disappear_zone(area):
	area.connect("body_entered", _on_disappear_area)


func _on_find_path_timer_timeout():
	var distance_to_target = nav.distance_to_target()
	# More responsive timer intervals, especially for distant targets
	if distance_to_target < 20 or not waypoints.is_empty():
		find_path_timer.wait_time = 0.1
	elif distance_to_target < 35:
		find_path_timer.wait_time = 0.3 # Reduced from 0.5
	elif distance_to_target < 50:
		find_path_timer.wait_time = 0.5 # Reduced from 0.8
	else:
		find_path_timer.wait_time = 0.8 # Significantly reduced from 1.7
	makepath()


func _on_kill_zone_body_entered(body):
	if body.is_in_group("player"):
		body.kill(position)
		current_target = null
		velocity = Vector3.ZERO


func _on_interaction_timer_timeout():
	var collider = interaction_ray.get_collider()
	if collider:
		var root_node = collider.get_parent()
		if root_node is Openable:
			if root_node.has_method("open_with_point") and can_open_door:
				# Don't pass a triggering player - enemies shouldn't show door locked messages to players
				root_node.open_with_point(interaction_ray.get_collision_point())
			elif is_wandering:
				direction = Vector3(-direction.x, 0, -direction.z)


func _check_wall_collision() -> bool:
	"""Check if the enemy is about to collide with a wall during wandering using interaction_ray"""
	if not interaction_ray:
		if debug_prints:
			print("No interaction_ray available")
		return false
	
	# Check if ray is currently colliding with something
	if interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if debug_prints:
			print("Ray collision detected with: ", collider.name if collider else "null")
			if collider:
				print("Collider groups: ", collider.get_groups())
		
		# Return true if it's a wall (not a player)
		if collider != null and not collider.is_in_group("player"):
			return true
	else:
		if debug_prints:
			print("No ray collision detected")
	
	return false


func _change_wandering_direction() -> void:
	"""Change wandering direction when hitting a wall - simple turn around approach"""
	# Simple approach: turn around 180 degrees
	direction = - direction.normalized()
	
	if debug_prints:
		print("Enemy turned around to avoid wall, new direction: ", direction)


func _on_wandering_timer_timeout():
	wandering_timer.wait_time = randf_range(0.2, 2.8)
	direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()


func _on_navigation_agent_3d_target_reached():
	if not waypoints.is_empty():
		waypoints.pop_front()
		if waypoints.is_empty(): velocity = Vector3.ZERO


func _on_navigation_agent_3d_link_reached(details):
	if details.owner.is_in_group("jump-up"):
		velocity.y = 12
		jump_speed = gravity
	if details.owner.is_in_group("jump-down"):
		jump_speed = gravity


func _on_navigation_agent_3d_waypoint_reached(_details):
	jump_speed = 0


func _on_disappear_area(body):
	if body == self:
		queue_free()
