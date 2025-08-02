extends Enemy

var current_anim := ""

@onready var animation_player = $Graphics/AnimationPlayer


func _ready():
	super._ready()
	animation_player.speed_scale = speed / 7.0


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_animation_state()


func _update_animation_state():
	"""Update animation state based on movement velocity"""
	if velocity.length() > 0.1:
		moving_state = "run"
		if animation_player:
			animation_player.play("move")
	else:
		moving_state = "idle"
		if animation_player:
			animation_player.play("RESET")
