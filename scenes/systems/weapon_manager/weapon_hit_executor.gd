class_name WeaponHitExecutor
extends RefCounted

## Handles weapon hit/firing execution logic.
## Extracted from WeaponResource to keep Resources as pure config/state.
##
## This executor handles:
## - Raycast collision detection
## - Particle/decal instantiation
## - Sound playback
## - Damage application

var _scene_tree: SceneTree
var _bullet_raycast: RayCast3D
var _muzzle_flash_light: OmniLight3D
var _muzzle_flash_timer: Timer


func setup(scene_tree: SceneTree, bullet_raycast: RayCast3D) -> void:
	"""Initialize the executor with required references"""
	_scene_tree = scene_tree
	_bullet_raycast = bullet_raycast


func _ensure_muzzle_flash_nodes() -> void:
	if not _scene_tree or not is_instance_valid(_scene_tree.root):
		return

	if not is_instance_valid(_muzzle_flash_light):
		_muzzle_flash_light = OmniLight3D.new()
		_muzzle_flash_light.light_color = Color.YELLOW
		_muzzle_flash_light.light_energy = 0.16
		_muzzle_flash_light.omni_range = 0.12
		_muzzle_flash_light.visible = false

	if _muzzle_flash_light.get_parent() == null:
		_scene_tree.root.add_child(_muzzle_flash_light)
		if _muzzle_flash_light.get_parent() == null:
			_scene_tree.root.call_deferred("add_child", _muzzle_flash_light)

	if not is_instance_valid(_muzzle_flash_timer):
		_muzzle_flash_timer = Timer.new()
		_muzzle_flash_timer.one_shot = true
		_muzzle_flash_timer.wait_time = 0.1
		_muzzle_flash_timer.timeout.connect(_hide_muzzle_flash)

	if _muzzle_flash_timer.get_parent() == null:
		_scene_tree.root.add_child(_muzzle_flash_timer)
		if _muzzle_flash_timer.get_parent() == null:
			_scene_tree.root.call_deferred("add_child", _muzzle_flash_timer)


func execute_hit(weapon: WeaponResource) -> void:
	"""Execute a hit for the given weapon
	
	Args:
		weapon: The weapon resource containing hit configuration
	"""
	if weapon.shoot_type == WeaponResource.ShootTypes.HitScan:
		_execute_hitscan(weapon)


func _execute_hitscan(weapon: WeaponResource) -> void:
	"""Execute a hitscan weapon hit"""
	if not _bullet_raycast or not _scene_tree:
		push_warning("WeaponHitExecutor: Missing raycast or scene tree reference")
		return
	
	var collider = _bullet_raycast.get_collider()
	if not collider:
		return
	
	var hit_pos = _bullet_raycast.get_collision_point()
	var hit_normal = _bullet_raycast.get_collision_normal()
	var is_enemy_hit := _is_enemy_hit(collider)
	var water_splash := _find_water_splash_node(collider)
	if water_splash:
		water_splash.play_splash_sound(collider, hit_pos)
	
	if not is_enemy_hit:
		_spawn_hit_particle(weapon, hit_pos, hit_normal)
	_spawn_hit_decal(weapon, collider, hit_pos, hit_normal)
	_play_hit_sound(weapon, collider, hit_pos)
	_apply_damage(weapon, collider, hit_pos)


func _spawn_hit_particle(weapon: WeaponResource, hit_pos: Vector3, hit_normal: Vector3) -> void:
	"""Spawn hit particle effect at collision point"""
	if not weapon.hit_particle:
		return
	
	var particle = weapon.hit_particle.instantiate()
	_scene_tree.root.add_child(particle)
	particle.global_transform.origin = hit_pos + hit_normal * 0.01
	
	if particle.has_signal("animation_finished"):
		particle.connect("animation_finished", particle.queue_free)
	
	if weapon.hit_muzzle_flash:
		_spawn_muzzle_flash(hit_pos, hit_normal)


func _spawn_muzzle_flash(hit_pos: Vector3, hit_normal: Vector3) -> void:
	"""Spawn a brief muzzle flash light at hit point"""
	_ensure_muzzle_flash_nodes()
	if not is_instance_valid(_muzzle_flash_light) or not _muzzle_flash_light.is_inside_tree():
		return

	_muzzle_flash_light.global_position = hit_pos + hit_normal * 0.1
	_muzzle_flash_light.visible = true

	if is_instance_valid(_muzzle_flash_timer) and _muzzle_flash_timer.is_inside_tree():
		_muzzle_flash_timer.start()


func _hide_muzzle_flash() -> void:
	if is_instance_valid(_muzzle_flash_light):
		_muzzle_flash_light.visible = false


func _spawn_hit_decal(weapon: WeaponResource, collider: Node, hit_pos: Vector3, hit_normal: Vector3) -> void:
	"""Spawn decal on hit surface"""
	if not weapon.hit_decal:
		return
	if collider.is_in_group("entity"):
		return
	if collider.is_in_group("no_decals"):
		return
	if not _is_wall_surface(hit_normal):
		return
	
	var decal = weapon.hit_decal.instantiate()
	collider.add_child(decal)
	decal.global_transform.origin = hit_pos + hit_normal * (decal.size.y * 0.05)
	decal.global_transform.basis = _calculate_decal_rotation(hit_normal)


func _play_hit_sound(weapon: WeaponResource, collider: Node, hit_pos: Vector3) -> void:
	"""Play appropriate hit sound based on what was hit"""
	if collider.is_in_group("entity"):
		if weapon.damage_entity_sound:
			Services.utils.play_sound(weapon.damage_entity_sound, _scene_tree.root, hit_pos)
	elif weapon.damage_wall_sound:
		Services.utils.play_sound(weapon.damage_wall_sound, _scene_tree.root, hit_pos)


func _apply_damage(weapon: WeaponResource, collider: Node, hit_pos: Vector3) -> void:
	"""Apply damage to the hit collider using Damageable interface"""
	var shot_direction := -_bullet_raycast.global_transform.basis.z.normalized()

	# Use typed interface for damage application (priority: directional > positional > basic)
	Damageable.deal_damage(collider, weapon.damage, hit_pos, shot_direction)

	if collider.is_in_group("destroyable"):
		collider.queue_free()


func _is_enemy_hit(collider: Node) -> bool:
	if collider == null:
		return false
	if collider.is_in_group("enemy"):
		return true
	var parent := collider.get_parent()
	return parent != null and parent.is_in_group("enemy")


func _find_water_splash_node(collider: Node) -> Node:
	if collider == null:
		return null

	for node in [collider, collider.get_parent()]:
		if node == null:
			continue
		for child in node.get_children():
			if child != null and child.has_method("play_splash_sound"):
				return child

	return null


func _is_wall_surface(normal: Vector3) -> bool:
	"""Check if surface is a wall (not floor or ceiling)"""
	return abs(normal.y) < 0.7


func _calculate_decal_rotation(normal: Vector3) -> Basis:
	"""Calculate rotation for decal to align with surface"""
	var forward = Vector3(0, 0, 1)
	
	if abs(normal.dot(forward)) > 0.99:
		forward = Vector3(1, 0, 0)
	
	var right_vector = forward.cross(normal).normalized()
	var forward_vector = normal.cross(right_vector).normalized()
	
	return Basis(right_vector, -normal, forward_vector)
