@tool
class_name ButtonImageLibrary
extends Resource

## Resource-based catalog for button textures.
## Maps button types to their pressed/unpressed states.

@export_group("Lever Button")
@export var lever_up: Texture2D
@export var lever_down: Texture2D

@export_group("Circle Button")
@export var circle_up: Texture2D
@export var circle_down: Texture2D


func get_texture(button_type: String, is_pressed: bool) -> Texture2D:
	match button_type:
		"lever":
			return lever_down if is_pressed else lever_up
		"circle":
			return circle_down if is_pressed else circle_up
		_:
			push_warning("ButtonImageLibrary: Unknown button type '%s'" % button_type)
			return circle_down if is_pressed else circle_up
