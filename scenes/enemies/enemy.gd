class_name Enemy extends CharacterBody3D

@export var current_room: String
@export var disappear_zones: Array[Area3D]
@export var is_wandering: bool = false

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var players: Node3D
var current_target: CharacterBody3D
var waypoints: Array
var jump_speed := 0.0
var direction: Vector3
var map_transitions: Node3D
var ground_type: String
var is_flyting := false

var speed: float
var accel: float

@onready var nav = $NavigationAgent3D
@onready var find_path_timer = $Timers/FindPathTimer
@onready var wandering_timer = $Timers/WanderingTimer
@onready var rotation_controller = $RotationController
@onready var interaction_ray = $RotationController/Interaction


func _ready():
	players = get_tree().get_first_node_in_group("players")
	map_transitions = get_tree().get_first_node_in_group("transitions")
	for disappear_zone in disappear_zones:
		disappear_zone.connect("body_entered", _on_disappear_area)


func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
	if not current_target:
		check_targets()
	if current_target or waypoints:
		var distance_to_target = nav.distance_to_target()
		if distance_to_target < 0.2:
			velocity = Vector3.ZERO
		else:
			var next_pos = nav.get_next_path_position()
			if global_position != next_pos and is_on_floor():
				rotation_controller.look_at(next_pos)
			direction = (next_pos - global_position).normalized()
			velocity = velocity.lerp(direction * (speed + jump_speed), accel * delta)
			if current_target.killed:
				current_target = null
				velocity = Vector3.ZERO
	elif is_wandering:
		if wandering_timer.is_stopped():
			wandering_timer.start()
		velocity = velocity.lerp(direction * (speed + jump_speed), accel * delta)
	move_and_slide()


func check_targets():
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
				and not target.killed
			):
				current_target = result.collider


func makepath() -> void:
	if current_target:
		if current_target.current_room == current_room or not current_room:
			nav.target_position = current_target.global_position
		elif map_transitions:
			var transition_point = find_path_to_player()[0]
			nav.target_position = map_transitions.get_node(transition_point).global_position
	elif waypoints:
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
				if transitionPoint == "ThirdFloorAbyss":
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
	if distance_to_target < 10:
		find_path_timer.wait_time = 0.1
	elif distance_to_target < 20:
		find_path_timer.wait_time = 0.2
	elif distance_to_target < 35:
		find_path_timer.wait_time = 0.5
	elif distance_to_target < 50:
		find_path_timer.wait_time = 0.8
	else:
		find_path_timer.wait_time = 1.7
	makepath()


func _on_kill_zone_body_entered(body):
	if body.is_in_group("player"):
		body.kill(position)
		current_target = null
		velocity = Vector3.ZERO


func _on_interaction_timer_timeout():
	var collider = interaction_ray.get_collider()
	if collider:
		var parent = collider.get_parent()
		if parent.is_in_group("door") and parent.can_manual_open:
			parent.open(collider.name)
		elif is_wandering:
			direction = Vector3(-direction.x, 0, -direction.z)
			if global_position != global_position + direction and is_on_floor():
				rotation_controller.look_at(global_position + direction)


func _on_wandering_timer_timeout():
	wandering_timer.wait_time = randf_range(0.5, 3)
	direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	if global_position != global_position + direction and is_on_floor():
		rotation_controller.look_at(global_position + direction)


func _on_navigation_agent_3d_target_reached():
	if waypoints:
		waypoints.pop_back()
		velocity = Vector3.ZERO


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

