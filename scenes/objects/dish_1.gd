extends StaticBody3D

const COLLISION_MASK_WALLS: int = 1 << 2
const TRACE_DISTANCE: float = 5.4
const TRACE_NOISE_LOW: float = 0.15
const TRACE_NOISE_MED: float = 0.18
const TRACE_NOISE_HIGH: float = 0.20

func take_damage(dmg: int) -> void:
	# Fallback when we don't know hit position (e.g. explosions)
	take_damage_at_position(dmg, global_position)


func take_damage_at_position(dmg: int, hit_pos: Vector3) -> void:
	take_damage_with_direction(dmg, hit_pos, Vector3.ZERO)


func take_damage_with_direction(dmg: int, hit_pos: Vector3, shot_direction: Vector3) -> void:
	var vfx_catalog := Services.get_vfx_catalog()
	if not vfx_catalog or not vfx_catalog.red_blood_particle:
		return

	var particle := vfx_catalog.red_blood_particle.instantiate() as RigidBody3D
	if not particle:
		return

	var parent_node := get_parent()
	if not parent_node:
		return

	parent_node.add_child(particle)
	particle.global_position = hit_pos
	particle.linear_velocity = Vector3(0, 2.5, 0)

	if shot_direction.length_squared() > 0.01 and vfx_catalog.blood_splat_decal:
		_trace_blood_to_walls(dmg, hit_pos, shot_direction, vfx_catalog.blood_splat_decal)


func _trace_blood_to_walls(dmg: int, hit_pos: Vector3, shot_direction: Vector3, decal_scene: PackedScene) -> void:
	var decal_count: int
	var noise: float

	if dmg < 15:
		if dmg <= 10:
			if randi() % 256 < 160:
				return
		decal_count = 1
		noise = TRACE_NOISE_LOW
	elif dmg < 25:
		decal_count = 2
		noise = TRACE_NOISE_MED
	else:
		if randi() % 256 < 24:
			decal_count = 1
			noise = TRACE_NOISE_HIGH
		else:
			decal_count = 3
			noise = TRACE_NOISE_HIGH

	for i in range(decal_count):
		_trace_single_blood_ray(hit_pos, shot_direction, noise, decal_scene)


func _trace_single_blood_ray(hit_pos: Vector3, shot_direction: Vector3, noise: float, decal_scene: PackedScene) -> void:
	var noisy_direction := shot_direction
	noisy_direction = noisy_direction.rotated(Vector3.UP, randf_range(-noise, noise))
	noisy_direction = noisy_direction.rotated(Vector3.RIGHT, randf_range(-noise, noise))
	noisy_direction = noisy_direction.normalized()

	var ray_end := hit_pos + noisy_direction * TRACE_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(hit_pos, ray_end)
	query.exclude = [self]
	query.collision_mask = COLLISION_MASK_WALLS

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return

	var collider := result.get("collider") as Node
	if not collider or collider.is_in_group("entity") or collider.is_in_group("no_decals"):
		return

	var hit_normal: Vector3 = result.get("normal", Vector3.UP)
	if abs(hit_normal.y) >= 0.7:
		return

	var hit_point: Vector3 = result.get("position", hit_pos)
	_spawn_blood_decal(collider, decal_scene, hit_point, hit_normal)


func _spawn_blood_decal(collider: Node, decal_scene: PackedScene, hit_pos: Vector3, hit_normal: Vector3) -> void:
	if not collider is Node3D:
		return

	var decal := decal_scene.instantiate()
	(collider as Node3D).add_child(decal)

	decal.global_position = hit_pos + hit_normal * (decal.size.y * 0.05)
	decal.global_transform.basis = _calculate_decal_rotation(hit_normal)

	# Apply red blood color
	BloodColorable.set_color(decal, Color.RED)


func _calculate_decal_rotation(normal: Vector3) -> Basis:
	var forward := Vector3.FORWARD
	if abs(normal.dot(forward)) > 0.99:
		forward = Vector3.RIGHT

	var right_vector := forward.cross(normal).normalized()
	var forward_vector := normal.cross(right_vector).normalized()

	return Basis(right_vector, -normal, forward_vector)
