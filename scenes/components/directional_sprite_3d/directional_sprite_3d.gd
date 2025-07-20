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
		call_deferred("_generate_atlas_if_ready")

#endregion

#region Internal Variables

var has_moving_state: bool = false
var idle_sprites: Dictionary = {}
var movement_sprites: Dictionary = {}

#endregion

#region Initialization

func _ready():
	_initialize_sprite_dictionaries()
	_update_moving_state()

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
		call_deferred("_generate_atlas_if_ready")
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
	
	# Collect sprites and determine dimensions
	var all_sprites: Array[Array] = []
	var sprite_size = _get_sprite_dimensions(directions)
	var max_frames = 1
	
	# Collect all sprites for each direction
	for direction in directions:
		var direction_sprites = _collect_direction_sprites(direction)
		all_sprites.append([direction, direction_sprites])
		max_frames = max(max_frames, direction_sprites.size())
	
	# Create and populate atlas
	var atlas_dimensions = Vector2i(sprite_size.x * max_frames, sprite_size.y * directions.size())
	var atlas_texture = _create_atlas_texture(all_sprites, atlas_dimensions, sprite_size)
	
	if atlas_texture:
		texture = atlas_texture
	
	return atlas_texture

func _generate_atlas_if_ready():
	if is_inside_tree():
		if _has_any_sprites():
			generate_atlas()
		else:
			texture = null

#endregion

#region Atlas Utility Functions

## Get the atlas frame coordinates for a specific direction and frame
func get_atlas_frame_position(direction: String, frame_index: int = 0) -> Vector2i:
	var directions = _get_current_directions()
	var direction_row = directions.find(direction)
	
	if direction_row == -1 or texture == null:
		return Vector2i.ZERO
	
	var frame_size = get_atlas_frame_size()
	if frame_size == Vector2i.ZERO:
		return Vector2i.ZERO
	
	return Vector2i(frame_index * frame_size.x, direction_row * frame_size.y)

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
	for direction in directions:
		var idle_sprite = idle_sprites.get(direction)
		if idle_sprite is Texture2D:
			return _get_texture_dimensions(idle_sprite)
		
		var movement_sprites_array = movement_sprites.get(direction, [])
		for sprite in movement_sprites_array:
			if sprite is Texture2D:
				return _get_texture_dimensions(sprite)
	
	return Vector2i.ZERO

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

func _create_atlas_texture(all_sprites: Array[Array], atlas_dimensions: Vector2i, sprite_size: Vector2i) -> ImageTexture:
	var atlas_image = Image.create(atlas_dimensions.x, atlas_dimensions.y, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color.TRANSPARENT)
	
	# Blit sprites into atlas
	var row = 0
	for sprite_data in all_sprites:
		var sprite_array = sprite_data[1]
		
		for col in range(sprite_array.size()):
			var sprite = sprite_array[col]
			if sprite is Texture2D:
				_blit_sprite_to_atlas(sprite, atlas_image, col, row, sprite_size)
		
		row += 1
	
	# Create texture
	var atlas_texture = ImageTexture.new()
	atlas_texture.set_image(atlas_image)
	
	if atlas_texture.get_width() == 0 or atlas_texture.get_height() == 0:
		push_error("DirectionalSprite3D: Failed to create atlas texture")
		return null
	
	return atlas_texture

func _blit_sprite_to_atlas(sprite: Texture2D, atlas_image: Image, col: int, row: int, sprite_size: Vector2i):
	var sprite_image = sprite.get_image()
	if sprite_image == null:
		return
	
	# Handle compressed textures
	if sprite_image.is_compressed():
		sprite_image.decompress()
	
	# Convert to atlas format
	if sprite_image.get_format() != Image.FORMAT_RGBA8:
		sprite_image.convert(Image.FORMAT_RGBA8)
	
	# Calculate position and blit
	var dest_pos = Vector2i(col * sprite_size.x, row * sprite_size.y)
	var src_rect = Rect2i(0, 0, 
		min(sprite_image.get_width(), sprite_size.x), 
		min(sprite_image.get_height(), sprite_size.y))
	
	atlas_image.blit_rect(sprite_image, src_rect, dest_pos)

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

func _get_target_node() -> Node:
	if not target_node_path.is_empty() and has_node(target_node_path):
		return get_node(target_node_path)
	return get_parent()

func _target_has_moving_state(target: Node) -> bool:
	if target.get("moving_state") != null:
		return true
	
	if target.get_script() != null:
		var script_properties = target.get_script().get_script_property_list()
		return script_properties.any(func(prop): return prop.name == "moving_state")
	
	return false

#endregion




