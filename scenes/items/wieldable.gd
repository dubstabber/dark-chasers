extends Area3D

const GameEventTypesScript = preload("res://scenes/resources/game_event_types.gd")

signal item_pickedup(event_string)

@export var wieldable_item: WeaponResource
@export var pickup_sound: AudioStream
@export var event_string: String


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group('player'):
		if pickup_sound:
			Services.utils.play_sound(pickup_sound, get_parent(), position)
		if body.has_signal("weapon_added"):
			body.weapon_added.emit(wieldable_item)
		# Emit the pickup message for HUD display
		if event_string:
			item_pickedup.emit(event_string)
			Services.event_bus.emit(GameEventTypesScript.ITEM_PICKEDUP, {
				"message": event_string,
				"item": self,
				"body": body
			}, self)
		queue_free()
