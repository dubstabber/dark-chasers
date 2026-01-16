extends Enemy

@onready var directional_sprite: DirectionalSprite3D = $Graphics/DirectionalSprite3D
@onready var mouse_sound_player: AudioStreamPlayer3D = $MouseSoundPlayer3D
@onready var animation_component: EnemyAnimationComponent = $EnemyAnimationComponent
@onready var health_component: HealthComponent = $HealthComponent


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if animation_component:
		animation_component.update_animation_state()


func _on_sound_interval_timeout() -> void:
	mouse_sound_player.play()


func take_damage(amount: int) -> void:
	super.take_damage(amount)
	if health_component:
		health_component.take_damage(amount)


func take_damage_at_position(amount: int, hit_pos: Vector3) -> void:
	super.take_damage_at_position(amount, hit_pos)
	if health_component:
		health_component.take_damage(amount)


func take_damage_with_direction(amount: int, hit_pos: Vector3, shot_direction: Vector3) -> void:
	super.take_damage_with_direction(amount, hit_pos, shot_direction)
	if health_component:
		health_component.take_damage(amount)


func _on_died() -> void:
	super._on_died()
	if animation_component:
		animation_component.play_death_animation()
	$Timers/SoundInterval.autostart = false
	$Timers/SoundInterval.stop()
	collision_layer = 0
	collision_mask = 12
	$DeathSound.play()
