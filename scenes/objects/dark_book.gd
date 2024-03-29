extends StaticBody3D

var health := 5


func take_damage(dmg: int):
	health -= dmg
	if health <= 0:
		Utils.play_sound(Preloads.PAPER_BREAK_SOUND,get_parent(),position)
		for i in 18:
			var paper_scrap = Preloads.SCRAP_SCENE.instantiate()
			get_parent().add_child(paper_scrap)
			paper_scrap.set_scrap_type('paper scrap')
			paper_scrap.position = global_position
			paper_scrap.linear_velocity = Vector3(randf_range(-5,5),5,randf_range(-5,5))
		queue_free()
