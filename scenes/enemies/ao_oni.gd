extends Enemy

@onready var animated_sprite_3d = $RotationController/AnimatedSprite3D


func _ready():
	super._ready()
	speed = 7.0
	accel = 10
	animated_sprite_3d.connect("frame_changed", handle_footstep)


func _physics_process(delta):
	super._physics_process(delta)
	animateSprite()


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
