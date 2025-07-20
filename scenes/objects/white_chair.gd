extends RigidBody3D

var health := 20


@onready var animated_sprite_3d = $AnimatedSprite3D


func take_damage(dmg: int):
	health -= dmg
	if health <= 0:
		Utils.play_sound(Preloads.WOOD_BREAK_SOUND, get_parent(), position)
		for i in 4:
			var small_scrap = Preloads.SCRAP_SCENE.instantiate()
			get_parent().add_child(small_scrap)
			small_scrap.set_scrap_type("small wood scrap")
			small_scrap.position = global_position
			small_scrap.linear_velocity = Vector3(randf_range(-4, 4), 5, randf_range(-4, 4))
		var big_scrap = Preloads.SCRAP_SCENE.instantiate()
		get_parent().add_child(big_scrap)
		big_scrap.set_scrap_type("big wood scrap")
		big_scrap.position = global_position
		big_scrap.linear_velocity = Vector3(randf_range(-3, 3), 5, randf_range(-3, 3))
		for i in [7, 8].pick_random():
			var white_scrap = Preloads.SCRAP_SCENE.instantiate()
			get_parent().add_child(white_scrap)
			white_scrap.set_scrap_type("white scrap")
			white_scrap.position = global_position
			white_scrap.linear_velocity = Vector3(randf_range(-5, 5), 5, randf_range(-5, 5))
		queue_free()
