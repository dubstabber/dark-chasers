@tool
class_name DirectionalSprite3D
extends Sprite3D

const DirectionalAtlasGeneratorScript = preload("res://scenes/components/directional_sprite_3d/directional_atlas_generator.gd")

enum DirectionMode {
	THREE_DIRECTIONS, ## front, side, back
	FOUR_DIRECTIONS, ## front, left, right, back
	FIVE_DIRECTIONS, ## front, side, back, front-side, back-side
	EIGHT_DIRECTIONS, ## front, left, right, back, front-left, front-right, back-left, back-right
}

const IDLE_SUFFIX = "_idle_sprite"
const MOVEMENT_SUFFIX = "_movement_sprites"
const SHOOTING_SUFFIX = "_shooting_sprites"


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
		# target_position is now calculated from MODEL_MATRIX in shader (per-instance)
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
	"""Update cached node references for state tracking.
	
	_state_node: Node that provides moving_state/shooting_state (set via target_node_path)
	
	Note: Position for direction calculation is now handled per-instance in the shader
	using MODEL_MATRIX, so no position node tracking is needed.
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


func _get_target_node() -> Node:
	"""Get the state node (for backward compatibility with atlas generation)."""
	return _state_node


func _get_current_sprite_state(target_node: Node) -> int:
	"""Get the current sprite state for the target node.
	Returns 0 for idle states, 1 for movement states, 2 for shooting states."""

	if not target_node:
		return 0

	# Use AnimationStateProvider interface for typed state access
	return AnimationStateProvider.get_state_priority(target_node)


func generate_atlas():
	var directions = _get_current_directions()
	var result = DirectionalAtlasGeneratorScript.generate(
		direction_mode,
		directions,
		idle_sprites,
		movement_sprites,
		shooting_sprites
	)
	
	atlas_texture = result.texture
	var max_sprite_size: Vector2i = result.max_sprite_size
	
	if not atlas_texture:
		return
	
	# Create properly sized current sprite texture
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

	notify_property_list_changed()
