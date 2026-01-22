extends Area3D

const HealableInterface = preload("res://scenes/interfaces/healable.gd")

signal item_pickedup(event_string)

@export var event_string: String
@export var pickup_sound: AudioStream
@export var heal_value := 10

func _on_body_entered(body):
	if body.is_in_group('player'):
		if not HealableInterface.check(body):
			return
		
		var healed = HealableInterface.heal(body, heal_value)
		if healed:
			if pickup_sound:
				Utils.play_sound(pickup_sound, get_parent(), position)
			item_pickedup.emit(event_string)
			queue_free()
		else:
			# Optional: Show message that health is full
			print("Health is already full!")
