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
		# Regenerate atlas if sprites are present; otherwise ensure uniforms are updated
		call_deferred("_generate_atlas_if_ready")
		# Always refresh shader uniforms after direction mode changes so parameters like
		# `direction_count` and `direction_mode` stay in sync even when using a manually
		# assigned atlas texture.
		call_deferred("_update_shader_uniforms")

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

# Atlas and texture management
var atlas_texture: ImageTexture
var current_sprite_texture: ImageTexture

#endregion

#region Initialization

func _ready():
	_initialize_sprite_dictionaries()
	_update_moving_state()
	# Set up shader material if needed
	if material_override is ShaderMaterial:
		directional_material = material_override
	if directional_material == null and (_has_any_sprites() or atlas_texture != null):
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

	if prop_name == "atlas_preview":
		return atlas_texture

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

	# Add atlas preview property (read-only)
	properties.append({
		"name": "Atlas Preview",
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP,
	})

	properties.append({
		"name": "atlas_preview",
		"type": TYPE_OBJECT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE,
		"hint_string": "Texture2D",
		"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY
	})

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
	atlas_texture = _create_atlas_texture(all_sprites, atlas_dimensions, sprite_size)

	if atlas_texture:
		# Create properly sized current sprite texture
		_update_current_sprite_texture(sprite_size)
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
			# Only clear texture if it was generated by us (not manually set)
			# We can detect this by checking if we have individual sprites but no texture
			# If there's a texture but no individual sprites, it was manually set
			if texture != null and not _has_any_sprites():
				# This is a manually set texture; make sure shader material and uniforms are up to date.
				if directional_material == null:
					_setup_shader_material()
				# Even if the material already exists, ensure its parameters reflect any changes
				# to direction mode or billboard settings.
				call_deferred("_update_shader_uniforms")
			else:
				# No sprites and no texture, clear everything
				texture = null
				atlas_texture = null
				current_sprite_texture = null
				# Reset to default material when no sprites
				if directional_material != null:
					material_override = null
					directional_material = null

## Create a properly sized texture for the current sprite selection
## This texture has the maximum dimensions of all sprites but shows only the selected sprite
func _update_current_sprite_texture(sprite_size: Vector2i):
	if sprite_size == Vector2i.ZERO:
		current_sprite_texture = null
		texture = null
		return

	# Create a texture with the proper size (max dimensions of all sprites)
	var current_image = Image.create(sprite_size.x, sprite_size.y, false, Image.FORMAT_RGBA8)
	current_image.fill(Color.TRANSPARENT)

	# Get the current sprite to display
	var current_sprite = _get_current_display_sprite()
	if current_sprite != null:
		var sprite_image = current_sprite.get_image()
		if sprite_image != null:
			# Handle compressed textures
			if sprite_image.is_compressed():
				sprite_image.decompress()

			# Convert to proper format
			if sprite_image.get_format() != Image.FORMAT_RGBA8:
				sprite_image.convert(Image.FORMAT_RGBA8)

			# Center the sprite in the properly sized canvas
			var actual_width = sprite_image.get_width()
			var actual_height = sprite_image.get_height()
			var offset_x = (sprite_size.x - actual_width) / 2
			var offset_y = (sprite_size.y - actual_height) / 2

			# Blit the sprite centered in the canvas
			current_image.blit_rect(sprite_image, Rect2i(0, 0, actual_width, actual_height), Vector2i(offset_x, offset_y))

	# Create the texture
	current_sprite_texture = ImageTexture.new()
	current_sprite_texture.set_image(current_image)
	texture = current_sprite_texture

## Get the sprite that should currently be displayed based on direction and movement state
func _get_current_display_sprite() -> Texture2D:
	var directions = _get_current_directions()
	if directions.is_empty():
		return null

	# Use the first direction as default, or current_direction if it's valid
	var display_direction = directions[0]
	if current_direction in directions:
		display_direction = current_direction

	# Prefer movement sprite if moving and available, otherwise use idle
	if is_moving and has_moving_state:
		var movement_sprites_array = movement_sprites.get(display_direction, [])
		if movement_sprites_array.size() > 0 and movement_sprites_array[0] != null:
			return movement_sprites_array[0] # Use first movement frame

	# Fall back to idle sprite
	var idle_sprite = idle_sprites.get(display_direction)
	if idle_sprite is Texture2D:
		return idle_sprite

	return null

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
	# Only set up shader material if we have an atlas texture
	if atlas_texture == null:
		return

	# Re-use a material the user already assigned in the editor so that any
	# parameters tweaked from the Inspector carry over to the running game.
	if material_override is ShaderMaterial:
		directional_material = material_override
		# Check if it's using our shader, if not, don't override it
		var shader_path = "res://scenes/components/directional_sprite_3d/directional_sprite_3d.gdshader"
		if directional_material.shader == null or directional_material.shader.resource_path != shader_path:
			# This is a different shader material, don't interfere with it
			return
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

	# Calculate current direction for display texture updates
	var camera = get_viewport().get_camera_3d()
	var new_direction = current_direction
	if camera != null:
		new_direction = _calculate_camera_direction(camera, target_node)

	# Update if movement state or direction changed
	var state_changed = new_moving_state != is_moving
	var direction_changed = new_direction != current_direction

	if state_changed or direction_changed:
		is_moving = new_moving_state
		current_direction = new_direction
		_update_shader_uniforms()
		# Update the display texture to show the correct sprite
		if atlas_texture != null:
			var sprite_size = get_atlas_frame_size()
			_update_current_sprite_texture(sprite_size)

func _calculate_camera_direction(camera: Camera3D, target: Node3D) -> String:
	# Calculate direction vector from target to camera
	var direction_to_camera = target.global_position.direction_to(camera.global_position)

	# Get target's transform basis for local direction calculation
	var target_basis = target.global_transform.basis
	var forward = target_basis.z # Local forward direction
	var right = target_basis.x # Local right direction

	# Calculate dot products for direction determination
	var forward_dot = forward.dot(direction_to_camera)
	var right_dot = right.dot(direction_to_camera)

	# Determine direction based on current mode
	match direction_mode:
		DirectionMode.THREE_DIRECTIONS:
			if forward_dot < -0.5:
				return "front" # Camera is in front of target
			elif forward_dot > 0.5:
				return "back" # Camera is behind target
			else:
				return "side" # Camera is to the side

		DirectionMode.FOUR_DIRECTIONS:
			if forward_dot < -0.5:
				return "front"
			elif forward_dot > 0.5:
				return "back"
			elif right_dot > 0.0:
				return "right"
			else:
				return "left"

		DirectionMode.FIVE_DIRECTIONS:
			if forward_dot < -0.5:
				return "front"
			elif forward_dot > 0.5:
				return "back"
			else:
				# Side directions - check if it's more front-side or back-side
				if forward_dot < 0.0:
					return "front_side"
				else:
					return "back_side"

		DirectionMode.EIGHT_DIRECTIONS:
			# Use 8-direction calculation with 45-degree sectors
			var angle = atan2(right_dot, -forward_dot)

			# Convert angle to 0-2π range
			if angle < 0.0:
				angle += 2.0 * PI

			# Determine direction based on angle (8 sectors of 45 degrees each)
			var sector = angle / (PI / 4.0)
			var direction_index = int(sector + 0.5) % 8

			# Map to direction names
			match direction_index:
				0, 7:
					return "front"
				1:
					return "front_left"
				2:
					return "left"
				3:
					return "back_left"
				4:
					return "back"
				5:
					return "back_right"
				6:
					return "right"
				_:
					return "front_right"

		_:
			# Default fallback
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
	if directional_material == null or atlas_texture == null:
		return

	# Set atlas texture (use the generated atlas, not the display texture)
	directional_material.set_shader_parameter("atlas_texture", atlas_texture)

	# Calculate atlas dimensions and frame size
	var atlas_size = Vector2(atlas_texture.get_width(), atlas_texture.get_height())
	var frame_size = get_atlas_frame_size()

	if frame_size != Vector2i.ZERO and atlas_size != Vector2.ZERO:
		directional_material.set_shader_parameter("atlas_dimensions", atlas_size)
		directional_material.set_shader_parameter("frame_size", Vector2(frame_size))

		# Set direction count
		var directions = _get_current_directions()
		directional_material.set_shader_parameter("direction_count", directions.size())

		# Set direction mode for shader (only if the shader supports it)
		if directional_material.shader != null and directional_material.shader.resource_path == "res://scenes/components/directional_sprite_3d/directional_sprite_3d.gdshader":
			directional_material.set_shader_parameter("direction_mode", int(direction_mode))

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
	# THREE_DIRECTIONS and FIVE_DIRECTIONS modes use horizontal flipping for side directions
	# FOUR_DIRECTIONS and EIGHT_DIRECTIONS have dedicated sprites for each direction
	var uses_flipping = (direction_mode == DirectionMode.THREE_DIRECTIONS and current_direction == "side") or \
						(direction_mode == DirectionMode.FIVE_DIRECTIONS and (current_direction == "front_side" or current_direction == "back_side"))

	if not uses_flipping:
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
