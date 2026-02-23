class_name DoorOpenerEffect
extends ComposableEffect

## Composable effect that opens a door when triggered.
## Attach as child of an interactable and connect to its signal.

@export var target_door: Door


func trigger() -> void:
	if target_door:
		target_door.open()
