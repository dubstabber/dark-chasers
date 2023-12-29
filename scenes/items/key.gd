extends Area3D

signal key_collected(body, type, event_name)

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
		key_collected.emit(body, key_type, event_name)
		match key_type:
			"ruby":
				print("Picked up a ruby key.")
			"weird":
				print("Picked up some odd looking key.")
			"brown":
				print("Picked up a rusty brown key.")
			"gold":
				print("Picked up a fancy gold key.")
			"emerald":
				print("Picked up an emerald key.")
			"silver":
				print("Picked up a shiny silver key.")
			"useless":
				print('Congratulations! You just picked up the useless key!')
			_:
				print("Picked up a key.")
		Utils.play_sound(Preloads.key_collected_sound, body)
		queue_free()
