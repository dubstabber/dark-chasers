extends Node3D

# App-level input (quit/fullscreen) is handled by InputRouter autoload.

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
