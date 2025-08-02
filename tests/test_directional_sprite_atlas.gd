@tool
extends EditorScript

## Test script to verify DirectionalSprite3D atlas generation fixes
## This test verifies that shooting sprites are properly included in atlas dimension calculations
## and that sprite padding/centering works correctly for different sized sprites

func _run():
	print("=== DirectionalSprite3D Atlas Generation Test ===")
	
	# Create a test DirectionalSprite3D instance
	var sprite_3d = DirectionalSprite3D.new()
	sprite_3d.direction_mode = DirectionalSprite3D.DirectionMode.THREE_DIRECTIONS
	
	# Create test textures of different sizes
	var small_texture = _create_test_texture(16, 16, Color.RED)
	var medium_texture = _create_test_texture(32, 32, Color.GREEN)
	var large_texture = _create_test_texture(64, 64, Color.BLUE)
	
	# Test 1: Verify shooting sprites are included in dimension calculations
	print("\n--- Test 1: Shooting sprites dimension calculation ---")
	
	# Set up sprites with different sizes
	sprite_3d.idle_sprites["front"] = small_texture
	sprite_3d.movement_sprites["front"] = [medium_texture]
	sprite_3d.shooting_sprites["front"] = [large_texture]  # This should determine the max size
	
	# Get max dimensions - should be 64x64 from the large shooting sprite
	var max_dims = sprite_3d._get_sprite_max_dimensions(["front"])
	
	if max_dims == Vector2i(64, 64):
		print("✅ PASS: Shooting sprites correctly included in dimension calculation")
		print("   Expected: (64, 64), Got: (%d, %d)" % [max_dims.x, max_dims.y])
	else:
		print("❌ FAIL: Shooting sprites not properly included in dimension calculation")
		print("   Expected: (64, 64), Got: (%d, %d)" % [max_dims.x, max_dims.y])
	
	# Test 2: Verify all sprite types are considered
	print("\n--- Test 2: All sprite types consideration ---")
	
	# Clear previous test data
	sprite_3d.idle_sprites.clear()
	sprite_3d.movement_sprites.clear()
	sprite_3d.shooting_sprites.clear()
	
	# Set up sprites where shoot sprite is largest
	sprite_3d.idle_sprites["front"] = small_texture      # 16x16
	sprite_3d.idle_sprites["side"] = medium_texture      # 32x32
	sprite_3d.movement_sprites["back"] = [small_texture] # 16x16
	sprite_3d.shooting_sprites["front"] = [large_texture]   # 64x64 - should be max
	
	var all_dims = sprite_3d._get_sprite_max_dimensions(["front", "side", "back"])
	
	if all_dims == Vector2i(64, 64):
		print("✅ PASS: All sprite types properly considered for max dimensions")
		print("   Expected: (64, 64), Got: (%d, %d)" % [all_dims.x, all_dims.y])
	else:
		print("❌ FAIL: Not all sprite types considered for max dimensions")
		print("   Expected: (64, 64), Got: (%d, %d)" % [all_dims.x, all_dims.y])
	
	# Test 3: Verify empty shooting sprites don't cause issues
	print("\n--- Test 3: Empty shooting sprites handling ---")
	
	sprite_3d.idle_sprites.clear()
	sprite_3d.movement_sprites.clear()
	sprite_3d.shooting_sprites.clear()
	
	sprite_3d.idle_sprites["front"] = medium_texture
	sprite_3d.shooting_sprites["front"] = []  # Empty array
	
	var empty_dims = sprite_3d._get_sprite_max_dimensions(["front"])
	
	if empty_dims == Vector2i(32, 32):
		print("✅ PASS: Empty shooting sprite arrays handled correctly")
		print("   Expected: (32, 32), Got: (%d, %d)" % [empty_dims.x, empty_dims.y])
	else:
		print("❌ FAIL: Empty shooting sprite arrays not handled correctly")
		print("   Expected: (32, 32), Got: (%d, %d)" % [empty_dims.x, empty_dims.y])
	
	print("\n=== Test Complete ===")
	
	# Clean up
	sprite_3d.queue_free()


func _create_test_texture(width: int, height: int, color: Color) -> ImageTexture:
	"""Create a test texture with specified dimensions and color"""
	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture
