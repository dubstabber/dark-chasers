extends Node
## Blue demon on the bring-up map: a real Level and the real Player (plan section 11.3, M1-M6).
## Runner: tests/test_blue_demon_map.tscn.
##
## The map scene is loaded by path and added as a child of this runner; Level._ready is
## self-sufficient (it registers the context nodes and spawns the Player). No blue demon class is
## named in code. Without the ripped assets the runner SKIPs: exit 0, no OK banner.

const Arena := preload("res://tests/blue_demon_test_arena.gd")

const MAP_SCENE := "res://scenes/maps/blue_demon_room.tscn"
const PREY_SCRIPT := "res://scenes/interfaces/blue_demon_prey.gd"
const OK_BANNER := "=== BLUE DEMON MAP TEST OK ==="
const SKIP_LINE := "SKIP: blue demon assets not present (ripped assets are not committed)"

const WATCHDOG_SECONDS := 10.0

var _failed := false
var _finished := false
var _sim := 0.0
var _unstepped := 0.0
var _case := ""
var _watches: Array = []
var _hooks: Array[Callable] = []
var _kill_events: Array = []
var _tap: Variant = null             # Arena.ErrorTap: script and engine errors logged while the test runs
var _reached_end := false


func _ready() -> void:
	print("=".repeat(60))
	print("BLUE DEMON MAP TEST (real Level, real Player)")
	print("=".repeat(60))
	if not Arena.assets_present():
		print(SKIP_LINE)
		_finished = true
		get_tree().quit(0)
		return
	_case = "boot"
	if load(Arena.DEMON_SCENE) == null:
		_assert(false, "the assets are present but %s does not load" % Arena.DEMON_SCENE)
		_finished = true
		get_tree().quit(1)
		return

	_tap = Arena.ErrorTap.new()
	OS.add_logger(_tap)
	Services.event_bus.subscribe(GameEventTypes.ENEMY_KILLED_PLAYER, _on_kill_event)
	await _run_map_test()
	Services.event_bus.unsubscribe(GameEventTypes.ENEMY_KILLED_PLAYER, _on_kill_event)
	# A script error ends _run_map_test() and resumes this function: without the two checks below the runner
	# would print its OK banner over a test that stopped half-way.
	var logged: Vector2i = _tap.mark()
	_assert(logged == Vector2i.ZERO, "no script error (%d) and no engine error (%d) was logged during the test%s" % [logged.x, logged.y, _tap.describe_since(Vector2i.ZERO)])
	_assert(_reached_end, "the test reached its end (it stops early after a failed set-up assertion or a script error)")
	OS.remove_logger(_tap)
	_hooks.clear()
	_watches.clear()
	Services.enemy_context.set_players_node(null)
	Services.enemy_context.set_transitions_node(null)

	await get_tree().process_frame
	_finished = true
	print("\nsimulated %.1f s" % _sim)
	if _failed:
		print("=== BLUE DEMON MAP TEST FAILED ===")
	else:
		print(OK_BANNER)
	get_tree().quit(1 if _failed else 0)


## Watchdog: if the test has not stepped for WATCHDOG_SECONDS of simulated time, fail loudly instead of
## never quitting. (A script error inside the test does not hang the runner: it ends _run_map_test() and
## resumes _ready(), which checks the error tap and that the test reached its end.)
func _physics_process(delta: float) -> void:
	if _finished:
		return
	_unstepped += delta
	if _unstepped > WATCHDOG_SECONDS:
		_finished = true
		_failed = true
		push_error("ASSERT FAILED: [%s] the test stopped stepping for %.0f simulated seconds (a script error ended it?)" % [_case, WATCHDOG_SECONDS])
		OS.remove_logger(_tap)
		get_tree().quit(1)


func _run_map_test() -> void:
	# --- M1: load, instantiate, run 1 s -----------------------------------------------------------
	_case = "M1 load"
	print("\n--- %s ---" % _case)
	var packed := load(MAP_SCENE) as PackedScene
	_assert(packed != null, "%s loads" % MAP_SCENE)
	if packed == null:
		return
	var level := packed.instantiate()
	add_child(level)
	var demon: Variant = level.get_node_or_null("Enemies/BlueDemon")
	_assert(demon != null and demon is Enemy, "Enemies/BlueDemon exists and is an Enemy")
	if demon == null or not (demon is Enemy):
		return
	var watch: Variant = Arena.Watch.new(demon, _sim)
	_watches.append(watch)
	if not watch.missing_signals.is_empty():
		_assert(false, "the demon has the signals the test observes; missing: %s" % ", ".join(PackedStringArray(watch.missing_signals)))
	await _run(1.0)

	_assert(level.get_node_or_null("Enemies/Fuwatty") != null, "Enemies/Fuwatty still exists (inherited room_1 content intact)")
	_assert(demon.active == true, "demon.active after 1 s in a real Level")
	_assert(demon.current_room == "MainRoom", "demon.current_room == 'MainRoom', got '%s'" % demon.current_room)
	var players: Array = Services.enemy_context.get_players()
	_assert(players.size() == 1 and players[0] is Player, "exactly one player from Services.enemy_context.get_players() and it is a Player (%d)" % players.size())
	if players.is_empty() or not (players[0] is Player):
		return
	var player := players[0] as Player
	_assert(player.current_room == "MainRoom", "the player is in 'MainRoom', got '%s'" % player.current_room)
	_assert(demon.target == player, "demon.target == player, got %s" % demon.target)

	# --- M2: graph ---------------------------------------------------------------------------------
	_case = "M2 graph"
	print("\n--- %s ---" % _case)
	var point_script: Variant = load(Arena.POINT_SCRIPT)
	_assert(point_script != null, "the patrol-point script loads")
	var registered: Array = []
	if point_script != null:
		registered = point_script.get_registered()
	var main_room := 0
	var small_room := 0
	var navigation_map: RID = demon.get_world_3d().navigation_map
	for point: Variant in registered:
		if point.room == "MainRoom":
			main_room += 1
		elif point.room == "SmallRoom":
			small_room += 1
		var at: Vector3 = point.global_position
		var on_mesh: Vector3 = NavigationServer3D.map_get_closest_point(navigation_map, at)
		var off_mesh: float = Arena.planar(at, on_mesh)
		_assert(off_mesh <= 0.3, "patrol point %s is %.3f m (horizontal) from the navmesh (expected <= 0.3)" % [point.name, off_mesh])
	_assert(registered.size() == 6 and main_room == 4 and small_room == 2, "get_registered() has 6 points (%d): 4 in MainRoom (%d), 2 in SmallRoom (%d)" % [registered.size(), main_room, small_room])
	var usable: Array = demon.get_patrol_points()
	_assert(usable.size() == 4, "demon.get_patrol_points().size() == 4 (its own room only), got %d" % usable.size())
	# R5: the editor gizmo (an unowned MeshInstance3D child) and its bookkeeping never exist in a running game.
	var linked := 0
	var gizmo_children := 0
	var predecessor_entries := 0
	for point: Variant in registered:
		linked += point.next_points.size()
		gizmo_children += point.get_child_count()
		# The list is created lazily by the editor branch, so in a running game it is not even an Array.
		var bookkeeping: Variant = point._gizmo_predecessors
		if bookkeeping is Array:
			predecessor_entries += bookkeeping.size()
	_assert(linked > 0 and gizmo_children == 0 and predecessor_entries == 0, "in the running game the %d points (%d authored edges) have no child node (%d) and no _gizmo_predecessors entry (%d)" % [registered.size(), linked, gizmo_children, predecessor_entries])

	# --- M3: the adapter on the real player --------------------------------------------------------
	_case = "M3 adapter"
	print("\n--- %s ---" % _case)
	var prey: Variant = load(PREY_SCRIPT)
	_assert(prey != null, "the prey adapter script loads")
	if prey != null:
		_assert(prey.is_stand_up(player) == true, "is_stand_up(player) is true for the standing player")
		var face: Vector3 = prey.face_position(player)
		var span: Vector2 = prey.get_collider_span(player)
		var feet: float = player.global_position.y
		_assert(face.y > span.x and face.y < span.y, "face_position(player).y = %.3f lies inside the standing capsule span %.3f..%.3f" % [face.y, span.x, span.y])
		_assert(absf(face.y - (feet + 1.0)) <= 0.15, "face_position(player).y is %.3f above the feet (expected 1.0 +- 0.15)" % (face.y - feet))
		_assert(prey.is_flash_light_on(player) == false, "is_flash_light_on(player) is false (the lighter is not lit)")

	# --- M4: first leg -----------------------------------------------------------------------------
	_case = "M4 first leg"
	print("\n--- %s ---" % _case)
	var p1: Variant = level.get_node_or_null("BlueDemonPatrol/P1")
	_assert(p1 != null, "BlueDemonPatrol/P1 exists")
	var is_at_p1 := func() -> bool:
		return p1 != null and _point_source(demon) == p1
	var leg_started_at := _sim
	var arrived: bool = await _until(is_at_p1, 20.0)
	_assert(arrived, "within 20 s current_state.current_point.source_point is P1 (%.2f s; log: %s)" % [_sim - leg_started_at, watch.names_text()])
	_assert(watch.path_length >= 20.0, "the demon has travelled %.2f m (expected >= 20)" % watch.path_length)
	var player_distance: float = Arena.planar(demon.global_position, player.global_position)
	_assert(watch.count_prefix("Chase") == 0, "the idle player at the spawn (now %.1f m away) has caused no 'Chase' name (log: %s)" % [player_distance, watch.names_text()])
	if not arrived:
		return

	# --- M5: sight on real geometry ----------------------------------------------------------------
	_case = "M5 sight"
	print("\n--- %s ---" % _case)
	demon.sleep()
	var in_front: Vector3 = demon.global_position + demon.facing_forward() * 10.0
	in_front.y = demon.global_position.y
	player.global_position = in_front
	player.velocity = Vector3.ZERO
	await _run(_ticks(3))
	_assert(demon.is_find_player(25.0, 75.0) == true, "with the player 10 m in front, is_find_player(25, 75) is true: the mask-5 ray from the eye marker hits the real player first")

	# --- M6: kill, death flow, revive --------------------------------------------------------------
	_case = "M6 kill"
	print("\n--- %s ---" % _case)
	demon.force_chase()
	var is_player_dead := func() -> bool:
		return player.is_dead()
	var ordered_at := _sim
	var killed: bool = await _until(is_player_dead, 8.0)
	_assert(killed, "player.is_dead() within 8 s of force_chase() (%.2f s, name '%s')" % [_sim - ordered_at, _name(demon)])
	if not killed:
		return
	_assert(_kill_events.size() == 1, "one enemy_killed_player event, got %d" % _kill_events.size())
	await _run(1.5)
	var thrown: float = demon.global_position.distance_to(player.global_position)
	print("  demon-player distance 1.5 s after the kill: %.2f m (the stock death throw; the kill position is the demon's feet)" % thrown)
	_assert(player.is_inside_tree() and player.is_dead(), "after 1.5 s the player is still in the tree and dead")
	_assert(thrown > 4.0, "after 1.5 s the player is %.2f m away (expected > 4: the stock death throw, D7)" % thrown)
	_assert(_name(demon) == "Wandering", "after the kill the name is 'Wandering', got '%s'" % _name(demon))

	# The demon is made to stand where it is (a 30 s summon to its own position) and the revived player is put
	# in front of it, in plain view: only the revive grace then keeps a 'Chase' name away. Left where the death
	# throw dropped it, the player is out of the cone and the assertion below could not fail.
	demon.call_to_position(demon.global_position, 30.0, 2.0)
	await _step()
	player.respawn()
	_assert(player.is_alive(), "player.respawn(): player.is_alive()")
	var respawned_at := _sim
	var mark: int = watch.names.size()
	var grace := {"min_distance": INF}
	var distance_probe := func() -> void:
		grace["min_distance"] = minf(grace["min_distance"], demon.global_position.distance_to(player.global_position))
	_hooks.append(distance_probe)
	var origin: Vector3 = demon.global_position
	var forward: Vector3 = demon.facing_forward()
	var in_view := false
	var view_text := "nowhere"
	for candidate: Vector2 in [Vector2(0.0, 6.0), Vector2(40.0, 6.0), Vector2(-40.0, 6.0), Vector2(0.0, 4.0), Vector2(40.0, 4.0), Vector2(-40.0, 4.0)]:
		player.global_position = origin + Arena.turned_right(forward, candidate.x) * candidate.y   # (degrees to the right, metres)
		player.velocity = Vector3.ZERO
		await _run(_ticks(3))
		if demon._senses.has_line_of_sight(25.0):        # the ray alone: is_find_player() is what the grace blocks
			in_view = true
			view_text = "%.0f m away, %.0f deg to the right of the facing" % [candidate.y, candidate.x]
			break
	_assert(in_view and _name(demon) == "Wandering", "set-up: the revived player stands in plain view of the standing demon (%s; name '%s')" % [view_text, _name(demon)])
	await _run(maxf(0.0, respawned_at + 2.8 - _sim))
	_assert(watch.count_prefix("Chase", mark) == 0, "for 2.8 s after the respawn no 'Chase' name although the player is in plain view (revive grace; log: %s)" % watch.names_text())
	var is_look_again := func() -> bool:
		return watch.index_of("Chase.LOOK", mark) >= 0
	var looked: bool = await _until(is_look_again, 1.6)
	_hooks.clear()
	var look_after: float = watch.time_of("Chase.LOOK", mark) - respawned_at
	_assert(looked and look_after >= 2.9 and look_after <= 4.3, "Chase.LOOK %.3f s after the respawn (expected 2.9-4.3: once the grace is over the same player is seen)" % look_after)
	print("  minimum demon-player distance over the grace window: %.2f m (player alive: %s)" % [grace["min_distance"], player.is_alive()])
	_reached_end = true


# --- harness -----------------------------------------------------------------------------------

func _step() -> void:
	await get_tree().physics_frame
	_sim += get_physics_process_delta_time()
	_unstepped = 0.0
	for watch: Variant in _watches:
		watch.sample(_sim)
	for hook in _hooks:
		hook.call()


func _run(seconds: float) -> void:
	var waited := 0.0
	while waited < seconds - 0.000001:
		await _step()
		waited += get_physics_process_delta_time()


func _until(condition: Callable, max_seconds: float) -> bool:
	if condition.call():
		return true
	var waited := 0.0
	while waited < max_seconds - 0.000001:
		await _step()
		waited += get_physics_process_delta_time()
		if condition.call():
			return true
	return false


func _ticks(count: int) -> float:
	return count * get_physics_process_delta_time()


func _name(demon: Variant) -> String:
	return String(demon.get_state_name())


## current_state.current_point.source_point when the wandering state is current, else null.
func _point_source(demon: Variant) -> Node:
	if not is_instance_valid(demon) or demon.current_state == null or _name(demon) != "Wandering":
		return null
	var data: Variant = demon.current_state.current_point
	if data == null:
		return null
	return data.source_point as Node


func _on_kill_event(event: RefCounted) -> void:
	_kill_events.append(event)


func _assert(condition: bool, message: String) -> void:
	var text := "[%s] %s" % [_case, message]
	if condition:
		print("  ok   ", text)
	else:
		_failed = true
		push_error("ASSERT FAILED: " + text)
		print("  FAIL ", text)
