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
	test_domain_specific_event_routing()
	test_generic_and_domain_events_both_fire()

	print("=== ALL EVENT SYSTEM TESTS COMPLETED ===")


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
	
	GameEventBus.subscribe(&"test_subscribe", _on_test_event)
	
	assert(GameEventBus.has_subscribers(&"test_subscribe"), "Should have subscriber")
	assert(GameEventBus.get_subscriber_count(&"test_subscribe") == 1, "Should have 1 subscriber")
	
	GameEventBus.emit(&"test_subscribe", {"data": "hello"})
	
	assert(received_events.size() == 1, "Should have received 1 event")
	assert(received_events[0].event_type == &"test_subscribe", "Event type should match")
	assert(received_events[0].payload.get("data") == "hello", "Payload should match")
	
	# Cleanup
	GameEventBus.unsubscribe(&"test_subscribe", _on_test_event)
	
	print("✓ EventBus subscribe/emit works correctly")


func test_event_bus_unsubscribe():
	print("\n--- Testing EventBus Unsubscribe ---")
	
	received_events.clear()
	
	GameEventBus.subscribe(&"test_unsub", _on_test_event)
	GameEventBus.unsubscribe(&"test_unsub", _on_test_event)
	
	assert(not GameEventBus.has_subscribers(&"test_unsub"), "Should not have subscribers after unsubscribe")
	
	GameEventBus.emit(&"test_unsub", {})
	
	assert(received_events.size() == 0, "Should not receive events after unsubscribe")
	
	print("✓ EventBus unsubscribe works correctly")


func test_event_bus_history():
	print("\n--- Testing EventBus History ---")
	
	# Emit a few events
	GameEventBus.emit(&"history_test_1", {"index": 1})
	GameEventBus.emit(&"history_test_2", {"index": 2})
	GameEventBus.emit(&"history_test_3", {"index": 3})
	
	var recent = GameEventBus.get_recent_events(3)
	assert(recent.size() >= 3, "Should have at least 3 recent events")
	
	var typed = GameEventBus.get_events_of_type(&"history_test_2", 10)
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


func _on_test_event(event: RefCounted) -> void:
	received_events.append(event)


# === Phase E: Domain-Specific Event Routing Tests ===

var domain_events_received: Array = []
var generic_events_received: Array = []


func test_domain_specific_event_routing():
	print("\n--- Testing Domain-Specific Event Routing (Phase E) ---")

	domain_events_received.clear()

	# Subscribe to a domain-specific event type (e.g., BUTTON_CHECK_TV)
	GameEventBus.subscribe(GameEventTypesScript.BUTTON_CHECK_TV, _on_domain_event)

	# Emit the domain-specific event
	GameEventBus.emit(GameEventTypesScript.BUTTON_CHECK_TV, {
		"body": null,
		"button": null
	})

	assert(domain_events_received.size() == 1, "Should receive 1 domain-specific event")
	assert(domain_events_received[0].event_type == GameEventTypesScript.BUTTON_CHECK_TV, "Event type should be BUTTON_CHECK_TV")

	# Cleanup
	GameEventBus.unsubscribe(GameEventTypesScript.BUTTON_CHECK_TV, _on_domain_event)

	print("✓ Domain-specific event routing works correctly")


func test_generic_and_domain_events_both_fire():
	print("\n--- Testing Generic + Domain Events Both Fire ---")

	domain_events_received.clear()
	generic_events_received.clear()

	# Subscribe to both generic and domain-specific events
	GameEventBus.subscribe(GameEventTypesScript.BUTTON_PRESSED, _on_generic_event)
	GameEventBus.subscribe(GameEventTypesScript.BUTTON_CHECK_MAP, _on_domain_event)

	# Simulate what Button.gd does: emit both domain-specific and generic events
	# First, domain-specific
	GameEventBus.emit(GameEventTypesScript.BUTTON_CHECK_MAP, {
		"body": null,
		"button": null
	})
	# Then, generic
	GameEventBus.emit(GameEventTypesScript.BUTTON_PRESSED, {
		"body": null,
		"button": null
	})

	assert(domain_events_received.size() == 1, "Should receive 1 domain-specific event")
	assert(generic_events_received.size() == 1, "Should receive 1 generic event")
	assert(domain_events_received[0].event_type == GameEventTypesScript.BUTTON_CHECK_MAP, "Domain event type should match")
	assert(generic_events_received[0].event_type == GameEventTypesScript.BUTTON_PRESSED, "Generic event type should match")

	# Cleanup
	GameEventBus.unsubscribe(GameEventTypesScript.BUTTON_PRESSED, _on_generic_event)
	GameEventBus.unsubscribe(GameEventTypesScript.BUTTON_CHECK_MAP, _on_domain_event)

	print("✓ Generic + domain events both fire correctly")


func _on_domain_event(event: RefCounted) -> void:
	domain_events_received.append(event)


func _on_generic_event(event: RefCounted) -> void:
	generic_events_received.append(event)
