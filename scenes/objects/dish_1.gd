extends StaticBody3D

@onready var _destructible: DestructibleComponent = get_node_or_null("DestructibleComponent") as DestructibleComponent


func take_damage(dmg: int) -> void:
	if _destructible:
		_destructible.take_damage(dmg)


func take_damage_at_position(dmg: int, _hit_pos: Vector3) -> void:
	take_damage(dmg)
