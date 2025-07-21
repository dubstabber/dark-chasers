extends Node

## Test script to verify atlas generation and check for texture bleeding issues

func _ready():
	print("=== DirectionalSprite3D Enhanced Debug Test ===")
	print("Testing atlas generation and checking for idle sprite artifacts...")

	# Find the DirectionalSprite3D component in the scene
	var directional_sprite = find_directional_sprite(get_tree().current_scene)

	if directional_sprite == null:
		print("ERROR: No DirectionalSprite3D found in scene")
		return

	# Configure sprites for testing
	setup_test_sprites(directional_sprite)

	# Force atlas regeneration to trigger enhanced debugging
	print("\n=== Forcing Atlas Regeneration with Enhanced Debugging ===")
	directional_sprite._last_atlas_hash = "" # Force regeneration
	var atlas = directional_sprite.generate_atlas()

	if atlas:
		print("✓ Atlas generated successfully: %dx%d" % [atlas.get_width(), atlas.get_height()])

		# Wait a frame to ensure shader is updated
		await get_tree().process_frame

		# Verify shader parameters are correct
		print("\n=== Verifying Shader Parameters After Atlas Generation ===")
		if directional_sprite.directional_material:
			var shader_atlas_dims = directional_sprite.directional_material.get_shader_parameter("atlas_dimensions")
			var shader_frame_size = directional_sprite.directional_material.get_shader_parameter("frame_size")
			var shader_padded_size = directional_sprite.directional_material.get_shader_parameter("padded_frame_size")
			var shader_compressed = directional_sprite.directional_material.get_shader_parameter("has_compressed_textures")

			print("Actual atlas: %dx%d" % [atlas.get_width(), atlas.get_height()])
			print("Shader atlas_dimensions: %s" % str(shader_atlas_dims))
			print("Shader frame_size: %s" % str(shader_frame_size))
			print("Shader padded_frame_size: %s" % str(shader_padded_size))
			print("Shader has_compressed_textures: %s" % str(shader_compressed))

			# Check if dimensions match
			if shader_atlas_dims and Vector2(atlas.get_width(), atlas.get_height()) == shader_atlas_dims:
				print("✅ Shader atlas dimensions MATCH actual atlas!")
			else:
				print("❌ Shader atlas dimensions MISMATCH! This will cause artifacts!")
		else:
			print("❌ No shader material found!")
	else:
		print("❌ Atlas generation failed!")

	# Test atlas generation
	test_atlas_generation(directional_sprite)

	# Test shader parameters
	test_shader_parameters(directional_sprite)

	print("\n=== Enhanced Debug Test Completed ===")
	print("Check the output above for any suspicious content warnings!")

func find_directional_sprite(node: Node) -> Node:
	if node.get_script() != null:
		var script_path = node.get_script().resource_path
		if script_path.ends_with("directional_sprite_3d.gd"):
			return node
	
	for child in node.get_children():
		var result = find_directional_sprite(child)
		if result != null:
			return result
	
	return null

func setup_test_sprites(sprite: Node):
	print("=== Setting up test sprites ===")

	# Load Hiroshi character sprites for testing
	var idle_front = load("res://images/characters/hiroshi/HIROA1.png")
	var idle_side = load("res://images/characters/hiroshi/HIROA3A7.png")
	var idle_back = load("res://images/characters/hiroshi/HIROA5.png")

	var move_front_1 = load("res://images/characters/hiroshi/HIROB1.png")
	var move_front_2 = load("res://images/characters/hiroshi/HIROD1.png")
	var move_side_1 = load("res://images/characters/hiroshi/HIROB3B7.png")
	var move_side_2 = load("res://images/characters/hiroshi/HIROD3D7.png")
	var move_back_1 = load("res://images/characters/hiroshi/HIROB5.png")
	var move_back_2 = load("res://images/characters/hiroshi/HIROD5.png")

	# Set up idle sprites
	sprite.idle_sprites = {
		"front": idle_front,
		"side": idle_side,
		"back": idle_back
	}

	# Set up movement sprites
	sprite.movement_sprites = {
		"front": [move_front_1, move_front_2],
		"side": [move_side_1, move_side_2],
		"back": [move_back_1, move_back_2]
	}

	print("✓ Test sprites configured")

func test_atlas_generation(sprite: Node):
	print("\n=== Testing Atlas Generation ===")
	
	# Check if atlas is generated
	var atlas_texture = sprite.texture
	if atlas_texture == null:
		print("WARNING: No atlas texture generated")
		return

	print("Atlas dimensions: %dx%d" % [atlas_texture.get_width(), atlas_texture.get_height()])

	# Check frame size
	var frame_size = sprite.get_atlas_frame_size()
	print("Frame size: %dx%d" % [frame_size.x, frame_size.y])

	# Check if padding is applied correctly
	var expected_padded_size = Vector2i(frame_size.x + sprite.ATLAS_PADDING, frame_size.y + sprite.ATLAS_PADDING)
	print("Expected padded frame size: %dx%d" % [expected_padded_size.x, expected_padded_size.y])

	# Check for compressed textures
	var has_compressed = false
	var directions = sprite._get_current_directions()
	for direction in directions:
		var idle_sprite = sprite.idle_sprites.get(direction)
		if idle_sprite is Texture2D:
			var image = idle_sprite.get_image()
			if image != null and image.is_compressed():
				has_compressed = true
				print("Found compressed texture in direction '%s'" % direction)
				break

	if has_compressed:
		print("✓ Compressed textures detected - should use %d pixel padding" % sprite.COMPRESSED_TEXTURE_PADDING)
	else:
		print("ℹ No compressed textures - using %d pixel padding" % sprite.ATLAS_PADDING)

	# Verify atlas layout
	print("Directions: %s" % str(directions))

	for i in range(directions.size()):
		var direction = directions[i]
		var frame_pos = sprite.get_atlas_frame_position(direction, 0)
		print("Direction '%s' (row %d) frame position: %dx%d" % [direction, i, frame_pos.x, frame_pos.y])

func test_shader_parameters(sprite: Node):
	print("\n=== Testing Shader Parameters ===")
	
	var material = sprite.directional_material
	if material == null:
		print("WARNING: No directional material found")
		return
	
	# Check key shader parameters
	var atlas_dimensions = material.get_shader_parameter("atlas_dimensions")
	var frame_size = material.get_shader_parameter("frame_size")
	var padded_frame_size = material.get_shader_parameter("padded_frame_size")
	var has_compressed_textures = material.get_shader_parameter("has_compressed_textures")

	print("Shader atlas_dimensions: %s" % str(atlas_dimensions))
	print("Shader frame_size: %s" % str(frame_size))
	print("Shader padded_frame_size: %s" % str(padded_frame_size))
	print("Shader has_compressed_textures: %s" % str(has_compressed_textures))

	# Verify padding calculation
	if padded_frame_size != null and frame_size != null:
		var actual_padding = Vector2(
			padded_frame_size.x - frame_size.x,
			padded_frame_size.y - frame_size.y
		)
		var expected_padding = sprite.ATLAS_PADDING
		if has_compressed_textures:
			expected_padding = sprite.COMPRESSED_TEXTURE_PADDING

		print("Calculated padding: %s (expected: %d)" % [str(actual_padding), expected_padding])

		if actual_padding.x == expected_padding and actual_padding.y == expected_padding:
			print("✓ Padding correctly applied to shader parameters")
		else:
			print("✗ Padding mismatch in shader parameters")

		# Check for compressed texture detection
		if has_compressed_textures:
			print("✓ Compressed textures detected - using enhanced bleeding prevention")
		else:
			print("ℹ No compressed textures detected - using standard padding")
