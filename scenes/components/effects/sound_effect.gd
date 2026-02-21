class_name SoundEffect
extends ComposableEffect

## Composable effect that plays a sound when triggered.
## Attach as child of an interactable and connect to its signal.

@export var sound: AudioStream
@export var volume_db: float = -25.0


func trigger() -> void:
	if sound:
		var parent_3d = get_parent() as Node3D
		if parent_3d:
			Services.utils.play_sound(sound, parent_3d, parent_3d.global_position, volume_db)
