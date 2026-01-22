extends Area3D

const ArmorableInterface = preload("res://scenes/interfaces/armorable.gd")

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
				Utils.play_sound(pickup_sound, get_parent(), position)
			item_pickedup.emit(event_string)
			queue_free()
		else:
			print("Armor is already at maximum!")
