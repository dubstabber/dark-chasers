extends StaticBody3D

var health := 20
var is_destroyed := false

@onready var animated_sprite_3d = $AnimatedSprite3D


func _ready():
	pass # Replace with function body.


func _process(_delta):
	pass


func take_damage(dmg: int):
	health -= dmg
	if health <= 0 and not is_destroyed:
		is_destroyed = true
		animated_sprite_3d.play()
		animated_sprite_3d.position.y = -0.40
		$CollisionShape3D.disabled = true
		$CollisionShape3D2.disabled = false
		
