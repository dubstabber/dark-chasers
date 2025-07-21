@tool
extends Sprite3D
class_name DirectionalSprite3D

## A directional sprite component that automatically generates texture atlases
## from idle and movement sprites based on viewing direction.

#region Enums and Constants

enum DirectionMode {
	THREE_DIRECTIONS, ## front, side, back
	FOUR_DIRECTIONS, ## front, left, right, back
	FIVE_DIRECTIONS, ## front, side, back, front-side, back-side
	EIGHT_DIRECTIONS, ## front, left, right, back, front-left, front-right, back-left, back-right
}

const IDLE_SUFFIX = "_idle_sprite"
const MOVEMENT_SUFFIX = "_movement_sprites"

# Direction definitions for each mode
const DIRECTION_SETS = {
	DirectionMode.THREE_DIRECTIONS: ["front", "side", "back"],
	DirectionMode.FOUR_DIRECTIONS: ["front", "left", "right", "back"],
	DirectionMode.FIVE_DIRECTIONS: ["front", "side", "back", "front_side", "back_side"],
	DirectionMode.EIGHT_DIRECTIONS: ["front", "left", "right", "back", "front_left", "front_right", "back_left", "back_right"]
}

#endregion

#region Exported Properties

@export var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_update_moving_state()

@export var direction_mode: DirectionMode = DirectionMode.THREE_DIRECTIONS:
	set(value):
		direction_mode = value
		_initialize_sprite_dictionaries()
		notify_property_list_changed()
		_update_moving_state()
		_schedule_atlas_generation()

#endregion

#region Internal Variables

# Atlas generation constants
const ATLAS_PADDING: int = 2 # Pixels of padding between atlas cells to prevent bleeding
const COMPRESSED_TEXTURE_PADDING: int = 4 # Extra padding for compressed textures with Fix Alpha Border

var has_moving_state: bool = false
var idle_sprites: Dictionary = {}
var movement_sprites: Dictionary = {}

# Direction and animation state
var current_direction: String = "front"
var current_frame: int = 0
var is_moving: bool = false

# Shader material for directional rendering
var directional_material: ShaderMaterial

# Atlas generation state
var _atlas_generation_pending: bool = false
var _last_atlas_hash: String = ""

#endregion

#region Initialization

func _ready():
	_initialize_sprite_dictionaries()
	_update_moving_state()
	_setup_shader_material()

func _process(_delta):
	_update_directional_rendering()
	_update_target_position()

func _initialize_sprite_dictionaries():
	var directions = _get_current_directions()
	for direction in directions:
		if not movement_sprites.has(direction):
			movement_sprites[direction] = []

#endregion

#region Property Management

func _get(property: StringName):
	var prop_name = str(property)
	
	if prop_name.ends_with(IDLE_SUFFIX):
		var direction = prop_name.replace(IDLE_SUFFIX, "")
		return idle_sprites.get(direction)
	
	if prop_name.ends_with(MOVEMENT_SUFFIX):
		var direction = prop_name.replace(MOVEMENT_SUFFIX, "")
		if not movement_sprites.has(direction):
			movement_sprites[direction] = []
		return movement_sprites[direction]
	
	return null

func _set(property: StringName, value) -> bool:
	var prop_name = str(property)
	var changed = false
	
	if prop_name.ends_with(IDLE_SUFFIX):
		var direction = prop_name.replace(IDLE_SUFFIX, "")
		if _is_valid_direction(direction):
			idle_sprites[direction] = value
			changed = true
	
	if prop_name.ends_with(MOVEMENT_SUFFIX):
		var direction = prop_name.replace(MOVEMENT_SUFFIX, "")
		if _is_valid_direction(direction):
			movement_sprites[direction] = _validate_texture_array(value)
			changed = true
	
	if changed:
		_schedule_atlas_generation()
		return true
	
	return false

func _get_property_list():
	var properties: Array[Dictionary] = []
	var directions = _get_current_directions()
	
	_add_sprite_group_properties(properties, "Idle sprites", directions, IDLE_SUFFIX, TYPE_OBJECT, "Texture2D")
	
	if has_moving_state:
		_add_sprite_group_properties(properties, "Movement sprites", directions, MOVEMENT_SUFFIX, TYPE_ARRAY, "%d/%d:Texture2D" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE])
	
	return properties

func _add_sprite_group_properties(properties: Array[Dictionary], group_name: String, directions: Array, suffix: String, property_type: int, hint_string: String):
	properties.append({
		"name": group_name,
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP,
	})
	
	var hint_type = PROPERTY_HINT_RESOURCE_TYPE if property_type == TYPE_OBJECT else PROPERTY_HINT_ARRAY_TYPE
	
	for direction in directions:
		properties.append({
			"name": direction + suffix,
			"type": property_type,
			"hint": hint_type,
			"hint_string": hint_string,
			"usage": PROPERTY_USAGE_DEFAULT
		})

#endregion

#region Atlas Generation

## Generate an atlas texture from all idle and movement sprites
## First column contains idle sprites, subsequent columns contain movement animation frames
func generate_atlas() -> ImageTexture:
	if not _has_any_sprites():
		return null

	var directions = _get_current_directions()
	if directions.is_empty():
		push_warning("DirectionalSprite3D: No directions available for atlas generation")
		return null

	# Validate sprite dimensions before proceeding
	if not _validate_sprite_dimensions(directions):
		return null

	# Collect sprites and determine dimensions
	var all_sprites: Array[Array] = []
	var sprite_size = _get_sprite_dimensions(directions)
	var max_frames = 1

	# Use original direction order to maintain shader compatibility
	# The shader hardcodes direction indices, so we must preserve the original order
	# Collect all sprites for each direction in original order
	for direction in directions:
		var direction_sprites = _collect_direction_sprites(direction)
		all_sprites.append([direction, direction_sprites])
		max_frames = max(max_frames, direction_sprites.size())

	# Add padding between atlas cells to prevent bleeding
	# Use extra padding if any textures are compressed
	var padding = ATLAS_PADDING
	if _has_compressed_textures(all_sprites):
		padding = COMPRESSED_TEXTURE_PADDING
		print("DirectionalSprite3D: Using increased padding (%d pixels) for compressed textures" % padding)

	var padded_sprite_size = Vector2i(sprite_size.x + padding, sprite_size.y + padding)

	# Create and populate atlas with padding
	var atlas_dimensions = Vector2i(padded_sprite_size.x * max_frames, padded_sprite_size.y * directions.size())
	var atlas_texture = _create_atlas_texture(all_sprites, atlas_dimensions, sprite_size, padding)

	if atlas_texture:
		texture = atlas_texture
		# Update shader uniforms immediately after atlas is set
		_update_shader_uniforms()

	return atlas_texture

func _schedule_atlas_generation():
	if _atlas_generation_pending:
		return # Already scheduled

	_atlas_generation_pending = true
	call_deferred("_generate_atlas_if_ready")

func _generate_atlas_if_ready():
	_atlas_generation_pending = false

	if not is_inside_tree():
		return

	if _has_any_sprites():
		# Generate a hash of current sprite configuration to detect changes
		var current_hash = _generate_sprite_hash()
		if current_hash != _last_atlas_hash:
			_last_atlas_hash = current_hash
			generate_atlas()
			# Ensure shader material is set up
			if directional_material == null:
				_setup_shader_material()
	else:
		texture = null
		_last_atlas_hash = ""

func _generate_sprite_hash() -> String:
	var hash_parts: Array[String] = []
	var directions = _get_current_directions()

	# Use original direction order to maintain shader compatibility
	# The shader hardcodes direction indices, so we must preserve the original order
	for direction in directions:
		# Add idle sprite hash
		var idle_sprite = idle_sprites.get(direction)
		if idle_sprite is Texture2D:
			hash_parts.append("idle_%s_%s" % [direction, str(idle_sprite.get_rid().get_id())])
		else:
			hash_parts.append("idle_%s_null" % direction)

		# Add movement sprites hash
		var movement_array = movement_sprites.get(direction, [])
		for i in range(movement_array.size()):
			var sprite = movement_array[i]
			if sprite is Texture2D:
				hash_parts.append("move_%s_%d_%s" % [direction, i, str(sprite.get_rid().get_id())])
			else:
				hash_parts.append("move_%s_%d_null" % [direction, i])

	return "_".join(hash_parts)

#endregion

#region Atlas Utility Functions

## Get the atlas frame coordinates for a specific direction and frame
func get_atlas_frame_position(direction: String, frame_index: int = 0) -> Vector2i:
	var directions = _get_current_directions()
	# Use original direction order to match atlas generation and shader expectations
	var direction_row = directions.find(direction)

	if direction_row == -1 or texture == null:
		return Vector2i.ZERO

	var frame_size = get_atlas_frame_size()
	if frame_size == Vector2i.ZERO:
		return Vector2i.ZERO

	# Account for padding in atlas layout - detect if compressed texture padding was used
	var padding = ATLAS_PADDING
	if texture != null:
		# Simple heuristic: if atlas is larger than expected with normal padding, assume compressed padding
		var current_directions = _get_current_directions()
		if not current_directions.is_empty():
			var expected_width_normal = (frame_size.x + ATLAS_PADDING) * (texture.get_width() / (frame_size.x + ATLAS_PADDING))
			var expected_width_compressed = (frame_size.x + COMPRESSED_TEXTURE_PADDING) * (texture.get_width() / (frame_size.x + COMPRESSED_TEXTURE_PADDING))
			# If the atlas width is closer to compressed padding expectation, use compressed padding
			if abs(texture.get_width() - expected_width_compressed) < abs(texture.get_width() - expected_width_normal):
				padding = COMPRESSED_TEXTURE_PADDING

	var padded_frame_size = Vector2i(frame_size.x + padding, frame_size.y + padding)

	return Vector2i(frame_index * padded_frame_size.x, direction_row * padded_frame_size.y)

## Get the size of individual sprites in the atlas
func get_atlas_frame_size() -> Vector2i:
	var directions = _get_current_directions()
	return _get_sprite_dimensions(directions)

#endregion

#region Helper Functions

func _get_current_directions() -> Array:
	return DIRECTION_SETS.get(direction_mode, [])

func _is_valid_direction(direction: String) -> bool:
	return direction in _get_current_directions()

func _validate_texture_array(value) -> Array[Texture2D]:
	if value == null:
		return []
	
	if not value is Array:
		push_warning("DirectionalSprite3D: Expected Array for movement sprites")
		return []
	
	if value is Array[Texture2D]:
		return value
	
	var validated_array: Array[Texture2D] = []
	for item in value:
		if item is Texture2D:
			validated_array.append(item)
		elif item != null:
			push_warning("DirectionalSprite3D: Non-Texture2D item found in movement sprites array")
	
	return validated_array

func _has_compressed_textures(all_sprites: Array[Array]) -> bool:
	for sprite_data in all_sprites:
		var sprite_array = sprite_data[1]
		for sprite in sprite_array:
			if sprite is Texture2D:
				var image = sprite.get_image()
				if image != null and image.is_compressed():
					return true
	return false

func _has_any_sprites() -> bool:
	# Check idle sprites
	for direction in idle_sprites:
		var sprite = idle_sprites[direction]
		if sprite != null and sprite is Texture2D:
			return true
	
	# Check movement sprites
	for direction in movement_sprites:
		var sprite_array = movement_sprites[direction]
		if sprite_array is Array and sprite_array.size() > 0:
			for sprite in sprite_array:
				if sprite != null and sprite is Texture2D:
					return true
	
	return false

func _get_sprite_dimensions(directions: Array) -> Vector2i:
	var max_width = 0
	var max_height = 0

	if OS.is_debug_build():
		print("DirectionalSprite3D: _get_sprite_dimensions called with directions: %s" % str(directions))
		print("DirectionalSprite3D: idle_sprites keys: %s" % str(idle_sprites.keys()))
		print("DirectionalSprite3D: movement_sprites keys: %s" % str(movement_sprites.keys()))

	# Scan all sprites to find maximum dimensions (use full decompressed size for consistency)
	for direction in directions:
		# Check idle sprite
		var idle_sprite = idle_sprites.get(direction)
		if idle_sprite is Texture2D:
			var dimensions = _get_texture_dimensions(idle_sprite)
			if OS.is_debug_build():
				print("DirectionalSprite3D: Idle sprite '%s' dimensions: %dx%d" % [direction, dimensions.x, dimensions.y])
			max_width = max(max_width, dimensions.x)
			max_height = max(max_height, dimensions.y)
		else:
			if OS.is_debug_build():
				print("DirectionalSprite3D: No idle sprite found for direction '%s'" % direction)
		
		# Check movement sprites
		var movement_sprites_array = movement_sprites.get(direction, [])
		for sprite in movement_sprites_array:
			if sprite is Texture2D:
				var dimensions = _get_texture_dimensions(sprite)
				max_width = max(max_width, dimensions.x)
				max_height = max(max_height, dimensions.y)
	
	if OS.is_debug_build():
		print("DirectionalSprite3D: Final sprite dimensions: %dx%d" % [max_width, max_height])

	return Vector2i(max_width, max_height)

func _get_texture_dimensions(tex: Texture2D) -> Vector2i:
	var image = tex.get_image()
	if image == null:
		return Vector2i.ZERO

	if image.is_compressed():
		image.decompress()

	return Vector2i(image.get_width(), image.get_height())

## Get actual content dimensions, excluding decompression padding
func _get_actual_content_dimensions(tex: Texture2D) -> Vector2i:
	var image = tex.get_image()
	if image == null:
		return Vector2i.ZERO

	# For compressed images, we need to find the actual content area
	# by analyzing the alpha channel to exclude padding
	if image.is_compressed():
		image.decompress()

		# Find the actual content bounds by scanning for non-transparent pixels
		var min_x = image.get_width()
		var max_x = -1
		var min_y = image.get_height()
		var max_y = -1

		for y in range(image.get_height()):
			for x in range(image.get_width()):
				var pixel = image.get_pixel(x, y)
				if pixel.a > 0.01: # Non-transparent pixel
					min_x = min(min_x, x)
					max_x = max(max_x, x)
					min_y = min(min_y, y)
					max_y = max(max_y, y)

		# If we found content, return the bounding box size
		if max_x >= min_x and max_y >= min_y:
			var content_width = max_x - min_x + 1
			var content_height = max_y - min_y + 1

			if OS.is_debug_build():
				print("DirectionalSprite3D: Content analysis - decompressed: %dx%d, actual content: %dx%d" % [
					image.get_width(), image.get_height(), content_width, content_height
				])

			return Vector2i(content_width, content_height)

	# For uncompressed images or if content analysis fails, use full dimensions
	return Vector2i(image.get_width(), image.get_height())

## Validates that all sprites have reasonable dimensions for atlas generation
func _validate_sprite_dimensions(directions: Array) -> bool:
	var max_dimensions = _get_sprite_dimensions(directions)
	if max_dimensions == Vector2i.ZERO:
		push_warning("DirectionalSprite3D: No valid sprites found for atlas generation")
		return false
	
	# Check for extremely large textures that might cause memory issues
	if max_dimensions.x > 2048 or max_dimensions.y > 2048:
		push_warning("DirectionalSprite3D: Large sprite dimensions detected (%dx%d). Consider using smaller textures for better performance." % [max_dimensions.x, max_dimensions.y])
	
	return true

func _collect_direction_sprites(direction: String) -> Array[Texture2D]:
	var direction_sprites: Array[Texture2D] = []

	# Add idle sprite - only add if it exists and is valid
	var idle_sprite = idle_sprites.get(direction)
	if idle_sprite is Texture2D:
		if OS.is_debug_build():
			var image = idle_sprite.get_image()
			var size_info = "unknown"
			var compression_info = "unknown"
			var format_info = "unknown"
			if image:
				size_info = "%dx%d" % [image.get_width(), image.get_height()]
				compression_info = "compressed" if image.is_compressed() else "uncompressed"
				format_info = str(image.get_format())

				# Check for suspicious content in idle sprites
				var has_suspicious_content = _check_sprite_for_artifacts(image, direction, "idle")
				if has_suspicious_content:
					print("DirectionalSprite3D: ⚠️  SUSPICIOUS CONTENT detected in idle sprite for '%s'!" % direction)

				# Check for size mismatches that could cause artifacts
				var expected_size = _get_sprite_dimensions([direction])
				if image.get_width() != expected_size.x or image.get_height() != expected_size.y:
					print("DirectionalSprite3D: ⚠️  SIZE MISMATCH in idle sprite for '%s': actual %dx%d vs expected %dx%d" % [
						direction, image.get_width(), image.get_height(), expected_size.x, expected_size.y
					])

			print("DirectionalSprite3D: Idle sprite for '%s': %s (size: %s, %s, format: %s)" % [direction, str(idle_sprite.resource_path), size_info, compression_info, format_info])
		direction_sprites.append(idle_sprite)
	else:
		if OS.is_debug_build():
			print("DirectionalSprite3D: No idle sprite for direction '%s', using null placeholder" % direction)
		# Create a transparent placeholder to maintain consistent atlas layout
		direction_sprites.append(null)

	# Add movement sprites - only add valid textures
	var movement_sprite_array = movement_sprites.get(direction, [])
	if movement_sprite_array is Array:
		for i in range(movement_sprite_array.size()):
			var sprite = movement_sprite_array[i]
			if sprite is Texture2D:
				if OS.is_debug_build():
					var image = sprite.get_image()
					var size_info = "unknown"
					var compression_info = "unknown"
					if image:
						size_info = "%dx%d" % [image.get_width(), image.get_height()]
						compression_info = "compressed" if image.is_compressed() else "uncompressed"

						# Check for suspicious content in movement sprites for comparison
						var has_suspicious_content = _check_sprite_for_artifacts(image, direction, "movement[%d]" % i)
						if has_suspicious_content:
							print("DirectionalSprite3D: ⚠️  SUSPICIOUS CONTENT detected in movement sprite for '%s'[%d]!" % [direction, i])

					print("DirectionalSprite3D: Movement sprite for '%s'[%d]: %s (size: %s, %s)" % [direction, i, str(sprite.resource_path), size_info, compression_info])
				direction_sprites.append(sprite)
			# Note: We don't add null placeholders for movement sprites to avoid gaps

	return direction_sprites

func _create_atlas_texture(all_sprites: Array[Array], atlas_dimensions: Vector2i, sprite_size: Vector2i, padding: int = 0) -> ImageTexture:
	# Create atlas image with proper initialization
	var atlas_image = Image.create(atlas_dimensions.x, atlas_dimensions.y, false, Image.FORMAT_RGBA8)

	# Fill with completely transparent black to ensure clean background
	atlas_image.fill(Color(0.0, 0.0, 0.0, 0.0))

	# Calculate padded cell size
	var padded_cell_size = Vector2i(sprite_size.x + padding, sprite_size.y + padding)

	# Debug: Print atlas generation info (can be removed in production)
	if OS.is_debug_build():
		print("DirectionalSprite3D: Generating atlas %dx%d, cell size %dx%d, padding %d" % [
			atlas_dimensions.x, atlas_dimensions.y,
			padded_cell_size.x, padded_cell_size.y,
			padding
		])

	# Blit sprites into atlas with padding
	var row = 0
	for sprite_data in all_sprites:
		var direction_name = sprite_data[0]
		var sprite_array = sprite_data[1]

		for col in range(sprite_array.size()):
			var sprite = sprite_array[col]
			if sprite is Texture2D:
				if OS.is_debug_build():
					print("DirectionalSprite3D: Blitting sprite for direction '%s', frame %d" % [direction_name, col])
				_blit_sprite_to_atlas(sprite, atlas_image, col, row, sprite_size, padded_cell_size)
			else:
				if OS.is_debug_build():
					print("DirectionalSprite3D: NULL SPRITE DETECTED for direction '%s', frame %d - this will leave atlas cell uninitialized!" % [direction_name, col])
				# Fill the atlas cell with a solid color to make null sprites visible
				_fill_atlas_cell_with_debug_color(atlas_image, col, row, sprite_size, padded_cell_size)

		row += 1

	# Create texture with explicit settings
	var atlas_texture = ImageTexture.create_from_image(atlas_image)

	if atlas_texture == null or atlas_texture.get_width() == 0 or atlas_texture.get_height() == 0:
		push_error("DirectionalSprite3D: Failed to create atlas texture")
		return null

	if OS.is_debug_build():
		print("DirectionalSprite3D: Atlas texture created successfully: %dx%d" % [atlas_texture.get_width(), atlas_texture.get_height()])

		# Save atlas for visual debugging
		var debug_image = atlas_texture.get_image()
		if debug_image:
			var debug_path = "user://debug_atlas_%d.png" % Time.get_unix_time_from_system()
			debug_image.save_png(debug_path)
			print("DirectionalSprite3D: Atlas saved to %s for visual inspection" % debug_path)

	return atlas_texture

func _blit_sprite_to_atlas(sprite: Texture2D, atlas_image: Image, col: int, row: int, sprite_size: Vector2i, padded_cell_size: Vector2i = Vector2i.ZERO):
	var sprite_image = sprite.get_image()
	if sprite_image == null:
		return

	# Handle compressed textures
	var was_compressed = sprite_image.is_compressed()
	if was_compressed:
		sprite_image.decompress()

	# Convert to atlas format
	if sprite_image.get_format() != Image.FORMAT_RGBA8:
		sprite_image.convert(Image.FORMAT_RGBA8)

	# Get actual sprite dimensions
	var actual_width = sprite_image.get_width()
	var actual_height = sprite_image.get_height()

	# Use padded cell size if provided, otherwise use sprite size
	var cell_size = padded_cell_size if padded_cell_size != Vector2i.ZERO else sprite_size
	var padding = (cell_size.x - sprite_size.x) / 2 # Calculate padding from cell size difference

	# Calculate atlas cell position
	var cell_pos = Vector2i(col * cell_size.x, row * cell_size.y)

	# Position sprite at the center of the padded cell
	# This ensures the sprite is exactly where the shader expects it
	var sprite_start_pos = Vector2i(cell_pos.x + padding, cell_pos.y + padding)

	# Prepare source rectangle for blitting
	var blit_width = min(actual_width, sprite_size.x)
	var blit_height = min(actual_height, sprite_size.y)
	var src_rect = Rect2i(0, 0, blit_width, blit_height)

	# Adjust if sprite is larger than allocated area (crop from center)
	if actual_width > sprite_size.x or actual_height > sprite_size.y:
		var crop_offset_x = int((actual_width - sprite_size.x) / 2)
		var crop_offset_y = int((actual_height - sprite_size.y) / 2)
		src_rect = Rect2i(crop_offset_x, crop_offset_y, sprite_size.x, sprite_size.y)

	# Always pad sprites to ensure consistent cell filling and eliminate artifacts
	if actual_width != sprite_size.x or actual_height != sprite_size.y:
		# Create a padded version of the sprite that fills the entire cell
		var padded_image = Image.create(sprite_size.x, sprite_size.y, false, Image.FORMAT_RGBA8)
		padded_image.fill(Color.TRANSPARENT)

		# Center the original sprite in the padded image
		var center_x = int((sprite_size.x - actual_width) / 2)
		var center_y = int((sprite_size.y - actual_height) / 2)
		padded_image.blit_rect(sprite_image, src_rect, Vector2i(center_x, center_y))

		# Blit the padded sprite to fill the entire cell
		atlas_image.blit_rect(padded_image, Rect2i(0, 0, sprite_size.x, sprite_size.y), sprite_start_pos)

		if OS.is_debug_build():
			print("DirectionalSprite3D: Padded sprite %dx%d to %dx%d and positioned at (%d,%d)" % [
				actual_width, actual_height, sprite_size.x, sprite_size.y, sprite_start_pos.x, sprite_start_pos.y
			])
	else:
		# Sprite is exact size, blit directly to fill the cell
		atlas_image.blit_rect(sprite_image, src_rect, sprite_start_pos)

		if OS.is_debug_build():
			print("DirectionalSprite3D: Positioned exact-size sprite %dx%d at (%d,%d)" % [
				actual_width, actual_height, sprite_start_pos.x, sprite_start_pos.y
			])

	# Only extend borders for compressed textures to prevent bleeding
	# Be conservative to avoid conflicts with Fix Alpha Border
	if padding > 1 and was_compressed:
		_extend_sprite_borders(atlas_image, sprite_start_pos, Vector2i(blit_width, blit_height), padding - 1)

## Extends sprite borders into padding area to prevent texture bleeding
## This is crucial for compressed textures which can have sampling artifacts
func _extend_sprite_borders(atlas_image: Image, sprite_pos: Vector2i, sprite_size: Vector2i, padding: int):
	var atlas_width = atlas_image.get_width()
	var atlas_height = atlas_image.get_height()

	# Extend top and bottom edges
	for x in range(sprite_size.x):
		var src_x = sprite_pos.x + x
		if src_x >= 0 and src_x < atlas_width:
			# Top edge - extend upward
			var top_color = atlas_image.get_pixel(src_x, sprite_pos.y)
			for p in range(1, padding + 1):
				var dest_y = sprite_pos.y - p
				if dest_y >= 0:
					atlas_image.set_pixel(src_x, dest_y, top_color)

			# Bottom edge - extend downward
			var bottom_color = atlas_image.get_pixel(src_x, sprite_pos.y + sprite_size.y - 1)
			for p in range(1, padding + 1):
				var dest_y = sprite_pos.y + sprite_size.y - 1 + p
				if dest_y < atlas_height:
					atlas_image.set_pixel(src_x, dest_y, bottom_color)

	# Extend left and right edges
	for y in range(sprite_size.y):
		var src_y = sprite_pos.y + y
		if src_y >= 0 and src_y < atlas_height:
			# Left edge - extend leftward
			var left_color = atlas_image.get_pixel(sprite_pos.x, src_y)
			for p in range(1, padding + 1):
				var dest_x = sprite_pos.x - p
				if dest_x >= 0:
					atlas_image.set_pixel(dest_x, src_y, left_color)

			# Right edge - extend rightward
			var right_color = atlas_image.get_pixel(sprite_pos.x + sprite_size.x - 1, src_y)
			for p in range(1, padding + 1):
				var dest_x = sprite_pos.x + sprite_size.x - 1 + p
				if dest_x < atlas_width:
					atlas_image.set_pixel(dest_x, src_y, right_color)

## Fill an atlas cell with a debug color to make null sprites visible
func _fill_atlas_cell_with_debug_color(atlas_image: Image, col: int, row: int, sprite_size: Vector2i, padded_cell_size: Vector2i):
	var cell_pos = Vector2i(col * padded_cell_size.x, row * padded_cell_size.y)
	var padding = int((padded_cell_size.x - sprite_size.x) / 2)
	var sprite_start_pos = Vector2i(cell_pos.x + padding, cell_pos.y + padding)

	# Fill with a bright magenta color to make it obvious
	var debug_color = Color.MAGENTA
	for x in range(sprite_size.x):
		for y in range(sprite_size.y):
			var pixel_x = sprite_start_pos.x + x
			var pixel_y = sprite_start_pos.y + y
			if pixel_x >= 0 and pixel_x < atlas_image.get_width() and pixel_y >= 0 and pixel_y < atlas_image.get_height():
				atlas_image.set_pixel(pixel_x, pixel_y, debug_color)

## Check sprite for suspicious content that might indicate corruption or wrong assignment
func _check_sprite_for_artifacts(image: Image, direction: String, sprite_type: String) -> bool:
	if image == null:
		return false

	# Skip analysis for compressed images to avoid errors
	if image.is_compressed():
		print("DirectionalSprite3D: Skipping artifact check for compressed %s sprite '%s'" % [sprite_type, direction])
		return false

	var width = image.get_width()
	var height = image.get_height()

	# Check bottom 10% of the image for unusual patterns (where artifacts typically appear)
	var bottom_start_y = int(height * 0.9)
	var suspicious_pixels = 0
	var total_bottom_pixels = 0

	for y in range(bottom_start_y, height):
		for x in range(width):
			total_bottom_pixels += 1
			var pixel = image.get_pixel(x, y)

			# Check for unusual patterns that might indicate artifacts
			# Look for very bright pixels, unusual colors, or patterns that don't belong
			if pixel.a > 0.1: # Non-transparent pixel
				# Check for unusually bright or saturated pixels
				var brightness = (pixel.r + pixel.g + pixel.b) / 3.0
				var saturation = max(pixel.r, max(pixel.g, pixel.b)) - min(pixel.r, min(pixel.g, pixel.b))

				if brightness > 0.9 or saturation > 0.8:
					suspicious_pixels += 1

	# If more than 5% of bottom pixels are suspicious, flag it
	var suspicious_ratio = float(suspicious_pixels) / float(total_bottom_pixels) if total_bottom_pixels > 0 else 0.0

	if suspicious_ratio > 0.05:
		print("DirectionalSprite3D: Suspicious content in %s sprite '%s': %.1f%% suspicious pixels in bottom area" % [sprite_type, direction, suspicious_ratio * 100.0])
		return true

	return false

#endregion

#region Target Node Management

func _update_moving_state():
	var target = _get_target_node()
	if target == null:
		return

	var previous_state = has_moving_state
	has_moving_state = _target_has_moving_state(target)
	
	if previous_state != has_moving_state:
		notify_property_list_changed()
		call_deferred("_generate_atlas_if_ready")

func _get_target_node() -> Node3D:
	var target_node: Node = null
	if not target_node_path.is_empty() and has_node(target_node_path):
		target_node = get_node(target_node_path)
	else:
		target_node = get_parent()

	# Ensure we return a Node3D or null
	if target_node is Node3D:
		return target_node
	else:
		return null

func _target_has_moving_state(target: Node3D) -> bool:
	if target.get("moving_state") != null:
		return true
	
	if target.get_script() != null:
		var script_properties = target.get_script().get_script_property_list()
		return script_properties.any(func(prop): return prop.name == "moving_state")
	
	return false

#endregion

#region Directional Rendering

func _setup_shader_material():
	# Re-use a material the user already assigned in the editor so that any
	# parameters tweaked from the Inspector carry over to the running game.
	if material_override is ShaderMaterial:
		directional_material = material_override
	else:
		if directional_material == null:
			directional_material = ShaderMaterial.new()
			directional_material.shader = load("res://scenes/components/directional_sprite_3d/directional_sprite_3d.gdshader")
			material_override = directional_material

	# Initialize shader uniforms
	_update_shader_uniforms()

func _update_directional_rendering():
	if not is_inside_tree() or directional_material == null:
		return

	# Check for movement state changes (direction is now calculated in shader)
	var target_node = _get_target_node()
	if target_node == null:
		return

	var new_moving_state = _get_moving_state(target_node)

	# Update if movement state changed (shader handles direction automatically)
	if new_moving_state != is_moving:
		is_moving = new_moving_state
		_update_shader_uniforms()

func _calculate_camera_direction(camera: Camera3D, target: Node3D) -> String:
	# Calculate direction vector from target to camera
	var direction_to_camera = target.global_position.direction_to(camera.global_position)

	# Get target's transform basis for local direction calculation
	var target_basis = target.global_transform.basis
	var forward = target_basis.z # Local forward direction
	var right = target_basis.x # Local right direction

	# Calculate dot products for direction determination
	var forward_dot = forward.dot(direction_to_camera)
	var _right_dot = right.dot(direction_to_camera) # Used for other direction modes

	# Determine direction based on THREE_DIRECTIONAL system
	if direction_mode == DirectionMode.THREE_DIRECTIONS:
		if forward_dot < -0.5:
			return "front" # Camera is in front of target
		elif forward_dot > 0.5:
			return "back" # Camera is behind target
		else:
			return "side" # Camera is to the side

	# For other direction modes, implement similar logic
	# This is a simplified version focusing on THREE_DIRECTIONAL
	return "front"

func _get_moving_state(target: Node3D) -> bool:
	# Check if target has moving_state property
	if target.has_method("get") and target.get("moving_state") != null:
		var moving_state = target.get("moving_state")
		# Ensure we return a boolean
		if moving_state is bool:
			return moving_state
		elif moving_state is String:
			return moving_state != "" and moving_state != "idle"
		else:
			return bool(moving_state)

	# Check if target has velocity and is moving
	if target.has_method("get") and target.get("velocity") != null:
		var velocity = target.get("velocity")
		if velocity is Vector3:
			return velocity.length() > 0.1

	return false

func _update_shader_uniforms():
	if directional_material == null or texture == null:
		return

	# Set atlas texture
	directional_material.set_shader_parameter("atlas_texture", texture)

	# Calculate atlas dimensions and frame size
	var atlas_size = Vector2(texture.get_width(), texture.get_height())
	var frame_size = get_atlas_frame_size()

	if OS.is_debug_build():
		print("DirectionalSprite3D: _update_shader_uniforms called - atlas: %dx%d, frame: %dx%d" % [
			int(atlas_size.x), int(atlas_size.y), frame_size.x, frame_size.y
		])

	if frame_size != Vector2i.ZERO:
		directional_material.set_shader_parameter("atlas_dimensions", atlas_size)

		# Pass the actual sprite size (without padding) to the shader
		directional_material.set_shader_parameter("frame_size", Vector2(frame_size))

		# Pass the padded cell size for proper UV calculations - detect actual padding used
		var padding = ATLAS_PADDING
		var current_directions = _get_current_directions()
		if not current_directions.is_empty():
			# Calculate max frames to determine atlas layout correctly
			var max_frames = 1
			for direction in current_directions:
				var direction_sprites = _collect_direction_sprites(direction)
				max_frames = max(max_frames, direction_sprites.size())

			# Correct atlas dimension calculation: width = max_frames * padded_cell_width, height = directions * padded_cell_height
			var expected_width_normal = max_frames * (frame_size.x + ATLAS_PADDING)
			var expected_width_compressed = max_frames * (frame_size.x + COMPRESSED_TEXTURE_PADDING)
			if abs(atlas_size.x - expected_width_compressed) < abs(atlas_size.x - expected_width_normal):
				padding = COMPRESSED_TEXTURE_PADDING

		var padded_frame_size = Vector2(frame_size.x + padding, frame_size.y + padding)
		directional_material.set_shader_parameter("padded_frame_size", padded_frame_size)

		# Pass compressed texture flag to shader for enhanced UV clamping
		var has_compressed = padding == COMPRESSED_TEXTURE_PADDING
		directional_material.set_shader_parameter("has_compressed_textures", has_compressed)

		if OS.is_debug_build():
			print("DirectionalSprite3D: Shader updated - atlas: %dx%d, frame: %dx%d, padded: %dx%d, compressed: %s" % [
				int(atlas_size.x), int(atlas_size.y),
				int(frame_size.x), int(frame_size.y),
				int(padded_frame_size.x), int(padded_frame_size.y),
				str(has_compressed)
			])

		# Set direction count
		var directions = _get_current_directions()
		directional_material.set_shader_parameter("direction_count", directions.size())

		# Set current frame (0 for idle, >0 for movement frames)
		var frame_index = 0
		if is_moving and has_moving_state:
			# For movement, use frame 1+ (idle is frame 0)
			frame_index = 1 # Could be animated based on time
		directional_material.set_shader_parameter("current_frame", frame_index)

		# Set target position for shader-based direction calculation
		var target_node = _get_target_node()
		if target_node:
			directional_material.set_shader_parameter("target_position", target_node.global_position)
		else:
			directional_material.set_shader_parameter("target_position", global_position)

		# Enable automatic direction calculation in shader (works for all camera types)
		directional_material.set_shader_parameter("auto_direction", true)

		# Convey the Sprite3D billboard mode to the shader
		var billboard_enabled = (billboard != BaseMaterial3D.BILLBOARD_DISABLED)
		directional_material.set_shader_parameter("billboard_enabled", billboard_enabled)


func _should_flip_horizontal() -> bool:
	if direction_mode != DirectionMode.THREE_DIRECTIONS or current_direction != "side":
		return false

	# Get current camera for flip determination
	var current_camera = get_viewport().get_camera_3d()
	var target_node = _get_target_node()

	if current_camera == null or target_node == null:
		return false

	# Calculate if camera is on the right side (should flip)
	var direction_to_camera = target_node.global_position.direction_to(current_camera.global_position)
	var target_basis = target_node.global_transform.basis
	var right = target_basis.x

	return right.dot(direction_to_camera) > 0

func _update_target_position():
	# Update target position in shader for real-time direction calculation
	if directional_material == null:
		return

	var target_node = _get_target_node()
	if target_node:
		directional_material.set_shader_parameter("target_position", target_node.global_position)
	else:
		directional_material.set_shader_parameter("target_position", global_position)

#endregion
