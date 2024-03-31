extends StaticBody3D

var health := 5


func take_damage(dmg: int):
	health -= dmg
	if health <= 0:
		Utils.play_sound(Preloads.GLASS_BREAK_SOUND,get_parent(),position)
		for i in 21:
			var glass_scrap = Preloads.SCRAP_SCENE.instantiate()
			get_parent().add_child(glass_scrap)
			glass_scrap.set_scrap_type('glass scrap')
			glass_scrap.position = global_position
			glass_scrap.linear_velocity = Vector3(randf_range(-7,7),5,randf_range(-7,7))
		queue_free()
