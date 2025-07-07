extends Enemy

var cur_anim := ""

@onready var animated_sprite = $Graphics/AnimatedSprite3D


func _physics_process(delta):
	super._physics_process(delta)
	animate_sprite()


func animate_sprite():
	if velocity:
		cur_anim = 'run'
	else:
		cur_anim = 'stay'
		
	if animated_sprite.animation != cur_anim:
		animated_sprite.play(cur_anim)
