extends CharacterBody3D

const SPEED = 5.0
const ACCEL = 10

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var target: CharacterBody3D
var look_point_dir: Vector3
var jump_speed: float = 0
var direction: Vector3

@onready var nav = $NavigationAgent3D
@onready var find_path_timer = $FindPathTimer
@onready var animated_sprite_3d = $AnimatedSprite3D


func _ready():
	target = get_tree().get_first_node_in_group('player')


func _physics_process(delta):
	if not target: return
	var next_pos = nav.get_next_path_position()
	if global_position != next_pos and is_on_floor():
		look_at(next_pos)
	direction = (next_pos - global_position).normalized()
	
	velocity = velocity.lerp(direction * (SPEED+jump_speed), ACCEL * delta)
	animateSprite()
	move_and_slide()
	

func animateSprite():
	var p_pos = global_position.direction_to(target.global_position)
	var vertical_side = global_transform.basis.z
	var horizontal_side = global_transform.basis.x
	var h_dot = horizontal_side.dot(p_pos)
	var v_dot = vertical_side.dot(p_pos)
	if v_dot < -0.5:
		animated_sprite_3d.play('stay-front')
	elif v_dot > 0.5:
		animated_sprite_3d.play('stay-back')
	else:
		animated_sprite_3d.flip_h = h_dot > 0
		if abs(v_dot) < 0.3:
			animated_sprite_3d.play('stay-side')

func makepath() -> void:
	if !!target:
		nav.target_position = target.global_position

func _on_find_path_timer_timeout():
	var distance_to_target = nav.distance_to_target()
	if distance_to_target < 5:
		find_path_timer.wait_time = 0.1
	elif distance_to_target < 10:
		find_path_timer.wait_time = 0.6
	elif distance_to_target < 20:
		find_path_timer.wait_time = 1.0
	elif distance_to_target < 50:
		find_path_timer.wait_time = 2.0
	else:
		find_path_timer.wait_time = 4.0
	makepath()
