extends Area3D

signal item_pickedup(event_string)

@export var ammo_value := 20
@export var pickup_sound: AudioStream
@export var event_string: String

# Weapon targeting options
@export_group("Weapon Targeting")
@export var target_weapon_name: String = "" # Target specific weapon by name (e.g., "Hiroshi pistol")
@export var target_weapon_slot: int = 0 # Target weapons in specific slot (0 = any slot)
@export var target_all_weapons: bool = false # Add ammo to all non-infinite weapons


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group('player'):
		# Try to add ammo using the player's add_ammo method
		var ammo_added = false
		
		if body.has_method("add_ammo"):
			if target_all_weapons:
				ammo_added = body.add_ammo(ammo_value, "", 0, true)
			elif target_weapon_name != "":
				ammo_added = body.add_ammo(ammo_value, target_weapon_name)
			elif target_weapon_slot > 0:
				ammo_added = body.add_ammo(ammo_value, "", target_weapon_slot)
			else:
				# Default: add ammo to current weapon
				ammo_added = body.add_ammo(ammo_value)
		
		# Only consume the item if ammo was successfully added
		if ammo_added:
			if pickup_sound:
				Utils.play_sound(pickup_sound, get_parent(), position)
			item_pickedup.emit(event_string)
			queue_free()
		else:
			print("Could not add ammo - weapon at maximum or not found!")
