extends Enemy

var cur_anim := ""

@onready var animated_sprite = $Graphics/AnimatedSprite3D


func _physics_process(delta):
	super._physics_process(delta)
	_animate_sprite()


func _animate_sprite():
	if velocity.length() > 0.1:
		cur_anim = 'run'
	else:
		cur_anim = 'stay'
		
	if animated_sprite.animation != cur_anim:
		animated_sprite.play(cur_anim)
