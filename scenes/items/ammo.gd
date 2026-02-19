extends Area3D

const AmmoConsumerInterface = preload("res://scenes/interfaces/ammo_consumer.gd")
const GameEventTypesScript = preload("res://scenes/resources/game_event_types.gd")

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
		if not AmmoConsumerInterface.check(body):
			Services.utils.debug_warning("Ammo: Player cannot receive ammo!")
			return
		
		var ammo_added = false
		if ammo_type != "":
			ammo_added = AmmoConsumerInterface.add_ammo(body, ammo_type, ammo_value)
		elif target_all_weapons:
			ammo_added = AmmoConsumerInterface.add_universal_ammo(body, ammo_value)
		else:
			Services.utils.debug_warning("Ammo: pickup has no ammo_type specified and is not universal ammo!")
			return

		# Only consume the item if ammo was successfully added
		if ammo_added:
			if pickup_sound:
				Services.utils.play_sound(pickup_sound, get_parent(), position)
			item_pickedup.emit(event_string)
			Services.event_bus.emit(GameEventTypesScript.ITEM_PICKEDUP, {
				"message": event_string,
				"item": self,
				"body": body
			}, self)
			queue_free()
		else:
			if ammo_type != "":
				Services.utils.debug_log("Ammo: could not add ammo - %s at maximum!" % ammo_type)
			else:
				Services.utils.debug_log("Ammo: could not add universal ammo - all weapons at maximum!")
