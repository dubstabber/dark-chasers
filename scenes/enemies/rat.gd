extends Enemy

var current_anim := ""
var health := 20

@onready var animated_sprite: AnimatedSprite3D = $Graphics/AnimatedSprite3D
@onready var mouse_sound_player: AudioStreamPlayer3D = $MouseSoundPlayer3D


func _physics_process(delta):
	super._physics_process(delta)
	animate_sprite()


func animate_sprite():
	if is_killed:
		return
	var current_camera = get_viewport().get_camera_3d()
	if current_camera:
		var p_pos = graphics.global_position.direction_to(current_camera.global_position)
		var vertical_side = graphics.global_transform.basis.z
		var horizontal_side = graphics.global_transform.basis.x
		var h_dot = horizontal_side.dot(p_pos)
		var v_dot = vertical_side.dot(p_pos)
		var state = "run" if velocity else "stay"
		if v_dot < -0.85:
			current_anim = state + "-front"
		elif v_dot > 0.85:
			current_anim = state + "-back"
		else:
			animated_sprite.flip_h = h_dot < 0
			if abs(v_dot) < 0.3:
				current_anim = state + "-side"
			elif v_dot < 0:
				current_anim = state + "-front-side"
			else:
				current_anim = state + "-back-side"

	if animated_sprite.animation != current_anim:
		animated_sprite.play(current_anim)


func _on_sound_interval_timeout() -> void:
	mouse_sound_player.play()


func take_damage(amount: int) -> void:
	if is_killed:
		return
	if health >= 0:
		is_killed = true
		animated_sprite.play('death')
		velocity = Vector3.ZERO
		$Timers/SoundInterval.autostart = false
		$Timers/SoundInterval.stop()
		collision_layer = 0
		collision_mask = 12
		$Graphics/AnimatedSprite3D.position.y -= 0.1
		$DeathSound.play()
