extends Enemy

@onready var directional_sprite: DirectionalSprite3D = $Graphics/DirectionalSprite3D
@onready var mouse_sound_player: AudioStreamPlayer3D = $MouseSoundPlayer3D
@onready var animation_component: EnemyAnimationComponent = $EnemyAnimationComponent
@onready var health_component: HealthComponent = $HealthComponent


func _on_sound_interval_timeout() -> void:
	mouse_sound_player.play()


func _on_died() -> void:
	super._on_died()
	if animation_component:
		animation_component.play_death_animation()
	$Timers/SoundInterval.autostart = false
	$Timers/SoundInterval.stop()
	collision_layer = 0
	collision_mask = 12
	$DeathSound.play()
