extends Enemy

var current_anim := ""
var health := 20

@onready var directional_sprite: DirectionalSprite3D = $Graphics/DirectionalSprite3D
@onready var mouse_sound_player: AudioStreamPlayer3D = $MouseSoundPlayer3D
@onready var sprite_animation_player: AnimationPlayer = $SpriteAnimationPlayer


func _ready() -> void:
	super._ready()
	# Set red blood defaults if not configured in inspector
	if not blood_particle_scene:
		blood_color = Color(1.0, 0.0, 0.0, 1.0)
		blood_particle_scene = Preloads.AO_RED_BLOOD_PARTICLE
		blood_decal_scene = Preloads.BLOOD_SPLAT_DECAL


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_animation_state()


func _update_animation_state():
	if velocity.length() > 0.1:
		moving_state = "run"
		sprite_animation_player.play("move")
	elif health > 0:
		moving_state = "idle"
		sprite_animation_player.play("RESET")


func _on_sound_interval_timeout() -> void:
	mouse_sound_player.play()


func take_damage(amount: int) -> void:
	_apply_damage(amount)


func take_damage_at_position(amount: int, hit_pos: Vector3) -> void:
	super.take_damage_at_position(amount, hit_pos)
	_apply_damage(amount)


func take_damage_with_direction(amount: int, hit_pos: Vector3, shot_direction: Vector3) -> void:
	super.take_damage_with_direction(amount, hit_pos, shot_direction)
	_apply_damage(amount)


func _apply_damage(amount: int) -> void:
	if is_killed:
		return
	health -= amount
	if health <= 0:
		is_killed = true
		sprite_animation_player.play('death')
		velocity = Vector3.ZERO
		$Timers/SoundInterval.autostart = false
		$Timers/SoundInterval.stop()
		collision_layer = 0
		collision_mask = 12
		$DeathSound.play()
