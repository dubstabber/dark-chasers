extends StaticBody3D


func take_damage(_dmg: int) -> void:
	# Fallback when we don't know hit position (e.g. explosions)
	take_damage_at_position(_dmg, global_position)

func take_damage_at_position(_dmg: int, hit_pos: Vector3) -> void:
	# Spawn blood particle exactly where the projectile hit
	var vfx: VfxCatalog = Services.preloads.get_vfx_catalog()
	var particle = vfx.red_blood_particle.instantiate()
	get_parent().add_child(particle)
	particle.global_position = hit_pos
	particle.linear_velocity = Vector3(0, 2.5, 0)
