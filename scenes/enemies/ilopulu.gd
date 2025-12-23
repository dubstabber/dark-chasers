extends Enemy

var cur_anim := ""

@onready var animated_sprite = $Graphics/AnimatedSprite3D


func _ready():
	super._ready()
	# Set black blood defaults if not configured in inspector
	if not blood_particle_scene:
		blood_color = Color(0.0, 0.0, 0.0, 1.0)
		blood_particle_scene = Preloads.AO_BLUE_BLOOD_PARTICLE
		blood_decal_scene = Preloads.BLOOD_SPLAT_DECAL


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
