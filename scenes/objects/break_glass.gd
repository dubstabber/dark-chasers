extends StaticBody3D

var health := 5


func take_damage(dmg: int):
	health -= dmg
	if health <= 0:
		var catalog: ParticleCatalog = Services.preloads.get_particle_catalog()
		Services.utils.play_sound(catalog.glass_break_sound, get_parent(), position)
		for i in 21:
			var glass_scrap = catalog.scrap_scene.instantiate()
			get_parent().add_child(glass_scrap)
			glass_scrap.set_scrap_type('glass scrap')
			glass_scrap.position = global_position
			glass_scrap.linear_velocity = Vector3(randf_range(-7, 7), 5, randf_range(-7, 7))
		queue_free()
