class_name PickupItem
extends Area3D

## Base class for pickup items. Handles common pickup flow:
## player check, sound, signal emission, event bus, queue_free.
##
## Subclasses override _try_pickup() to implement specific pickup logic
## and call _complete_pickup() on success.

const GameEventTypesScript = preload("res://scenes/resources/game_event_types.gd")

signal item_pickedup(event_string)

@export var pickup_sound: AudioStream
@export var event_string: String


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group('player'):
		_try_pickup(body)


func _try_pickup(_body: Node3D) -> void:
	pass


func _complete_pickup(body: Node3D) -> void:
	if pickup_sound:
		Services.utils.play_sound(pickup_sound, get_parent(), position)
	if event_string:
		item_pickedup.emit(event_string)
		Services.event_bus.emit(GameEventTypesScript.ITEM_PICKEDUP, {
			"message": event_string,
			"item": self,
			"body": body
		}, self)
	queue_free()
