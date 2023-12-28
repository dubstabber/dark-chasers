extends StaticBody3D

signal button_pressed(event_name)

@export var button_type: String
@export var event_name: String
@export var one_use := true
@export var door_to_open: Node3D

var is_pressed := false

@onready var sprite_3d = $Sprite3D


func press():
	if not is_pressed:
		button_pressed.emit(event_name)
		if door_to_open: door_to_open.open()
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

