class_name Level extends Node3D

const GameEventTypesScript = preload("res://scenes/resources/game_event_types.gd")

# Base key collection system - can be overridden by specific maps
var keys_collected: Array = []

@onready var hud = $HUD
@onready var transitions = get_node_or_null("%Transitions")
@onready var player_spawners = get_node_or_null("%PlayerSpawners")
@onready var players = get_node_or_null("%Players")
@onready var enemies = get_node_or_null("%Enemies")
@onready var corpses = get_node_or_null("%Corpses")


func _ready():
	# Register with context services (replaces group-based discovery)
	Services.world_context.set_level_node(self)
	if players:
		Services.enemy_context.set_players_node(players)
	if transitions:
		Services.enemy_context.set_transitions_node(transitions)
	
	# Keep groups as fallback/debug convenience (can be removed later)
	add_to_group("level")
	if hud:
		hud.add_to_group("hud")

	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Subscribe to typed events from GameEventBus (replaces group-based signal wiring)
	Services.event_bus.subscribe(GameEventTypesScript.KEY_COLLECTED, _on_key_event)
	Services.event_bus.subscribe(GameEventTypesScript.BUTTON_PRESSED, _on_button_event)
	Services.event_bus.subscribe(GameEventTypesScript.AREA_ENTERED, _on_area_event)
	Services.event_bus.subscribe(GameEventTypesScript.DOOR_LOCKED, _on_door_locked_event)
	Services.event_bus.subscribe(GameEventTypesScript.ITEM_PICKEDUP, _on_item_pickedup_event)
	
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
	Services.event_bus.unsubscribe(GameEventTypesScript.KEY_COLLECTED, _on_key_event)
	Services.event_bus.unsubscribe(GameEventTypesScript.BUTTON_PRESSED, _on_button_event)
	Services.event_bus.unsubscribe(GameEventTypesScript.AREA_ENTERED, _on_area_event)
	Services.event_bus.unsubscribe(GameEventTypesScript.DOOR_LOCKED, _on_door_locked_event)
	Services.event_bus.unsubscribe(GameEventTypesScript.ITEM_PICKEDUP, _on_item_pickedup_event)


# === GENERIC EVENT HANDLERS ===
# These handle common patterns from generic events (KEY_COLLECTED, BUTTON_PRESSED, AREA_ENTERED).
# Child classes should subscribe to domain-specific events (e.g., BUTTON_CHECK_TV) directly
# instead of overriding _handle_*_event methods.

func _on_key_event(event: RefCounted) -> void:
	var body = event.get_body()
	var key_type = event.get_string("key_type")
	var message = event.get_string("message")
	_key_body_entered(body, key_type, message)


func _on_button_event(event: RefCounted) -> void:
	_handle_trigger_event(event)


func _on_area_event(event: RefCounted) -> void:
	_handle_trigger_event(event)


func _handle_trigger_event(event: RefCounted) -> void:
	# Handle camera switching if event has a camera configured
	var camera = event.get_node("camera")
	if camera:
		Services.camera_manager.set_active_camera(camera)

	# Handle door opening if event has a door configured
	var door = event.get_node("door")
	if door and door is Openable:
		door.open()


func _on_door_locked_event(event: RefCounted) -> void:
	var text = event.get_string("text")
	var triggering_player = event.payload.get("triggering_player")
	_door_locked(text, triggering_player)


func _on_item_pickedup_event(event: RefCounted) -> void:
	var message = event.get_string("message")
	if hud and message:
		hud.add_log(message)


# App-level input (quit/fullscreen) is now handled by InputRouter autoload


func handle_transition(body, area3dname, marker):
	# Use RoomAware interface for room-based transitions
	if not RoomAware.check(body):
		push_warning("handle_transition: body is not RoomAware: %s" % body.name)
		return

	var from_room = RoomAware.get_current_room(body)
	if from_room == "" or from_room == null:
		push_warning("handle_transition: body.current_room is empty for %s" % body.name)
		return

	var map_transitions = TransitionsData.get_map_transitions(transitions)
	if from_room not in map_transitions:
		push_warning("handle_transition: from_room '%s' not in map_transitions for %s" % [from_room, body.name])
		return

	if area3dname not in map_transitions[from_room]:
		push_warning("handle_transition: transition '%s' not found from room '%s' for %s" % [area3dname, from_room, body.name])
		return

	var to_room = map_transitions[from_room][area3dname]
	RoomAware.set_current_room(body, to_room)
	body.global_position = marker.global_position

	# Use PathfindingEntity interface to make pathfinding responsive after transition
	PathfindingEntity.make_responsive(body)


func _on_transition_entered(body, transitor):
	if body is Player and transitor:
		if body.interaction_component:
			body.interaction_component.set_transit_point(transitor)


func _on_transition_exited(body):
	if body is Player:
		if body.interaction_component:
			body.interaction_component.clear_transit_point()


func _key_body_entered(_body, key_type, message_text):
	# Add log message to HUD
	if hud:
		hud.add_log(message_text)

	# Add key to collection if not already collected
	if key_type and key_type != "useless" and key_type not in keys_collected:
		keys_collected.push_back(key_type)

		# Update the key display in the HUD
		if hud:
			hud.update_keys_display(keys_collected)


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
	if hud:
		hud.update_keys_display(keys_collected)


func _door_locked(_text, _triggering_player): pass


func spawn_player() -> void:
	"""Virtual: Override in subclass for custom spawn behavior.
	
	Default implementation instantiates a player from the scene catalog,
	adds it to the players node, and respawns at a random spawner.
	Subclasses like mansion_1 override this for custom intro sequences.
	"""
	var player = Services.preloads.get_scene_catalog().player_scene.instantiate() as Player
	players.add_child(player)
	setup_player(player)
	respawn(player)


func respawn(player: CharacterBody3D) -> void:
	"""Virtual: Override in subclass for custom respawn logic.
	
	Default implementation places the player at a random spawner position.
	"""
	player.position = player_spawners.get_children().pick_random().global_position
