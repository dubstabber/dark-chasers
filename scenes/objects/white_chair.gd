extends RigidBody3D

var health := 20

# Debug option - set to true to print angle information
@export var debug_angles := false

@onready var animated_sprite_3d = $AnimatedSprite3D
@onready var sprite_animator = $DirectionalSpriteAnimator

func _ready():
	# Configure the sprite animator component
	if sprite_animator:
		sprite_animator.sprite_node_path = NodePath("AnimatedSprite3D")
		sprite_animator.reference_node_path = NodePath("") # Use WhiteChair itself as reference
		sprite_animator.sprite_changed.connect(_on_sprite_changed)

		# For games with frequent camera changes, enable always_check_camera
		# sprite_animator.always_check_camera = true

		# Example: Configure for 4-directional mode (uncomment to use)
		# sprite_animator.setup_4_directional(["front", "right", "back", "left"])

		# Example: Configure for 8-directional mode with custom names (default)
		# sprite_animator.setup_8_directional() # Uses default 8-directional names

func _on_sprite_changed(sprite_name: String):
	if debug_angles and sprite_animator:
		var debug_info = sprite_animator.debug_angle_info()
		print("Chair [%s]: %s | Angle: %.1f° | Segment: %d/%d" % [
			debug_info.get("direction_mode", "unknown"),
			sprite_name,
			debug_info.get("angle_degrees", 0),
			debug_info.get("segment", -1),
			sprite_animator.sprite_names.size() - 1
		])

# Debug function you can call from the console or other scripts
func print_angle_debug():
	if sprite_animator:
		var debug_info = sprite_animator.debug_angle_info()
		print("=== Chair Angle Debug ===")
		print("Direction mode: ", debug_info.get("direction_mode", "unknown"))
		print("Current sprite: ", debug_info.get("sprite_name", "unknown"))
		print("Raw angle: %.2f°" % debug_info.get("angle_degrees", 0))
		print("Adjusted angle: %.2f°" % debug_info.get("adjusted_angle", 0))
		print("Segment size: %.1f°" % debug_info.get("segment_size", 0))
		print("Segment: %d/%d" % [debug_info.get("segment", -1), sprite_animator.sprite_names.size() - 1])
		print("Forward component: %.3f" % debug_info.get("forward_component", 0))
		print("Right component: %.3f" % debug_info.get("right_component", 0))


func take_damage(dmg: int):
	health -= dmg
	if health <= 0:
		Utils.play_sound(Preloads.WOOD_BREAK_SOUND, get_parent(), position)
		for i in 4:
			var small_scrap = Preloads.SCRAP_SCENE.instantiate()
			get_parent().add_child(small_scrap)
			small_scrap.set_scrap_type("small wood scrap")
			small_scrap.position = global_position
			small_scrap.linear_velocity = Vector3(randf_range(-4, 4), 5, randf_range(-4, 4))
		var big_scrap = Preloads.SCRAP_SCENE.instantiate()
		get_parent().add_child(big_scrap)
		big_scrap.set_scrap_type("big wood scrap")
		big_scrap.position = global_position
		big_scrap.linear_velocity = Vector3(randf_range(-3, 3), 5, randf_range(-3, 3))
		for i in [7, 8].pick_random():
			var white_scrap = Preloads.SCRAP_SCENE.instantiate()
			get_parent().add_child(white_scrap)
			white_scrap.set_scrap_type("white scrap")
			white_scrap.position = global_position
			white_scrap.linear_velocity = Vector3(randf_range(-5, 5), 5, randf_range(-5, 5))
		queue_free()
