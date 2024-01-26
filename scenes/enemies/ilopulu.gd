extends Enemy

@onready var animated_sprite_3d = $RotationController/AnimatedSprite3D


func _ready():
	super._ready()
	speed = 9.0
	accel = 10

func _physics_process(delta):
	super._physics_process(delta)
	animateSprite()

func animateSprite():
	if velocity and not animated_sprite_3d.animation.contains('run'):
		animated_sprite_3d.play('run')
	elif not velocity and not animated_sprite_3d.animation.contains('stay'):
		animated_sprite_3d.play('stay')

