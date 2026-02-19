extends PickupItem

@export var shield_value := 50


func _try_pickup(body: Node3D) -> void:
	if not Armorable.check(body):
		return

	var armor_added = Armorable.add_armor(body, shield_value)
	if armor_added:
		_complete_pickup(body)
	else:
		Services.utils.debug_log("Shield: armor already at maximum")
