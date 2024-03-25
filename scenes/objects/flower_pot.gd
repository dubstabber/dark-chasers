extends StaticBody3D

var health := 20
var is_destroyed := false

@onready var animated_sprite_3d = $AnimatedSprite3D


func take_damage(dmg: int):
	if not is_destroyed:
		health -= dmg
		if health <= 0:
			Utils.play_sound(Preloads.POT_BREAK_SOUND,get_parent(),position)
			is_destroyed = true
			animated_sprite_3d.play()
			animated_sprite_3d.position.y = -0.40
			$CollisionShape3D.disabled = true
			$CollisionShape3D2.disabled = false
			for i in 10:
				var pot_scrap = Preloads.SCRAP_SCENE.instantiate()
				get_parent().add_child(pot_scrap)
				pot_scrap.set_scrap_type("pot scrap")
				pot_scrap.position = global_position
				pot_scrap.linear_velocity = Vector3(randf_range(-4,4),5,randf_range(-4,4))
				
