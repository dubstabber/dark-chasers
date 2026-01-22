class_name GameEvent
extends RefCounted

## Typed game event for the event bus system.
## Replaces string-based event routing with structured, typed events.

var event_type: StringName
var payload: Dictionary
var source: Node
var timestamp: float

func _init(p_event_type: StringName, p_payload: Dictionary = {}, p_source: Node = null) -> void:
	event_type = p_event_type
	payload = p_payload
	source = p_source
	timestamp = Time.get_ticks_msec() / 1000.0


func get_body() -> Node:
	return payload.get("body")


func get_string(key: String, default: String = "") -> String:
	return payload.get(key, default)


func get_int(key: String, default: int = 0) -> int:
	return payload.get(key, default)


func get_float(key: String, default: float = 0.0) -> float:
	return payload.get(key, default)


func get_vector3(key: String, default: Vector3 = Vector3.ZERO) -> Vector3:
	return payload.get(key, default)


func get_node(key: String) -> Node:
	return payload.get(key)
