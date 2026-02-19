extends StaticBody3D

var health := 5


func take_damage(dmg: int):
	health -= dmg
	if health <= 0:
		var catalog: ParticleCatalog = Services.preloads.get_particle_catalog()
		Services.utils.play_sound(catalog.paper_break_sound, get_parent(), position)
		for i in 18:
			var paper_scrap = catalog.scrap_scene.instantiate()
			get_parent().add_child(paper_scrap)
			paper_scrap.set_scrap_type('paper scrap')
			paper_scrap.position = global_position
			paper_scrap.linear_velocity = Vector3(randf_range(-5, 5), 5, randf_range(-5, 5))
		queue_free()
