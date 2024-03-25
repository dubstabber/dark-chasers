extends Area3D

signal key_collected(body, type, event_name, message_text)

@export var key_type: String
@export var event_name: String

func _ready():
	match key_type:
		"ruby":
			$Sprite3D.texture = Preloads.RUBY_KEY_IMAGE
		"weird":
			$Sprite3D.texture = Preloads.WEIRD_KEY_IMAGE
		"brown":
			$Sprite3D.texture = Preloads.BROWN_KEY_IMAGE
		"gold":
			$Sprite3D.texture = Preloads.GOLD_KEY_IMAGE
		"emerald":
			$Sprite3D.texture = Preloads.EMERALD_KEY_IMAGE
		"silver", _:
			$Sprite3D.texture = Preloads.SILVER_KEY_IMAGE


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
		key_collected.emit(body, key_type, event_name, message_text)
		Utils.play_sound(Preloads.KEY_COLLECTED_SOUND, body)
		queue_free()
