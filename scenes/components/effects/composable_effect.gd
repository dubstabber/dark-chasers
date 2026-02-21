class_name ComposableEffect
extends Node

## Base composable effect that can auto-connect to a parent signal and trigger itself.

@export var auto_connect_parent_signal: String = "button_pressed"


func _ready() -> void:
	var parent_node := get_parent()
	if auto_connect_parent_signal == "" or parent_node == null:
		return
	if not parent_node.has_signal(auto_connect_parent_signal):
		return

	var callback := Callable(self, "_on_parent_triggered")
	if not parent_node.is_connected(auto_connect_parent_signal, callback):
		parent_node.connect(auto_connect_parent_signal, callback)


func _on_parent_triggered(_arg = null) -> void:
	trigger()


func trigger() -> void:
	pass
