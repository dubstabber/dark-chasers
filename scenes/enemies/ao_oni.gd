extends Enemy

## AoOni has blue blood like the Cacodemon in DOOM

@onready var animation_player = $Graphics/AnimationPlayer


func _ready():
	super._ready()
	# Set blue blood defaults if not configured in inspector
	if not blood_particle_scene:
		blood_color = Color(0.0, 0.0, 1.0, 1.0)
		blood_particle_scene = Preloads.AO_BLUE_BLOOD_PARTICLE
		blood_decal_scene = Preloads.BLOOD_SPLAT_DECAL
	
	animation_player.speed_scale = speed / 7.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_animation_state()


func _update_animation_state():
	if velocity.length() > 0.1:
		moving_state = "run"
		if animation_player:
			animation_player.play("move")
	else:
		moving_state = "idle"
		if animation_player:
			animation_player.play("RESET")
