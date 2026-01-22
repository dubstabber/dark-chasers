class_name CameraSwitchEffect
extends Node

## Composable effect that switches to a camera when triggered.
## Attach as child of an interactable and connect to its signal.

@export var target_camera: Camera3D
@export var auto_connect_parent_signal: String = "button_pressed"


func _ready() -> void:
	if auto_connect_parent_signal != "" and get_parent().has_signal(auto_connect_parent_signal):
		get_parent().connect(auto_connect_parent_signal, _on_triggered)


func _on_triggered(_body = null, _event_name = null) -> void:
	trigger()


func trigger() -> void:
	if target_camera:
		CameraManager.set_active_camera(target_camera)
