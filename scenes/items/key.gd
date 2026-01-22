@tool
extends Area3D

const GameEventTypesScript = preload("res://scenes/resources/game_event_types.gd")

signal key_collected(body, type, event_name, message_text)

@export var key_type: String
@export var event_name: String

func _ready():
	$Sprite3D.texture = Preloads.get_key_texture(key_type)


func _on_body_entered(body):
	if body.is_in_group('player'):
		var message_text: String
		match key_type:
			"ruby":
				message_text = "Picked up a ruby key."
			"weird":
				message_text = "Picked up some odd looking key."
			"brown":
				message_text = "Picked up a rusty brown key."
			"gold":
				message_text = "Picked up a fancy gold key."
			"emerald":
				message_text = "Picked up an emerald key."
			"silver":
				message_text = "Picked up a shiny silver key."
			"useless":
				message_text = 'Congratulations! You just picked up the useless key!'
			_:
				message_text = "Picked up a key."
		# Emit typed event to GameEventBus
		GameEventBus.emit(GameEventTypesScript.KEY_COLLECTED, {
			"body": body,
			"key_type": key_type,
			"event_name": event_name,
			"message": message_text
		}, self)
		# Keep legacy signal for backward compatibility
		key_collected.emit(body, key_type, event_name, message_text)
		Utils.play_sound(Preloads.KEY_COLLECTED_SOUND, body)
		queue_free()
