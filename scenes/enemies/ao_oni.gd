extends Enemy

@onready var animation_player = $RotationController/AnimationPlayer
@onready var sprite_3d = $RotationController/Sprite3D


func _ready():
	super._ready()
	if not speed: speed = 7.0
	accel = 10
	animation_player.speed_scale = speed / 7.0


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
	if v_dot < -0.5 and not animation_player.current_animation.contains(state+'-front'):
		animation_player.play(state + "-front")
	elif v_dot > 0.5 and not animation_player.current_animation.contains(state+'-back'):
		animation_player.play(state + "-back")
	else:
		sprite_3d.flip_h = h_dot > 0
		if abs(v_dot) < 0.3 and not animation_player.current_animation.contains(state+'-side'):
			animation_player.play(state + "-side")

