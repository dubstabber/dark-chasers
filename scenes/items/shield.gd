extends Area3D

signal item_pickedup(event_string)

@export var shield_value := 50
@export var pickup_sound: AudioStream
@export var event_string: String


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group('player'):
		pass
