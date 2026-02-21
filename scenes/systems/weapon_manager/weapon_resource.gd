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


# Note: hit() execution logic has been moved to WeaponHitExecutor
# WeaponResource is now pure config/state - no scene-tree mutations


## Ammo Management Methods
## These methods handle ammo consumption, checking, and reloading

func _has_valid_ammo_setup() -> bool:
	"""Validate that ammo_type and ammo_component are properly configured.
	Logs errors if configuration is invalid. Does NOT check infinite_ammo."""
	if ammo_type == "":
		push_error("Weapon '%s' has no ammo_type specified!" % name)
		return false
	if not ammo_component:
		push_error("Weapon '%s' has no ammo_component reference!" % name)
		return false
	return true


func can_fire() -> bool:
	"""Check if the weapon can fire (has enough ammo or infinite ammo)

	Returns:
		bool: True if weapon can fire, False if insufficient ammo
	"""
	if infinite_ammo:
		return true
	if not _has_valid_ammo_setup():
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
	if not _has_valid_ammo_setup():
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
	if not _has_valid_ammo_setup():
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
	if not _has_valid_ammo_setup():
		return 0
	return ammo_component.get_ammo(ammo_type)


func get_max_ammo_amount() -> int:
	"""Get maximum ammo amount for this weapon

	Returns:
		int: Maximum ammo amount
	"""
	if infinite_ammo:
		return -1 # Sentinel value representing infinite ammo
	if not _has_valid_ammo_setup():
		return 0
	return ammo_component.get_max_ammo(ammo_type)


func get_ammo_percentage() -> float:
	"""Get current ammo as a percentage of max ammo

	Returns:
		float: Ammo percentage (0.0 to 1.0)
	"""
	if infinite_ammo:
		return 1.0
	if not _has_valid_ammo_setup():
		return 1.0
	return ammo_component.get_ammo_percentage(ammo_type)
