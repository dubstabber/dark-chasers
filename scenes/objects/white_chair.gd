extends RigidBody3D

@onready var rotation_controller = $RotationController
@onready var animated_sprite_3d = $RotationController/AnimatedSprite3D

func _process(_delta):
	animate_sprite()


func animate_sprite():
	var p_pos = rotation_controller.global_position.direction_to(get_viewport().get_camera_3d().global_position)
	var vertical_side = rotation_controller.global_transform.basis.z
	var horizontal_side = rotation_controller.global_transform.basis.x
	var h_dot = horizontal_side.dot(p_pos)
	var v_dot = vertical_side.dot(p_pos)
	if v_dot < -0.85:
		animated_sprite_3d.play("front")
	elif v_dot > 0.85:
		animated_sprite_3d.play("back")
	else:
		if abs(v_dot) < 0.3:
			if h_dot > 0:
				animated_sprite_3d.play("right")
			else:
				animated_sprite_3d.play("left")
		elif v_dot < 0:
			if h_dot > 0:
				animated_sprite_3d.play("front-right")
			else:
				animated_sprite_3d.play("front-left")
		else:
			if h_dot > 0:
				animated_sprite_3d.play("back-right")
			else:
				animated_sprite_3d.play("back-left")

