class_name DoorOpenerEffect
extends Node

## Composable effect that opens a door when triggered.
## Attach as child of an interactable and connect to its signal.

@export var target_door: Node3D
@export var auto_connect_parent_signal: String = "button_pressed"


func _ready() -> void:
	if auto_connect_parent_signal != "" and get_parent().has_signal(auto_connect_parent_signal):
		get_parent().connect(auto_connect_parent_signal, _on_triggered)


func _on_triggered(_body = null, _event_name = null) -> void:
	trigger()


func trigger() -> void:
	if target_door and target_door is Openable:
		target_door.open()
