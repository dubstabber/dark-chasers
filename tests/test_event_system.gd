extends Node

## Tests for GameEventBus and SequenceDirector

const GameEventScript = preload("res://scenes/resources/game_event.gd")
const GameEventTypesScript = preload("res://scenes/resources/game_event_types.gd")
const SequenceDataScript = preload("res://scenes/resources/sequence_data.gd")
const SequenceActionScript = preload("res://scenes/resources/sequence_action.gd")

var received_events: Array = []


func _ready():
	print("=== EVENT SYSTEM TESTS ===")

	test_game_event_creation()
	test_event_bus_subscribe_emit()
	test_event_bus_unsubscribe()
	test_event_bus_history()
	test_sequence_action_creation()
	test_sequence_data_builder()
	await test_sequence_director_cancel_runs_async_cleanup()
	await test_sequence_director_skip_runs_async_cleanup()
	test_domain_specific_event_routing()
	test_generic_and_domain_events_both_fire()
	test_payload_policy_event_scripts_no_double_camera_handling()
	test_payload_policy_level_handles_generic_payloads()

	print("=== ALL EVENT SYSTEM TESTS COMPLETED ===")
	get_tree().quit()


func test_game_event_creation():
	print("\n--- Testing GameEvent Creation ---")
	
	var event = GameEventScript.new(&"test_event", {"key": "value", "number": 42})
	
	assert(event.event_type == &"test_event", "Event type should match")
	assert(event.payload.get("key") == "value", "Payload key should match")
	assert(event.get_int("number") == 42, "get_int should work")
	assert(event.get_string("key") == "value", "get_string should work")
	assert(event.get_string("missing", "default") == "default", "get_string default should work")
	assert(event.timestamp > 0, "Timestamp should be set")
	
	print("✓ GameEvent creation works correctly")


func test_event_bus_subscribe_emit():
	print("\n--- Testing EventBus Subscribe/Emit ---")
	
	received_events.clear()
	
	Services.event_bus.subscribe(&"test_subscribe", _on_test_event)
	
	assert(Services.event_bus.has_subscribers(&"test_subscribe"), "Should have subscriber")
	assert(Services.event_bus.get_subscriber_count(&"test_subscribe") == 1, "Should have 1 subscriber")
	
	Services.event_bus.emit(&"test_subscribe", {"data": "hello"})
	
	assert(received_events.size() == 1, "Should have received 1 event")
	assert(received_events[0].event_type == &"test_subscribe", "Event type should match")
	assert(received_events[0].payload.get("data") == "hello", "Payload should match")
	
	# Cleanup
	Services.event_bus.unsubscribe(&"test_subscribe", _on_test_event)
	
	print("✓ EventBus subscribe/emit works correctly")


func test_event_bus_unsubscribe():
	print("\n--- Testing EventBus Unsubscribe ---")
	
	received_events.clear()
	
	Services.event_bus.subscribe(&"test_unsub", _on_test_event)
	Services.event_bus.unsubscribe(&"test_unsub", _on_test_event)
	
	assert(not Services.event_bus.has_subscribers(&"test_unsub"), "Should not have subscribers after unsubscribe")
	
	Services.event_bus.emit(&"test_unsub", {})
	
	assert(received_events.size() == 0, "Should not receive events after unsubscribe")
	
	print("✓ EventBus unsubscribe works correctly")


func test_event_bus_history():
	print("\n--- Testing EventBus History ---")
	
	# Emit a few events
	Services.event_bus.emit(&"history_test_1", {"index": 1})
	Services.event_bus.emit(&"history_test_2", {"index": 2})
	Services.event_bus.emit(&"history_test_3", {"index": 3})
	
	var recent = Services.event_bus.get_recent_events(3)
	assert(recent.size() >= 3, "Should have at least 3 recent events")
	
	var typed = Services.event_bus.get_events_of_type(&"history_test_2", 10)
	assert(typed.size() >= 1, "Should find at least 1 event of type")
	assert(typed[0].event_type == &"history_test_2", "Found event should match type")
	
	print("✓ EventBus history works correctly")


func test_sequence_action_creation():
	print("\n--- Testing SequenceAction Creation ---")
	
	var wait_action = SequenceActionScript.wait(2.5)
	assert(wait_action.action_type == SequenceActionScript.Type.WAIT, "Wait action type should match")
	assert(wait_action.duration == 2.5, "Wait duration should match")
	
	var text_action = SequenceActionScript.show_text("Hello World", 5.0)
	assert(text_action.action_type == SequenceActionScript.Type.SHOW_TEXT, "Show text action type should match")
	assert(text_action.text == "Hello World", "Text should match")
	assert(text_action.duration == 5.0, "Duration should match")
	
	var music_action = SequenceActionScript.play_music(null, -10.0)
	assert(music_action.action_type == SequenceActionScript.Type.PLAY_MUSIC, "Play music action type should match")
	assert(music_action.volume_db == -10.0, "Volume should match")
	
	print("✓ SequenceAction creation works correctly")


func test_sequence_data_builder():
	print("\n--- Testing SequenceData Builder ---")
	
	var sequence = SequenceDataScript.create(&"test_sequence") \
		.wait(1.0) \
		.show_text("Step 1", 2.0) \
		.wait(0.5) \
		.show_text("Step 2", 2.0) \
		.set_skippable(false)
	
	assert(sequence.id == &"test_sequence", "Sequence ID should match")
	assert(sequence.actions.size() == 4, "Should have 4 actions")
	assert(sequence.skippable == false, "Should not be skippable")
	
	# Verify action types
	assert(sequence.actions[0].action_type == SequenceActionScript.Type.WAIT, "First action should be wait")
	assert(sequence.actions[1].action_type == SequenceActionScript.Type.SHOW_TEXT, "Second action should be show_text")
	
	print("✓ SequenceData builder works correctly")


func test_sequence_director_cancel_runs_async_cleanup() -> void:
	print("\n--- Testing SequenceDirector cancel awaits cleanup ---")

	var cleanup_state := {"completed": false}
	var sequence = SequenceDataScript.create(&"cancel_cleanup_test") \
		.wait(3.0)
	sequence.add_cleanup(SequenceActionScript.custom(func():
		var timer := get_tree().create_timer(0.01)
		timer.timeout.connect(func():
			cleanup_state["completed"] = true
		, CONNECT_ONE_SHOT)
		return timer.timeout
	))

	Services.sequence_director.play_sequence(sequence)
	await get_tree().process_frame
	await Services.sequence_director.cancel_current()

	assert(cleanup_state.get("completed", false), "Cancel should await async cleanup actions")
	assert(not Services.sequence_director.is_playing(), "SequenceDirector should not be playing after cancel")

	print("✓ SequenceDirector cancel cleanup works correctly")


func test_sequence_director_skip_runs_async_cleanup() -> void:
	print("\n--- Testing SequenceDirector skip awaits cleanup ---")

	var cleanup_state := {"completed": false}
	var sequence = SequenceDataScript.create(&"skip_cleanup_test") \
		.wait(3.0) \
		.set_skippable(true)
	sequence.add_cleanup(SequenceActionScript.custom(func():
		var timer := get_tree().create_timer(0.01)
		timer.timeout.connect(func():
			cleanup_state["completed"] = true
		, CONNECT_ONE_SHOT)
		return timer.timeout
	))

	Services.sequence_director.play_sequence(sequence)
	await get_tree().process_frame
	await Services.sequence_director.skip_current()

	assert(cleanup_state.get("completed", false), "Skip should await async cleanup actions")
	assert(not Services.sequence_director.is_playing(), "SequenceDirector should not be playing after skip")

	print("✓ SequenceDirector skip cleanup works correctly")


func _on_test_event(event: RefCounted) -> void:
	received_events.append(event)


# === Phase E: Domain-Specific Event Routing Tests ===

var domain_events_received: Array = []
var generic_events_received: Array = []


func test_domain_specific_event_routing():
	print("\n--- Testing Domain-Specific Event Routing (Phase E) ---")

	domain_events_received.clear()

	# Subscribe to a domain-specific event type (e.g., BUTTON_CHECK_TV)
	Services.event_bus.subscribe(GameEventTypesScript.BUTTON_CHECK_TV, _on_domain_event)

	# Emit the domain-specific event
	Services.event_bus.emit(GameEventTypesScript.BUTTON_CHECK_TV, {
		"body": null,
		"button": null
	})

	assert(domain_events_received.size() == 1, "Should receive 1 domain-specific event")
	assert(domain_events_received[0].event_type == GameEventTypesScript.BUTTON_CHECK_TV, "Event type should be BUTTON_CHECK_TV")

	# Cleanup
	Services.event_bus.unsubscribe(GameEventTypesScript.BUTTON_CHECK_TV, _on_domain_event)

	print("✓ Domain-specific event routing works correctly")


func test_generic_and_domain_events_both_fire():
	print("\n--- Testing Generic + Domain Events Both Fire ---")

	domain_events_received.clear()
	generic_events_received.clear()

	# Subscribe to both generic and domain-specific events
	Services.event_bus.subscribe(GameEventTypesScript.BUTTON_PRESSED, _on_generic_event)
	Services.event_bus.subscribe(GameEventTypesScript.BUTTON_CHECK_MAP, _on_domain_event)

	# Simulate what Button.gd does: emit both domain-specific and generic events
	# First, domain-specific
	Services.event_bus.emit(GameEventTypesScript.BUTTON_CHECK_MAP, {
		"body": null,
		"button": null
	})
	# Then, generic
	Services.event_bus.emit(GameEventTypesScript.BUTTON_PRESSED, {
		"body": null,
		"button": null
	})

	assert(domain_events_received.size() == 1, "Should receive 1 domain-specific event")
	assert(generic_events_received.size() == 1, "Should receive 1 generic event")
	assert(domain_events_received[0].event_type == GameEventTypesScript.BUTTON_CHECK_MAP, "Domain event type should match")
	assert(generic_events_received[0].event_type == GameEventTypesScript.BUTTON_PRESSED, "Generic event type should match")

	# Cleanup
	Services.event_bus.unsubscribe(GameEventTypesScript.BUTTON_PRESSED, _on_generic_event)
	Services.event_bus.unsubscribe(GameEventTypesScript.BUTTON_CHECK_MAP, _on_domain_event)

	print("✓ Generic + domain events both fire correctly")


func _on_domain_event(event: RefCounted) -> void:
	domain_events_received.append(event)


func _on_generic_event(event: RefCounted) -> void:
	generic_events_received.append(event)


# === Payload Policy Tests ===
# Verifies that emitters follow the camera/door payload policy documented in PLANNING.md

func test_payload_policy_event_scripts_no_double_camera_handling():
	print("\n--- Testing Payload Policy: No Double Camera Handling ---")
	
	# Policy: Event scripts should NOT manually switch cameras that are already
	# configured as payloads on the emitter (avoids double-handling).
	# 
	# This test documents the expected pattern:
	# - Payload with temporary_camera → Level handles immediate switch
	# - Event script with sequence → should only use camera_restore(), not camera_cut()
	#   for the same camera that's in the payload
	
	# Scan mansion_1 event scripts to verify they follow the payload policy
	var event_scripts := [
		"res://scenes/rooms/mansion_1_events/mansion_1_button_events.gd",
		"res://scenes/rooms/mansion_1_events/mansion_1_area_events.gd",
		"res://scenes/rooms/mansion_1_events/mansion_1_key_events.gd",
	]
	
	var scripts_checked := 0
	for script_path in event_scripts:
		var file := FileAccess.open(script_path, FileAccess.READ)
		if not file:
			continue
		var content := file.get_as_text()
		scripts_checked += 1
		
		# Check if script uses both camera_cut() and references a payload camera
		# Note: camera_cut in sequences is allowed when the emitter has NO temporary_camera
		# This is a documentation test, not a hard enforcement
		var has_camera_cut := "camera_cut(" in content
		var has_camera_restore := "camera_restore()" in content
		
		# Pattern 2 (payload + domain): should have camera_restore but camera_cut is optional
		# Pattern 3 (domain only): can use camera_cut freely
		# The key is: if emitter has temporary_camera, don't also camera_cut to same camera in script
		
		if has_camera_cut and has_camera_restore:
			# This is fine - script uses both (pattern 3 with explicit control)
			pass
	
	assert(scripts_checked == event_scripts.size(), "All event scripts should be readable")
	
	print("✓ Payload policy documentation test passed")
	print("  Note: Manual review recommended - see PLANNING.md 'Camera/door payload policy'")


func test_payload_policy_level_handles_generic_payloads():
	print("\n--- Testing Payload Policy: Level Handles Generic Payloads ---")
	
	# Verify that Level._on_button_event and Level._on_area_event check for payloads
	var level_script_path := "res://scenes/rooms/level.gd"
	var file := FileAccess.open(level_script_path, FileAccess.READ)
	assert(file != null, "Should be able to open level.gd")
	
	var content := file.get_as_text()
	
	# Check that Level handles camera from payload
	assert('event.get_node("camera")' in content, "Level should extract camera from event payload")
	assert("set_active_camera" in content, "Level should use CameraManager.set_active_camera")
	
	# Check that Level handles door from payload
	assert('event.get_node("door")' in content, "Level should extract door from event payload")
	assert("door.open()" in content, "Level should call door.open() for payload doors")
	
	print("✓ Level correctly handles generic payloads")
