class_name DoorOpenerEffect
extends ComposableEffect

## Composable effect that opens a door when triggered.
## Attach as child of an interactable and connect to its signal.

@export var target_door: Node3D


func trigger() -> void:
	if target_door and target_door is Openable:
		target_door.open()
