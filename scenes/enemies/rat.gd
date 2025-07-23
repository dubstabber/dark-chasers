extends Enemy

var current_anim := ""
var health := 20

@onready var directional_sprite: DirectionalSprite3D = $Graphics/DirectionalSprite3D
@onready var mouse_sound_player: AudioStreamPlayer3D = $MouseSoundPlayer3D


func _on_sound_interval_timeout() -> void:
	mouse_sound_player.play()

func _monitor_death_animation():
	# Monitor death animation frames and adjust positioning for optimal visibility
	if is_killed and directional_sprite.animation == "death":
		var current_frame = directional_sprite.frame
		# Fine-tune positioning based on current death animation frame
		# Early frames (0-2) tend to be positioned lower in their textures
		# Later frames (3-5) tend to be positioned higher
		match current_frame:
			0, 1, 2:
				# Early frames: ensure they're visible above ground
				if directional_sprite.position.y < 0.28:
					directional_sprite.position.y = 0.28
			3, 4:
				# Middle frames: slight adjustment
				if directional_sprite.position.y < 0.28:
					directional_sprite.position.y = 0.28
			5:
				# Final frame: prevent floating, position closer to ground
				if directional_sprite.position.y > 0.04:
					directional_sprite.position.y = 0.04

func _on_death_animation_finished():
	# When death animation finishes, ensure the final frame is positioned correctly
	if is_killed and directional_sprite.animation == "death":
		# Final positioning for the death sprite
		directional_sprite.position.y = 0.15


func take_damage(amount: int) -> void:
	if is_killed:
		return
	health -= amount
	if health <= 0:
		is_killed = true
		directional_sprite.position.y += 0.05
		directional_sprite.play('death')
		velocity = Vector3.ZERO
		$Timers/SoundInterval.autostart = false
		$Timers/SoundInterval.stop()
		collision_layer = 0
		collision_mask = 12
		$DeathSound.play()
