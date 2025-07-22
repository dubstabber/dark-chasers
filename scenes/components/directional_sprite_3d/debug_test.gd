@tool
extends EditorScript

## Debug script to test DirectionalSprite3D atlas generation

func _run():
	print("=== Testing DirectionalSprite3D Atlas Generation ===")
	
	# Create a DirectionalSprite3D instance
	var sprite = DirectionalSprite3D.new()
	sprite.direction_mode = DirectionalSprite3D.DirectionMode.THREE_DIRECTIONS
	
	# Load some test textures
	var front_texture = load("res://images/enemies/ao-oni/AONIA1.png")
	var side_texture = load("res://images/enemies/ao-oni/AONIB1.png") 
	var back_texture = load("res://images/enemies/ao-oni/AONIC1.png")
	
	if not front_texture or not side_texture or not back_texture:
		print("ERROR: Could not load test textures")
		return
	
	print("Loaded textures:")
	print("  Front: ", front_texture.get_size())
	print("  Side: ", side_texture.get_size())
	print("  Back: ", back_texture.get_size())
	
	# Set the sprites
	sprite.idle_sprites["front"] = front_texture
	sprite.idle_sprites["side"] = side_texture
	sprite.idle_sprites["back"] = back_texture
	
	print("Set idle sprites, calling generate_atlas()...")
	
	# Generate atlas
	var atlas = sprite.generate_atlas()
	
	if atlas:
		print("SUCCESS: Atlas generated with size: ", atlas.get_size())
		print("Atlas texture variable: ", sprite.atlas_texture.get_size() if sprite.atlas_texture else "null")
	else:
		print("ERROR: Atlas generation failed")
	
	# Test the debug function
	sprite.debug_atlas_info()
	
	print("=== Test Complete ===")
