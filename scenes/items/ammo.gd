extends PickupItem

@export var ammo_value := 20

# Centralized ammo system options
@export_group("Ammo Type")
@export var ammo_type: String = "" # Ammo type for centralized system (e.g., "pistol_ammo", "lighter_fuel")

# Special targeting options
@export_group("Special Targeting")
@export var target_all_weapons: bool = false # Add ammo to all non-infinite weapons (uses legacy system)


func _try_pickup(body: Node3D) -> void:
	if not AmmoConsumer.check(body):
		Services.utils.debug_warning("Ammo: Player cannot receive ammo!")
		return

	var ammo_added = false
	if ammo_type != "":
		ammo_added = AmmoConsumer.add_ammo(body, ammo_type, ammo_value)
	elif target_all_weapons:
		ammo_added = AmmoConsumer.add_universal_ammo(body, ammo_value)
	else:
		Services.utils.debug_warning("Ammo: pickup has no ammo_type specified and is not universal ammo!")
		return

	if ammo_added:
		_complete_pickup(body)
	else:
		if ammo_type != "":
			Services.utils.debug_log("Ammo: could not add ammo - %s at maximum!" % ammo_type)
		else:
			Services.utils.debug_log("Ammo: could not add universal ammo - all weapons at maximum!")
