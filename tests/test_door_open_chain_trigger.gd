extends Node

var _door_opened_events: Array[RefCounted] = []
var _chain_events: Array[RefCounted] = []


func _ready() -> void:
	print("=== DOOR OPEN CHAIN TRIGGER TESTS ===")
	await _test_door_emits_opened_event_on_open_completion()
	_test_chain_trigger_requires_order_and_fires_once()
	_test_chain_trigger_can_disable_player_requirement()
	print("=== DOOR OPEN CHAIN TRIGGER TESTS COMPLETED ===")
	get_tree().quit()


func _test_door_emits_opened_event_on_open_completion() -> void:
	print("\n--- Testing DOOR_OPENED emission on open completion ---")

	_door_opened_events.clear()
	Services.event_bus.subscribe(GameEventTypes.DOOR_OPENED, _on_door_opened_event)

	var door_scene := load("res://scenes/objects/ao_moving_wall9.tscn") as PackedScene
	var door := door_scene.instantiate() as Door
	add_child(door)
	await get_tree().process_frame

	door.open()
	var timeout_at := Time.get_ticks_msec() + 3500
	while _door_opened_events.is_empty() and Time.get_ticks_msec() < timeout_at:
		await get_tree().process_frame

	Services.event_bus.unsubscribe(GameEventTypes.DOOR_OPENED, _on_door_opened_event)

	assert(_door_opened_events.size() == 1, "Door should emit exactly one DOOR_OPENED event after opening")
	assert(_door_opened_events[0].source == door, "DOOR_OPENED event source should be the opened door")
	assert(not _door_opened_events[0].payload.has("door"), "DOOR_OPENED should not include a redundant door node payload")
	assert(_door_opened_events[0].payload.get("triggering_player") == null, "Button/force opens should not attribute a triggering player")

	door.queue_free()
	await get_tree().process_frame

	print("✓ DOOR_OPENED emits on successful open completion")


func _test_chain_trigger_requires_order_and_fires_once() -> void:
	print("\n--- Testing ordered one-shot chain trigger behavior ---")

	_chain_events.clear()
	Services.event_bus.subscribe(&"test_chain_result", _on_chain_result_event)

	var trigger = load("res://scenes/components/door/door_open_chain_trigger.gd").new()
	var prerequisite_door := Door.new()
	var completion_door := Door.new()
	var player := Player.new()

	trigger.event_type_id = &"test_chain_result"
	trigger.prerequisite_door = prerequisite_door
	trigger.completion_door = completion_door
	add_child(trigger)

	Services.event_bus.emit(GameEventTypes.DOOR_OPENED, {
		"triggering_player": player
	}, completion_door)
	assert(_chain_events.is_empty(), "Completion door should not fire before prerequisite door opens")

	Services.event_bus.emit(GameEventTypes.DOOR_OPENED, {}, prerequisite_door)
	assert(_chain_events.is_empty(), "Prerequisite door should only arm the chain")

	Services.event_bus.emit(GameEventTypes.DOOR_OPENED, {}, completion_door)
	assert(_chain_events.is_empty(), "Completion should not fire without a player when player requirement is enabled")

	Services.event_bus.emit(GameEventTypes.DOOR_OPENED, {
		"triggering_player": player
	}, completion_door)
	assert(_chain_events.size() == 1, "Completion after prerequisite should fire exactly once")
	assert(_chain_events[0].source == trigger, "Chain result event source should be the trigger node")
	assert(_chain_events[0].payload.get("triggering_player") == player, "Chain result event should forward the triggering player")

	Services.event_bus.emit(GameEventTypes.DOOR_OPENED, {
		"triggering_player": player
	}, completion_door)
	assert(_chain_events.size() == 1, "One-shot chain trigger should not fire again after first completion")

	Services.event_bus.unsubscribe(&"test_chain_result", _on_chain_result_event)
	trigger.queue_free()
	prerequisite_door.free()
	completion_door.free()
	player.free()

	print("✓ Ordered one-shot chain behavior works correctly")


func _test_chain_trigger_can_disable_player_requirement() -> void:
	print("\n--- Testing chain trigger can disable player requirement ---")

	_chain_events.clear()
	Services.event_bus.subscribe(&"test_chain_result_no_player", _on_chain_result_event)

	var trigger = load("res://scenes/components/door/door_open_chain_trigger.gd").new()
	var prerequisite_door := Door.new()
	var completion_door := Door.new()
	var opener := CharacterBody3D.new()

	trigger.event_type_id = &"test_chain_result_no_player"
	trigger.prerequisite_door = prerequisite_door
	trigger.completion_door = completion_door
	trigger.require_player_for_completion = false
	add_child(trigger)

	Services.event_bus.emit(GameEventTypes.DOOR_OPENED, {}, prerequisite_door)
	Services.event_bus.emit(GameEventTypes.DOOR_OPENED, {
		"triggering_player": opener
	}, completion_door)

	assert(_chain_events.size() == 1, "Disabling player requirement should allow any CharacterBody3D opener")
	assert(_chain_events[0].payload.get("triggering_player") == opener, "Chain result should preserve the non-player opener when allowed")

	Services.event_bus.unsubscribe(&"test_chain_result_no_player", _on_chain_result_event)
	trigger.queue_free()
	prerequisite_door.free()
	completion_door.free()
	opener.free()

	print("✓ Player requirement can be disabled when desired")


func _on_door_opened_event(event: RefCounted) -> void:
	_door_opened_events.append(event)


func _on_chain_result_event(event: RefCounted) -> void:
	_chain_events.append(event)
