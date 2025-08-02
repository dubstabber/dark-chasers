extends Enemy

var current_anim := ""
var health := 20

@onready var directional_sprite: DirectionalSprite3D = $Graphics/DirectionalSprite3D
@onready var mouse_sound_player: AudioStreamPlayer3D = $MouseSoundPlayer3D
@onready var sprite_animation_player: AnimationPlayer = $SpriteAnimationPlayer


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
