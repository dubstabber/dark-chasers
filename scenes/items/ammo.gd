extends Area3D

signal item_pickedup(event_string)

@export var ammo_value := 20
@export var pickup_sound: AudioStream
@export var event_string: String

# Centralized ammo system options
@export_group("Ammo Type")
@export var ammo_type: String = "" # Ammo type for centralized system (e.g., "pistol_ammo", "lighter_fuel")

# Special targeting options
@export_group("Special Targeting")
@export var target_all_weapons: bool = false # Add ammo to all non-infinite weapons (uses legacy system)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group('player'):
		var ammo_added = false

		# Use component-based ammo system if ammo_type is specified
		if ammo_type != "":
			# Get the player's ammo component
			var player_ammo_component = body.get("ammo_component")
			if player_ammo_component and player_ammo_component.has_method("add_ammo"):
				ammo_added = player_ammo_component.add_ammo(ammo_type, ammo_value)
			else:
				print("Player has no ammo_component!")
				return
		elif target_all_weapons:
			# Special case: universal ammo that adds to all weapon types
			if body.has_method("add_ammo"):
				ammo_added = body.add_ammo(ammo_value, "", 0, true)
		else:
			print("Ammo pickup has no ammo_type specified and is not universal ammo!")
			return

		# Only consume the item if ammo was successfully added
		if ammo_added:
			if pickup_sound:
				Utils.play_sound(pickup_sound, get_parent(), position)
			item_pickedup.emit(event_string)
			queue_free()
		else:
			if ammo_type != "":
				print("Could not add ammo - %s at maximum!" % ammo_type)
			else:
				print("Could not add universal ammo - all weapons at maximum!")
