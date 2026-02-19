extends StaticBody3D

@onready var _destructible: DestructibleComponent = $DestructibleComponent


func take_damage(dmg: int):
	if _destructible:
		_destructible.take_damage(dmg)
