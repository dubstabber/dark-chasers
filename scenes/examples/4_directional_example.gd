extends Node3D

## Example script showing how to use DirectionalSpriteAnimator in 4-directional mode

@onready var sprite_animator = $DirectionalSpriteAnimator
@onready var animated_sprite_3d = $AnimatedSprite3D

func _ready():
	# Configure for 4-directional mode
	if sprite_animator:
		sprite_animator.sprite_node_path = NodePath("AnimatedSprite3D")
		sprite_animator.reference_node_path = NodePath("")  # Use this node as reference
		
		# Method 1: Use the setup helper function
		sprite_animator.setup_4_directional()
		
		# Method 2: Manual configuration (alternative)
		# sprite_animator.direction_mode = DirectionalSpriteAnimator.DirectionMode.FOUR_DIRECTIONAL
		# sprite_animator.sprite_names = ["front", "right", "back", "left"]
		
		# Optional: Enable debug output
		sprite_animator.sprite_changed.connect(_on_sprite_changed)

func _on_sprite_changed(sprite_name: String):
	print("4-Directional Example: ", sprite_name)

# Example function to switch to 8-directional mode at runtime
func switch_to_8_directional():
	if sprite_animator:
		sprite_animator.setup_8_directional()
		print("Switched to 8-directional mode")

# Example function to switch back to 4-directional mode
func switch_to_4_directional():
	if sprite_animator:
		sprite_animator.setup_4_directional()
		print("Switched to 4-directional mode")
