extends Enemy

@onready var animation_player = $Graphics/AnimationPlayer


func _ready():
	super._ready()
	animation_player.speed_scale = speed / 8.0


func _physics_process(delta):
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
