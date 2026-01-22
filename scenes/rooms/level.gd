class_name Level extends Node3D

const GameEventTypesScript = preload("res://scenes/resources/game_event_types.gd")

# Base key collection system - can be overridden by specific maps
var keys_collected: Array = []

@onready var hud = $HUD
@onready var transitions = get_node_or_null("%Transitions")
@onready var player_spawners = get_node_or_null("%PlayerSpawners")
@onready var players = get_node_or_null("%Players")
@onready var enemies = get_node_or_null("%Enemies")


func _ready():
	# Register with context services (replaces group-based discovery)
	WorldContext.set_level_node(self)
	if players:
		EnemyContext.set_players_node(players)
	if transitions:
		EnemyContext.set_transitions_node(transitions)
	
	# Keep groups as fallback/debug convenience (can be removed later)
	add_to_group("level")
	if hud:
		hud.add_to_group("hud")

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Subscribe to typed events from GameEventBus (replaces group-based signal wiring)
	GameEventBus.subscribe(GameEventTypesScript.KEY_COLLECTED, _on_key_event)
	GameEventBus.subscribe(GameEventTypesScript.BUTTON_PRESSED, _on_button_event)
	GameEventBus.subscribe(GameEventTypesScript.AREA_ENTERED, _on_area_event)
	
	# Door locked signals - Openable class has door_locked signal
	var doors = get_tree().get_nodes_in_group("door")
	for door in doors:
		if door is Openable:
			door.door_locked.connect(_door_locked)
	
	# Item pickup signals still use group discovery (items don't emit to event bus yet)
	var items = get_tree().get_nodes_in_group("item")
	for item in items:
		item.connect("item_pickedup", hud.add_log)
	
	if transitions:
		for t in transitions.get_children():
			for m in t.get_children():
				if m.is_in_group("spawn_point"):
					t.connect("body_entered", handle_transition.bind(t.name, m))
				if m.is_in_group("manual_spawn_point"):
					t.connect("body_entered", _on_transition_entered.bind(m))
					t.connect("body_exited", _on_transition_exited)


func _exit_tree():
	# Unsubscribe from event bus when level is removed
	GameEventBus.unsubscribe(GameEventTypesScript.KEY_COLLECTED, _on_key_event)
	GameEventBus.unsubscribe(GameEventTypesScript.BUTTON_PRESSED, _on_button_event)
	GameEventBus.unsubscribe(GameEventTypesScript.AREA_ENTERED, _on_area_event)


# Typed event handlers - extract data from GameEvent and delegate to legacy handlers
func _on_key_event(event: RefCounted) -> void:
	var body = event.get_body()
	var key_type = event.get_string("key_type")
	var event_name = event.get_string("event_name")
	var message = event.get_string("message")
	_key_body_entered(body, key_type, event_name, message)


func _on_button_event(event: RefCounted) -> void:
	var body = event.get_body()
	var event_name = event.get_string("event_name")
	_handle_button_event(body, event_name)


func _on_area_event(event: RefCounted) -> void:
	var body = event.get_body()
	var event_name = event.get_string("event_name")
	_handle_area_event(body, event_name)


# App-level input (quit/fullscreen) is now handled by InputRouter autoload


func handle_transition(body, area3dname, marker):
	if not "current_room" in body:
		push_warning("handle_transition: body has no current_room property: %s" % body.name)
		return
	
	var from_room = body.current_room
	if from_room == "" or from_room == null:
		push_warning("handle_transition: body.current_room is empty for %s" % body.name)
		return
	
	if from_room not in transitions.map_transitions:
		push_warning("handle_transition: from_room '%s' not in map_transitions for %s" % [from_room, body.name])
		return
	
	if area3dname not in transitions.map_transitions[from_room]:
		push_warning("handle_transition: transition '%s' not found from room '%s' for %s" % [area3dname, from_room, body.name])
		return
	
	var to_room = transitions.map_transitions[from_room][area3dname]
	body.current_room = to_room
	body.global_position = marker.global_position
	
	if "find_path_timer" in body:
		body.find_path_timer.wait_time = 0.1
		body.find_path_timer.start()


func _on_transition_entered(body, transitor):
	if body.is_in_group("player") and transitor:
		if body.has_node("InteractionComponent"):
			body.interaction_component.set_transit_point(transitor)


func _on_transition_exited(body):
	if body.is_in_group("player"):
		if body.has_node("InteractionComponent"):
			body.interaction_component.clear_transit_point()


func _key_body_entered(body, key_type, event, message_text):
	# Add log message to HUD
	if hud and hud.has_method("add_log"):
		hud.add_log(message_text)

	# Add key to collection if not already collected
	if key_type and key_type not in keys_collected:
		keys_collected.push_back(key_type)

		# Update the key display in the HUD
		if hud and hud.has_method("update_keys_display"):
			hud.update_keys_display(keys_collected)

	# Handle any specific events (can be overridden by child classes)
	_handle_key_event(body, key_type, event, message_text)


func _handle_key_event(_body, _key_type, _event, _message_text):
	"""Override this method in specific maps to handle key-specific events"""
	pass


func setup_player(player: CharacterBody3D) -> void:
	"""Centralized player setup - connects HUD and performs standard initialization
	
	Call this from spawn_player() in child level scripts instead of manually
	setting player.hud = hud. This centralizes the player-HUD integration and
	allows for future extensions without modifying every level script.
	
	Args:
		player: The player instance to set up
	"""
	if hud:
		player.hud = hud
	
	# Add player to "player" group if not already
	if not player.is_in_group("player"):
		player.add_to_group("player")


func refresh_key_display():
	"""Manually refresh the key display - useful for testing or when keys are added programmatically"""
	if hud and hud.has_method("update_keys_display"):
		hud.update_keys_display(keys_collected)
func _handle_button_event(_body, _event): pass
func _handle_area_event(_body: CharacterBody3D, _event): pass
func _door_locked(_text, _triggering_player): pass
