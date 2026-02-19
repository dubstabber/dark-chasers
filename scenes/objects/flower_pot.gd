extends StaticBody3D

@onready var _destructible: DestructibleComponent = $DestructibleComponent
@onready var animated_sprite_3d = $AnimatedSprite3D


func take_damage(dmg: int) -> void:
	if _destructible:
		_destructible.take_damage(dmg)


func _on_destructible_destroyed() -> void:
	animated_sprite_3d.play()
	animated_sprite_3d.position.y = -0.50
	$CollisionShape3D.disabled = true
	$CollisionShape3D2.disabled = false
