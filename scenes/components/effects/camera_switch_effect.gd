class_name CameraSwitchEffect
extends ComposableEffect

## Composable effect that switches to a camera when triggered.
## Attach as child of an interactable and connect to its signal.

@export var target_camera: Camera3D


func trigger() -> void:
	if target_camera:
		Services.camera_manager.set_active_camera(target_camera)
