extends RigidBody3D

var health := 20
var current_anim := ""

@onready var rotation_controller = $RotationController
@onready var animated_sprite_3d = $RotationController/AnimatedSprite3D

func _process(_delta):
	animate_sprite()


func animate_sprite():
	var current_camera = get_viewport().get_camera_3d()
	if current_camera:
		var p_pos = rotation_controller.global_position.direction_to(current_camera.global_position)
		var vertical_side = rotation_controller.global_transform.basis.z
		var horizontal_side = rotation_controller.global_transform.basis.x
		var h_dot = horizontal_side.dot(p_pos)
		var v_dot = vertical_side.dot(p_pos)
		if v_dot < -0.85:
			current_anim = "front"
		elif v_dot > 0.85:
			current_anim = "back"
		else:
			if abs(v_dot) < 0.3:
				if h_dot > 0:
					current_anim = "right"
				else:
					current_anim = "left"
			elif v_dot < 0:
				if h_dot > 0:
					current_anim = "front-right"
				else:
					current_anim = "front-left"
			else:
				if h_dot > 0:
					current_anim = "back-right"
				else:
					current_anim = "back-left"
		
		if animated_sprite_3d.animation != current_anim:
			animated_sprite_3d.play(current_anim)


func take_damage(dmg: int):
	health -= dmg
	if health <= 0:
		Utils.play_sound(Preloads.WOOD_BREAK_SOUND,get_parent(),position)
		for i in 4:
			var small_scrap = Preloads.SCRAP_SCENE.instantiate()
			get_parent().add_child(small_scrap)
			small_scrap.set_scrap_type("small wood scrap")
			small_scrap.position = global_position
			small_scrap.linear_velocity = Vector3(randf_range(-4,4),5,randf_range(-4,4))
		var big_scrap = Preloads.SCRAP_SCENE.instantiate()
		get_parent().add_child(big_scrap)
		big_scrap.set_scrap_type("big wood scrap")
		big_scrap.position = global_position
		big_scrap.linear_velocity = Vector3(randf_range(-3,3),5,randf_range(-3,3))
		for i in [7,8].pick_random():
			var white_scrap = Preloads.SCRAP_SCENE.instantiate()
			get_parent().add_child(white_scrap)
			white_scrap.set_scrap_type("white scrap")
			white_scrap.position = global_position
			white_scrap.linear_velocity = Vector3(randf_range(-5,5),5,randf_range(-5,5))
		queue_free()
