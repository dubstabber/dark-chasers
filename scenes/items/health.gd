extends Area3D

@export var event_string: String
@export var pickup_sound: AudioStream
@export var heal_value := 10

func _on_body_entered(body):
	if body.is_in_group('player'):
		if pickup_sound: 
			Utils.play_sound(pickup_sound, get_parent(), position)
		print(event_string)
		queue_free()
