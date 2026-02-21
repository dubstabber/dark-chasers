class_name InputRouter
extends Node

## Centralized handler for app-level input (quit, fullscreen, debug toggles).
## Owned by the Services autoload (Services.input_router), not a separate autoload.

signal quit_requested
signal fullscreen_toggled(is_fullscreen: bool)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		quit_requested.emit()
		get_tree().quit()
	
	if event.is_action_pressed("toggle-window-mode"):
		_toggle_fullscreen()


func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		fullscreen_toggled.emit(true)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		fullscreen_toggled.emit(false)
