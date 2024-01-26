extends Enemy

@onready var sprite_3d = $RotationController/Sprite3D


func _ready():
	super._ready()
	if not speed: speed = 4.0
	accel = 10


func _physics_process(delta):
	super._physics_process(delta)

