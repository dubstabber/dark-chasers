extends Area3D

var map: Node3D

@export var key_type: String

func _ready():
	map = get_tree().get_first_node_in_group('map')
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
		if key_type and not key_type in map.keys_collected:
			map.keys_collected.push_back(key_type)
			
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
			_:
				print('Congratulations! You just picked up the useless key!')
		
		queue_free()
