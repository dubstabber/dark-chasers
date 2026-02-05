class_name DirectionalAtlasGenerator
extends RefCounted

## Utility class for generating texture atlases from directional sprite sets.
## Extracted from DirectionalSprite3D to enforce SRP and reduce file size.

# Static atlas cache: signature -> {texture: ImageTexture, max_sprite_size: Vector2i}
static var _atlas_cache: Dictionary = {}


static func generate(
	direction_mode: int,
	directions: Array,
	idle_sprites: Dictionary,
	movement_sprites: Dictionary,
	shooting_sprites: Dictionary
) -> Dictionary:
	"""Generate an atlas texture from sprite sets.
	
	Returns:
		Dictionary with keys: texture (ImageTexture or null), max_sprite_size (Vector2i)
	"""
	if not _has_any_sprites(idle_sprites, movement_sprites, shooting_sprites):
		return {"texture": null, "max_sprite_size": Vector2i.ZERO}
	
	if directions.is_empty():
		push_warning("DirectionalAtlasGenerator: No directions available for atlas generation")
		return {"texture": null, "max_sprite_size": Vector2i.ZERO}
	
	# Validate sprite dimensions
	var max_sprite_size = _get_sprite_max_dimensions(directions, idle_sprites, movement_sprites, shooting_sprites)
	if max_sprite_size == Vector2i.ZERO:
		push_warning("DirectionalAtlasGenerator: No valid sprites found for atlas generation")
		return {"texture": null, "max_sprite_size": Vector2i.ZERO}
	
	# Check for large textures
	if max_sprite_size.x > 2048 or max_sprite_size.y > 2048:
		push_warning("DirectionalAtlasGenerator: Large sprite dimensions detected (%dx%d). Consider using smaller textures." % [max_sprite_size.x, max_sprite_size.y])
	
	# Check cache first
	var signature = _compute_signature(direction_mode, directions, idle_sprites, movement_sprites, shooting_sprites)
	
	if signature in _atlas_cache:
		var cached = _atlas_cache[signature]
		return {"texture": cached.texture, "max_sprite_size": cached.max_sprite_size}
	
	# Collect sprites and determine dimensions
	var all_sprites: Array[Array] = []
	var max_frames = 1
	
	for direction in directions:
		var direction_sprites = _collect_direction_sprites(direction, idle_sprites, movement_sprites, shooting_sprites)
		all_sprites.append([direction, direction_sprites])
		max_frames = max(max_frames, direction_sprites.size())
	
	# Create and populate atlas
	var atlas_dimensions = Vector2i(max_sprite_size.x * max_frames, max_sprite_size.y * directions.size())
	var atlas_texture = _create_atlas_texture(all_sprites, atlas_dimensions, max_sprite_size)
	
	# Store in cache
	if atlas_texture:
		_atlas_cache[signature] = {"texture": atlas_texture, "max_sprite_size": max_sprite_size}
	
	return {"texture": atlas_texture, "max_sprite_size": max_sprite_size}


static func _has_any_sprites(idle_sprites: Dictionary, movement_sprites: Dictionary, shooting_sprites: Dictionary) -> bool:
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
	
	# Check shooting sprites
	for direction in shooting_sprites:
		var sprite_array = shooting_sprites[direction]
		if sprite_array is Array and sprite_array.size() > 0:
			for sprite in sprite_array:
				if sprite != null and sprite is Texture2D:
					return true
	
	return false


static func _compute_signature(
	direction_mode: int,
	directions: Array,
	idle_sprites: Dictionary,
	movement_sprites: Dictionary,
	shooting_sprites: Dictionary
) -> String:
	"""Generate a unique signature from the sprite set for cache keying."""
	var parts: PackedStringArray = []
	parts.append(str(direction_mode))
	
	for direction in directions:
		# Idle sprite
		var idle = idle_sprites.get(direction)
		if idle is Texture2D:
			parts.append(idle.resource_path if idle.resource_path else str(idle.get_rid().get_id()))
		else:
			parts.append("null")
		
		# Movement sprites
		var movement = movement_sprites.get(direction, [])
		if movement is Array:
			for sprite in movement:
				if sprite is Texture2D:
					parts.append(sprite.resource_path if sprite.resource_path else str(sprite.get_rid().get_id()))
				else:
					parts.append("null")
		
		# Shooting sprites
		var shooting = shooting_sprites.get(direction, [])
		if shooting is Array:
			for sprite in shooting:
				if sprite is Texture2D:
					parts.append(sprite.resource_path if sprite.resource_path else str(sprite.get_rid().get_id()))
				else:
					parts.append("null")
	
	return "|".join(parts)


static func _get_sprite_max_dimensions(
	directions: Array,
	idle_sprites: Dictionary,
	movement_sprites: Dictionary,
	shooting_sprites: Dictionary
) -> Vector2i:
	var max_width = 0
	var max_height = 0
	
	for direction in directions:
		# Check idle sprite
		var idle_sprite = idle_sprites.get(direction)
		if idle_sprite is Texture2D:
			var dimensions = _get_texture_dimensions(idle_sprite)
			max_width = max(max_width, dimensions.x)
			max_height = max(max_height, dimensions.y)
		
		# Check movement sprites
		var movement_array = movement_sprites.get(direction, [])
		for sprite in movement_array:
			if sprite is Texture2D:
				var dimensions = _get_texture_dimensions(sprite)
				max_width = max(max_width, dimensions.x)
				max_height = max(max_height, dimensions.y)
		
		# Check shooting sprites
		var shooting_array = shooting_sprites.get(direction, [])
		for sprite in shooting_array:
			if sprite is Texture2D:
				var dimensions = _get_texture_dimensions(sprite)
				max_width = max(max_width, dimensions.x)
				max_height = max(max_height, dimensions.y)
	
	return Vector2i(max_width, max_height)


static func _get_texture_dimensions(tex: Texture2D) -> Vector2i:
	var image = tex.get_image()
	if image == null:
		return Vector2i.ZERO
	
	if image.is_compressed():
		image.decompress()
	
	return Vector2i(image.get_width(), image.get_height())


static func _collect_direction_sprites(
	direction: String,
	idle_sprites: Dictionary,
	movement_sprites: Dictionary,
	shooting_sprites: Dictionary
) -> Array[Texture2D]:
	var direction_sprites: Array[Texture2D] = []
	
	# Add idle sprite or placeholder
	var idle_sprite = idle_sprites.get(direction)
	if idle_sprite is Texture2D:
		direction_sprites.append(idle_sprite)
	else:
		direction_sprites.append(null)
	
	# Add movement sprites
	var movement_array = movement_sprites.get(direction, [])
	if movement_array is Array:
		for sprite in movement_array:
			if sprite is Texture2D:
				direction_sprites.append(sprite)
	
	# Add shooting sprites
	var shooting_array = shooting_sprites.get(direction, [])
	if shooting_array is Array:
		for sprite in shooting_array:
			if sprite is Texture2D:
				direction_sprites.append(sprite)
	
	return direction_sprites


static func _create_atlas_texture(all_sprites: Array[Array], atlas_dimensions: Vector2i, max_sprite_size: Vector2i) -> ImageTexture:
	var atlas_image = Image.create_empty(atlas_dimensions.x, atlas_dimensions.y, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color.TRANSPARENT)
	
	# Blit sprites into atlas
	var row = 0
	for sprite_data in all_sprites:
		var sprite_array = sprite_data[1]
		
		for col in range(sprite_array.size()):
			var sprite = sprite_array[col]
			if sprite is Texture2D:
				_blit_sprite_to_atlas(sprite, atlas_image, col, row, max_sprite_size)
		
		row += 1
	
	# Create texture
	var new_atlas_texture = ImageTexture.new()
	new_atlas_texture.set_image(atlas_image)

	if new_atlas_texture.get_width() == 0 or new_atlas_texture.get_height() == 0:
		push_error("DirectionalAtlasGenerator: Failed to create atlas texture")
		return null

	return new_atlas_texture


static func _blit_sprite_to_atlas(sprite: Texture2D, atlas_image: Image, col: int, row: int, max_sprite_size: Vector2i):
	var sprite_image = sprite.get_image()
	if sprite_image == null:
		return
	
	# Handle compressed textures
	if sprite_image.is_compressed():
		sprite_image.decompress()
	
	# Convert to atlas format
	if sprite_image.get_format() != Image.FORMAT_RGBA8:
		sprite_image.convert(Image.FORMAT_RGBA8)
	
	# Get actual sprite dimensions
	var actual_width = sprite_image.get_width()
	var actual_height = sprite_image.get_height()
	
	# Calculate atlas cell position
	var cell_pos = Vector2i(col * max_sprite_size.x, row * max_sprite_size.y)
	
	# Center the sprite within the atlas cell if it's smaller
	var offset_x = (max_sprite_size.x - actual_width) / 2.0
	var offset_y = (max_sprite_size.y - actual_height) / 2.0
	var dest_pos = Vector2i(cell_pos.x + offset_x, cell_pos.y + offset_y)
	
	# Ensure we don't exceed atlas cell boundaries
	var blit_width = min(actual_width, max_sprite_size.x)
	var blit_height = min(actual_height, max_sprite_size.y)
	var src_rect = Rect2i(0, 0, blit_width, blit_height)
	
	# Adjust destination if sprite is larger than cell (crop from center)
	if actual_width > max_sprite_size.x or actual_height > max_sprite_size.y:
		var crop_offset_x = (actual_width - max_sprite_size.x)
		var crop_offset_y = (actual_height - max_sprite_size.y)
		src_rect = Rect2i(crop_offset_x, crop_offset_y, max_sprite_size.x, max_sprite_size.y)
		dest_pos = cell_pos
	
	atlas_image.blit_rect(sprite_image, src_rect, dest_pos)
