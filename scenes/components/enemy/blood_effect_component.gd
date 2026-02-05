class_name BloodEffectComponent
extends Node

signal blood_splattered(position: Vector3)
signal blood_decal_spawned(position: Vector3, normal: Vector3)

@export_group("Settings")
@export var enabled: bool = true
@export var blood_color: Color = Color(1.0, 0.0, 0.0, 1.0)
@export var particle_scene: PackedScene
@export var decal_scene: PackedScene

@export_group("Physics")
@export var upward_velocity: float = 0.5
@export var z_offset_range: float = 0.1
@export var surface_offset: float = 0.01
@export var trace_distance: float = 5.4

@export_group("Noise")
@export var trace_noise_low: float = 0.15
@export var trace_noise_med: float = 0.18
@export var trace_noise_high: float = 0.20

var _owner_node: Node3D = null


func _ready() -> void:
	_owner_node = owner as Node3D


func spawn_splatter(hit_pos: Vector3, shot_direction: Vector3 = Vector3.ZERO) -> void:
	if not enabled or not particle_scene:
		return
	
	var particle := particle_scene.instantiate()
	get_tree().root.add_child(particle)
	
	var offset := Vector3.ZERO
	if shot_direction.length_squared() > 0.01:
		offset = - shot_direction.normalized() * surface_offset
	
	var y_offset = randf_range(-z_offset_range, z_offset_range)
	particle.global_position = hit_pos + offset + Vector3(0, y_offset, 0)
	particle.linear_velocity = Vector3(0, upward_velocity, 0)
	
	# Apply blood color using BloodColorable interface
	if not BloodColorable.set_color(particle, blood_color):
		# Fallback: manually set shader parameter on sprite
		var sprite := particle.get_node_or_null("AnimatedSprite3D") as AnimatedSprite3D
		if sprite and sprite.material_override:
			# Duplicate material to avoid affecting other instances
			sprite.material_override = sprite.material_override.duplicate()
			sprite.material_override.set_shader_parameter("blood_color", blood_color)
	
	blood_splattered.emit(hit_pos)


func trace_to_walls(damage: int, hit_pos: Vector3, shot_direction: Vector3) -> void:
	if not enabled or not decal_scene:
		return
	
	var decal_count: int
	var noise: float
	
	if damage < 15:
		if damage <= 10:
			if randi() % 256 < 160:
				return
		decal_count = 1
		noise = trace_noise_low
	elif damage < 25:
		decal_count = 2
		noise = trace_noise_med
	else:
		if randi() % 256 < 24:
			decal_count = 1
			noise = trace_noise_high
		else:
			decal_count = 3
			noise = trace_noise_high
	
	for i in range(decal_count):
		_trace_single_ray(hit_pos, shot_direction, noise)


func _trace_single_ray(hit_pos: Vector3, shot_direction: Vector3, noise: float) -> void:
	var noisy_direction = shot_direction
	noisy_direction = noisy_direction.rotated(Vector3.UP, randf_range(-noise, noise))
	noisy_direction = noisy_direction.rotated(Vector3.RIGHT, randf_range(-noise, noise))
	noisy_direction = noisy_direction.normalized()
	
	var space_state = _owner_node.get_world_3d().direct_space_state
	var ray_end = hit_pos + noisy_direction * trace_distance
	
	var query = PhysicsRayQueryParameters3D.create(hit_pos, ray_end)
	if _owner_node:
		query.exclude = [_owner_node]
	query.collision_mask = 4 # Walls layer (layer 3)
	
	var result = space_state.intersect_ray(query)
	
	if result and not result.collider.is_in_group("entity") and not result.collider.is_in_group("no_decals"):
		if _is_wall_surface(result.normal):
			_spawn_decal(result.position, result.normal, result.collider)


func _is_wall_surface(normal: Vector3) -> bool:
	return abs(normal.y) < 0.7


func _spawn_decal(hit_pos: Vector3, hit_normal: Vector3, collider: Node3D) -> void:
	var decal := decal_scene.instantiate()
	collider.add_child(decal)
	
	decal.global_position = hit_pos + hit_normal * (decal.size.y * 0.05)
	decal.global_transform.basis = _calculate_decal_rotation(hit_normal)
	
	# Apply blood color using BloodColorable interface
	if not BloodColorable.set_color(decal, blood_color):
		# Fallback: use modulate for decals without the interface
		decal.modulate = Color(blood_color.r * 0.5, blood_color.g * 0.5, blood_color.b * 0.5, 1.0)
	
	blood_decal_spawned.emit(hit_pos, hit_normal)


func _calculate_decal_rotation(normal: Vector3) -> Basis:
	var forward = Vector3.FORWARD
	
	if abs(normal.dot(forward)) > 0.99:
		forward = Vector3.RIGHT
	
	var right_vector = forward.cross(normal).normalized()
	var forward_vector = normal.cross(right_vector).normalized()
	
	return Basis(right_vector, -normal, forward_vector)


func set_blood_color_value(color: Color) -> void:
	blood_color = color


func set_particle_scene_value(scene: PackedScene) -> void:
	particle_scene = scene


func set_decal_scene_value(scene: PackedScene) -> void:
	decal_scene = scene
