extends Area3D

const ArmorableInterface = preload("res://scenes/interfaces/armorable.gd")
const GameEventTypesScript = preload("res://scenes/resources/game_event_types.gd")

signal item_pickedup(event_string)

@export var shield_value := 50
@export var pickup_sound: AudioStream
@export var event_string: String


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group('player'):
		if not ArmorableInterface.check(body):
			return
		
		var armor_added = ArmorableInterface.add_armor(body, shield_value)

		# Only consume the item if armor was successfully added
		if armor_added:
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
			Services.utils.debug_log("Shield: armor already at maximum")
