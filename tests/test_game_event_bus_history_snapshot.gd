extends SceneTree

const GameEventBusScript = preload("res://scenes/services/game_event_bus.gd")

var _failed := false


func _init() -> void:
	print("=== GAME EVENT BUS HISTORY SNAPSHOT TESTS ===")
	_test_history_snapshot_sanitizes_node_references()
	print("=== GAME EVENT BUS HISTORY SNAPSHOT TESTS COMPLETED ===")
	quit(1 if _failed else 0)


func _test_history_snapshot_sanitizes_node_references() -> void:
	print("\n--- Testing history snapshot sanitization ---")

	var bus := GameEventBusScript.new()
	var marker_node := Node.new()
	marker_node.name = "history_snapshot_marker"

	bus.emit(&"history_snapshot_test", {
		"index": 99,
		"node_ref": marker_node,
		"nested": {
			"node": marker_node,
		},
	}, marker_node)

	var typed := bus.get_events_of_type(&"history_snapshot_test", 1)
	_assert(typed.size() == 1, "Should find history snapshot event")

	var snapshot: RefCounted = typed[0]
	_assert(snapshot.source == null, "History snapshot should clear event source reference")

	var node_ref_snapshot: Variant = snapshot.payload.get("node_ref")
	_assert(node_ref_snapshot is Dictionary, "Node payload should be sanitized to dictionary metadata")
	_assert(node_ref_snapshot.get("_type") == "Node", "Sanitized node payload should mark Node type")

	var nested_snapshot: Variant = snapshot.payload.get("nested")
	_assert(nested_snapshot is Dictionary, "Nested payload should remain dictionary snapshot")
	_assert(nested_snapshot.get("node", {}).get("_type") == "Node", "Nested node payload should be sanitized")

	marker_node.free()
	bus.free()

	print("✓ History snapshot sanitizes node/source references")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("ASSERT FAILED: " + message)
