extends Enemy

@onready var sprite_3d = $Graphics/Sprite3D


func _ready():
	super._ready()
	if not speed: speed = 4.0
	accel = 10
