extends Area3D

signal key_collected(body, type, event_name, message_text)

@export var key_type: String
@export var event_name: String

func _ready():
	match key_type:
		"ruby":
			$Sprite3D.texture = Preloads.ruby_key
		"weird":
			$Sprite3D.texture = Preloads.weird_key
		"brown":
			$Sprite3D.texture = Preloads.brown_key
		"gold":
			$Sprite3D.texture = Preloads.gold_key
		"emerald":
			$Sprite3D.texture = Preloads.emerald_key
		"silver", _:
			$Sprite3D.texture = Preloads.silver_key


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
		Utils.play_sound(Preloads.key_collected_sound, body)
		queue_free()
