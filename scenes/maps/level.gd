class_name Level extends Node3D

# Base key collection system - can be overridden by specific maps
var keys_collected: Array = []

# Transition spawn handoff (used once on initial spawn after a level transition)
var _initial_spawn_id: StringName = &""
var _initial_spawn_consumed: bool = false

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

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Subscribe to shared cross-level events from GameEventBus.
	Services.event_bus.subscribe(GameEventTypes.KEY_COLLECTED, _on_key_event)
	Services.event_bus.subscribe(GameEventTypes.DOOR_LOCKED, _on_door_locked_event)
	Services.event_bus.subscribe(GameEventTypes.ITEM_PICKEDUP, _on_item_pickedup_event)
	
	if transitions:
		for t in transitions.get_children():
			for m in t.get_children():
				if m.is_in_group("spawn_point"):
					t.connect("body_entered", handle_transition.bind(t.name, m))
				if m.is_in_group("manual_spawn_point"):
					t.connect("body_entered", _on_transition_entered.bind(m))
					t.connect("body_exited", _on_transition_exited)

	_capture_initial_transition_context()


func _exit_tree():
	# Unsubscribe from event bus when level is removed
	Services.event_bus.unsubscribe(GameEventTypes.KEY_COLLECTED, _on_key_event)
	Services.event_bus.unsubscribe(GameEventTypes.DOOR_LOCKED, _on_door_locked_event)
	Services.event_bus.unsubscribe(GameEventTypes.ITEM_PICKEDUP, _on_item_pickedup_event)


# === SHARED EVENT HANDLERS ===
# These handle truly shared cross-level concerns (keys, locks, item pickups).
# Button/area trigger side effects should be owned by typed subscribers and/or
# explicit effect components attached to the trigger instances.

func _on_key_event(event: RefCounted) -> void:
	var key_type = event.get_string("key_type")
	var message = event.get_string("message")
	_key_collected(key_type, message)


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


func _key_collected(key_type, message_text):
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


func spawn_player() -> Player:
	"""Virtual: Override in subclass for custom spawn behavior.
	
	Default implementation instantiates a player from the scene catalog,
	adds it to the players node, and respawns at a random spawner.
	Subclasses like mansion_1 override this for custom intro sequences.
	"""
	var player = Services.get_scene_catalog().get_player_scene().instantiate() as Player
	players.add_child(player)
	setup_player(player)
	respawn(player)
	return player


func respawn(player: CharacterBody3D) -> void:
	"""Virtual: Override in subclass for custom respawn logic.
	
	Default implementation places the player at a random spawner position.
	"""
	if not _initial_spawn_consumed:
		_initial_spawn_consumed = true
		if _initial_spawn_id != &"":
			var marker := _find_player_spawn_marker(_initial_spawn_id)
			if marker:
				player.position = marker.global_position
				return
			push_warning("Level: spawn_id '%s' not found in PlayerSpawners for %s" % [String(_initial_spawn_id), scene_file_path])

	if player_spawners:
		player.position = player_spawners.get_children().pick_random().global_position
		return

	push_warning("Level: No %PlayerSpawners found; cannot respawn player")


func _capture_initial_transition_context() -> void:
	if not (Services and Services.level_manager):
		return

	var req: Dictionary = Services.level_manager.get_last_transition_request()
	var req_scene_path: String = req.get("scene_path", "")
	# Only accept spawn context that targets this level.
	if req_scene_path != "" and req_scene_path != scene_file_path:
		return

	var ctx: Dictionary = req.get("context", {})
	var spawn_var: Variant = ctx.get("spawn_id", null)
	if spawn_var is StringName:
		_initial_spawn_id = spawn_var
	elif spawn_var is String and spawn_var != "":
		_initial_spawn_id = StringName(spawn_var)


func _find_player_spawn_marker(spawn_id: StringName) -> Node3D:
	if not player_spawners:
		return null

	var wanted := String(spawn_id)
	var queue: Array[Node] = [player_spawners]
	while not queue.is_empty():
		var node := queue.pop_front() as Node
		for child in node.get_children():
			queue.append(child)
			if not (child is Node3D):
				continue

			# Prefer explicit metadata if present.
			if child.has_meta("spawn_id"):
				var meta_val: Variant = child.get_meta("spawn_id")
				if String(meta_val) == wanted:
					return child
			# Fallback to node name match.
			if String(child.name) == wanted:
				return child

	return null
