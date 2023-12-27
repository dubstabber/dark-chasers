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
		change_sprite()
		if not one_use:
			await get_tree().create_timer(1.0).timeout
			is_pressed = false
			change_sprite()

func change_sprite():
	match button_type:
		"lever":
			if is_pressed: sprite_3d.texture = Preloads.button_down_5
			else: sprite_3d.texture = Preloads.button_up_5
		"circle":
			if is_pressed: sprite_3d.texture = Preloads.button_down_1
			else: sprite_3d.texture = Preloads.button_up_1


func _button_body_entered(body):
	if "button_to_press" in body:
		body.button_to_press = self


func _button_body_exited(body):
	if "button_to_press" in body:
		body.button_to_press = null
