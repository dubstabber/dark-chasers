extends PickupItem

@export var heal_value := 10


func _try_pickup(body: Node3D) -> void:
	if not Healable.check(body):
		return

	var healed = Healable.heal(body, heal_value)
	if healed:
		_complete_pickup(body)
	else:
		Services.utils.debug_log("Health: already full")
