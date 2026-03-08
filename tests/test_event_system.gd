extends Node

## Tests for GameEventBus and SequenceDirector

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
	test_trigger_emitters_avoid_legacy_generic_button_area_bus_events()
	test_composable_effect_prefers_typed_events_and_local_parent_signals()
	test_mansion_scene_wires_explicit_trigger_effect_components()
	test_level_keeps_only_shared_generic_routes()
	test_shared_events_trim_redundant_live_node_payloads()
	test_generic_key_collection_route_avoids_unused_body_payload()

	print("=== ALL EVENT SYSTEM TESTS COMPLETED ===")
	get_tree().quit()


func test_game_event_creation():
	print("\n--- Testing GameEvent Creation ---")
	
	var event = GameEvent.new(&"test_event", {"key": "value", "number": 42})
	
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
	
	var wait_action = SequenceAction.wait(2.5)
	assert(wait_action.action_type == SequenceAction.Type.WAIT, "Wait action type should match")
	assert(wait_action.duration == 2.5, "Wait duration should match")
	
	var text_action = SequenceAction.show_text("Hello World", 5.0)
	assert(text_action.action_type == SequenceAction.Type.SHOW_TEXT, "Show text action type should match")
	assert(text_action.text == "Hello World", "Text should match")
	assert(text_action.duration == 5.0, "Duration should match")
	
	var music_action = SequenceAction.play_music(null, -10.0)
	assert(music_action.action_type == SequenceAction.Type.PLAY_MUSIC, "Play music action type should match")
	assert(music_action.volume_db == -10.0, "Volume should match")
	
	print("✓ SequenceAction creation works correctly")


func test_sequence_data_builder():
	print("\n--- Testing SequenceData Builder ---")
	
	var sequence = SequenceData.create(&"test_sequence") \
		.wait(1.0) \
		.show_text("Step 1", 2.0) \
		.wait(0.5) \
		.show_text("Step 2", 2.0) \
		.set_skippable(false)
	
	assert(sequence.id == &"test_sequence", "Sequence ID should match")
	assert(sequence.actions.size() == 4, "Should have 4 actions")
	assert(sequence.skippable == false, "Should not be skippable")
	
	# Verify action types
	assert(sequence.actions[0].action_type == SequenceAction.Type.WAIT, "First action should be wait")
	assert(sequence.actions[1].action_type == SequenceAction.Type.SHOW_TEXT, "Second action should be show_text")
	
	print("✓ SequenceData builder works correctly")


func test_sequence_director_cancel_runs_async_cleanup() -> void:
	print("\n--- Testing SequenceDirector cancel awaits cleanup ---")

	var cleanup_state := {"completed": false}
	var sequence = SequenceData.create(&"cancel_cleanup_test") \
		.wait(3.0)
	sequence.add_cleanup(SequenceAction.custom(func():
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
	var sequence = SequenceData.create(&"skip_cleanup_test") \
		.wait(3.0) \
		.set_skippable(true)
	sequence.add_cleanup(SequenceAction.custom(func():
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
	Services.event_bus.subscribe(GameEventTypes.BUTTON_CHECK_TV, _on_domain_event)

	# Emit the domain-specific event
	Services.event_bus.emit(GameEventTypes.BUTTON_CHECK_TV, {
		"body": null
	})

	assert(domain_events_received.size() == 1, "Should receive 1 domain-specific event")
	assert(domain_events_received[0].event_type == GameEventTypes.BUTTON_CHECK_TV, "Event type should be BUTTON_CHECK_TV")

	# Cleanup
	Services.event_bus.unsubscribe(GameEventTypes.BUTTON_CHECK_TV, _on_domain_event)

	print("✓ Domain-specific event routing works correctly")


func test_trigger_emitters_avoid_legacy_generic_button_area_bus_events():
	print("\n--- Testing Trigger Emitters Avoid Legacy Generic Button/Area Bus Events ---")

	var button_file := FileAccess.open("res://scenes/objects/button.gd", FileAccess.READ)
	assert(button_file != null, "Should be able to open button.gd")
	var button_content := button_file.get_as_text()

	var area_file := FileAccess.open("res://scenes/objects/area_event.gd", FileAccess.READ)
	assert(area_file != null, "Should be able to open area_event.gd")
	var area_content := area_file.get_as_text()

	assert("signal button_pressed" in button_content, "button.gd should expose a local button_pressed signal")
	assert("button_pressed.emit(body)" in button_content, "button.gd should emit its local button_pressed signal")
	assert("GameEventTypes.BUTTON_PRESSED" not in button_content, "button.gd should not emit legacy BUTTON_PRESSED")
	assert('"button": self' not in button_content, "button.gd should not include the button node in typed event payloads")
	assert('"door": door_to_open' not in button_content, "button.gd should not include legacy door node payloads")
	assert('"camera": temporary_camera' not in button_content, "button.gd should not include legacy camera node payloads")

	assert("signal trigger_entered" in area_content, "area_event.gd should expose a local trigger_entered signal")
	assert("trigger_entered.emit(body)" in area_content, "area_event.gd should emit its local trigger_entered signal")
	assert("GameEventTypes.AREA_ENTERED" not in area_content, "area_event.gd should not emit legacy AREA_ENTERED")
	assert('"area": self' not in area_content, "area_event.gd should not include the area node in typed event payloads")
	assert('"door": door_to_open' not in area_content, "area_event.gd should not include legacy door node payloads")
	assert('"camera": temporary_camera' not in area_content, "area_event.gd should not include legacy camera node payloads")

	print("✓ Trigger emitters now use typed events and/or local effect signals")


func _on_domain_event(event: RefCounted) -> void:
	domain_events_received.append(event)


func _on_generic_event(event: RefCounted) -> void:
	generic_events_received.append(event)


func test_composable_effect_prefers_typed_events_and_local_parent_signals():
	print("\n--- Testing ComposableEffect Prefers Typed Events + Local Parent Signals ---")

	var file := FileAccess.open("res://scenes/components/effects/composable_effect.gd", FileAccess.READ)
	assert(file != null, "Should be able to open composable_effect.gd")
	var content := file.get_as_text()

	assert("return GameEventTypes.KEY_COLLECTED" in content, "ComposableEffect should retain KEY_COLLECTED fallback")
	assert("return \"button_pressed\"" in content, "ComposableEffect should infer button_pressed local signal")
	assert("return \"trigger_entered\"" in content, "ComposableEffect should infer trigger_entered local signal")
	assert("return GameEventTypes.BUTTON_PRESSED" not in content, "ComposableEffect should not fall back to BUTTON_PRESSED")
	assert("return GameEventTypes.AREA_ENTERED" not in content, "ComposableEffect should not fall back to AREA_ENTERED")

	print("✓ ComposableEffect now routes button/area effects without legacy generic bus events")


func test_mansion_scene_wires_explicit_trigger_effect_components():
	print("\n--- Testing Mansion Scene Wires Explicit Trigger Effect Components ---")

	var file := FileAccess.open("res://scenes/maps/mansion_1/mansion_1.tscn", FileAccess.READ)
	assert(file != null, "Should be able to open mansion_1.tscn")
	var content := file.get_as_text()

	var required_effect_nodes := [
		"NavigationRegion3D/Buttons/Button1",
		"NavigationRegion3D/Buttons/Button2",
		"NavigationRegion3D/Buttons/Button3",
		"NavigationRegion3D/Buttons/Button4",
		"NavigationRegion3D/Buttons/ToiletFlush",
		"NavigationRegion3D/AreaEvents/AreaEvent",
	]
	for trigger_path in required_effect_nodes:
		assert(trigger_path in content, "Scene should still include trigger %s" % trigger_path)

	assert("parent=\"NavigationRegion3D/Buttons/Button1\"" in content and "DoorOpenerEffect" in content, "Button1 should have a DoorOpenerEffect")
	assert("parent=\"NavigationRegion3D/Buttons/Button1\"" in content and "CameraSwitchEffect" in content, "Button1 should have a CameraSwitchEffect")
	assert("parent=\"NavigationRegion3D/Buttons/Button2\"" in content and "DoorOpenerEffect" in content, "Button2 should have a DoorOpenerEffect")
	assert("parent=\"NavigationRegion3D/Buttons/Button3\"" in content and "DoorOpenerEffect" in content, "Button3 should have a DoorOpenerEffect")
	assert("parent=\"NavigationRegion3D/Buttons/Button4\"" in content and "CameraSwitchEffect" in content, "Button4 should have a CameraSwitchEffect")
	assert("parent=\"NavigationRegion3D/Buttons/ToiletFlush\"" in content and "CameraSwitchEffect" in content, "ToiletFlush should have a CameraSwitchEffect")
	assert("parent=\"NavigationRegion3D/AreaEvents/AreaEvent\"" in content and "CameraSwitchEffect" in content, "AreaEvent should have a CameraSwitchEffect")
	assert("door_to_open = NodePath(" not in content, "Mansion scene should no longer serialize legacy button door references")
	assert("temporary_camera = NodePath(" not in content, "Mansion scene should no longer serialize legacy trigger camera references")

	print("✓ Mansion trigger instances now own explicit door/camera effects")


func test_level_keeps_only_shared_generic_routes():
	print("\n--- Testing Level Keeps Only Shared Generic Routes ---")

	var file := FileAccess.open("res://scenes/maps/level.gd", FileAccess.READ)
	assert(file != null, "Should be able to open level.gd")
	var content := file.get_as_text()

	assert("GameEventTypes.KEY_COLLECTED" in content, "Level should still subscribe to KEY_COLLECTED")
	assert("GameEventTypes.BUTTON_PRESSED" not in content, "Level should not subscribe to BUTTON_PRESSED anymore")
	assert("GameEventTypes.AREA_ENTERED" not in content, "Level should not subscribe to AREA_ENTERED anymore")
	assert('_handle_trigger_event' not in content, "Level should not keep generic trigger side-effect handling")
	assert('event.get_node("camera")' not in content, "Level should not read trigger cameras from generic payloads")
	assert('event.get_node("door")' not in content, "Level should not read trigger doors from generic payloads")

	print("✓ Level now keeps only shared generic routes such as key collection")


func test_shared_events_trim_redundant_live_node_payloads():
	print("\n--- Testing Shared Events Trim Redundant Live-Node Payloads ---")

	var door_file := FileAccess.open("res://scenes/objects/door.gd", FileAccess.READ)
	assert(door_file != null, "Should be able to open door.gd")
	var door_content := door_file.get_as_text()

	var input_file := FileAccess.open("res://scenes/components/input/player_input_component.gd", FileAccess.READ)
	assert(input_file != null, "Should be able to open player_input_component.gd")
	var input_content := input_file.get_as_text()

	var hud_file := FileAccess.open("res://scenes/hud.gd", FileAccess.READ)
	assert(hud_file != null, "Should be able to open hud.gd")
	var hud_content := hud_file.get_as_text()

	var sequence_file := FileAccess.open("res://scenes/services/sequence_director.gd", FileAccess.READ)
	assert(sequence_file != null, "Should be able to open sequence_director.gd")
	var sequence_content := sequence_file.get_as_text()

	var pickup_file := FileAccess.open("res://scenes/items/pickup_item.gd", FileAccess.READ)
	assert(pickup_file != null, "Should be able to open pickup_item.gd")
	var pickup_content := pickup_file.get_as_text()

	assert('"door": self' not in door_content, "DOOR_LOCKED should not include the door node in payload")
	assert('"player": player' not in input_content, "PLAYER_MODE_CHANGED should not include the player node in payload")
	assert('}, player)' in input_content, "PLAYER_MODE_CHANGED should identify the player via event.source")
	assert('payload.get("player", null)' not in hud_content, "HUD should not read player identity from payload")
	assert('event.source' in hud_content, "HUD should use event.source for player identity")
	assert('{"players": players}' not in sequence_content, "PLAYER_BLOCKED/UNBLOCKED should not include player node arrays in payload")
	assert('"player_count": players.size()' in sequence_content, "PLAYER_BLOCKED/UNBLOCKED should emit scalar metadata instead of node arrays")
	assert('"item": self' not in pickup_content, "ITEM_PICKEDUP should not include the item node in payload")
	assert('"body": body' not in pickup_content, "ITEM_PICKEDUP should not include the player node in payload")

	print("✓ Shared event payloads now avoid redundant live node references where consumers do not need them")


func test_generic_key_collection_route_avoids_unused_body_payload():
	print("\n--- Testing Generic Key Collection Route Avoids Unused Body Payload ---")

	var key_file := FileAccess.open("res://scenes/items/key.gd", FileAccess.READ)
	assert(key_file != null, "Should be able to open key.gd")
	var key_content := key_file.get_as_text()

	var level_file := FileAccess.open("res://scenes/maps/level.gd", FileAccess.READ)
	assert(level_file != null, "Should be able to open level.gd")
	var level_content := level_file.get_as_text()

	assert('Services.event_bus.emit(GameEventTypes.KEY_COLLECTED, {\n\t\t\t"body": body,' not in key_content,
		"Generic KEY_COLLECTED should not include the triggering player body in payload")
	assert('var body = event.get_body()' not in level_content, "Level generic key handler should not read an unused body from KEY_COLLECTED")
	assert('func _key_collected(key_type, message_text):' in level_content, "Level should use a key-specific shared handler without a body parameter")

	print("✓ Generic KEY_COLLECTED now carries only the shared data Level actually uses")
