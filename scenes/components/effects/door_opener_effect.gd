class_name DoorOpenerEffect
extends ComposableEffect

const DoorScript = preload("res://scenes/objects/door.gd")

## Composable effect that opens a door when triggered.
## Attach as child of an interactable and connect to its signal.

@export var target_door: Node3D


func trigger() -> void:
	if target_door and target_door is DoorScript:
		target_door.open()
