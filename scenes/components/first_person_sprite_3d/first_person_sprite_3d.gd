@tool
class_name FirstPersonSprite3D extends Sprite3D

## First-person Sprite3D with FOV control and wall clipping prevention
## Works with the weapon_clip_and_fov_shader for any first-person sprite elements
## Automatically syncs with Sprite3D properties like texture, shaded, alpha_cut, etc.

@export var sprite_fov: float = 85.0
@export var sprite_distance: float = 0.5
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var clip_prevention: float = 0.9
@export var lighting_influence: float = 1.0

var sprite_material: ShaderMaterial

# Override render_priority to sync with shader material
var _render_priority: int = 0:
	set(value):
		_render_priority = value
		render_priority = value
		sync_render_priority()
	get:
		return _render_priority

func _enter_tree():
	# Ensure material/uniforms are set both in editor and at runtime
	setup_sprite_shader()

func _ready():
	setup_sprite_shader()
	
	# Connect to property changes to auto-sync shader parameters
	if not is_connected("texture_changed", _on_sprite3d_property_changed):
		texture_changed.connect(_on_sprite3d_property_changed)


func _on_sprite3d_property_changed():
	"""Called when Sprite3D properties change to keep shader in sync"""
	sync_sprite3d_properties()


func setup_sprite_shader():
	"""Set up the shader material with automatic Sprite3D property synchronization"""
	
	# Ensure a ShaderMaterial is already assigned to this Sprite3D
	if not (material_override is ShaderMaterial):
		return
	# Use the assigned material as our sprite material
	sprite_material = material_override
	# Bail if the material has no shader attached
	if sprite_material.shader == null:
		return

	
	# Configure Sprite3D properties for first-person sprites
	billboard = BaseMaterial3D.BILLBOARD_DISABLED # Keep sprite oriented properly
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD # Handle transparency
	no_depth_test = false # We want depth testing for proper 3D integration
	
	# Apply material to the Sprite3D
	material_override = sprite_material
	
	# Sync shader parameters with Sprite3D properties
	sync_sprite3d_properties()
	
	# Configure sprite-specific shader parameters
	sprite_material.set_shader_parameter("viewmodel_fov", sprite_fov)
	sprite_material.set_shader_parameter("weapon_distance", sprite_distance)
	sprite_material.set_shader_parameter("weapon_offset", sprite_offset)
	sprite_material.set_shader_parameter("clip_prevention_strength", clip_prevention)
	sprite_material.set_shader_parameter("enable_depth_override", true)
	sprite_material.set_shader_parameter("lighting_influence", lighting_influence)
	
	# Ensure render priority is properly applied
	sync_render_priority()


func sync_sprite3d_properties():
	"""Synchronize shader parameters with Sprite3D built-in properties"""
	if not sprite_material:
		return
	
	# Automatically use Sprite3D's texture property
	sprite_material.set_shader_parameter("texture_albedo", texture)
	# Inform shader whether a texture is actually bound (prevents white quads in editor)
	sprite_material.set_shader_parameter("has_texture", texture != null)
	
	# Sync alpha cut properties
	sprite_material.set_shader_parameter("alpha_cut", float(alpha_cut))
	# Note: alpha_cut_threshold is not a Sprite3D property, so we use a default value
	sprite_material.set_shader_parameter("alpha_cut_threshold", 0.5)
	
	# Sync shaded property
	sprite_material.set_shader_parameter("use_sprite3d_shaded", shaded)
	
	# Sync texture filter mode
	var filter_mode = 1 # Default to linear
	match texture_filter:
		BaseMaterial3D.TEXTURE_FILTER_NEAREST:
			filter_mode = 0
		BaseMaterial3D.TEXTURE_FILTER_LINEAR:
			filter_mode = 1
		BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS:
			filter_mode = 2
		BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
			filter_mode = 3
		BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC:
			filter_mode = 4
		BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC:
			filter_mode = 5
	sprite_material.set_shader_parameter("texture_filter_mode", filter_mode)


func sync_render_priority():
	"""Synchronize render priority with the shader material"""
	if sprite_material:
		sprite_material.render_priority = render_priority


func update_sprite_fov(new_fov: float):
	"""Update the sprite FOV at runtime"""
	sprite_fov = new_fov
	if sprite_material:
		sprite_material.set_shader_parameter("viewmodel_fov", sprite_fov)


func update_sprite_position(pos_offset: Vector2, distance: float):
	"""Update sprite positioning at runtime"""
	sprite_offset = pos_offset
	sprite_distance = distance
	if sprite_material:
		sprite_material.set_shader_parameter("weapon_offset", sprite_offset)
		sprite_material.set_shader_parameter("weapon_distance", sprite_distance)


func set_lighting_influence(influence: float):
	"""Control how much 3D environmental lighting affects the sprite"""
	lighting_influence = clamp(influence, 0.0, 1.0)
	if sprite_material:
		sprite_material.set_shader_parameter("lighting_influence", lighting_influence)


func set_clip_prevention(strength: float):
	"""Adjust wall clipping prevention strength"""
	clip_prevention = clamp(strength, 0.0, 1.0)
	if sprite_material:
		sprite_material.set_shader_parameter("clip_prevention_strength", clip_prevention)
