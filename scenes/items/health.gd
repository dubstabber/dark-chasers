extends Area3D

signal item_pickedup(event_string)

@export var event_string: String
@export var pickup_sound: AudioStream
@export var heal_value := 10

func _on_body_entered(body):
	if body.is_in_group('player'):
		# Try to heal using HealthComponent first
		var health_component = body.get_node_or_null("HealthComponent")
		var healed = false

		if health_component and health_component.has_method("heal"):
			healed = health_component.heal(heal_value)
		elif body.has_method("heal"):
			# Fallback to direct heal method on the body
			healed = body.heal(heal_value)

		# Only consume the item if healing was successful
		if healed:
			if pickup_sound:
				Utils.play_sound(pickup_sound, get_parent(), position)
			item_pickedup.emit(event_string)
			queue_free()
		else:
			# Optional: Show message that health is full
			print("Health is already full!")
