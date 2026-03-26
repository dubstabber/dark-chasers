@tool
class_name ProceduralOverlayIndicator
extends MeshInstance3D

const SHADER_PATH := "res://shaders/procedural_direction_overlay.gdshader"

@export var world_size: Vector2 = Vector2(2.2, 0.9):
	set(value):
		world_size = Vector2(maxf(value.x, 0.01), maxf(value.y, 0.01))
		_rebuild_quad()

@export var use_default_arrow_shape := true:
	set(value):
		use_default_arrow_shape = value
		_apply_shape()

@export var custom_shape_points: PackedVector2Array = PackedVector2Array():
	set(value):
		custom_shape_points = value
		_apply_shape()

@export_group("Visual")
@export var base_color: Color = Color(1.0, 1.0, 1.0, 1.0):
	set(value):
		base_color = value
		_set_shader_param("base_color", base_color)

@export_range(0.0, 1.0, 0.01) var opacity := 0.45:
	set(value):
		opacity = value
		_set_shader_param("opacity", opacity)

@export_range(0.001, 0.4, 0.001) var edge_softness := 0.08:
	set(value):
		edge_softness = value
		_set_shader_param("edge_softness", edge_softness)

@export_range(0.0, 2.0, 0.01) var center_falloff := 0.25:
	set(value):
		center_falloff = value
		_set_shader_param("center_falloff", center_falloff)

@export_range(0.0, 5.0, 0.01) var glow_boost := 1.8:
	set(value):
		glow_boost = value
		_set_shader_param("glow_boost", glow_boost)

@export_group("Motion")
@export_range(0.0, 1.0, 0.01) var scanline_strength := 0.35:
	set(value):
		scanline_strength = value
		_set_shader_param("scanline_strength", scanline_strength)

@export_range(1.0, 120.0, 0.1) var scanline_density := 40.0:
	set(value):
		scanline_density = value
		_set_shader_param("scanline_density", scanline_density)

@export_range(-4.0, 4.0, 0.01) var drift_speed := 0.45:
	set(value):
		drift_speed = value
		_set_shader_param("drift_speed", drift_speed)

@export_group("Shape Transform")
@export var shape_scale: Vector2 = Vector2.ONE:
	set(value):
		shape_scale = value
		_set_shader_param("shape_scale", shape_scale)

@export var shape_offset: Vector2 = Vector2.ZERO:
	set(value):
		shape_offset = value
		_set_shader_param("shape_offset", shape_offset)

@export_range(-PI, PI, 0.001) var shape_rotation := 0.0:
	set(value):
		shape_rotation = value
		_set_shader_param("shape_rotation", shape_rotation)

var _shader_material: ShaderMaterial


func _ready() -> void:
	_ensure_material()
	_rebuild_quad()
	_apply_visual_uniforms()
	_apply_shape()


func _ensure_material() -> void:
	if material_override is ShaderMaterial and (material_override as ShaderMaterial).shader:
		_shader_material = material_override as ShaderMaterial
		return

	var shader := load(SHADER_PATH) as Shader
	if shader == null:
		push_error("ProceduralOverlayIndicator: Failed to load shader at %s." % SHADER_PATH)
		return

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	material_override = _shader_material


func _rebuild_quad() -> void:
	var quad := QuadMesh.new()
	quad.size = world_size
	mesh = quad


func _apply_shape() -> void:
	if not _shader_material:
		_ensure_material()
	if not _shader_material:
		return

	if use_default_arrow_shape:
		ProceduralOverlayShapeHelper.apply_default_arrow(_shader_material)
	else:
		ProceduralOverlayShapeHelper.apply_polygon(_shader_material, custom_shape_points)


func _apply_visual_uniforms() -> void:
	_set_shader_param("base_color", base_color)
	_set_shader_param("opacity", opacity)
	_set_shader_param("edge_softness", edge_softness)
	_set_shader_param("center_falloff", center_falloff)
	_set_shader_param("glow_boost", glow_boost)
	_set_shader_param("scanline_strength", scanline_strength)
	_set_shader_param("scanline_density", scanline_density)
	_set_shader_param("drift_speed", drift_speed)
	_set_shader_param("shape_scale", shape_scale)
	_set_shader_param("shape_offset", shape_offset)
	_set_shader_param("shape_rotation", shape_rotation)


func _set_shader_param(param_name: StringName, value: Variant) -> void:
	if not _shader_material:
		_ensure_material()
	if not _shader_material:
		return
	_shader_material.set_shader_parameter(param_name, value)
