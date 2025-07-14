extends Enemy

var current_anim := ""
var health := 20

@onready var animated_sprite: AnimatedSprite3D = $Graphics/AnimatedSprite3D
@onready var mouse_sound_player: AudioStreamPlayer3D = $MouseSoundPlayer3D
@onready var sprite_animator = $DirectionalSpriteAnimator

func _ready():
	_setup_sprite_animator()
	# Connect to animation signals to handle death animation positioning
	animated_sprite.animation_finished.connect(_on_death_animation_finished)

func _setup_sprite_animator():
	if sprite_animator:
		# Configure the sprite animator component
		sprite_animator.sprite_node_path = NodePath("Graphics/AnimatedSprite3D")
		sprite_animator.reference_node_path = NodePath("Graphics") # Use Graphics node as reference
		sprite_animator.sprite_changed.connect(_on_sprite_changed)

		# Configure for 8-directional animation with sprite flipping
		# Start with "stay" state sprites (only 5 sprites needed with flipping)
		var stay_sprites: Array[String] = ["stay-front", "stay-front-side", "stay-side", "stay-back-side", "stay-back"]
		sprite_animator.setup_8_directional_flipping(stay_sprites)

		# Enable for better responsiveness with camera changes
		sprite_animator.always_check_camera = true

func _on_sprite_changed(sprite_name: String):
	current_anim = sprite_name

func _physics_process(delta):
	super._physics_process(delta)
	_update_animation_state()
	_monitor_death_animation()

func _update_animation_state():
	if is_killed:
		sprite_animator.enabled = false
		return

	# Update sprite names based on current movement state
	var state = "run" if velocity else "stay"
	var new_sprites: Array[String] = []

	# Build sprite names for current state (5 sprites with flipping)
	var base_directions = ["front", "front-side", "side", "back-side", "back"]
	for dir_name in base_directions:
		new_sprites.append(state + "-" + dir_name)

	# Only update if the state changed
	if sprite_animator.sprite_names != new_sprites:
		sprite_animator.sprite_names = new_sprites
		sprite_animator.force_update()


func _on_sound_interval_timeout() -> void:
	mouse_sound_player.play()

func _monitor_death_animation():
	# Monitor death animation frames and adjust positioning for optimal visibility
	if is_killed and animated_sprite.animation == "death":
		var current_frame = animated_sprite.frame
		# Fine-tune positioning based on current death animation frame
		# Early frames (0-2) tend to be positioned lower in their textures
		# Later frames (3-5) tend to be positioned higher
		match current_frame:
			0, 1, 2:
				# Early frames: ensure they're visible above ground
				if animated_sprite.position.y < 0.28:
					animated_sprite.position.y = 0.28
			3, 4:
				# Middle frames: slight adjustment
				if animated_sprite.position.y < 0.28:
					animated_sprite.position.y = 0.28
			5:
				# Final frame: prevent floating, position closer to ground
				if animated_sprite.position.y > 0.04:
					animated_sprite.position.y = 0.04

func _on_death_animation_finished():
	# When death animation finishes, ensure the final frame is positioned correctly
	if is_killed and animated_sprite.animation == "death":
		# Final positioning for the death sprite
		animated_sprite.position.y = 0.15


func take_damage(amount: int) -> void:
	if is_killed:
		return
	health -= amount
	if health <= 0:
		is_killed = true
		# Disable the sprite animator and manually play death animation
		sprite_animator.enabled = false

		# Adjust sprite position for better death animation visibility
		# The death animation frames appear to be positioned lower in their textures
		# so we need to raise the sprite to keep it visible above ground
		animated_sprite.position.y += 0.05

		animated_sprite.play('death')
		velocity = Vector3.ZERO
		$Timers/SoundInterval.autostart = false
		$Timers/SoundInterval.stop()
		collision_layer = 0
		collision_mask = 12
		$DeathSound.play()
