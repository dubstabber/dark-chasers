class_name WeaponResource extends Resource

## A weapon resource that handles weapon properties, ammo management, and combat mechanics
##
## This resource defines weapon behavior including damage, animations, sounds, and ammo consumption.
## It emits signals for ammo changes to maintain separation of concerns with the UI system.

signal ammo_changed(current_ammo: int, max_ammo: int)
signal ammo_depleted()

enum ShootTypes {
	None,
	HitScan,
	Projectile,
}

var weapon_manager: WeaponManager
var ammo_component: PlayerAmmoComponent # Reference to the player's ammo component

@export var shoot_type: ShootTypes

@export var name: String

@export_range(1, 9) var slot: int = 1
@export_range(1, 10) var slot_priority: int = 1

@export var pullout_anim_name: String
@export var shoot_anim_name: String
@export var repeat_shoot_anim_name: String
@export var auto_hit := false
@export var melee_attack := false
@export var hit_sound: AudioStream
@export var draw_sound: AudioStream
@export var holster_sound: AudioStream
@export var damage_wall_sound: AudioStream
@export var damage_entity_sound: AudioStream
@export var damage := 10
@export var hit_particle: PackedScene
@export var hit_decal: PackedScene

@export_group("Ammo Settings")
@export var ammo_type: String = "" # Ammo type for centralized system (e.g., "pistol_ammo", "lighter_fuel")
@export var ammo_per_shot: int = 1
@export var infinite_ammo: bool = false


func hit() -> void:
	if shoot_type == ShootTypes.HitScan:
		var collider = weapon_manager.bullet_raycast.get_collider()
		if collider:
			var hit_pos = weapon_manager.bullet_raycast.get_collision_point()
			var hit_normal = weapon_manager.bullet_raycast.get_collision_normal()
			if hit_particle:
				var hit_particle1 = hit_particle.instantiate()
				weapon_manager.get_tree().root.add_child(hit_particle1)
				hit_particle1.global_transform.origin = hit_pos + hit_normal * 0.01
				hit_particle1.connect("animation_finished", hit_particle1.queue_free)
			if hit_decal and not collider.is_in_group("entity") and not collider.is_in_group("no_decals"):
				var hit_decal1 = hit_decal.instantiate()
				collider.add_child(hit_decal1)
				hit_decal1.global_transform.origin = hit_pos + hit_normal * 0.01
				var rotation_basis = _calculate_sprite_rotation(hit_normal)
				hit_decal1.global_transform.basis = rotation_basis

			if collider.is_in_group("entity"):
				if damage_entity_sound:
					Utils.play_sound(damage_entity_sound, weapon_manager.get_tree().root, hit_pos)
			elif damage_wall_sound:
				Utils.play_sound(damage_wall_sound, weapon_manager.get_tree().root, hit_pos)
			if collider.has_method("take_damage_at_position"):
				collider.take_damage_at_position(damage, hit_pos)
			elif collider.has_method("take_damage"):
				collider.take_damage(damage)
			if collider.is_in_group("destroyable"):
				collider.queue_free()


func _calculate_sprite_rotation(normal: Vector3) -> Basis:
	# Define a default "up" vector (Y-axis)
	var up_vector = Vector3(0, 1, 0)

	# Handle edge cases where the normal is parallel to the up vector
	if abs(normal.dot(up_vector)) > 0.99: # If normal is nearly parallel to up vector
		# Use a different "up" vector (e.g., Z-axis) to avoid singularity
		up_vector = Vector3(0, 0, 1)

	# Calculate the right and up vectors for the sprite
	var right_vector = up_vector.cross(normal).normalized()
	var sprite_up_vector = normal.cross(right_vector).normalized()

	# Construct the rotation basis
	# The Z-axis of the sprite should align with the normal
	# The X and Y axes should lie flat on the surface
	return Basis(right_vector, sprite_up_vector, normal)


## Ammo Management Methods
## These methods handle ammo consumption, checking, and reloading

func can_fire() -> bool:
	"""Check if the weapon can fire (has enough ammo or infinite ammo)

	Returns:
		bool: True if weapon can fire, False if insufficient ammo
	"""
	if infinite_ammo:
		return true

	# All weapons must have ammo_type specified
	if ammo_type == "":
		push_error("Weapon '%s' has no ammo_type specified!" % name)
		return false

	# Must have ammo component reference
	if not ammo_component:
		push_error("Weapon '%s' has no ammo_component reference!" % name)
		return false

	return ammo_component.has_ammo(ammo_type, ammo_per_shot)


func consume_ammo(amount: int = -1) -> bool:
	"""Consume ammo when firing

	Args:
		amount: Amount of ammo to consume (-1 uses ammo_per_shot)

	Returns:
		bool: True if ammo was consumed, False if not enough ammo
	"""
	if infinite_ammo:
		return true

	# All weapons must have ammo_type specified
	if ammo_type == "":
		push_error("Weapon '%s' has no ammo_type specified!" % name)
		return false

	# Must have ammo component reference
	if not ammo_component:
		push_error("Weapon '%s' has no ammo_component reference!" % name)
		return false

	# Use weapon's ammo_per_shot if amount not specified
	var ammo_to_consume = amount if amount > 0 else ammo_per_shot

	var consumed = ammo_component.consume_ammo(ammo_type, ammo_to_consume)
	if consumed:
		var current = ammo_component.get_ammo(ammo_type)
		var maximum = ammo_component.get_max_ammo(ammo_type)
		ammo_changed.emit(current, maximum)

		if current <= 0:
			ammo_depleted.emit()

	return consumed


func reload(amount: int = -1) -> bool:
	"""Reload the weapon with ammo

	Args:
		amount: Amount of ammo to add (-1 for full reload)

	Returns:
		bool: True if ammo was added, False if already at max
	"""
	if infinite_ammo:
		return false

	# All weapons must have ammo_type specified
	if ammo_type == "":
		push_error("Weapon '%s' has no ammo_type specified!" % name)
		return false

	# Must have ammo component reference
	if not ammo_component:
		push_error("Weapon '%s' has no ammo_component reference!" % name)
		return false

	var current = ammo_component.get_ammo(ammo_type)
	var maximum = ammo_component.get_max_ammo(ammo_type)

	if amount == -1:
		# Full reload - add enough to reach maximum
		var needed = maximum - current
		if needed > 0:
			var added = ammo_component.add_ammo(ammo_type, needed)
			if added:
				ammo_changed.emit(ammo_component.get_ammo(ammo_type), maximum)
			return added
	else:
		# Add specific amount
		var added = ammo_component.add_ammo(ammo_type, amount)
		if added:
			ammo_changed.emit(ammo_component.get_ammo(ammo_type), maximum)
		return added

	return false


func get_current_ammo() -> int:
	"""Get current ammo amount for this weapon

	Returns:
		int: Current ammo amount
	"""
	if infinite_ammo:
		return -1 # Sentinel value representing infinite ammo

	# All weapons must have ammo_type specified
	if ammo_type == "":
		push_error("Weapon '%s' has no ammo_type specified!" % name)
		return 0

	# Must have ammo component reference
	if not ammo_component:
		push_error("Weapon '%s' has no ammo_component reference!" % name)
		return 0

	return ammo_component.get_ammo(ammo_type)


func get_max_ammo_amount() -> int:
	"""Get maximum ammo amount for this weapon

	Returns:
		int: Maximum ammo amount
	"""
	if infinite_ammo:
		return -1 # Sentinel value representing infinite ammo

	# All weapons must have ammo_type specified
	if ammo_type == "":
		push_error("Weapon '%s' has no ammo_type specified!" % name)
		return 0

	# Must have ammo component reference
	if not ammo_component:
		push_error("Weapon '%s' has no ammo_component reference!" % name)
		return 0

	return ammo_component.get_max_ammo(ammo_type)


func get_ammo_percentage() -> float:
	"""Get current ammo as a percentage of max ammo

	Returns:
		float: Ammo percentage (0.0 to 1.0)
	"""
	if infinite_ammo:
		return 1.0

	# All weapons must have ammo_type specified
	if ammo_type == "":
		push_error("Weapon '%s' has no ammo_type specified!" % name)
		return 1.0

	# Must have ammo component reference
	if not ammo_component:
		push_error("Weapon '%s' has no ammo_component reference!" % name)
		return 1.0

	return ammo_component.get_ammo_percentage(ammo_type)
