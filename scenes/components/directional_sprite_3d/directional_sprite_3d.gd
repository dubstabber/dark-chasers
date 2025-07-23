@tool
class_name DirectionlSprite3D
extends Sprite3D

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

#region Internal Variables

var has_moving_state := false
var idle_sprites := {}
var movement_sprites := {}
var atlas_texture: Texture2D

# Shader material for directional rendering
var directional_material: ShaderMaterial

#endregion

@export var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		_get_target_node()
		generate_atlas()
		notify_property_list_changed()

@export var direction_mode: DirectionMode = DirectionMode.THREE_DIRECTIONS:
	set(value):
		direction_mode = value
		generate_atlas()
		notify_property_list_changed()


func _ready() -> void:
	_get_target_node()


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
	
	if prop_name == "billboard":
		material_override.set_shader_parameter("billboard_mode", value)

	if prop_name.ends_with(IDLE_SUFFIX):
		var direction = prop_name.replace(IDLE_SUFFIX, "")
		if direction in _get_current_directions():
			idle_sprites[direction] = value
			generate_atlas()
			return true
	
	if prop_name.ends_with(MOVEMENT_SUFFIX):
		var direction = prop_name.replace(MOVEMENT_SUFFIX, "")
		if direction in _get_current_directions():
			movement_sprites[direction] = value
			generate_atlas()
			return true
	
	return false


func _get_property_list():
	var properties: Array[Dictionary] = []
	var directions = _get_current_directions()
	
	_add_sprite_group_properties(properties, "Idle sprites", directions, IDLE_SUFFIX, TYPE_OBJECT, "Texture2D")
	
	if has_moving_state:
		_add_sprite_group_properties(properties, "Movement sprites", directions, MOVEMENT_SUFFIX, TYPE_ARRAY, "%d/%d:Texture2D" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE])
	
	return properties


func _get_current_directions() -> Array:
	return DIRECTION_SETS.get(direction_mode, [])


func _add_sprite_group_properties(properties: Array[Dictionary], group_name: String, directions: Array, suffix: String, property_type: int, hint_string: String) -> void:
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


func _get_target_node() -> Node3D:
	var target_node: Node = null
	if not target_node_path.is_empty() and has_node(target_node_path):
		target_node = get_node(target_node_path)
	else:
		target_node = get_parent()

	if target_node and target_node.get_script():
		var script_properties = target_node.get_script().get_script_property_list()
		has_moving_state = script_properties.any(func(prop): return prop.name == "moving_state")
	else: has_moving_state = false
	return target_node


func generate_atlas():
	if not _has_any_sprites():
		atlas_texture = null
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
	var max_sprite_size = _get_sprite_max_dimensions(directions)
	var max_frames = 1
	
	# Collect all sprites for each direction
	for direction in directions:
		var direction_sprites = _collect_direction_sprites(direction)
		all_sprites.append([direction, direction_sprites])
		max_frames = max(max_frames, direction_sprites.size())
	
	# Create and populate atlas
	var atlas_dimensions = Vector2i(max_sprite_size.x * max_frames, max_sprite_size.y * directions.size())
	atlas_texture = _create_atlas_texture(all_sprites, atlas_dimensions, max_sprite_size)
	
	if atlas_texture:
		# Create properly sized current sprite texture
		#_update_current_sprite_texture(sprite_size)
		# Update shader uniforms when atlas changes
		#call_deferred("_update_shader_uniforms")
		var image = Image.create(max_sprite_size.x, max_sprite_size.y, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		texture = ImageTexture.create_from_image(image)

		if material_override is ShaderMaterial and material_override.shader:
			material_override.set_shader_parameter("atlas_texture", atlas_texture)
			material_override.set_shader_parameter("billboard_mode", billboard)
			var atlas_size = Vector2(atlas_texture.get_width(), atlas_texture.get_height())
			material_override.set_shader_parameter("atlas_dimensions", atlas_size)
			material_override.set_shader_parameter("max_sprite_size", Vector2(max_sprite_size))
			material_override.set_shader_parameter("direction_mode", direction_mode)
			var target_node = _get_target_node()
			if target_node:
				directional_material.set_shader_parameter("target_position", target_node.global_position)

		notify_property_list_changed()


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

## Validates that all sprites have reasonable dimensions for atlas generation
func _validate_sprite_dimensions(directions: Array) -> bool:
	var max_dimensions = _get_sprite_max_dimensions(directions)
	if max_dimensions == Vector2i.ZERO:
		push_warning("DirectionalSprite3D: No valid sprites found for atlas generation")
		return false
	
	# Check for extremely large textures that might cause memory issues
	if max_dimensions.x > 2048 or max_dimensions.y > 2048:
		push_warning("DirectionalSprite3D: Large sprite dimensions detected (%dx%d). Consider using smaller textures for better performance." % [max_dimensions.x, max_dimensions.y])
	
	return true


func _get_sprite_max_dimensions(directions: Array) -> Vector2i:
	var max_width = 0
	var max_height = 0
	
	# Scan all sprites to find maximum dimensions
	for direction in directions:
		# Check idle sprite
		var idle_sprite = idle_sprites.get(direction)
		if idle_sprite is Texture2D:
			var dimensions = _get_texture_dimensions(idle_sprite)
			max_width = max(max_width, dimensions.x)
			max_height = max(max_height, dimensions.y)
		
		# Check movement sprites
		var movement_sprites_array = movement_sprites.get(direction, [])
		for sprite in movement_sprites_array:
			if sprite is Texture2D:
				var dimensions = _get_texture_dimensions(sprite)
				max_width = max(max_width, dimensions.x)
				max_height = max(max_height, dimensions.y)
	
	return Vector2i(max_width, max_height)


func _get_texture_dimensions(tex: Texture2D) -> Vector2i:
	var image = tex.get_image()
	if image == null:
		return Vector2i.ZERO
	
	if image.is_compressed():
		image.decompress()
	
	return Vector2i(image.get_width(), image.get_height())


func _collect_direction_sprites(direction: String) -> Array[Texture2D]:
	var direction_sprites: Array[Texture2D] = []
	
	# Add idle sprite or placeholder
	var idle_sprite = idle_sprites.get(direction)
	if idle_sprite is Texture2D:
		direction_sprites.append(idle_sprite)
	else:
		direction_sprites.append(null)
	
	# Add movement sprites
	var movement_sprite_array = movement_sprites.get(direction, [])
	if movement_sprite_array is Array:
		for sprite in movement_sprite_array:
			if sprite is Texture2D:
				direction_sprites.append(sprite)
	
	return direction_sprites


func _create_atlas_texture(all_sprites: Array[Array], atlas_dimensions: Vector2i, max_sprite_size: Vector2i) -> ImageTexture:
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
		push_error("DirectionalSprite3D: Failed to create atlas texture")
		return null

	return new_atlas_texture


func _blit_sprite_to_atlas(sprite: Texture2D, atlas_image: Image, col: int, row: int, max_sprite_size: Vector2i):
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


# func _notification(what):
# 	if what == NOTIFICATION_EDITOR_PRE_SAVE or what == NOTIFICATION_EDITOR_POST_SAVE:
# 		print('changedd')

# func _validate_property(property: Dictionary):
# 	if property.name == "billboard":
# 		print('billboard changed')
# 		print(property)
