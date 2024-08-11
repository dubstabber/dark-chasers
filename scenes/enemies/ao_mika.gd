extends Enemy

var current_anim := ""

@onready var animation_player = $Graphics/AnimationPlayer
@onready var sprite_3d = $Graphics/Sprite3D


func _ready():
	super._ready()
	if not speed: speed = 8.0
	accel = 10
	animation_player.speed_scale = speed / 8.0


func _physics_process(delta):
	super._physics_process(delta)
	animate_sprite()


func animate_sprite():
	var current_camera = get_viewport().get_camera_3d()
	if current_camera:
		var p_pos = graphics.global_position.direction_to(current_camera.global_position)
		var vertical_side = graphics.global_transform.basis.z
		var horizontal_side = graphics.global_transform.basis.x
		var h_dot = horizontal_side.dot(p_pos)
		var v_dot = vertical_side.dot(p_pos)
		var state = "run" if velocity else "stay"
		if v_dot < -0.5:
			current_anim = state + "-front"
		elif v_dot > 0.5:
			current_anim = state + "-back"
		else:
			sprite_3d.flip_h = h_dot > 0
			if abs(v_dot) < 0.3:
				current_anim = state + "-side"
	
	if animation_player.current_animation != current_anim:
		animation_player.play(current_anim)
