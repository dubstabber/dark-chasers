class_name ComposableEffect
extends Node

## Base composable effect that can auto-connect to a parent signal and trigger itself.

@export var auto_connect_parent_signal: String = "button_pressed"

var _subscribed_event_type: StringName = &""


func _ready() -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return

	_subscribed_event_type = _resolve_parent_event_type(parent_node)
	if _subscribed_event_type != &"":
		Services.event_bus.subscribe(_subscribed_event_type, _on_parent_event)
		return

	var parent_signal := _resolve_parent_signal(parent_node)
	if parent_signal == "":
		return
	if not parent_node.has_signal(parent_signal):
		return

	var callback := Callable(self, "_on_parent_triggered")
	if not parent_node.is_connected(parent_signal, callback):
		parent_node.connect(parent_signal, callback)


func _exit_tree() -> void:
	if _subscribed_event_type != &"":
		Services.event_bus.unsubscribe(_subscribed_event_type, _on_parent_event)
		_subscribed_event_type = &""


func _on_parent_event(event: RefCounted) -> void:
	if not event:
		return
	if event.source != get_parent():
		return
	trigger()


func _resolve_parent_event_type(parent_node: Node) -> StringName:
	var configured_event_type: Variant = parent_node.get("event_type_id")
	if configured_event_type is StringName and configured_event_type != &"":
		return configured_event_type

	var parent_script := parent_node.get_script() as Script
	if not parent_script:
		return &""

	match parent_script.resource_path:
		"res://scenes/items/key.gd":
			return GameEventTypes.KEY_COLLECTED

	return &""


func _resolve_parent_signal(parent_node: Node) -> String:
	if auto_connect_parent_signal != "" and parent_node.has_signal(auto_connect_parent_signal):
		return auto_connect_parent_signal

	var parent_script := parent_node.get_script() as Script
	if not parent_script:
		return ""

	match parent_script.resource_path:
		"res://scenes/objects/button.gd":
			return "button_pressed"
		"res://scenes/objects/area_event.gd":
			return "trigger_entered"

	return ""


func _on_parent_triggered(_arg = null) -> void:
	trigger()


func trigger() -> void:
	pass
