extends Area3D

@export var wieldable_item: WeaponResource
@export var pickup_sound: AudioStream


func _on_body_entered(body:Node3D) -> void:
	if body.is_in_group('player'):
		if pickup_sound:
			Utils.play_sound(pickup_sound, get_parent(), position)
		if body.has_signal("weapon_added"):
			body.weapon_added.emit(wieldable_item)
		queue_free()
