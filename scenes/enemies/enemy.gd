class_name Enemy extends CharacterBody3D

@export var current_room: String
@export var disappear_zones: Array[Area3D]
@export var is_wandering := false
@export var chase_player := true
@export var can_open_door := true
@export var speed: float = 7.0
@export var accel: float = 10.0
@export var debug_prints := false
@export var death_message: String = ""

var _blood_component: BloodEffectComponent
var _nav_component: EnemyNavigationComponent
var _ai_component: EnemyAIComponent
var _health_component: HealthComponent
var _wandering_component: EnemyWanderingComponent

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
	players = get_tree().get_first_node_in_group("players")
	map_transitions = get_tree().get_first_node_in_group("transitions")
	for disappear_zone in disappear_zones:
		disappear_zone.connect("body_entered", _on_disappear_area)
	_setup_components()


func _setup_components() -> void:
	_blood_component = get_node_or_null("BloodEffectComponent")
	_setup_navigation_component()
	_setup_ai_component()
	_setup_health_component()
	_setup_wandering_component()


func _setup_navigation_component() -> void:
	_nav_component = get_node_or_null("GodotNavigationComponent")
	if _nav_component:
		_nav_component.target_reached.connect(_on_navigation_agent_3d_target_reached)
		_nav_component.link_reached.connect(_on_navigation_agent_3d_link_reached)
		_nav_component.waypoint_reached.connect(_on_navigation_agent_3d_waypoint_reached)


func _setup_ai_component() -> void:
	_ai_component = get_node_or_null("EnemyAIComponent")
	if _ai_component:
		_ai_component.chase_player = chase_player
		_ai_component.target_acquired.connect(_on_target_acquired)
		_ai_component.target_died.connect(_on_target_died)


func _setup_health_component() -> void:
	_health_component = get_node_or_null("HealthComponent")
	if _health_component:
		_health_component.died.connect(_on_died)


func _setup_wandering_component() -> void:
	_wandering_component = get_node_or_null("EnemyWanderingComponent")
	if _wandering_component:
		_wandering_component.set_debug(debug_prints)
		_wandering_component.direction_changed.connect(_on_wandering_direction_changed)
		if is_wandering:
			_wandering_component.start_wandering()


func _on_wandering_direction_changed(new_dir: Vector3) -> void:
	direction = new_dir


func _on_died() -> void:
	is_killed = true
	velocity = Vector3.ZERO


func has_health_component() -> bool:
	return _health_component != null


func get_health_component() -> HealthComponent:
	return _health_component


func _physics_process(delta):
	if not is_on_floor() and not is_flying:
		velocity.y -= gravity * delta
	if not is_killed:
		if not current_target and chase_player:
			_check_for_targets()
		if current_target or not waypoints.is_empty():
			var next_pos = _get_next_path_position()
			var horizontal_direction = Vector3(next_pos.x - global_position.x, 0, next_pos.z - global_position.z).normalized()
			direction = horizontal_direction
			var target_velocity = horizontal_direction * (speed + jump_speed)
			velocity.x = lerp(velocity.x, target_velocity.x, accel * delta)
			velocity.z = lerp(velocity.z, target_velocity.z, accel * delta)
			if current_target and current_target.has_method("is_dead") and current_target.is_dead():
				current_target = null
				if _ai_component:
					_ai_component.clear_target()
				velocity = Vector3.ZERO
				find_path_timer.wait_time = 0.1
			if is_on_floor() or is_flying:
				look_forward()
		elif is_wandering:
			if _wandering_component:
				_wandering_component.update(delta)
				direction = _wandering_component.direction
			else:
				_legacy_wandering_update()
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


func _check_for_targets() -> void:
	if _ai_component:
		_ai_component.check_targets()
	else:
		_legacy_check_targets()


func _on_target_acquired(target: Node3D) -> void:
	current_target = target
	makepath()
	if debug_prints:
		print("Enemy detected new target, immediately calculating path")


func _on_target_died() -> void:
	current_target = null
	velocity = Vector3.ZERO
	find_path_timer.wait_time = 0.1


func _get_next_path_position() -> Vector3:
	if _nav_component:
		return _nav_component.get_next_path_position()
	return nav.get_next_path_position()


func _set_nav_target(pos: Vector3) -> void:
	if _nav_component:
		_nav_component.set_target(pos)
	else:
		nav.target_position = pos


func _get_distance_to_target() -> float:
	if _nav_component:
		return _nav_component.distance_to_target()
	return nav.distance_to_target()


func _legacy_check_targets() -> void:
	if not players:
		return
	var space_state = get_world_3d().direct_space_state
	for target in players.get_children():
		var params = PhysicsRayQueryParameters3D.new()
		params.from = global_position
		params.to = target.camera_3d.global_position
		params.exclude = [self]
		params.collision_mask = collision_mask
		var result = space_state.intersect_ray(params)
		if result and result.collider.is_in_group("player") and not (target.has_method("is_dead") and target.is_dead()):
			var was_target_null = current_target == null
			current_target = result.collider
			if was_target_null:
				makepath()


func makepath() -> void:
	if current_target:
		if current_target.current_room == current_room or not current_room:
			_set_nav_target(current_target.global_position)
		elif map_transitions:
			var transition_point = find_path_to_player()[0]
			_set_nav_target(map_transitions.get_node(transition_point).global_position)
	elif not waypoints.is_empty():
		_set_nav_target(waypoints[0])


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
	var distance_to_target = _get_distance_to_target()
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
		var msg = body.name + " " + death_message if death_message != "" else ""
		body.kill(position, msg)
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


func _legacy_wandering_update() -> void:
	if wandering_timer.is_stopped():
		wandering_timer.start()
	if interaction_ray and interaction_ray.is_colliding():
		var collider = interaction_ray.get_collider()
		if collider != null and not collider.is_in_group("player"):
			direction = - direction.normalized()


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


func take_damage(_amount: int) -> void:
	take_damage_at_position(_amount, global_position + Vector3(0, 1.0, 0))


func take_damage_at_position(_amount: int, hit_pos: Vector3) -> void:
	if _blood_component:
		_blood_component.spawn_splatter(hit_pos, Vector3.ZERO)


func take_damage_with_direction(amount: int, hit_pos: Vector3, shot_direction: Vector3) -> void:
	if _blood_component:
		_blood_component.spawn_splatter(hit_pos, shot_direction)
		_blood_component.trace_to_walls(amount, hit_pos, shot_direction)
