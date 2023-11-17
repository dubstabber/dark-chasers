extends CharacterBody3D

const SPEED = 7.0
const ACCEL = 10

@export var current_room: String

var transitionsNode: Node3D
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: CharacterBody3D
var look_point_dir: Vector3
var jump_speed: float = 0
var direction: Vector3
var noticed_target := true

@onready var nav = $NavigationAgent3D
@onready var find_path_timer = $FindPathTimer
@onready var animated_sprite_3d = $AnimatedSprite3D
@onready var sight_raycast = $NoticeRay


func _ready():
	transitionsNode = get_tree().get_first_node_in_group("transitions")
	target = get_tree().get_first_node_in_group("player")


func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if target:
		if (
			sight_raycast.is_colliding()
			and sight_raycast.get_collider().is_in_group("player")
			and not noticed_target
		):
			noticed_target = true
		if noticed_target:
			var next_pos = nav.get_next_path_position()
			if global_position != next_pos and is_on_floor():
				look_at(next_pos, Vector3(0.01, 0.91, 0.01))
			direction = (next_pos - global_position).normalized()
			velocity = velocity.lerp(direction * (SPEED + jump_speed), ACCEL * delta)
		animateSprite()
		move_and_slide()


func animateSprite():
	var p_pos = global_position.direction_to(target.global_position)
	var vertical_side = global_transform.basis.z
	var horizontal_side = global_transform.basis.x
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


func makepath() -> void:
	if !!target:
		if target.current_room == current_room:
			nav.target_position = target.global_position
		else:
			var transition_point = find_path_to_player()[0]
			nav.target_position = transitionsNode.get_node(transition_point).global_position


func find_path_to_player():
	var visitedRooms = []
	var queue = [[current_room]]

	while queue:
		var path = queue.pop_front()
		var c_room = path[-1]

		if c_room == target.current_room:
			var transitions = []
			for i in range(1, path.size(), 2):
				transitions.append(path[i])
			return transitions

		if c_room not in visitedRooms:
			visitedRooms.append(c_room)

			for transitionPoint in transitionsNode.map_transitions[c_room].keys():
				var nextRoom = transitionsNode.map_transitions[c_room][transitionPoint]
				if transitionPoint == "ThirdFloorAbyss":
					continue
				if nextRoom not in visitedRooms:
					var new_path = path.duplicate()
					new_path.append(transitionPoint)
					new_path.append(nextRoom)
					queue.append(new_path)
	return null


func _on_find_path_timer_timeout():
	var distance_to_target = nav.distance_to_target()
	if distance_to_target < 10:
		find_path_timer.wait_time = 0.1
	elif distance_to_target < 20:
		find_path_timer.wait_time = 0.3
	elif distance_to_target < 35:
		find_path_timer.wait_time = 0.6
	elif distance_to_target < 50:
		find_path_timer.wait_time = 1.0
	else:
		find_path_timer.wait_time = 2.0
	makepath()


func _on_sight_timer_timeout():
	if target:
		sight_raycast.target_position = target.global_position - global_position


func _on_kill_zone_body_entered(body):
	if body.is_in_group("player"):
		body.kill(position)
		noticed_target = false
		velocity = Vector3.ZERO


func _on_navigation_agent_3d_link_reached(details):
	if details.owner.is_in_group("jump-down"):
		jump_speed = gravity


func _on_navigation_agent_3d_waypoint_reached(_details):
	jump_speed = 0
