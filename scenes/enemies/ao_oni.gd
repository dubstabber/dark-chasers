extends CharacterBody3D

const SPEED = 7.0
const ACCEL = 10

@export var current_room: String
@export var disappear_zones: Array[Area3D]
@export var is_wandering: bool = false

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var players: Node3D
var current_target: CharacterBody3D
var waypoints: Array
var jump_speed: float = 0
var direction: Vector3
var map_transitions: Node3D
var ground_type: String

@onready var nav = $NavigationAgent3D
@onready var find_path_timer = $Timers/FindPathTimer
@onready var wandering_timer = $Timers/WanderingTimer
@onready var rotation_controller = $RotationController
@onready var animated_sprite_3d = $RotationController/AnimatedSprite3D
@onready var interaction_ray = $RotationController/Interaction


func _ready():
	players = get_tree().get_first_node_in_group("players")
	map_transitions = get_tree().get_first_node_in_group("transitions")
	for disappear_zone in disappear_zones:
		disappear_zone.connect("body_entered", _on_disappear_area)
	animated_sprite_3d.connect("frame_changed", handle_footstep)


func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if not current_target:
		check_targets()
	if current_target or waypoints:
		var distance_to_target = nav.distance_to_target()
		if distance_to_target < 0.6:
			velocity = Vector3.ZERO
		else:
			var next_pos = nav.get_next_path_position()
			if global_position != next_pos and is_on_floor():
				rotation_controller.look_at(next_pos)
			direction = (next_pos - global_position).normalized()
			velocity = velocity.lerp(direction * (SPEED + jump_speed), ACCEL * delta)
	elif is_wandering:
		if wandering_timer.is_stopped():
			wandering_timer.start()
		velocity = velocity.lerp(direction * (SPEED + jump_speed), ACCEL * delta)
	animateSprite()
	move_and_slide()


func animateSprite():
	var p_pos = rotation_controller.global_position.direction_to(get_viewport().get_camera_3d().global_position)
	var vertical_side = rotation_controller.global_transform.basis.z
	var horizontal_side = rotation_controller.global_transform.basis.x
	var h_dot = horizontal_side.dot(p_pos)
	var v_dot = vertical_side.dot(p_pos)
	var state = "run" if velocity else "stay"
	if v_dot < -0.5:
		animated_sprite_3d.play(state + "-front")
	elif v_dot > 0.5:
		animated_sprite_3d.play(state + "-back")
	else:
		animated_sprite_3d.flip_h = h_dot > 0
		if abs(v_dot) < 0.3:
			animated_sprite_3d.play(state + "-side")


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
				and not current_target
				and not target.killed
			):
				current_target = result.collider


func makepath() -> void:
	if current_target:
		if current_target.current_room == current_room or not current_room:
			nav.target_position = current_target.global_position
		else:
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


func _on_navigation_agent_3d_link_reached(details):
	if details.owner.is_in_group("jump-down"):
		jump_speed = gravity


func _on_navigation_agent_3d_waypoint_reached(_details):
	jump_speed = 0


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


func _on_disappear_area(_body):
	queue_free()


func handle_footstep():
	if animated_sprite_3d.animation.contains("run-"):
		match ground_type:
			"dirt":
				Utils.play_footstep_sound(Preloads.dirt_footsteps.pick_random(), self)
			"hard":
				Utils.play_footstep_sound(Preloads.hard_footsteps.pick_random(), self)
			"carpet":
				Utils.play_footstep_sound(Preloads.carpet_footsteps.pick_random(), self)
			"floor":
				Utils.play_footstep_sound(Preloads.floor_footsteps.pick_random(), self)
			"wood":
				Utils.play_footstep_sound(Preloads.wood_footsteps.pick_random(), self)
			"metal1":
				Utils.play_footstep_sound(Preloads.metal1_footsteps.pick_random(), self)
			"metal2":
				Utils.play_footstep_sound(Preloads.metal2_footsteps.pick_random(), self)
