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

# Direction and animation state
var current_direction: String = "front"
var current_frame: int = 0
var is_moving: bool = false

# Shader material for directional rendering
var directional_material: ShaderMaterial

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
	
	# Validate sprite dimensions before proceeding
	if not _validate_sprite_dimensions(directions):
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
		# Update shader uniforms when atlas changes
		call_deferred("_update_shader_uniforms")

	return atlas_texture

func _generate_atlas_if_ready():
	if is_inside_tree():
		if _has_any_sprites():
			generate_atlas()
			# Ensure shader material is set up
			if directional_material == null:
				_setup_shader_material()
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
	
	# Get actual sprite dimensions
	var actual_width = sprite_image.get_width()
	var actual_height = sprite_image.get_height()
	
	# Calculate atlas cell position
	var cell_pos = Vector2i(col * sprite_size.x, row * sprite_size.y)
	
	# Center the sprite within the atlas cell if it's smaller
	var offset_x = (sprite_size.x - actual_width) / 2.0
	var offset_y = (sprite_size.y - actual_height) / 2.0
	var dest_pos = Vector2i(cell_pos.x + offset_x, cell_pos.y + offset_y)
	
	# Ensure we don't exceed atlas cell boundaries
	var blit_width = min(actual_width, sprite_size.x)
	var blit_height = min(actual_height, sprite_size.y)
	var src_rect = Rect2i(0, 0, blit_width, blit_height)
	
	# Adjust destination if sprite is larger than cell (crop from center)
	if actual_width > sprite_size.x or actual_height > sprite_size.y:
		var crop_offset_x = (actual_width - sprite_size.x)
		var crop_offset_y = (actual_height - sprite_size.y)
		src_rect = Rect2i(crop_offset_x, crop_offset_y, sprite_size.x, sprite_size.y)
		dest_pos = cell_pos
	
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

	if frame_size != Vector2i.ZERO:
		directional_material.set_shader_parameter("atlas_dimensions", atlas_size)
		directional_material.set_shader_parameter("frame_size", Vector2(frame_size))

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
