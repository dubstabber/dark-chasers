extends PickupItem

@export var wieldable_item: WeaponResource


func _try_pickup(body: Node3D) -> void:
	WeaponReceiver.add_weapon(body, wieldable_item)
	_complete_pickup(body)
