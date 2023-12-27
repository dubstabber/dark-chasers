extends Area3D

signal button_pressed(event_name)

@export var button_type: String
@export var event_name: String
@export var one_use := true

var is_pressed := false

@onready var sprite_3d = $Sprite3D


func _ready():
	connect("body_entered", _button_body_entered)
	connect("body_exited", _button_body_exited)


func press():
	if not is_pressed:
		button_pressed.emit(event_name)
		is_pressed = true
		match button_type:
			"lever":
				sprite_3d.texture = Preloads.button_down_5
		if not one_use:
			print('TODO: unpress button after some delay')

func _button_body_entered(body):
	if "button_to_press" in body:
		body.button_to_press = self


func _button_body_exited(body):
	if "button_to_press" in body:
		body.button_to_press = null
