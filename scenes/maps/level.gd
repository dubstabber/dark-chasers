class_name Level extends Node3D

@export var auto_spawn_player := true

# Base key collection system - can be overridden by specific maps
var keys_collected: Array = []

# Transition spawn handoff (used once on initial spawn after a level transition)
var _initial_spawn_id: StringName = &""
var _initial_spawn_consumed: bool = false

@onready var hud = $HUD
@onready var transitions = _get_named_level_node(&"Transitions")
@onready var player_spawners = _get_named_level_node(&"PlayerSpawners")
@onready var players = _get_named_level_node(&"Players")
@onready var enemies = _get_named_level_node(&"Enemies")
@onready var corpses = _get_named_level_node(&"Corpses")


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
			var marker := _find_transition_arrival_marker(t)
			if marker:
				t.connect("body_entered", handle_transition.bind(t.name, marker))
			for m in t.get_children():
				if m.is_in_group("manual_spawn_point"):
					t.connect("body_entered", _on_transition_entered.bind(m))
					t.connect("body_exited", _on_transition_exited)

	_capture_initial_transition_context()

	if auto_spawn_player:
		spawn_player()


func _exit_tree():
	# Unsubscribe from event bus when level is removed
	Services.event_bus.unsubscribe(GameEventTypes.KEY_COLLECTED, _on_key_event)
	Services.event_bus.unsubscribe(GameEventTypes.DOOR_LOCKED, _on_door_locked_event)
	Services.event_bus.unsubscribe(GameEventTypes.ITEM_PICKEDUP, _on_item_pickedup_event)


func _get_named_level_node(node_name: StringName) -> Node:
	var unique_node := get_node_or_null(NodePath("%" + String(node_name)))
	if unique_node:
		return unique_node
	return get_node_or_null(NodePath(String(node_name)))


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
	if not (body is Node3D):
		push_warning("handle_transition: body is not Node3D for transition '%s'" % String(area3dname))
		return

	if not RoomAware.check(body):
		push_warning("handle_transition: body is not RoomAware: %s" % body.name)
		return

	var from_room = RoomAware.get_current_room(body)
	if from_room == "" or from_room == null:
		push_warning("handle_transition: body.current_room is empty for %s" % body.name)
		return

	var to_room: Variant = null
	var map_transitions = TransitionsData.get_map_transitions(transitions)
	if from_room in map_transitions and area3dname in map_transitions[from_room]:
		to_room = map_transitions[from_room][area3dname]
	if not TransitionArrival.apply(body as Node3D, marker):
		push_warning("handle_transition: failed to apply arrival for transition '%s'" % String(area3dname))
		return

	if to_room != null:
		RoomAware.set_current_room(body, String(to_room))

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
	if hud and "hud" in player:
		player.hud = hud

	# Add player to "player" group if not already
	if not player.is_in_group("player"):
		player.add_to_group("player")

	var player_camera := _get_player_camera(player)
	if player_camera and Services and Services.camera_manager:
		Services.camera_manager.set_player_camera(player_camera)
		Services.camera_manager.set_active_camera(player_camera)


func refresh_key_display():
	"""Manually refresh the key display - useful for testing or when keys are added programmatically"""
	if hud:
		hud.update_keys_display(keys_collected)


func _door_locked(text, triggering_player):
	if triggering_player:
		# Show event text only to the specific player who triggered the interaction
		hud.show_event_text_for_player(triggering_player, text, false, 3.0)
	# If no triggering player is specified (e.g., enemy interaction), don't show any message


func spawn_player() -> Player:
	"""Virtual: Override in subclass for custom spawn behavior.
	
	Default implementation instantiates a player from the scene catalog,
	adds it to the players node, and respawns at a random spawner.
	Subclasses like mansion_1 override this for custom intro sequences.
	"""
	var existing_player := _find_existing_player()
	if existing_player:
		setup_player(existing_player)
		return existing_player

	if not players:
		push_warning("Level: No %Players found; cannot spawn player")
		return null

	var player_scene := Services.get_scene_catalog().get_player_scene()
	if player_scene == null:
		push_warning("Level: Player scene is missing from SceneCatalog")
		return null

	var player := player_scene.instantiate() as Player
	if player == null:
		push_warning("Level: Player scene did not instantiate a Player")
		return null

	players.add_child(player)
	setup_player(player)
	respawn(player)
	return player


func respawn(player: CharacterBody3D) -> void:
	"""Virtual: Override in subclass for custom respawn logic.
	
	Default implementation places the player at a random spawner position.
	"""
	var test_spawn := _find_unique_test_spawn_marker()
	if test_spawn:
		_initial_spawn_consumed = true
		if TransitionArrival.apply(player, test_spawn):
			return
		push_warning("Level: failed to apply unique TestSpawn arrival")

	if not _initial_spawn_consumed:
		_initial_spawn_consumed = true
		if _initial_spawn_id != &"":
			var marker := _find_player_spawn_marker(_initial_spawn_id)
			if marker:
				if TransitionArrival.apply(player, marker):
					return
				push_warning("Level: failed to apply spawn_id arrival for '%s'" % String(_initial_spawn_id))
			else:
				push_warning("Level: spawn_id '%s' not found in PlayerSpawners for %s" % [String(_initial_spawn_id), scene_file_path])

	var spawn_markers := _get_player_spawn_markers()
	if not spawn_markers.is_empty():
		var random_spawner := spawn_markers.pick_random() as Marker3D
		if random_spawner and TransitionArrival.apply(player, random_spawner):
			return
		push_warning("Level: random player spawner is invalid")

	push_warning("Level: No Marker3D spawners found under %PlayerSpawners; cannot respawn player")


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


func _find_player_spawn_marker(spawn_id: StringName) -> Marker3D:
	if not player_spawners:
		return null

	var wanted := String(spawn_id)
	var queue: Array[Node] = [player_spawners]
	while not queue.is_empty():
		var node := queue.pop_front() as Node
		for child in node.get_children():
			queue.append(child)
			if not (child is Marker3D):
				continue

			# Prefer explicit metadata if present.
			if child.has_meta("spawn_id"):
				var meta_val: Variant = child.get_meta("spawn_id")
				if String(meta_val) == wanted:
					return child as Marker3D
			# Fallback to node name match.
			if String(child.name) == wanted:
				return child as Marker3D

	return null


func _find_unique_test_spawn_marker() -> Marker3D:
	if not player_spawners:
		return null

	var queue: Array[Node] = [player_spawners]
	while not queue.is_empty():
		var node := queue.pop_front() as Node
		for child in node.get_children():
			queue.append(child)
			if child is Marker3D and child.name == &"TestSpawn" and child.unique_name_in_owner:
				return child as Marker3D

	return null


func _get_player_spawn_markers() -> Array[Marker3D]:
	var spawn_markers: Array[Marker3D] = []
	if not player_spawners:
		return spawn_markers

	var queue: Array[Node] = [player_spawners]
	while not queue.is_empty():
		var node := queue.pop_front() as Node
		for child in node.get_children():
			queue.append(child)
			if child is Marker3D:
				spawn_markers.append(child as Marker3D)

	return spawn_markers


func _find_existing_player() -> Player:
	if players:
		for child in players.get_children():
			if child is Player:
				return child as Player

	var queue: Array[Node] = [self]
	while not queue.is_empty():
		var node := queue.pop_front() as Node
		for child in node.get_children():
			queue.append(child)
			if child is Player:
				return child as Player

	return null


func _get_player_camera(player: Node) -> Camera3D:
	if player == null:
		return null

	if "camera_3d" in player:
		var camera_var: Variant = player.get("camera_3d")
		if camera_var is Camera3D:
			return camera_var

	if player.has_method("get_hud_camera"):
		var hud_camera_var: Variant = player.call("get_hud_camera")
		if hud_camera_var is Camera3D:
			return hud_camera_var

	return null


func _find_transition_arrival_marker(root: Node) -> TransitionArrivalMarker:
	if root == null:
		return null

	var queue: Array[Node] = [root]
	while not queue.is_empty():
		var current := queue.pop_front() as Node
		for child_variant in current.get_children():
			var child := child_variant as Node
			queue.append(child)
			if child is TransitionArrivalMarker and not child.is_in_group("manual_spawn_point"):
				return child

	return null
