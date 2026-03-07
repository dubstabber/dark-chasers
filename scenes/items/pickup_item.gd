class_name PickupItem
extends Area3D

## Base class for pickup items. Handles common pickup flow:
## player check, sound, event bus emission, queue_free.
##
## Subclasses override _try_pickup() to implement specific pickup logic
## and call _complete_pickup() on success.

@export var pickup_sound: AudioStream
@export var pickup_message: String


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group('player'):
		_try_pickup(body)


func _try_pickup(_body: Node3D) -> void:
	pass


func _complete_pickup(_body: Node3D) -> void:
	if pickup_sound:
		Services.utils.play_sound(pickup_sound, get_parent(), position)
	if pickup_message:
		Services.event_bus.emit(GameEventTypes.ITEM_PICKEDUP, {
			"message": pickup_message
		}, self)
	queue_free()
