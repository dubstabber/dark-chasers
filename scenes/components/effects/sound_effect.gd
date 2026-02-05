class_name SoundEffect
extends Node

## Composable effect that plays a sound when triggered.
## Attach as child of an interactable and connect to its signal.

@export var sound: AudioStream
@export var volume_db: float = -25.0
@export var auto_connect_parent_signal: String = "button_pressed"


func _ready() -> void:
	if auto_connect_parent_signal != "" and get_parent().has_signal(auto_connect_parent_signal):
		get_parent().connect(auto_connect_parent_signal, _on_triggered)


func _on_triggered(_body = null) -> void:
	trigger()


func trigger() -> void:
	if sound:
		var parent_3d = get_parent() as Node3D
		if parent_3d:
			Utils.play_sound(sound, parent_3d, parent_3d.global_position, volume_db)
