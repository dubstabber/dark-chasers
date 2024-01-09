extends CharacterBody3D

const SPEED = 7.0
const ACCEL = 10

@export var current_room: String
@export var disappear_zones: Array[Area3D]

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var map: Node3D
var current_target: CharacterBody3D
var waypoints: Array
var jump_speed: float = 0
var direction: Vector3

@onready var nav = $NavigationAgent3D
@onready var find_path_timer = $FindPathTimer
@onready var rotation_controller = $RotationController
@onready var animated_sprite_3d = $RotationController/AnimatedSprite3D
@onready var sight_raycast = $NoticeRay
@onready var interaction = $RotationController/Interaction


func _ready():
	map = get_tree().get_first_node_in_group("map")
	for disappear_zone in disappear_zones:
		disappear_zone.connect("body_entered", _on_disappear_area)


func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if current_target or waypoints:
		var next_pos = nav.get_next_path_position()
		if global_position != next_pos and is_on_floor():
			#rotation_controller.look_at(next_pos, Vector3(0.01, 0.91, 0.01))
			rotation_controller.look_at(next_pos)

		direction = (next_pos - global_position).normalized()
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
	if map.players:
		for target in map.players.get_children():
			sight_raycast.target_position = target.camera_3d.global_position - global_position
			sight_raycast.force_raycast_update()
			if (
				sight_raycast.is_colliding()
				and sight_raycast.get_collider().is_in_group("player")
				and not current_target
			):
				current_target = sight_raycast.get_collider()


func makepath() -> void:
	if current_target:
		if current_target.current_room == current_room or not current_room:
			nav.target_position = current_target.global_position
		else:
			var transition_point = find_path_to_player()[0]
			nav.target_position = map.transitions.get_node(transition_point).global_position
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
			for transitionPoint in map.transitions.map_transitions[c_room].keys():
				var nextRoom = map.transitions.map_transitions[c_room][transitionPoint]
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


func _on_sight_timer_timeout():
	if not current_target:
		check_targets()


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
	var collider = interaction.get_collider()
	if collider:
		var parent = collider.get_parent()
		if parent.is_in_group("door") and parent.can_manual_open:
			parent.open(collider.name)


func _on_navigation_agent_3d_target_reached():
	if waypoints:
		waypoints.pop_back()
		velocity = Vector3.ZERO
		#rotation = Vector3.ZERO


func _on_disappear_area(_body):
	queue_free()
