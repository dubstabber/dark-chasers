@tool
class_name DirectionalSprite3D
extends Sprite3D

enum DirectionMode {
	THREE_DIRECTIONS, ## front, side, back
	FOUR_DIRECTIONS, ## front, left, right, back
	FIVE_DIRECTIONS, ## front, side, back, front-side, back-side
	EIGHT_DIRECTIONS, ## front, left, right, back, front-left, front-right, back-left, back-right
}

const IDLE_SUFFIX = "_idle_sprite"
const MOVEMENT_SUFFIX = "_movement_sprites"
const SHOOTING_SUFFIX = "_shooting_sprites"

# Static atlas cache: signature -> {texture: ImageTexture, max_sprite_size: Vector2i}
static var _atlas_cache: Dictionary = {}

# Direction definitions for each mode
const DIRECTION_SETS = {
	DirectionMode.THREE_DIRECTIONS: ["front", "side", "back"],
	DirectionMode.FOUR_DIRECTIONS: ["front", "left", "right", "back"],
	DirectionMode.FIVE_DIRECTIONS: ["front", "side", "back", "front_side", "back_side"],
	DirectionMode.EIGHT_DIRECTIONS: ["front", "left", "right", "back", "front_left", "front_right", "back_left", "back_right"]
}

#region Internal Variables

var has_moving_state := false
var has_shooting_state := false
var idle_sprites := {}
var movement_sprites := {}
var shooting_sprites := {}
var atlas_texture: Texture2D
var _atlas_generation_pending := false

# Shader material for directional rendering
var directional_material: ShaderMaterial

# Cached references
var _state_node: Node = null # Node providing moving_state/shooting_state
var _position_node: Node3D = null # Node3D for global_position (shader target)

#endregion


# Alpha cut mode: 0 Disabled,1 Discard,2 Opaque Pre-Pass,3 Alpha Hash
@export_enum("Disabled", "Discard", "Opaque Pre-Pass", "Alpha Hash") var sprite_alpha_cut_mode: int = 0:
	set(value):
		sprite_alpha_cut_mode = value
		if directional_material:
			directional_material.set_shader_parameter("alpha_cut_mode", sprite_alpha_cut_mode)
			directional_material.set_shader_parameter("shaded_enabled", 1 if self.shaded else 0)

# Alpha cut threshold for Discard/Pre-Pass
@export_range(0.0, 1.0, 0.01) var alpha_cut_threshold: float = 0.5:
	set(value):
		alpha_cut_threshold = value
		if directional_material:
			directional_material.set_shader_parameter("alpha_cut_threshold", alpha_cut_threshold)
			directional_material.set_shader_parameter("shaded_enabled", 1 if self.shaded else 0)
			directional_material.set_shader_parameter("shaded_enabled", 1 if self.shaded else 0)


@export var target_node_path: NodePath = NodePath(""):
	set(value):
		target_node_path = value
		if is_inside_tree():
			_update_node_references()
			_request_atlas_generation()
			notify_property_list_changed()

@export var direction_mode: DirectionMode = DirectionMode.THREE_DIRECTIONS:
	set(value):
		direction_mode = value
		_request_atlas_generation()
		notify_property_list_changed()

@export var debug_mode: bool = false:
	set(value):
		debug_mode = value
		if directional_material:
			directional_material.set_shader_parameter("debug_mode", debug_mode)


func _ready() -> void:
	_update_node_references()
	
	# Validate that material_override has a shader attached
	if not (material_override is ShaderMaterial and material_override.shader is Shader):
		push_error("DirectionalSprite3D: material_override must be a ShaderMaterial with a valid shader attached.")
		return
	
	# At runtime, create a fresh material to avoid stale SubResource issues
	# The saved material in scene files may have outdated shader parameters
	if not Engine.is_editor_hint():
		var saved_shader = material_override.shader
		directional_material = ShaderMaterial.new()
		directional_material.shader = saved_shader
		material_override = directional_material
	else:
		directional_material = material_override
	
	directional_material.set_shader_parameter("alpha_cut_mode", self.alpha_cut)
	directional_material.set_shader_parameter("alpha_cut_threshold", self.alpha_cut_threshold)
	directional_material.render_priority = self.render_priority
	
	# Generate atlas after material is set up - this ensures correct shader parameters
	# even if scene was saved with stale values
	_atlas_generation_pending = false # Cancel any pending deferred calls
	generate_atlas()


func _process(_delta: float) -> void:
	# Update per-frame shader parameters
	if directional_material and directional_material.shader:
		# Use _position_node (Node3D) for global_position, not the state node
		if _position_node:
			directional_material.set_shader_parameter("target_position", _position_node.global_position)
		
		# Synchronise shader parameters each frame
		directional_material.set_shader_parameter("alpha_cut_mode", self.alpha_cut)
		directional_material.set_shader_parameter("alpha_cut_threshold", self.alpha_cut_threshold)
		directional_material.render_priority = self.render_priority


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
	
	if prop_name.ends_with(SHOOTING_SUFFIX):
		var direction = prop_name.replace(SHOOTING_SUFFIX, "")
		if not shooting_sprites.has(direction):
			shooting_sprites[direction] = []
		return shooting_sprites[direction]
	
	return null


func _set(property: StringName, value) -> bool:
	var prop_name = str(property)
	
	if prop_name == "billboard":
		if directional_material:
			directional_material.set_shader_parameter("billboard_mode", value)
	
	if prop_name == "render_priority":
		if directional_material:
			directional_material.render_priority = value


	if prop_name.ends_with(IDLE_SUFFIX):
		var direction = prop_name.replace(IDLE_SUFFIX, "")
		if direction in _get_current_directions():
			idle_sprites[direction] = value
			_request_atlas_generation()
			return true
	
	if prop_name.ends_with(MOVEMENT_SUFFIX):
		var direction = prop_name.replace(MOVEMENT_SUFFIX, "")
		if direction in _get_current_directions():
			movement_sprites[direction] = value
			_request_atlas_generation()
			return true
	
	if prop_name.ends_with(SHOOTING_SUFFIX):
		var direction = prop_name.replace(SHOOTING_SUFFIX, "")
		if direction in _get_current_directions():
			shooting_sprites[direction] = value
			_request_atlas_generation()
			return true
	
	return false


func _request_atlas_generation() -> void:
	"""Defer atlas generation to batch multiple property changes."""
	if _atlas_generation_pending:
		return
	_atlas_generation_pending = true
	call_deferred("_do_deferred_atlas_generation")


func _do_deferred_atlas_generation() -> void:
	_atlas_generation_pending = false
	generate_atlas()


func _get_property_list():
	var properties: Array[Dictionary] = []
	var directions = _get_current_directions()
	
	_add_sprite_group_properties(properties, "Idle sprites", directions, IDLE_SUFFIX, TYPE_OBJECT, "Texture2D")
	
	if has_moving_state:
		_add_sprite_group_properties(properties, "Movement sprites", directions, MOVEMENT_SUFFIX, TYPE_ARRAY, "%d/%d:Texture2D" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE])
	
	if has_shooting_state:
		_add_sprite_group_properties(properties, "Shooting sprites", directions, SHOOTING_SUFFIX, TYPE_ARRAY, "%d/%d:Texture2D" % [TYPE_OBJECT, PROPERTY_HINT_RESOURCE_TYPE])
	
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


func _update_node_references() -> void:
	"""Update cached node references for state and position tracking.
	
	Separates concerns:
	- _state_node: Node that provides moving_state/shooting_state (set via target_node_path)
	- _position_node: Always uses scene owner (root node) - must be Node3D
	
	This means the sprite can be placed anywhere in the scene hierarchy,
	and position tracking will always use the scene root (e.g., Player, Enemy).
	"""
	# Get state node from target_node_path or parent
	if not target_node_path.is_empty() and has_node(target_node_path):
		_state_node = get_node(target_node_path)
	else:
		_state_node = get_parent()
	
	# Check for state properties on state node
	if _state_node and _state_node.get_script():
		var script_properties = _state_node.get_script().get_script_property_list()
		has_moving_state = script_properties.any(func(prop): return prop.name == "moving_state")
		has_shooting_state = script_properties.any(func(prop): return prop.name == "shooting_state")
	else:
		has_moving_state = false
		has_shooting_state = false
	
	# Position node is the scene owner (root node) or parent as fallback
	# This ensures consistent behavior regardless of where the sprite is placed
	if not is_inside_tree():
		_position_node = null
		return
	
	var position_candidate = owner if owner else get_parent()
	if position_candidate and position_candidate is Node3D:
		_position_node = position_candidate
	else:
		# Fallback: walk up the tree to find a Node3D
		var node = get_parent()
		while node:
			if node is Node3D:
				_position_node = node
				break
			node = node.get_parent() if node.get_parent() else null
	
	if not _position_node:
		push_warning("DirectionalSprite3D: No Node3D found for position tracking. owner=%s, parent=%s" % [owner, get_parent()])


func _get_target_node() -> Node:
	"""Get the state node (for backward compatibility with atlas generation)."""
	return _state_node


func _get_current_sprite_state(target_node: Node) -> int:
	"""Get the current sprite state for the target node.
	Returns 0 for idle states, 1 for movement states, 2 for shooting states."""

	if not target_node:
		return 0

	# Check for shooting state first (highest priority)
	if "shooting_state" in target_node and target_node.shooting_state != "":
		return 2

	# Check for movement state
	if "moving_state" in target_node:
		var state = target_node.moving_state
		# Movement states that should return 1
		if state in ["run", "moving", "move", "walk", "sprint"]:
			return 1

	# Default to idle state
	return 0


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
	
	# Check cache first
	var signature = _compute_sprite_set_signature(directions)
	var max_sprite_size: Vector2i
	
	if signature in _atlas_cache:
		var cached = _atlas_cache[signature]
		atlas_texture = cached.texture
		max_sprite_size = cached.max_sprite_size
	else:
		# Collect sprites and determine dimensions
		var all_sprites: Array[Array] = []
		max_sprite_size = _get_sprite_max_dimensions(directions)
		var max_frames = 1
		
		# Collect all sprites for each direction
		for direction in directions:
			var direction_sprites = _collect_direction_sprites(direction)
			all_sprites.append([direction, direction_sprites])
			max_frames = max(max_frames, direction_sprites.size())
		
		# Create and populate atlas
		var atlas_dimensions = Vector2i(max_sprite_size.x * max_frames, max_sprite_size.y * directions.size())
		atlas_texture = _create_atlas_texture(all_sprites, atlas_dimensions, max_sprite_size)
		
		# Store in cache
		if atlas_texture:
			_atlas_cache[signature] = {"texture": atlas_texture, "max_sprite_size": max_sprite_size}
	
	if atlas_texture:
		# Create properly sized current sprite texture
		#_update_current_sprite_texture(sprite_size)
		# Update shader uniforms when atlas changes
		#call_deferred("_update_shader_uniforms")
		var image = Image.create(max_sprite_size.x, max_sprite_size.y, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		texture = ImageTexture.create_from_image(image)
		
		# Ensure we have the shader material set up
		if not directional_material:
			push_error("DirectionalSprite3D: directional_material not initialized. Ensure material_override has a valid shader.")
			return
		
		if directional_material and directional_material.shader:
			var atlas_size = Vector2(atlas_texture.get_width(), atlas_texture.get_height())
			directional_material.set_shader_parameter("atlas_texture", atlas_texture)
			directional_material.set_shader_parameter("billboard_mode", billboard)
			directional_material.set_shader_parameter("atlas_dimensions", atlas_size)
			directional_material.set_shader_parameter("max_sprite_size", Vector2(max_sprite_size))
			directional_material.set_shader_parameter("direction_mode", direction_mode)
			directional_material.set_shader_parameter("alpha_cut_mode", self.alpha_cut)
			directional_material.set_shader_parameter("alpha_cut_threshold", self.alpha_cut_threshold)
			directional_material.render_priority = self.render_priority
			directional_material.set_shader_parameter("debug_mode", debug_mode)
			# Target position will be updated in _process

		notify_property_list_changed()


func _compute_sprite_set_signature(directions: Array) -> String:
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
	
	# Check shooting sprites
	for direction in shooting_sprites:
		var sprite_array = shooting_sprites[direction]
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
		
		# Check shooting sprites
		var shooting_sprites_array = shooting_sprites.get(direction, [])
		for sprite in shooting_sprites_array:
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
	
	# Add shooting sprites
	var shooting_sprite_array = shooting_sprites.get(direction, [])
	if shooting_sprite_array is Array:
		for sprite in shooting_sprite_array:
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
