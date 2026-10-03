extends Node
## Blue demon, extended cases X01-X11 (plan section 11.3): rooms, framework idioms, travel edge
## cases, presentation, a map without a navmesh. Runner: tests/test_blue_demon_extended.tscn.
## R1-R6 are regression cases for the review fixes, one group per `# DST R<n>` comment in the demon's
## code: nodes that are freed or leave the tree, absence before the boot gate, orders before the boot
## gate, the travel_blocked re-arm, the patrol-point gizmo at runtime (R5 is in the map test), the warp order.
##
## Same rules as tests/test_blue_demon.gd (plan 11.1): no blue demon class is named in code, time is
## simulated time, bodies are positioned before add_child, each case builds and frees its own arena
## and ends by checking that no script or engine error was logged while it ran, and without the ripped
## assets the runner SKIPs (exit 0, no OK banner).
##
## Times in assertions come from the per-demon observer (Arena.Watch): the simulated time at the start
## of the physics tick in which a thing happened. A thing that happens n ticks after an order the test
## issued between two ticks is therefore logged n - 1 ticks after the order; where a duration is
## measured from an order, one tick is added (_since_order).

const Arena := preload("res://tests/blue_demon_test_arena.gd")

const CHASE_STATE_SCRIPT := "res://scenes/components/enemy/blue_demon/blue_demon_chase_state.gd"
const SE_SCRIPT := "res://scenes/components/enemy/blue_demon/blue_demon_se.gd"
const OK_BANNER := "=== BLUE DEMON EXTENDED TESTS OK ==="
const SKIP_LINE := "SKIP: blue demon assets not present (ripped assets are not committed)"

# SeType { FIND, LOOK, CHASE, NONE } of the demon root.
const SE_FIND := 0
const SE_LOOK := 1
const SE_CHASE := 2
# State { INIT, MOVE, THINKING, NONE } of the wandering state.
const WANDER_MOVE := 1
const WANDER_THINKING := 2
const WANDER_NONE := 3
# Command { HOLD, GOTO, PURSUE } of the travel layer.
const COMMAND_GOTO := 1
const COMMAND_PURSUE := 2

const TIME_EPS := 0.005
const ROTATION_EPS := 0.0001
const ACTIVATION_BUDGET := 2.0
const WATCHDOG_SECONDS := 10.0

var _failed := false
var _finished := false
var _sim := 0.0
var _unstepped := 0.0
var _case := ""
var _arena: Dictionary = {}
var _tap: Variant = null             # Arena.ErrorTap: script and engine errors logged while the cases run
var _tap_mark := Vector2i.ZERO       # its counts when the current case began
var _watches: Array = []
var _hooks: Array[Callable] = []


func _ready() -> void:
	print("=".repeat(60))
	print("BLUE DEMON TESTS (extended, X01-X11)")
	print("=".repeat(60))
	if not Arena.assets_present():
		print(SKIP_LINE)
		_finished = true
		get_tree().quit(0)
		return
	if load(Arena.DEMON_SCENE) == null:
		_case = "boot"
		_assert(false, "the assets are present but %s does not load" % Arena.DEMON_SCENE)
		_finished = true
		get_tree().quit(1)
		return
	_tap = Arena.ErrorTap.new()
	OS.add_logger(_tap)

	await _x01_rooms_gate_senses_and_graph()
	await _x02a_injected_target()
	await _x02b_injected_waypoint()
	await _x02b_prime_waypoint_while_travelling()
	await _x02c_start_stop_chasing_players()
	await _x03_mid_leg_teleport()
	await _x03b_teleport_during_stare()
	await _x04_trail(false)
	await _x04_trail(true)
	await _x05_return_home(true)
	await _x05_return_home(false)
	await _x06a_unreachable_point()
	await _x06b_winding_path()
	await _x07_footsteps()
	await _x08a_stare_at_prey_above()
	await _x08b_facing_while_travelling()
	await _x09_neck()
	_x10_se_table()
	await _x11a_no_navmesh_goto()
	await _x11b_no_navmesh_chase()
	await _r1a_prey_freed_mid_chase()
	await _r1b_prey_freed_during_the_stare()
	await _r1c_spawner_target_freed_before_activation()
	await _r1d_order_right_after_the_free()
	await _r1e_replacement_prey()
	await _r1f_prey_removed_not_freed()
	await _r1f2_pursued_prey_removed()
	await _r1g_successor_outside_the_tree()
	await _r1h_point_freed_mid_leg()
	await _r2_absent_from_the_first_frame("a: start_asleep set before add_child", "export")
	await _r2_absent_from_the_first_frame("b: sleep() right after add_child, 1 m above the floor", "sleep_after")
	await _r2_absent_from_the_first_frame("c: start_asleep set right after add_child (the spawn_setup order)", "export_after")
	await _r2_absent_from_the_first_frame("d: sleep() before add_child", "sleep_before")
	await _r2e_not_a_sleeper_after_all(true)
	await _r2e_not_a_sleeper_after_all(false)
	await _r3_orders_before_activation("a: start_asleep, then wake()", true, ["wake"], "Wandering")
	await _r3_orders_before_activation("b: force_chase(), then call_to_position()", false, ["force_chase", "call_to_position"], "Chase.FORCE_CHASE")
	await _r3_orders_before_activation("c: force_chase(), then call_to(point, true)", false, ["force_chase", "call_to_ignore"], "Chase.FORCE_CHASE")
	await _r3_orders_before_activation("d: force_chase(), then stop_chasing_players()", false, ["force_chase", "stop_chasing_players"], "Wandering")
	await _r3_orders_before_activation("e: force_chase(5.0), then stop_force_chase()", false, ["force_chase_wait", "stop_force_chase"], "Chase.LOOK")
	await _r4_blocked_blind_commits()
	await _r6a_warp_and_resume()
	await _r6b_warp_refusals()
	await _r6c_warp_wakes_a_sleeper()
	await _r6d_warp_before_activation()
	await _r6e_warp_while_chasing()

	_finish_cases()
	await get_tree().process_frame
	_finished = true
	print("\nsimulated %.1f s" % _sim)
	if _failed:
		print("=== BLUE DEMON EXTENDED TESTS FAILED ===")
	else:
		print(OK_BANNER)
	get_tree().quit(1 if _failed else 0)


## Watchdog: if no case has stepped for WATCHDOG_SECONDS of simulated time, fail loudly instead of never
## quitting. (A script error inside a case does not hang the runner: it ends the case's coroutine and
## resumes _ready(), which is why the next _begin(), _finish_cases() and the error tap report it.)
func _physics_process(delta: float) -> void:
	if _finished:
		return
	_unstepped += delta
	if _unstepped > WATCHDOG_SECONDS:
		_finished = true
		_failed = true
		push_error("ASSERT FAILED: [%s] the case stopped stepping for %.0f simulated seconds (a script error ended it?)" % [_case, WATCHDOG_SECONDS])
		OS.remove_logger(_tap)
		get_tree().quit(1)


# --- X01 ---------------------------------------------------------------------------------------

func _x01_rooms_gate_senses_and_graph() -> void:
	_begin("X01 rooms gate the senses and the graph")
	Arena.set_graph(_arena, {"A": {}, "B": {}})
	Arena.add_point(_arena, "PB", Vector3(5.0, 0.0, 5.0), 0.0, 2.0, 0.0, "B")
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, -8.0), 0.0, "B")
	stub.velocity = Vector3(8.0, 0.0, 0.0)               # in plain view and sprint-loud, but in room "B"
	var demon: Variant = _spawn(Vector3.ZERO, 0.0, "A")
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	var start: Vector3 = demon.global_position
	var seen := {"left_none": false}
	var state_probe := func() -> void:
		if _wander_state(demon) != WANDER_NONE:
			seen["left_none"] = true
	state_probe.call()
	_hooks.append(state_probe)
	await _run(3.0)
	_hooks.clear()
	_assert(watch.se.is_empty(), "for 3 s no se_requested, got %d" % watch.se.size())
	_assert(_name(demon) == "Wandering" and watch.count_prefix("Chase") == 0, "for 3 s the name is 'Wandering' (log: %s)" % watch.names_text())
	_assert(not seen["left_none"], "for 3 s current_state._state is NONE: PB (room 'B') is not chosen")
	var moved: float = Arena.planar(demon.global_position, start)
	_assert(moved < 0.1, "displacement in 3 s %.3f m (expected < 0.1)" % moved)

	stub.current_room = "A"
	var is_look := func() -> bool:
		return _name(demon) == "Chase.LOOK"
	var entered_at := _sim
	var looked: bool = await _until(is_look, 1.4)
	_assert(looked, "stub.current_room = 'A' gives Chase.LOOK within 1.4 s (%.3f s waited, name '%s')" % [_sim - entered_at, _name(demon)])
	await _end()


# --- X02 ---------------------------------------------------------------------------------------

func _x02a_injected_target() -> void:
	_begin("X02a current_target = player; makepath()")
	# Two stubs: the one under Players is what the demon resolves by itself; the injected one stands beside
	# the Players node, so the demon can only have it from the injection.
	var listed: Variant = Arena.add_stub(_arena, Vector3(15.0, 0.0, 0.0))                  # to the side, silent
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, 15.0), 0.0, "", false)    # behind the demon, silent
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	if not await _await_active(demon):
		await _end()
		return
	var has_listed := func() -> bool:
		return demon.target == listed
	var resolved: bool = await _until(has_listed, 1.0)
	_assert(resolved, "set-up: before the injection demon.target is the stub under Players, got %s" % demon.target)
	demon.current_target = stub
	demon.makepath()
	await _step()
	_assert(_name(demon) == "Chase.FORCE_CHASE", "'Chase.FORCE_CHASE' on the next tick, got '%s'" % _name(demon))
	_assert(demon.target == stub and demon.target != listed, "demon.target is the injected stub, which the enemy context does not list, got %s" % demon.target)
	var start_distance: float = Arena.planar(demon.global_position, stub.global_position)
	var is_closer := func() -> bool:
		return Arena.planar(demon.global_position, stub.global_position) <= start_distance - 3.0
	var closer: bool = await _until(is_closer, 2.0)
	var now_distance: float = Arena.planar(demon.global_position, stub.global_position)
	_assert(closer, "at least 3 m closer within 2 s: %.2f m -> %.2f m" % [start_distance, now_distance])
	await _end()


func _x02b_injected_waypoint() -> void:
	_begin("X02b waypoints.push_back(position)")
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	if not await _await_active(demon):
		await _end()
		return
	var goal := Vector3(10.0, 0.0, 10.0)
	demon.waypoints.push_back(goal)
	var is_summoned := func() -> bool:
		var destination: Vector3 = demon._travel.destination
		return _name(demon) == "Wandering" and _wander_state(demon) == WANDER_MOVE \
			and destination.distance_to(goal) < 0.01 and is_equal_approx(demon.desired_speed, 5.0)
	var summoned: bool = await _until(is_summoned, _ticks(2))
	_assert(summoned, "within 2 ticks: name 'Wandering' ('%s'), _state MOVE (%d), _travel.destination %s == (10, 0, 10), desired_speed == 5.0 (%.2f: the SRC summon speed)" % [
		_name(demon), _wander_state(demon), demon._travel.destination, demon.desired_speed])
	_assert(demon._warned.has(&"injected_waypoint"), "demon._warned has 'injected_waypoint' (loud, not silent)")
	var is_there := func() -> bool:
		return Arena.planar(demon.global_position, goal) <= 0.7
	var arrived: bool = await _until(is_there, 5.0)
	var goal_distance: float = Arena.planar(demon.global_position, goal)
	_assert(arrived, "arrives within 0.7 m of (10, 0, 10) within 5 s (%.3f m away)" % goal_distance)
	await _end()


## Red-team D5: while the demon travels, waypoints[0] is its OWN destination; scripts append.
func _x02b_prime_waypoint_while_travelling() -> void:
	_begin("X02b' waypoints.push_back() on a patrolling demon")
	var p: Variant = Arena.add_point(_arena, "P", Vector3(0.0, 0.0, 0.0), 0.0, 2.0)
	var q: Variant = Arena.add_point(_arena, "Q", Vector3(12.0, 0.0, 0.0), 0.0, 2.0)
	var demon: Variant = _spawn(Vector3(0.0, 0.0, -3.0))
	if demon == null or p == null or q == null:
		_assert(false, "set-up: demon and both points exist")
		await _end()
		return
	Arena.link(p, [q])
	Arena.link(q, [p])
	var watch: Variant = _watch(demon)
	var is_past_p := func() -> bool:
		return _point_source(demon) == p and _wander_state(demon) == WANDER_MOVE and demon.global_position.x >= 2.0
	var on_leg: bool = await _until(is_past_p, 15.0)
	_assert(on_leg, "set-up: on the leg P -> Q, 2 m past P (log: %s)" % watch.names_text())
	if not on_leg:
		await _end()
		return
	_assert(int(demon._travel.command) == COMMAND_GOTO and demon.waypoints.size() == 1, "set-up: _travel.command is GOTO (%d) and waypoints.size() == 1 (%d)" % [int(demon._travel.command), demon.waypoints.size()])
	var first_push := Vector3(-10.0, 0.0, 10.0)
	var q_position: Vector3 = q.global_position
	demon.waypoints.push_back(first_push)
	demon.waypoints.push_back(Vector3(-10.0, 0.0, 20.0))
	var is_redirected := func() -> bool:
		var destination: Vector3 = demon._travel.destination
		return destination.distance_to(first_push) < 0.01
	var redirected: bool = await _until(is_redirected, _ticks(2))
	var destination_now: Vector3 = demon._travel.destination
	_assert(redirected, "within 2 ticks _travel.destination is the first pushed entry (-10, 0, 10), got %s (Q is %s, the second push (-10, 0, 20))" % [destination_now, q_position])
	_assert(demon.waypoints.size() <= 1, "waypoints.size() <= 1 after the injection, got %d" % demon.waypoints.size())
	var is_there := func() -> bool:
		return Arena.planar(demon.global_position, first_push) <= 0.7
	var arrived: bool = await _until(is_there, 6.0)
	var goal_distance: float = Arena.planar(demon.global_position, first_push)
	_assert(arrived, "arrives within 0.7 m of (-10, 0, 10) within 6 s (%.3f m away)" % goal_distance)
	await _end()


func _x02c_start_stop_chasing_players() -> void:
	_begin("X02c start_chasing_players() / stop_chasing_players()")
	Arena.add_stub(_arena, Vector3(0.0, 0.0, 15.0))      # behind the demon, silent
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	if not await _await_active(demon):
		await _end()
		return
	demon.start_chasing_players()
	_assert(_name(demon) == "Chase.FORCE_CHASE", "start_chasing_players() gives 'Chase.FORCE_CHASE', got '%s'" % _name(demon))
	await _step()
	_assert(_name(demon) == "Chase.FORCE_CHASE", "still 'Chase.FORCE_CHASE' one tick later, got '%s'" % _name(demon))
	demon.stop_chasing_players()
	_assert(_name(demon) == "Wandering", "stop_chasing_players() gives 'Wandering', got '%s'" % _name(demon))
	await _step()
	_assert(_name(demon) == "Wandering", "still 'Wandering' one tick later, got '%s'" % _name(demon))
	_assert(demon._ai_component != null and demon._ai_component.chase_player == false, "_ai_component.chase_player is still false (the stock AI was never re-enabled)")
	await _end()


# --- X03 ---------------------------------------------------------------------------------------

func _x03_mid_leg_teleport() -> void:
	_begin("X03 mid-leg teleport re-plans (C4)")
	Arena.set_graph(_arena, {"A": {}, "B": {}})
	var a1: Variant = Arena.add_point(_arena, "A1", Vector3(10.0, 0.0, 0.0), 0.0, 2.0, 0.0, "A")
	var b1: Variant = Arena.add_point(_arena, "B1", Vector3(-20.0, 0.0, -20.0), 0.0, 2.0, 0.0, "B")
	var b2: Variant = Arena.add_point(_arena, "B2", Vector3(-10.0, 0.0, -20.0), 0.0, 2.0, 0.0, "B")
	var demon: Variant = _spawn(Vector3.ZERO, 0.0, "A")
	if demon == null or a1 == null or b1 == null or b2 == null:
		_assert(false, "set-up: demon and the three points exist")
		await _end()
		return
	Arena.link(b1, [b2])
	Arena.link(b2, [b1])
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	var a1_position: Vector3 = a1.global_position
	var b1_position: Vector3 = b1.global_position
	var first: Vector3 = demon._travel.destination
	_assert(first.distance_to(a1_position) < 0.01, "set-up: walking to A1 %s, _travel.destination %s" % [a1_position, first])
	await _run(1.0)

	demon.current_room = "B"                             # a teleport the demon did not cause
	demon.global_position = Vector3(-22.0, 0.05, -22.0)
	var is_replanned := func() -> bool:
		var destination: Vector3 = demon._travel.destination
		return destination.distance_to(b1_position) < 0.01
	var replanned: bool = await _until(is_replanned, _ticks(3))
	_assert(replanned, "within 3 ticks _travel.destination is B1 %s, got %s" % [b1_position, demon._travel.destination])

	var seen := {"went_to_a1": false, "arrived_after": -1.0}
	var teleported_at := _sim
	var destination_probe := func() -> void:
		var destination: Vector3 = demon._travel.destination
		if destination.distance_to(a1_position) < 0.01:
			seen["went_to_a1"] = true
		if seen["arrived_after"] < 0.0 and Arena.planar(demon.global_position, b1_position) <= 0.7:
			seen["arrived_after"] = _sim - teleported_at
	_hooks.append(destination_probe)
	await _run(6.0)
	_hooks.clear()
	_assert(not seen["went_to_a1"], "for the next 5 s (6 s watched) _travel.destination is never A1 again")
	_assert(seen["arrived_after"] >= 0.0 and seen["arrived_after"] <= 6.0, "the demon arrives within 0.7 m of B1 within 6 s (after %.3f s)" % seen["arrived_after"])
	_assert(watch.max_tilt < ROTATION_EPS, "rotation.x == 0 and rotation.z == 0, max |tilt| %.6f rad" % watch.max_tilt)
	await _end()


## Red-team m5: on_teleported neither rewinds nor advances the stare clock.
func _x03b_teleport_during_stare() -> void:
	_begin("X03b a 6 m jump during the stare")
	var stub_at := Vector3(0.0, 0.0, -8.0)
	var stub: Variant = Arena.add_stub(_arena, stub_at, Arena.yaw_towards(stub_at, Vector3.ZERO))
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	var is_look := func() -> bool:
		return _name(demon) == "Chase.LOOK"
	var seen_look: bool = await _until(is_look, 4.0)
	_assert(seen_look, "set-up: the demon reached Chase.LOOK (log: %s)" % watch.names_text())
	if seen_look:
		await _run(1.0)
		demon.global_position += Vector3(6.0, 0.0, 0.0)  # the stub stays inside the stare cone
		var is_chase := func() -> bool:
			return _name(demon) == "Chase.CHASE"
		var seen_chase: bool = await _until(is_chase, 2.0)
		var stare_time: float = watch.time_of("Chase.CHASE") - watch.time_of("Chase.LOOK")
		_assert(seen_chase and _in_window(stare_time, 1.9, 2.2), "Chase.CHASE %.3f s after LOOK began (expected 1.9-2.2, as in T03; log: %s)" % [stare_time, watch.names_text()])
		_assert(stub.kill_calls == 0, "the stub is alive (kill_calls %d)" % stub.kill_calls)
	await _end()


# --- X04, X05 ----------------------------------------------------------------------------------

## X04 / X05 set-up, up to the moment the stub is about to leave room "A": gates, a demon at
## (15, 0, 0) in "A" facing +X, a stub 7 m ahead facing it, and a chase that has acquired it.
## Empty when it did not get there.
func _trail_setup(graph: Dictionary, with_home_gate: bool, return_home: bool) -> Dictionary:
	Arena.set_graph(_arena, graph)
	Arena.add_gate(_arena, "DoorAB", Vector3(28.6, 0.0, 0.0), Vector3(-20.0, 0.0, -20.0))    # the navmesh edge is x = 28
	Arena.add_gate(_arena, "DoorBC", Vector3(-20.0, 0.0, -28.6), Vector3(0.0, 0.0, 20.0))
	if with_home_gate:
		Arena.add_gate(_arena, "DoorBA", Vector3(-28.6, 0.0, -20.0), Vector3(15.0, 0.0, 5.0))
	var stub_at := Vector3(22.0, 0.0, 0.0)
	var demon_at := Vector3(15.0, 0.0, 0.0)
	var stub: Variant = Arena.add_stub(_arena, stub_at, Arena.yaw_towards(stub_at, demon_at), "A")
	var configure := func(node: Variant) -> void:
		node.return_home = return_home
	var demon: Variant = _spawn(demon_at, deg_to_rad(-90.0), "A", true, configure)
	if demon == null:
		return {}
	var watch: Variant = _watch(demon)
	var is_pursuing := func() -> bool:
		return _name(demon) == "Chase.CHASE" and demon.current_target == stub
	var pursuing: bool = await _until(is_pursuing, 8.0)
	_assert(pursuing, "set-up: Chase.CHASE with current_target == stub (log: %s)" % watch.names_text())
	if not pursuing:
		return {}
	return {"demon": demon, "stub": stub, "watch": watch}


## (i) the stub goes to room "B"; (ii) it goes to room "C", two rooms away.
func _x04_trail(to_room_c: bool) -> void:
	_begin("X04ii trail: one transition per sighting, prey two rooms away" if to_room_c else "X04i trail through a gate 0.6 m off the navmesh, prey in the next room")
	var setup: Dictionary = await _trail_setup({"A": {"DoorAB": "B"}, "B": {"DoorBC": "C"}}, false, false)
	if setup.is_empty():
		await _end()
		return
	var demon: Variant = setup["demon"]
	var stub: Variant = setup["stub"]
	var watch: Variant = setup["watch"]
	var transition: Variant = demon.get_node_or_null("EnemyTransitionComponent")
	if transition == null:
		_assert(false, "the demon has an EnemyTransitionComponent")
		await _end()
		return
	if to_room_c:
		stub.current_room = "C"
		stub.global_position = Vector3(0.0, 0.0, 25.0)
	else:
		stub.current_room = "B"
		stub.global_position = Vector3(-20.0, 0.0, -25.0)
	var left_at := _sim

	var is_trailing := func() -> bool:
		return demon.current_target == stub and demon._travel.trailing == true and transition.pending_transition_name == "DoorAB"
	var trailing: bool = await _until(is_trailing, 1.5)
	_assert(trailing, "within 1.5 s: current_target == stub still (%s), _travel.trailing == true (%s), pending_transition_name == 'DoorAB' ('%s')" % [
		demon.current_target == stub, demon._travel.trailing, transition.pending_transition_name])

	var is_in_b := func() -> bool:
		return demon.current_room == "B"
	var hopped: bool = await _until(is_in_b, maxf(0.0, left_at + 6.0 - _sim))
	var marker := Vector3(-20.0, 0.0, -20.0)
	var marker_distance: float = Arena.planar(demon.global_position, marker)
	_assert(hopped and marker_distance < 0.5, "within 6 s current_room == 'B' ('%s') and d(demon, (-20, 0, -20)) = %.3f m < 0.5: the gate was reached with the stock 1.0 radius" % [demon.current_room, marker_distance])
	if not hopped:
		await _end()
		return
	# Teleport checkpoint B ends the trail in the hop tick (red-team D1).
	_assert(demon._travel.trailing == false, "on the first sample that shows room 'B': _travel.trailing == false, got %s" % demon._travel.trailing)
	var hopped_at := _sim

	if not to_room_c:
		await _step()                                    # the first full tick in the new room
		var is_resumed := func() -> bool:
			return demon.current_target == stub and _name(demon) == "Chase.CHASE" \
				and int(demon._travel.command) == COMMAND_PURSUE and demon._travel.trailing == false
		var resumed: bool = await _until(is_resumed, maxf(0.0, hopped_at + 1.0 - _sim))
		_assert(resumed, "within 1 s of the hop: current_target == stub (%s), name 'Chase.CHASE' ('%s'), a live PURSUE (command %d, trailing %s): pursuit resumed by sight" % [
			demon.current_target == stub, _name(demon), int(demon._travel.command), demon._travel.trailing])
		await _end()
		return

	var is_lost := func() -> bool:
		return _name(demon) == "Chase.LOST"
	var lost: bool = await _until(is_lost, 1.0)
	_assert(lost, "after the hop the name becomes 'Chase.LOST' (the prey is in room 'C'; name '%s')" % _name(demon))
	var lost_index: int = watch.index_of("Chase.LOST")
	var is_back := func() -> bool:
		return lost_index >= 0 and watch.index_of("Wandering", lost_index) >= 0
	var gave_up: bool = await _until(is_back, maxf(0.0, hopped_at + 5.0 - _sim))
	_assert(gave_up, "Chase.LOST, then Wandering within 5 s of the hop (%.3f s; log: %s)" % [_sim - hopped_at, watch.names_text()])
	_assert(int(demon._travel.hops_left) == 0, "_travel.hops_left == 0, got %d (one sighting buys one transition)" % int(demon._travel.hops_left))
	_assert(transition.pending_transition_name == "", "pending_transition_name == '' once the demon is parked, got '%s'" % transition.pending_transition_name)
	await _run(6.0)
	_assert(demon.current_room == "B", "current_room is still 'B' 6 s later, got '%s' (one hop only)" % demon.current_room)
	await _end()


func _x05_return_home(return_home: bool) -> void:
	_begin("X05 return home" if return_home else "X05 variant: return_home = false stays where the chase ended")
	var a1: Variant = Arena.add_point(_arena, "A1", Vector3(20.0, 0.0, 5.0), 0.0, 2.0, 0.0, "A")
	var graph := {"A": {"DoorAB": "B"}, "B": {"DoorBA": "A", "DoorBC": "C"}}
	var setup: Dictionary = await _trail_setup(graph, true, return_home)
	if setup.is_empty() or a1 == null:
		_assert(a1 != null, "set-up: the point A1 exists")
		await _end()
		return
	var demon: Variant = setup["demon"]
	var stub: Variant = setup["stub"]
	var watch: Variant = setup["watch"]
	stub.current_room = "C"
	stub.global_position = Vector3(0.0, 0.0, 25.0)

	var is_given_up := func() -> bool:
		var lost_index: int = watch.index_of("Chase.LOST")
		return demon.current_room == "B" and lost_index >= 0 and watch.index_of("Wandering", lost_index) >= 0
	var gave_up: bool = await _until(is_given_up, 15.0)
	_assert(gave_up, "set-up: one hop into 'B', Chase.LOST, then the give-up Wandering (room '%s'; log: %s)" % [demon.current_room, watch.names_text()])
	if not gave_up:
		await _end()
		return
	var gave_up_at := _sim

	if not return_home:
		await _run(20.0)
		_assert(demon.current_room == "B" and _wander_state(demon) == WANDER_NONE, "20 s after the give-up the room is still 'B' ('%s') and _state is NONE (%d)" % [demon.current_room, _wander_state(demon)])
		await _end()
		return

	var is_home := func() -> bool:
		return demon.current_room == "A"
	var home: bool = await _until(is_home, 30.0)
	_assert(home, "within 30 s of the give-up current_room == 'A' (%.3f s, room '%s', %d travel_blocked)" % [_sim - gave_up_at, demon.current_room, watch.blocked.size()])
	if home:
		var a1_position: Vector3 = a1.global_position
		var is_at_a1 := func() -> bool:
			var destination: Vector3 = demon._travel.destination
			return destination.distance_to(a1_position) < 0.01 and Arena.planar(demon.global_position, a1_position) <= 0.7
		var arrived: bool = await _until(is_at_a1, 10.0)
		var a1_distance: float = Arena.planar(demon.global_position, a1_position)
		_assert(arrived, "then _travel.destination is A1 %s (%s) and the demon arrives within 0.7 m within 10 s (%.3f m away)" % [a1_position, demon._travel.destination, a1_distance])
	await _end()


# --- X06 ---------------------------------------------------------------------------------------

func _x06a_unreachable_point() -> void:
	_begin("X06a unreachable authored point (G2)")
	var p: Variant = Arena.add_point(_arena, "P", Vector3(0.0, 0.0, 0.0), 0.0, 2.0)
	var q: Variant = Arena.add_point(_arena, "Q", Vector3(40.0, 0.0, 0.0), 0.0, 2.0, 1.0)     # 12 m off the navmesh
	var r: Variant = Arena.add_point(_arena, "R", Vector3(0.0, 0.0, 10.0), 0.0, 2.0)
	var demon: Variant = _spawn(Vector3(0.0, 0.0, -3.0))
	if demon == null or p == null or q == null or r == null:
		_assert(false, "set-up: demon and the three points exist")
		await _end()
		return
	Arena.link(p, [q])
	Arena.link(q, [r])
	Arena.link(r, [p])
	var watch: Variant = _watch(demon)
	var edge := {"finished_at": -1.0}
	var edge_probe := func() -> void:
		var nav: Variant = demon.get_nav_component()
		if edge["finished_at"] < 0.0 and demon.global_position.x >= 27.0 and nav != null and nav.is_navigation_finished():
			edge["finished_at"] = watch.tick_sim
	_hooks.append(edge_probe)
	var is_blocked := func() -> bool:
		return not watch.blocked.is_empty()
	var blocked: bool = await _until(is_blocked, 25.0)
	_hooks.clear()
	_assert(blocked, "travel_blocked was emitted on the leg to Q (log: %s)" % watch.names_text())
	if not blocked:
		await _end()
		return
	# At the navmesh edge the navigation reports finished and the demon brakes, but it is not at Q: BLOCKED
	# after blocked_grace (0.5 s), not after the 3 s stall rule, which is for a body that cannot move (X11).
	var block_delay: float = watch.blocked[0][1] - edge["finished_at"]
	_assert(edge["finished_at"] >= 0.0 and _in_window(block_delay, 0.45, 0.6), "travel_blocked %.3f s after the navigation finished at the navmesh edge (expected 0.45-0.6: blocked_grace 0.5)" % block_delay)
	var blocked_at := _sim
	var q_position: Vector3 = q.global_position
	var r_position: Vector3 = r.global_position
	var reported: Vector3 = watch.blocked[0][0]
	_assert(reported.distance_to(q_position) < 0.01, "travel_blocked carries a destination within 0.01 m of Q %s, got %s" % [q_position, reported])
	var stop_x: float = demon.global_position.x
	_assert(stop_x >= 27.0 and stop_x <= 28.6, "the demon stops with x = %.3f (expected 27.0-28.6: the navmesh edge)" % stop_x)
	var is_at_r := func() -> bool:
		return _point_source(demon) == r
	var arrived: bool = await _until(is_at_r, 25.0)
	var r_distance: float = Arena.planar(demon.global_position, r_position)
	_assert(arrived and r_distance <= 0.7, "it dwells and then arrives %.3f m from R within 25 s of the block (%.3f s): no hang" % [r_distance, _sim - blocked_at])
	_assert(watch.blocked.size() == 1, "travel_blocked was emitted exactly once before the arrival at R, got %d" % watch.blocked.size())
	await _end()


func _x06b_winding_path() -> void:
	_begin("X06b a winding path is not 'blocked'", "u")
	var demon: Variant = _spawn(Vector3(-24.0, 0.0, -20.0))
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	var goal := Vector3(24.0, 0.0, -20.0)
	var start_distance: float = Arena.planar(demon.global_position, goal)
	demon.call_to_position(goal, 1.0, 5.0)
	var trip := {"max_distance": start_distance}
	var distance_probe := func() -> void:
		trip["max_distance"] = maxf(trip["max_distance"], Arena.planar(demon.global_position, goal))
	_hooks.append(distance_probe)
	var is_there := func() -> bool:
		return Arena.planar(demon.global_position, goal) <= 0.6
	var ordered_at := _sim
	var arrived: bool = await _until(is_there, 30.0)
	_hooks.clear()
	var goal_distance: float = Arena.planar(demon.global_position, goal)
	_assert(arrived, "the demon arrives (d <= 0.6) within 30 s: %.3f m away after %.2f s" % [goal_distance, _sim - ordered_at])
	_assert(watch.blocked.is_empty(), "travel_blocked was never emitted, got %d" % watch.blocked.size())
	_assert(trip["max_distance"] > 55.0, "the maximum straight-line distance to the destination was %.2f m (expected > 55; it started at %.2f): the path really wound away" % [trip["max_distance"], start_distance])
	await _end()


# --- X07 ---------------------------------------------------------------------------------------

func _x07_footsteps() -> void:
	_begin("X07 footsteps")
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	await _run(2.0)
	_assert(watch.stamps.is_empty(), "zero 'stamped' during the idle 2 s, got %d" % watch.stamps.size())
	var goal := Vector3(0.0, 0.0, -12.0)
	demon.call_to_position(goal, 0.0, 2.0)
	var is_there := func() -> bool:
		return Arena.planar(demon.global_position, goal) <= 0.7
	var arrived: bool = await _until(is_there, 8.0)
	_assert(arrived, "set-up: the demon walked to (0, 0, -12)")
	var stamps: Array = watch.stamps
	_assert(stamps.size() >= 5, "'stamped' fired %d times during the walk (expected >= 5)" % stamps.size())
	var alternating := true
	var volume_min := INF
	var volume_max := -INF
	var pitch_min := INF
	var pitch_max := -INF
	for i in stamps.size():
		var foot_index: int = stamps[i][0]
		var volume: float = stamps[i][1]
		var pitch: float = stamps[i][2]
		if i > 0 and foot_index == int(stamps[i - 1][0]):
			alternating = false
		volume_min = minf(volume_min, volume)
		volume_max = maxf(volume_max, volume)
		pitch_min = minf(pitch_min, pitch)
		pitch_max = maxf(pitch_max, pitch)
	if not stamps.is_empty():
		_assert(alternating, "foot indices alternate")
		_assert(volume_min >= 0.5 and volume_max <= 0.7, "stamp volume in [%.3f, %.3f] (expected within 0.5-0.7)" % [volume_min, volume_max])
		_assert(pitch_min >= 0.8 and pitch_max <= 0.95, "stamp pitch in [%.3f, %.3f] (expected within 0.8-0.95)" % [pitch_min, pitch_max])
	await _end()


# --- X08 ---------------------------------------------------------------------------------------

## (a) the stare converges on a prey 2 m above the floor: the body only yaws (G9, C3).
func _x08a_stare_at_prey_above() -> void:
	_begin("X08a facing, pitch and the stare: prey 2 m higher")
	var stub: Variant = Arena.add_stub(_arena, Vector3(-6.0, 2.0, 1.0))    # not simulated: it stays up there
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	var has_target := func() -> bool:
		return demon.target == stub
	var targeted: bool = await _until(has_target, 1.0)
	var chase_script := load(CHASE_STATE_SCRIPT) as GDScript
	_assert(targeted and chase_script != null, "set-up: demon.target == stub and the chase-state script loads")
	if not targeted or chase_script == null:
		await _end()
		return
	var hold := {"max_gap": 0.0}
	var hold_probe := func() -> void:
		hold["max_gap"] = maxf(hold["max_gap"], absf(angle_difference(demon.rotation.y, demon.facing_yaw)))
	_hooks.append(hold_probe)

	demon.set_state(chase_script.new())
	var ordered_at := _sim
	var is_rotating := func() -> bool:
		return _name(demon) == "Chase.LOOK_ROTATE"
	var rotated: bool = await _until(is_rotating, 0.5)
	_assert(rotated, "Chase.LOOK_ROTATE is observed (log: %s)" % watch.names_text())
	var is_look := func() -> bool:
		return _name(demon) == "Chase.LOOK"
	var converged: bool = await _until(is_look, maxf(0.0, ordered_at + 1.6 - _sim))
	_assert(rotated and converged, "the name is 'Chase.LOOK' again within 1.6 s (%.3f s; the planar angle converges although the prey is 18 deg up; log: %s)" % [_sim - ordered_at, watch.names_text()])
	await _run(0.5)
	_hooks.clear()
	_assert(watch.max_tilt < ROTATION_EPS, "rotation.x == 0 and rotation.z == 0 on every tick, max |tilt| %.6f rad" % watch.max_tilt)
	_assert(watch.max_scale_error < 0.00001, "scale == ONE on every tick, max error %.6f" % watch.max_scale_error)
	_assert(hold["max_gap"] < 0.01, "while holding abs(angle_difference(rotation.y, facing_yaw)) < 0.01, max %.5f rad" % hold["max_gap"])
	await _end()


## (b) the root snaps to the velocity, the visible facing follows at 120 deg/s (V1, C2, N4).
func _x08b_facing_while_travelling() -> void:
	_begin("X08b facing while travelling straight behind")
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	if not await _await_active(demon):
		await _end()
		return
	var graphics := demon.get_node_or_null("Graphics") as Node3D
	var start_yaw: float = demon.facing_yaw
	demon.call_to_position(Vector3(0.0, 0.0, 20.0), 0.0, 5.0)
	await _run(0.5)
	var planar_velocity := Vector3(demon.velocity.x, 0.0, demon.velocity.z)
	var root_forward: Vector3 = -demon.global_transform.basis.z
	var moving := planar_velocity.length() > 0.5
	var root_error: float = rad_to_deg(root_forward.angle_to(planar_velocity.normalized())) if moving else 180.0
	var heading_error: float = rad_to_deg(planar_velocity.normalized().angle_to(Vector3.BACK)) if moving else 180.0
	_assert(moving and root_error < 5.0 and heading_error < 5.0, "0.5 s after the order the root -basis.z is %.2f deg from the velocity direction, which is %.2f deg from +Z (expected < 5 each; speed %.2f m/s)" % [root_error, heading_error, planar_velocity.length()])
	var turned: float = absf(rad_to_deg(angle_difference(start_yaw, demon.facing_yaw)))
	_assert(turned >= 48.0 and turned <= 72.0, "facing_yaw has turned %.2f deg from its start (expected 60 +- 12: 120 deg/s)" % turned)
	if graphics != null:
		var graphics_forward: Vector3 = -graphics.global_transform.basis.z
		var facing_forward: Vector3 = demon.facing_forward()
		var graphics_error: float = rad_to_deg(graphics_forward.angle_to(facing_forward))
		_assert(graphics_error < 1.0, "Graphics' world forward is %.3f deg from facing_forward() (expected < 1)" % graphics_error)
	else:
		_assert(false, "the demon has a Graphics node")
	await _run(1.5)
	var gap: float = absf(rad_to_deg(angle_difference(demon.rotation.y, demon.facing_yaw)))
	_assert(gap < 5.0, "after 2.0 s the facing is %.2f deg from the root (expected < 5)" % gap)
	await _end()


# --- X09 ---------------------------------------------------------------------------------------

## The neck write survives the mixer; 75 deg is a gate, not a clamp; the measure is planar (B6).
func _x09_neck() -> void:
	_begin("X09 neck twist")
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	if not await _await_active(demon):
		await _end()
		return
	var model := demon.get_node_or_null("Graphics/Model") as Node3D
	var skeleton: Skeleton3D = null
	if model != null:
		var skeletons: Array = model.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty():
			skeleton = skeletons[0] as Skeleton3D
	var neck: int = skeleton.find_bone("Neck") if skeleton != null else -1
	_assert(skeleton != null and neck >= 0, "set-up: the skeleton has a 'Neck' bone")
	if skeleton == null or neck < 0:
		await _end()
		return

	await _run_process(0.5)
	var neck_idle: Quaternion = skeleton.get_bone_pose_rotation(neck)
	var origin: Vector3 = demon.global_position
	var forward: Vector3 = demon.facing_forward()
	var root := _arena["root"] as Node3D
	var targets: Array[Node3D] = []
	for offset: Vector3 in [
		Arena.turned_right(forward, 45.0) * 3.0,                       # (1) 45 deg right, the demon's height
		Arena.turned_right(forward, 110.0) * 3.0,                      # (2) 110 deg right
		Arena.turned_right(forward, 45.0) * 3.0 + Vector3.UP * 3.0,    # (3) 45 deg right and 3 m above
	]:
		var target := Node3D.new()
		target.position = origin + offset
		root.add_child(target)
		targets.append(target)

	# Reads are taken right after `await get_tree().process_frame` (the spike P6 method): the
	# AnimationTree mixes at priority 0, the body node writes the neck at priority 100.
	demon.set_look_target(targets[0])
	await _run_process(1.0)
	var angle_1 := _neck_angle(skeleton, neck, neck_idle)
	_assert(angle_1 >= 30.0 and angle_1 <= 50.0, "(1) target 45 deg to the right: neck angle %.2f deg after 1.0 s (expected 30-50)" % angle_1)
	demon.set_look_target(null)
	var is_straight := func() -> bool:
		return _neck_angle(skeleton, neck, neck_idle) < 2.0
	var relaxed: bool = await _until_process(is_straight, 1.5)
	_assert(relaxed, "(1) after set_look_target(null) the neck angle is below 2 deg within 1.5 s, is %.2f" % _neck_angle(skeleton, neck, neck_idle))

	demon.set_look_target(targets[1])
	await _run_process(1.0)
	var angle_2 := _neck_angle(skeleton, neck, neck_idle)
	_assert(angle_2 < 2.0, "(2) target 110 deg to the right: neck angle %.2f deg after 1.0 s (expected < 2: 75 deg is a gate, a clamp would read 75)" % angle_2)

	demon.set_look_target(targets[2])
	await _run_process(1.0)
	var angle_3 := _neck_angle(skeleton, neck, neck_idle)
	_assert(angle_3 >= 30.0 and angle_3 <= 50.0, "(3) target 45 deg right and 3 m above: neck angle %.2f deg after 1.0 s (expected 30-50: the measure is planar; a Y-inclusive one would read about 60 and give up)" % angle_3)
	demon.set_look_target(null)
	await _end()


func _neck_angle(skeleton: Skeleton3D, neck: int, neck_idle: Quaternion) -> float:
	return rad_to_deg(skeleton.get_bone_pose_rotation(neck).angle_to(neck_idle))


# --- X10 ---------------------------------------------------------------------------------------

## The SE table, on a bare player (no arena, no demon).
func _x10_se_table() -> void:
	_case = "X10 SE table"
	print("\n--- %s ---" % _case)
	_tap_mark = _tap.mark()
	var se_script := load(SE_SCRIPT) as GDScript
	_assert(se_script != null, "the SE script loads")
	if se_script == null:
		return
	var player: Variant = se_script.new()
	_assert(player is AudioStreamPlayer, "the SE script extends AudioStreamPlayer")
	if not (player is AudioStreamPlayer):
		return
	var find := _tiny_wav()
	var look := _tiny_wav()
	var chase := _tiny_wav()
	player.find_stream = find
	player.look_stream = look
	player.chase_stream = chase
	add_child(player)

	player.play_se(SE_FIND)
	_assert(player.stream == find, "play_se(0): stream == find")
	_assert(is_equal_approx(player.volume_db, linear_to_db(0.30)), "play_se(0): volume_db == linear_to_db(0.30) (%.3f), got %.3f" % [linear_to_db(0.30), player.volume_db])
	_assert(is_equal_approx(player.pitch_scale, 1.0), "play_se(0): pitch_scale == 1.0 (not written), got %.3f" % player.pitch_scale)

	player.play_se(SE_CHASE)
	var looping := player.stream as AudioStreamWAV
	_assert(looping != null and looping.loop_mode == AudioStreamWAV.LOOP_FORWARD and looping.loop_end > 0, "play_se(2): the stream is an AudioStreamWAV with loop_mode LOOP_FORWARD and loop_end > 0")
	_assert(chase.loop_mode == AudioStreamWAV.LOOP_DISABLED, "play_se(2): the original chase stream still has LOOP_DISABLED (a private looping copy plays)")
	_assert(is_equal_approx(player.pitch_scale, 0.92), "play_se(2): pitch_scale == 0.92, got %.3f" % player.pitch_scale)
	_assert(is_equal_approx(player.volume_db, linear_to_db(0.25)), "play_se(2): volume_db == linear_to_db(0.25) (%.3f), got %.3f" % [linear_to_db(0.25), player.volume_db])

	player.stop_se()
	player.play_se(SE_LOOK)
	var drone := player.stream as AudioStreamWAV
	_assert(player.stream == look, "stop_se(), play_se(1): stream == look")
	_assert(is_equal_approx(player.pitch_scale, 0.92), "play_se(1): pitch_scale is still 0.92 (SRC quirk: the branch writes no pitch), got %.3f" % player.pitch_scale)
	_assert(drone != null and drone.loop_mode == AudioStreamWAV.LOOP_DISABLED, "play_se(1): not looping")

	# Guard: FIND is dropped while anything plays. Only checkable when the driver reports `playing`.
	player.stop_se()
	player.play_se(SE_CHASE)
	if player.playing:
		var chase_copy: Variant = player.stream
		player.play_se(SE_FIND)
		_assert(player.stream == chase_copy and player.stream != find, "play_se(2); play_se(0) leaves the looping chase copy as the stream")
	else:
		print("  note [%s] `playing` is false right after play_se(2) under this audio driver: the FIND guard is not checked" % _case)
	player.stop_se()
	remove_child(player)
	player.free()
	_assert_no_errors()


func _tiny_wav() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.data = PackedByteArray([0, 0, 0, 0])
	return wav


# --- X11 ---------------------------------------------------------------------------------------

## Red-team D6, plan 8.9: on a map without a navigation region the framework cannot move the body.
func _x11a_no_navmesh_goto() -> void:
	_begin("X11a a map without a navmesh: GOTO ends by the stall rule", "none")
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	_assert(demon._warned.has(&"no_navmesh"), "after activation demon._warned has 'no_navmesh'")
	var start: Vector3 = demon.global_position
	demon.call_to_position(Vector3(0.0, 0.0, -10.0), 0.0, 2.0)
	var ordered_at := _sim
	var is_blocked := func() -> bool:
		return not watch.blocked.is_empty()
	var blocked: bool = await _until(is_blocked, 5.0)
	var blocked_after: float = _since_order(watch.blocked[0][1], ordered_at) if blocked else -1.0
	_assert(blocked and _in_window(blocked_after, 3.0, 3.6), "travel_blocked %.3f s after the order (expected 3.0-3.6: the stall rule, the agent never reports finished here)" % blocked_after)
	var is_idle := func() -> bool:
		return _wander_state(demon) == WANDER_NONE
	var idle: bool = await _until(is_idle, 1.0)
	_assert(idle, "afterwards current_state._state is NONE, got %d ('%s')" % [_wander_state(demon), _name(demon)])
	_assert(watch.blocked.size() == 1, "travel_blocked was emitted exactly once, got %d" % watch.blocked.size())
	var moved: float = Arena.planar(demon.global_position, start)
	_assert(moved < 0.3, "displacement %.3f m (expected < 0.3: the body cannot walk here)" % moved)

	var ahead: Vector3 = demon.global_position + demon.facing_forward() * 8.0
	ahead.y = 0.0
	Arena.add_stub(_arena, ahead)                        # 8 m ahead: the demon still processes
	var is_look := func() -> bool:
		return _name(demon) == "Chase.LOOK"
	var placed_at := _sim
	var looked: bool = await _until(is_look, 1.4)
	_assert(looked, "a stub placed 8 m ahead gives Chase.LOOK within 1.4 s (%.3f s waited, name '%s')" % [_sim - placed_at, _name(demon)])
	await _end()


func _x11b_no_navmesh_chase() -> void:
	_begin("X11b a map without a navmesh: the chase runs on the spot", "none")
	var stub_at := Vector3(0.0, 0.0, -8.0)
	var stub: Variant = Arena.add_stub(_arena, stub_at, Arena.yaw_towards(stub_at, Vector3.ZERO))
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	_assert(demon._warned.has(&"no_navmesh"), "after activation demon._warned has 'no_navmesh'")
	var is_chase := func() -> bool:
		return _name(demon) == "Chase.CHASE"
	var chasing: bool = await _until(is_chase, 6.0)
	_assert(chasing and watch.index_of("Chase.LOOK") >= 0 and watch.index_of("Chase.LOOK") < watch.index_of("Chase.CHASE"), "Chase.LOOK, then Chase.CHASE (log: %s)" % watch.names_text())
	if not chasing:
		await _end()
		return
	var chase_position: Vector3 = demon.global_position
	var chase := {"max_drift": 0.0, "left_chase": false}
	var chase_probe := func() -> void:
		chase["max_drift"] = maxf(chase["max_drift"], Arena.planar(demon.global_position, chase_position))
		if _name(demon) != "Chase.CHASE":
			chase["left_chase"] = true
	_hooks.append(chase_probe)
	await _run(3.0)
	_hooks.clear()
	_assert(not chase["left_chase"], "the name stays 'Chase.CHASE' for 3 s while the prey is visible (log: %s)" % watch.names_text())
	_assert(chase["max_drift"] < 0.3, "displacement over the 3 s of CHASE %.3f m (expected < 0.3: it runs on the spot)" % chase["max_drift"])
	_assert(demon.desired_speed > 2.0, "desired_speed rises above 2.0, is %.3f SRC" % demon.desired_speed)
	_assert(stub.kill_calls == 0, "stub.kill_calls == 0, got %d" % stub.kill_calls)

	stub.global_position = Vector3(0.0, 0.0, 60.0)
	var gone_at := _sim
	var is_lost := func() -> bool:
		return _name(demon) == "Chase.LOST"
	var lost: bool = await _until(is_lost, 4.5)
	_assert(lost, "after the stub is gone: Chase.LOST within 4.5 s (%.3f s, name '%s')" % [_sim - gone_at, _name(demon)])
	if lost:
		var lost_at := _sim
		var lost_index: int = watch.index_of("Chase.LOST")
		var is_back := func() -> bool:
			return watch.index_of("Wandering", lost_index) >= 0
		var gave_up: bool = await _until(is_back, 3.6)
		_assert(gave_up, "then Wandering within 3.6 s more (%.3f s; log: %s)" % [_sim - lost_at, watch.names_text()])
	await _end()


# --- R1: nodes that are freed, or leave the tree, while the demon holds them -------------------

## A freed object still compares equal to null, so "reads null" is tested on the Variant's type.
func _is_nil(value: Variant) -> bool:
	return typeof(value) == TYPE_NIL


func _r1a_prey_freed_mid_chase() -> void:
	_begin("R1a the prey is freed in the middle of a forced chase")
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, -14.0))
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	demon.force_chase()
	var is_pursuing := func() -> bool:
		return demon.current_target == stub
	var pursuing: bool = await _until(is_pursuing, 2.0)
	_assert(pursuing and int(demon._travel.command) == COMMAND_PURSUE, "set-up: a live PURSUE of the stub (name '%s', command %d)" % [_name(demon), int(demon._travel.command)])
	stub.free()
	await _step()
	_assert(_is_nil(demon.target), "one tick after the free demon.target reads null (typeof %d; %d would be a freed object)" % [typeof(demon.target), TYPE_OBJECT])
	_assert(_is_nil(demon.current_target), "demon.current_target reads null (typeof %d)" % typeof(demon.current_target))
	_assert(_is_nil(demon._travel.pursued) and int(demon._travel.command) != COMMAND_PURSUE, "_travel.pursued is null (typeof %d) and the command is no longer PURSUE (%d)" % [typeof(demon._travel.pursued), int(demon._travel.command)])
	var is_wandering := func() -> bool:
		return _name(demon) == "Wandering"
	var gave_up: bool = await _until(is_wandering, 0.6)
	_assert(gave_up and demon.is_chase == false and watch.chase_logged(false), "within 0.6 s the forced chase gives up: name 'Wandering' ('%s'), is_chase == false (%s), chase_changed(false) logged" % [_name(demon), demon.is_chase])
	var is_thinking := func() -> bool:
		return _wander_state(demon) == WANDER_THINKING
	var dwelling: bool = await _until(is_thinking, 1.5)
	_assert(dwelling, "1.5 s later it dwells where it gave up (current_state._state THINKING, got %d): the tick is alive" % _wander_state(demon))
	await _end()


## The body node reads the look target in the idle frame, between two physics ticks.
func _r1b_prey_freed_during_the_stare() -> void:
	_begin("R1b the prey is freed at idle time during the stare")
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, -8.0))
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	var is_look := func() -> bool:
		return _name(demon) == "Chase.LOOK"
	var looked: bool = await _until(is_look, 4.0)
	_assert(looked and demon.look_target == stub and demon.is_looking_at_something() == true, "set-up: Chase.LOOK with the stub as the look target (log: %s)" % watch.names_text())
	if not looked:
		await _end()
		return
	await get_tree().process_frame
	stub.free()
	var looking: Variant = demon.is_looking_at_something()
	_assert(looking is bool and looking == false, "right after the free is_looking_at_something() returns false, got %s" % [looking])
	_assert(_is_nil(demon.look_target), "demon.look_target reads null (typeof %d)" % typeof(demon.look_target))
	var fallback: Vector3 = demon.global_position + demon.facing_forward() * 5.0
	var look_position: Variant = demon.get_look_position()
	_assert(look_position is Vector3 and (look_position as Vector3).is_equal_approx(fallback), "get_look_position() is the facing fallback %s, got %s" % [fallback, look_position])
	await _step()                                        # from idle time to the next tick boundary: no tick has run yet
	await _step()
	_assert(demon.look_target == demon.dummy_look_target and demon._has_explicit_look_target == false, "one tick later look_target is dummy_look_target (%s) and _has_explicit_look_target is false (%s)" % [demon.look_target == demon.dummy_look_target, demon._has_explicit_look_target])
	var mark: int = watch.names.size()
	var is_wandering := func() -> bool:
		return watch.index_of("Wandering", mark) >= 0
	var broke: bool = await _until(is_wandering, 3.0)
	_assert(broke and watch.count_prefix("Chase.CHASE") == 0, "the stare ends in Wandering, never in Chase.CHASE (log: %s)" % watch.names_text())
	await _end()


func _r1c_spawner_target_freed_before_activation() -> void:
	_begin("R1c a spawner's current_target is freed before the boot gate passes")
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, -8.0))
	var demon: Variant = _spawn(Vector3(0.0, 0.05, 0.0), 0.0, "", false)
	if demon == null:
		await _end()
		return
	demon.current_target = stub
	stub.free()
	var watch: Variant = _watch(demon)
	if await _await_active(demon, 2.5):
		await _step()
		_assert(_is_nil(demon.current_target), "one tick after activation demon.current_target reads null (typeof %d)" % typeof(demon.current_target))
		_assert(watch.first_name() == "Wandering", "the first state name is 'Wandering', got '%s' (log: %s)" % [watch.first_name(), watch.names_text()])
		var goal := Vector3(0.0, 0.0, -4.0)
		demon.call_to_position(goal, 0.0, 2.0)
		var is_there := func() -> bool:
			return Arena.planar(demon.global_position, goal) <= 0.7
		var arrived: bool = await _until(is_there, 4.0)
		_assert(arrived, "the demon obeys an order afterwards (%.3f m from (0, 0, -4)): the tick is alive" % Arena.planar(demon.global_position, goal))
	await _end()


func _r1d_order_right_after_the_free() -> void:
	_begin("R1d force_chase() between the free and the demon's next tick")
	var stub: Variant = Arena.add_stub(_arena, Vector3(20.0, 0.0, 20.0))
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	var has_target := func() -> bool:
		return demon.target == stub
	var targeted: bool = await _until(has_target, 1.0)
	_assert(targeted, "set-up: demon.target == stub")
	stub.free()
	demon.force_chase()
	# chase_changed(true) and the FIND sting are the last two things the chase state's init does.
	_assert(_name(demon) == "Chase.FORCE_CHASE" and watch.chase_logged(true) and watch.se_count(SE_FIND) == 1, "the order is taken: name '%s', chase_changed(true) logged (%s) and se_requested(FIND) once (%d): the state's init ran to its end" % [
		_name(demon), watch.chase_logged(true), watch.se_count(SE_FIND)])
	_assert(demon.look_target == demon.dummy_look_target and demon.is_looking_at_something() == false, "look_target is dummy_look_target and is_looking_at_something() is false")
	var is_wandering := func() -> bool:
		return _name(demon) == "Wandering"
	var gave_up: bool = await _until(is_wandering, 0.6)
	_assert(gave_up, "with no prey left the forced chase gives up within 0.6 s, name '%s'" % _name(demon))
	await _end()


func _r1e_replacement_prey() -> void:
	_begin("R1e the chased prey is freed and a new prey node appears")
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, -14.0))
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	if not await _await_active(demon):
		await _end()
		return
	demon.force_chase()
	var is_pursuing := func() -> bool:
		return demon.current_target == stub
	var pursuing: bool = await _until(is_pursuing, 2.0)
	_assert(pursuing, "set-up: a live PURSUE of the first stub")
	stub.free()
	var fresh: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, -20.0))
	var is_adopted := func() -> bool:
		return demon.target == fresh
	var adopted: bool = await _until(is_adopted, 0.6)
	_assert(adopted, "demon.target is the new stub within 0.6 s, got %s" % [demon.target])
	_assert(demon.are_senses_blocked() == false, "are_senses_blocked() is false: a newly resolved prey starts no revive grace (_revive_grace_left %.2f)" % demon._revive_grace_left)
	await _end()


## A respawn or a reparent takes the prey out of the tree without freeing it: it has no global transform.
func _r1f_prey_removed_not_freed() -> void:
	_begin("R1f the prey leaves the tree (not freed) during the stare, and comes back")
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, -8.0))
	stub.velocity = Vector3(8.0, 0.0, 0.0)               # sprint-loud: only its absence keeps it unheard
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	var is_look := func() -> bool:
		return _name(demon) == "Chase.LOOK"
	var looked: bool = await _until(is_look, 4.0)
	_assert(looked and demon.is_feel_player_sound() == true, "set-up: Chase.LOOK, and the stub is heard while it is in the tree (log: %s)" % watch.names_text())
	if not looked:
		await _end()
		return
	var players := _arena["players"] as Node3D
	players.remove_child(stub)
	_assert(_is_nil(demon.target), "right after remove_child demon.target reads null (typeof %d)" % typeof(demon.target))
	_assert(is_inf(demon.distance_to_target()), "distance_to_target() == INF, got %s" % [demon.distance_to_target()])
	var own: Vector3 = demon.target_position_or_own()
	_assert(own.is_equal_approx(demon.global_position), "target_position_or_own() is the demon's own position, got %s" % own)
	_assert(demon.is_feel_player_sound() == false and demon.is_find_player(50.0, 120.0) == false, "is_feel_player_sound() and is_find_player(50, 120) are false")
	_assert(demon.is_looking_at_something() == false, "is_looking_at_something() is false")
	var fallback: Vector3 = demon.global_position + demon.facing_forward() * 5.0
	var look_position: Vector3 = demon.get_look_position()
	_assert(look_position.is_equal_approx(fallback), "get_look_position() is the facing fallback %s, got %s (not the world origin)" % [fallback, look_position])
	await _run(1.0)
	players.add_child(stub)
	var is_back := func() -> bool:
		return demon.target == stub
	var adopted: bool = await _until(is_back, 0.6)
	_assert(adopted, "re-added: demon.target == stub again within 0.6 s, got %s" % [demon.target])
	await _end()


func _r1f2_pursued_prey_removed() -> void:
	_begin("R1f2 the pursued prey leaves the tree: remaining_distance stays readable")
	var stub: Variant = Arena.add_stub(_arena, Vector3(10.0, 0.0, -14.0))
	var demon: Variant = _spawn(Vector3(10.0, 0.0, 0.0))
	if demon == null:
		await _end()
		return
	if not await _await_active(demon):
		await _end()
		return
	demon.force_chase()
	var is_pursuing := func() -> bool:
		return demon.current_target == stub
	var pursuing: bool = await _until(is_pursuing, 2.0)
	await _run(0.5)
	_assert(pursuing and int(demon._travel.command) == COMMAND_PURSUE, "set-up: a live PURSUE of the stub")
	(_arena["players"] as Node3D).remove_child(stub)
	# Between the removal and the next tick the travel layer still holds the node; it measures to its stored
	# destination (where the chase began, 10 m from the world origin) instead of reading the node's position.
	var stored: Vector3 = demon._travel.destination
	var expected: float = maxf(Arena.planar(demon.global_position, stored), 1.0)
	var remaining: float = demon.remaining_distance
	_assert(int(demon._travel.command) == COMMAND_PURSUE and absf(remaining - expected) < 0.001, "still PURSUE: remaining_distance %.3f is the distance to the stored destination %s (%.3f), not to the world origin (%.3f)" % [
		remaining, stored, expected, Arena.planar(demon.global_position, Vector3.ZERO)])
	await _step()
	_assert(_is_nil(demon.current_target) and int(demon._travel.command) != COMMAND_PURSUE, "one tick later the pursuit is dropped: current_target null (typeof %d), command %d" % [typeof(demon.current_target), int(demon._travel.command)])
	stub.free()
	await _end()


## Ring A -> B -> C -> A; B is taken out of the tree (an undoable delete, a sub-scene being swapped).
func _r1g_successor_outside_the_tree() -> void:
	_begin("R1g a successor that left the tree is never walked to")
	var a: Variant = Arena.add_point(_arena, "A", Vector3(0.0, 0.0, -6.0), 0.0, 3.0, 1.0)
	var b: Variant = Arena.add_point(_arena, "B", Vector3(8.0, 0.0, -6.0), 0.0, 3.0, 1.0)
	var c: Variant = Arena.add_point(_arena, "C", Vector3(8.0, 0.0, 4.0), 0.0, 3.0, 1.0)
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null or a == null or b == null or c == null:
		_assert(false, "set-up: demon and the three points exist")
		await _end()
		return
	Arena.link(a, [b])
	Arena.link(b, [c])
	Arena.link(c, [a])
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	await _run(0.3)
	(_arena["points"] as Node3D).remove_child(b)         # during the leg to A
	var is_at_a := func() -> bool:
		return _point_source(demon) == a and _wander_state(demon) == WANDER_THINKING
	var arrived: bool = await _until(is_at_a, 8.0)
	_assert(arrived, "set-up: the demon dwells at A (log: %s)" % watch.names_text())
	if arrived:
		var next_data: Variant = demon.current_state._next_point
		var next_source: Variant = next_data.source_point if next_data != null else null
		_assert(next_source == c, "at A the next point is C (the nearest other point in the tree), not the detached successor B; got %s" % [next_source])
		_assert(a.pick_next() == null, "A.pick_next() returns null while its only successor is outside the tree")
		var seen := {"origin_ticks": 0, "ticks": 0}
		var destination_probe := func() -> void:
			var destination: Vector3 = demon._travel.destination
			seen["ticks"] += 1
			if destination.is_zero_approx():
				seen["origin_ticks"] += 1
		_hooks.append(destination_probe)
		var is_at_c := func() -> bool:
			return _point_source(demon) == c
		var went_on: bool = await _until(is_at_c, 6.0)
		_hooks.clear()
		_assert(went_on, "the demon arrives at C within 6 s (%.3f m from it)" % Arena.planar(demon.global_position, c.global_position))
		_assert(seen["origin_ticks"] == 0, "_travel.destination was the world origin on %d of %d ticks (expected 0: B's position is not read outside the tree)" % [seen["origin_ticks"], seen["ticks"]])
		var signals_before: int = watch.state_signals.size()
		demon.call_to(b)
		await _step()
		_assert(watch.state_signals.size() == signals_before, "call_to(B) with B outside the tree: no state_changed (%d -> %d)" % [signals_before, watch.state_signals.size()])
	b.free()
	await _end()


## Nothing had to be fixed here; the case pins what was observed: the leg to a freed point is finished at the
## remembered position, and the patrol goes on along the successor list the point's data had copied.
func _r1h_point_freed_mid_leg() -> void:
	_begin("R1h the patrol point the demon walks to is freed mid-leg")
	var a: Variant = Arena.add_point(_arena, "A", Vector3(0.0, 0.0, -6.0), 0.0, 3.0, 1.0)
	var b: Variant = Arena.add_point(_arena, "B", Vector3(8.0, 0.0, -6.0), 0.0, 3.0, 1.0)
	var c: Variant = Arena.add_point(_arena, "C", Vector3(8.0, 0.0, 4.0), 0.0, 3.0, 1.0)
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null or a == null or b == null or c == null:
		_assert(false, "set-up: demon and the three points exist")
		await _end()
		return
	Arena.link(a, [b])
	Arena.link(b, [c])
	Arena.link(c, [a])
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	await _run(0.5)
	var a_position: Vector3 = a.global_position
	var first: Vector3 = demon._travel.destination
	_assert(first.distance_to(a_position) < 0.01 and _wander_state(demon) == WANDER_MOVE, "set-up: walking to A %s, _travel.destination %s" % [a_position, first])
	a.free()
	var is_thinking := func() -> bool:
		return _wander_state(demon) == WANDER_THINKING
	var arrived: bool = await _until(is_thinking, 8.0)
	var a_distance: float = Arena.planar(demon.global_position, a_position)
	_assert(arrived and a_distance <= 0.7, "the leg is finished: the demon dwells %.3f m from where A was (expected <= 0.7)" % a_distance)
	var order: PackedStringArray = []
	var visited := {"last": null}
	var visit_probe := func() -> void:
		var source := _point_source(demon)
		if source != null and source != visited["last"]:
			visited["last"] = source
			order.append(String(source.name))
	_hooks.append(visit_probe)
	var lap_done := func() -> bool:
		return order.size() >= 3
	var lapped: bool = await _until(lap_done, 20.0)
	_hooks.clear()
	# B is the successor A's data had copied; C follows by the edge B -> C; from C the only edge leads to the freed
	# A, so the demon falls back to the nearest other point, B.
	_assert(lapped and order == PackedStringArray(["B", "C", "B"]), "then it arrives at B, C, B within 20 s, got [%s] (log: %s)" % [", ".join(order), watch.names_text()])
	await _end()


# --- R2: a demon that starts asleep is absent from its first frame -----------------------------

## `how`: "export" (start_asleep through the configure callback), "sleep_after" (sleep() right after
## add_child, the demon 1 m above the floor), "export_after" (start_asleep set right after add_child, which
## is when EnemySpawnOwnerService runs a spawn_setup), "sleep_before" (sleep() before add_child).
func _r2_absent_from_the_first_frame(label: String, how: String) -> void:
	_begin("R2%s" % label)
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.5, 0.0, 0.5))     # inside the KillZone, clear of the body
	var configure := func(node: Variant) -> void:
		if how == "export":
			node.start_asleep = true
		elif how == "sleep_before":
			node.sleep()
	var at := Vector3(0.0, 1.0 if how == "sleep_after" else 0.0, 0.0)
	var demon: Variant = _spawn(at, 0.0, "", how == "export" or how == "sleep_before", configure)
	if demon == null:
		await _end()
		return
	if how == "sleep_after":
		demon.sleep()
	elif how == "export_after":
		demon.start_asleep = true
	var watch: Variant = _watch(demon)
	var seen := {"samples": 0, "visible": 0, "solid": 0, "ray_hits": 0, "boot_samples": 0, "boot_mask_wrong": 0,
		"active_name": "", "active_y": NAN}
	var sample := func() -> void:
		seen["samples"] += 1
		if demon.visible:
			seen["visible"] += 1
		if demon.collision_layer != 0:
			seen["solid"] += 1
		# What the world sees: a ray on the Enemies layer (2) through the capsule.
		var here: Vector3 = demon.global_position
		var query := PhysicsRayQueryParameters3D.create(here + Vector3(3.0, 0.7, 0.0), here + Vector3(-3.0, 0.7, 0.0), 2)
		if not demon.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			seen["ray_hits"] += 1
		if not demon.active:
			seen["boot_samples"] += 1
			if demon.collision_mask != 55:
				seen["boot_mask_wrong"] += 1
		elif seen["active_name"] == "":
			seen["active_name"] = _name(demon)
			seen["active_y"] = demon.global_position.y
	sample.call()                                        # right after the spawn call: no frame has run yet
	_hooks.append(sample)
	var active: bool = await _await_active(demon, 2.5)
	await _run(0.5)
	_hooks.clear()
	_assert(seen["visible"] == 0 and seen["solid"] == 0, "from the spawn call to 0.5 s after activation (%d samples): visible on %d, collision_layer != 0 on %d (expected 0 and 0)" % [seen["samples"], seen["visible"], seen["solid"]])
	_assert(seen["ray_hits"] == 0, "a ray on the Enemies layer through the body hit on %d of %d samples (expected 0)" % [seen["ray_hits"], seen["samples"]])
	_assert(seen["boot_samples"] >= 2 and seen["boot_mask_wrong"] == 0, "before activation (%d samples) collision_mask == 55 on every sample, wrong on %d (the body still settles on the floor)" % [seen["boot_samples"], seen["boot_mask_wrong"]])
	_assert(active and seen["active_name"] == "Sleeping" and watch.first_name() == "Sleeping" and absf(seen["active_y"]) < 0.05, "at activation the name is 'Sleeping' ('%s') and the body is on the floor (y = %.3f; log: %s)" % [seen["active_name"], seen["active_y"], watch.names_text()])
	_assert(stub.kill_calls == 0, "the stub inside the KillZone was not killed (kill_calls %d)" % stub.kill_calls)

	stub.global_position = Vector3(20.0, 0.0, 20.0)
	await _run(_ticks(3))
	demon.wake()
	var kill_zone: Variant = demon.get_node_or_null("KillZone")
	_assert(_name(demon) == "Wandering" and demon.visible == true and demon.collision_layer == 2 and demon.collision_mask == 55 and kill_zone != null and kill_zone.enabled == true,
		"after wake(): name 'Wandering' ('%s'), visible (%s), collision_layer 2 (%d), collision_mask 55 (%d), KillZone enabled" % [_name(demon), demon.visible, demon.collision_layer, demon.collision_mask])
	await _end()


## start_asleep, but the first state turns out not to be Sleeping: an order right after add_child
## (`by_order`), or a target a spawner supplied (nothing tells the demon when that var is assigned).
func _r2e_not_a_sleeper_after_all(by_order: bool) -> void:
	_begin("R2e start_asleep, then force_chase() right after add_child" if by_order else "R2f start_asleep, then a spawner's current_target")
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, -14.0))
	var asleep := func(node: Variant) -> void:
		node.start_asleep = true
	var demon: Variant = _spawn(Vector3.ZERO, 0.0, "", true, asleep)
	if demon == null:
		await _end()
		return
	_assert(demon.visible == false and demon.collision_layer == 0 and demon._boot_absent == true, "set-up: after add_child the start_asleep demon is hidden and on no layer (visible %s, layer %d, _boot_absent %s)" % [demon.visible, demon.collision_layer, demon._boot_absent])
	if by_order:
		demon.force_chase()
		_assert(demon.visible == true and demon.collision_layer == 2 and demon._boot_absent == false, "from the force_chase() call on it is visible (%s) and on collision_layer 2 (%d)" % [demon.visible, demon.collision_layer])
	else:
		demon.current_target = stub
	var watch: Variant = _watch(demon)
	var seen := {"active_samples": 0, "hidden": 0, "not_solid": 0, "boot_hidden": 0, "boot_samples": 0}
	var sample := func() -> void:
		if demon.active:
			seen["active_samples"] += 1
			if not demon.visible:
				seen["hidden"] += 1
			if demon.collision_layer != 2:
				seen["not_solid"] += 1
		else:
			seen["boot_samples"] += 1
			if not demon.visible:
				seen["boot_hidden"] += 1
	_hooks.append(sample)
	var active: bool = await _await_active(demon, 2.5)
	await _run(0.3)
	_hooks.clear()
	_assert(active and watch.first_name() == "Chase.FORCE_CHASE", "the first state name is 'Chase.FORCE_CHASE', got '%s' (log: %s)" % [watch.first_name(), watch.names_text()])
	_assert(seen["active_samples"] > 0 and seen["hidden"] == 0 and seen["not_solid"] == 0, "from activation on (%d samples): hidden on %d, collision_layer != 2 on %d (expected 0 and 0)" % [seen["active_samples"], seen["hidden"], seen["not_solid"]])
	_assert(demon.collision_mask == 55, "collision_mask == 55, got %d" % demon.collision_mask)
	if by_order:
		_assert(seen["boot_hidden"] == 0, "and it was visible on each of the %d samples before activation (hidden on %d)" % [seen["boot_samples"], seen["boot_hidden"]])
	await _end()


# --- R3: orders given before the boot gate -----------------------------------------------------

## The orders are issued right after add_child (the demon is not active); `expected_first` is the first
## state name the demon then shows, the same an active demon would end in after the same orders.
func _r3_orders_before_activation(label: String, asleep: bool, orders: Array, expected_first: String) -> void:
	_begin("R3%s" % label)
	Arena.add_stub(_arena, Vector3(0.0, 0.0, -12.0))
	var point: Variant = Arena.add_point(_arena, "CallPoint", Vector3(6.0, 0.0, 0.0), 0.0, 2.0, 30.0, "", {"type": 3})   # ONLY_CALL
	var configure := func(node: Variant) -> void:
		node.start_asleep = asleep
	var demon: Variant = _spawn(Vector3.ZERO, PI, "", false, configure)   # facing away from the stub
	if demon == null or point == null:
		_assert(false, "set-up: demon and the point exist")
		await _end()
		return
	_assert(demon.active == false, "set-up: the orders are issued before the boot gate (active == false)")
	for order: String in orders:
		match order:
			"wake":
				demon.wake()
			"force_chase":
				demon.force_chase()
			"force_chase_wait":
				demon.force_chase(5.0)
			"call_to_position":
				demon.call_to_position(Vector3(5.0, 0.0, 0.0))
			"call_to_ignore":
				demon.call_to(point, true)
			"stop_chasing_players":
				demon.stop_chasing_players()
			"stop_force_chase":
				demon.stop_force_chase()
			_:
				_assert(false, "set-up: unknown order '%s'" % order)
	var visible_after_orders: bool = demon.visible
	var watch: Variant = _watch(demon)
	var active: bool = await _await_active(demon, 2.5)
	await _run(0.2)
	_assert(active and watch.first_name() == expected_first, "the first state name is '%s', got '%s' (log: %s)" % [expected_first, watch.first_name(), watch.names_text()])
	if asleep:
		_assert(watch.index_of("Sleeping") < 0, "'Sleeping' never appears (log: %s)" % watch.names_text())
		_assert(visible_after_orders and demon.visible == true and demon.collision_layer == 2, "visible from the wake() call on (%s), and visible (%s) on collision_layer 2 (%d) once active" % [visible_after_orders, demon.visible, demon.collision_layer])
	await _end()


# --- R4: travel_blocked once per blocked blind commit -------------------------------------------

## One chase, three blind commits, each ending at a wall the navmesh does not know: BLOCKED by the stall
## rule, then 2 s of LOST while still blocked, then the wall goes and the prey is seen again.
func _r4_blocked_blind_commits() -> void:
	_begin("R4 travel_blocked once for every blocked blind commit of one chase")
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, -24.0))   # faces away: silent, the chase runs at the cap
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	var is_chase := func() -> bool:
		return _name(demon) == "Chase.CHASE"
	var is_lost := func() -> bool:
		return _name(demon) == "Chase.LOST"
	var chasing: bool = await _until(is_chase, 10.0)
	_assert(chasing, "set-up: the demon reached Chase.CHASE (log: %s)" % watch.names_text())
	if not chasing:
		await _end()
		return
	await _run(0.6)
	var per_commit: Array[int] = []
	var all_lost := true
	var all_blocked := true
	var all_reacquired := true
	for _commit in 3:
		var before: int = watch.blocked.size()
		var wall: StaticBody3D = Arena.add_wall(_arena, Vector3(0.0, 1.5, demon.global_position.z - 2.5), Vector3(30.0, 3.0, 0.5))
		var lost: bool = await _until(is_lost, 8.0)
		all_lost = all_lost and lost
		all_blocked = all_blocked and demon.was_travel_blocked()
		await _run(2.0)                                  # LOST and still blocked: a second emission would show here
		per_commit.append(watch.blocked.size() - before)
		wall.free()
		var reacquired: bool = await _until(is_chase, 2.0)
		all_reacquired = all_reacquired and reacquired
		await _run(0.4)
	_assert(all_lost and all_blocked and all_reacquired, "set-up: each of the 3 rounds ended in Chase.LOST (%s) with the travel BLOCKED (%s) and was re-acquired once the wall was gone (%s); stub.kill_calls %d (log: %s)" % [
		all_lost, all_blocked, all_reacquired, stub.kill_calls, watch.names_text()])
	_assert(per_commit == ([1, 1, 1] as Array[int]), "travel_blocked emissions per blocked blind commit: %s (expected [1, 1, 1]: re-armed by each new commit, never twice for one)" % [per_commit])
	await _end()


# --- R6: the warp order -----------------------------------------------------------------------

## Two two-point rings: A <-> B near the demon, C <-> D far away. C has yaw 90 deg and a 2 s dwell.
func _warp_graph(room: String = "") -> Array:
	var a: Variant = Arena.add_point(_arena, "A", Vector3(0.0, 0.0, -6.0), 0.0, 3.0, 1.0, room)
	var b: Variant = Arena.add_point(_arena, "B", Vector3(8.0, 0.0, -6.0), 0.0, 3.0, 1.0, room)
	var c: Variant = Arena.add_point(_arena, "C", Vector3(-14.0, 0.0, 12.0), PI * 0.5, 3.0, 2.0, room)
	var d: Variant = Arena.add_point(_arena, "D", Vector3(-14.0, 0.0, 20.0), 0.0, 3.0, 1.0, room)
	if a == null or b == null or c == null or d == null:
		return []
	Arena.link(a, [b])
	Arena.link(b, [a])
	Arena.link(c, [d])
	Arena.link(d, [c])
	return [a, b, c, d]


## Spawns the demon for an R6 case. Null (after a failed assertion) when it, the graph or the order is missing.
func _warp_demon(points: Array, at: Vector3, room: String = "", place_first: bool = true, configure: Callable = Callable()) -> Variant:
	var demon: Variant = _spawn(at, 0.0, room, place_first, configure)
	if demon == null or points.is_empty():
		_assert(false, "set-up: demon and the four points exist")
		return null
	if not demon.has_method(&"warp_call_to"):
		_assert(false, "the demon has the order warp_call_to(point, ignore_while_chase, min_distance)")
		return null
	return demon


func _r6a_warp_and_resume() -> void:
	_begin("R6a warp_call_to(C): at the point in the same call, then the patrol resumes there")
	var points := _warp_graph()
	var demon: Variant = _warp_demon(points, Vector3.ZERO)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	await _run(0.5)
	var c: Variant = points[2]
	var d: Variant = points[3]
	var c_position: Vector3 = c.global_position
	var a_position: Vector3 = points[0].global_position
	var before: Vector3 = demon._travel.destination
	_assert(before.distance_to(a_position) < 0.01 and Arena.planar(demon.global_position, c_position) > 15.0, "set-up: walking to A, %.2f m from C" % Arena.planar(demon.global_position, c_position))
	var signals_before: int = watch.state_signals.size()
	var blocked_before: int = watch.blocked.size()
	var yaw_before: float = demon.facing_yaw
	demon.warp_call_to(c)
	var at_once: float = demon.global_position.distance_to(c_position)
	var planar_speed: float = Vector2(demon.velocity.x, demon.velocity.z).length()
	_assert(at_once < 0.01 and is_zero_approx(planar_speed), "in the same call the demon is at C (%.3f m from it) with zero planar velocity (%.3f)" % [at_once, planar_speed])
	var checkpoint: Vector3 = demon._last_position
	_assert(checkpoint.distance_to(c_position) < 0.01, "the teleport checkpoint already holds C (%.3f m off): the demon's own warp is not an external teleport" % checkpoint.distance_to(c_position))
	_assert(watch.state_signals.size() == signals_before + 1 and String(watch.state_signals[-1][0]) == "Wandering", "exactly one state_changed('Wandering') (%d -> %d)" % [signals_before, watch.state_signals.size()])
	await _run(_ticks(2))
	_assert(Arena.planar(demon.global_position, c_position) < 0.2 and is_equal_approx(demon.facing_yaw, yaw_before), "two ticks later it is still at C (%.3f m) and its facing is unchanged" % Arena.planar(demon.global_position, c_position))
	var is_dwelling := func() -> bool:
		return _wander_state(demon) == WANDER_THINKING and _point_source(demon) == c
	var dwelling: bool = await _until(is_dwelling, 2.0)
	_assert(dwelling, "within 2 s it dwells at C (current_state._state %d, current_point.source_point == C: %s)" % [_wander_state(demon), _point_source(demon) == c])
	var is_at_d := func() -> bool:
		return _point_source(demon) == d
	var went_on: bool = await _until(is_at_d, 12.0)
	_assert(went_on, "then it walks on to C's successor D within 12 s (%.3f m from D)" % Arena.planar(demon.global_position, d.global_position))
	_assert(watch.state_signals.size() == signals_before + 1 and watch.blocked.size() == blocked_before, "no further state_changed (%d) and no travel_blocked (%d) on the way" % [watch.state_signals.size() - signals_before - 1, watch.blocked.size() - blocked_before])
	await _end()


func _r6b_warp_refusals() -> void:
	_begin("R6b warp_call_to refusals: null, another room, outside the tree, inside min_distance")
	var points := _warp_graph("Main")
	var other: Variant = Arena.add_point(_arena, "Other", Vector3(14.0, 0.0, 14.0), 0.0, 3.0, 1.0, "Elsewhere")
	var loose: Variant = Arena.add_point(_arena, "Loose", Vector3(3.0, 0.0, 3.0), 0.0, 3.0, 1.0, "Main")
	var demon: Variant = _warp_demon(points, Vector3.ZERO, "Main")
	if demon == null or other == null or loose == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	await _run(0.3)
	var c: Variant = points[2]
	var c_position: Vector3 = c.global_position
	var here: Vector3 = demon.global_position
	var signals_before: int = watch.state_signals.size()

	demon.warp_call_to(null)
	_assert(watch.state_signals.size() == signals_before and demon.global_position == here, "warp_call_to(null): no state_changed and no movement")
	demon.warp_call_to(other)
	_assert(watch.state_signals.size() == signals_before and demon.global_position == here and demon.current_room == "Main", "a point of room 'Elsewhere' is refused for a demon in 'Main': no state_changed, no movement, room still '%s'" % demon.current_room)
	_assert(demon._warned.has(StringName("warp_other_room_%d" % other.get_instance_id())), "and the refusal is loud (demon._warned has the point's key)")
	(_arena["points"] as Node3D).remove_child(loose)
	demon.warp_call_to(loose)
	_assert(watch.state_signals.size() == signals_before and demon.global_position == here, "a point outside the tree is refused: no state_changed and no movement")
	loose.free()
	var distance: float = demon.global_position.distance_to(c_position)
	demon.warp_call_to(c, false, distance + 1.0)
	_assert(watch.state_signals.size() == signals_before and demon.global_position == here, "min_distance %.2f with the demon %.2f m from C: refused (already close), no state_changed and no movement" % [distance + 1.0, distance])
	demon.warp_call_to(c, false, distance - 1.0)
	_assert(watch.state_signals.size() == signals_before + 1 and demon.global_position.distance_to(c_position) < 0.01, "min_distance %.2f: warped (one state_changed, %.3f m from C)" % [distance - 1.0, demon.global_position.distance_to(c_position)])
	await _end()


func _r6c_warp_wakes_a_sleeper() -> void:
	_begin("R6c warp_call_to wakes a sleeping demon at the point")
	var points := _warp_graph()
	var asleep := func(node: Variant) -> void:
		node.start_asleep = true
	var demon: Variant = _warp_demon(points, Vector3.ZERO, "", true, asleep)
	if demon == null:
		await _end()
		return
	if not await _await_active(demon):
		await _end()
		return
	await _run(0.3)
	var c_position: Vector3 = points[2].global_position
	_assert(_name(demon) == "Sleeping" and demon.visible == false, "set-up: asleep and hidden ('%s')" % _name(demon))
	demon.warp_call_to(points[2])
	await _run(_ticks(2))
	_assert(_name(demon) == "Wandering" and demon.visible == true and demon.collision_layer == 2 and Arena.planar(demon.global_position, c_position) < 0.2,
		"two ticks later: name 'Wandering' ('%s'), visible (%s), collision_layer 2 (%d), %.3f m from C" % [_name(demon), demon.visible, demon.collision_layer, Arena.planar(demon.global_position, c_position)])
	await _end()


func _r6d_warp_before_activation() -> void:
	_begin("R6d warp_call_to right after add_child is queued")
	var points := _warp_graph()
	var demon: Variant = _warp_demon(points, Vector3.ZERO, "", false)
	if demon == null:
		await _end()
		return
	var c_position: Vector3 = points[2].global_position
	demon.warp_call_to(points[2])
	var watch: Variant = _watch(demon)
	_assert(demon.active == false and demon.global_position.distance_to(Vector3.ZERO) < 0.01, "before activation the demon has not moved (%.3f m from its spawn)" % demon.global_position.distance_to(Vector3.ZERO))
	if await _await_active(demon, 2.5):
		_assert(Arena.planar(demon.global_position, c_position) < 0.2 and watch.first_name() == "Wandering", "at activation it is at C (%.3f m) and the first state name is 'Wandering' ('%s')" % [Arena.planar(demon.global_position, c_position), watch.first_name()])
		var is_dwelling := func() -> bool:
			return _wander_state(demon) == WANDER_THINKING and _point_source(demon) == points[2]
		var dwelling: bool = await _until(is_dwelling, 2.0)
		_assert(dwelling, "within 2 s it dwells at C")
	await _end()


func _r6e_warp_while_chasing() -> void:
	_begin("R6e warp_call_to while chasing")
	var points := _warp_graph()
	Arena.add_stub(_arena, Vector3(20.0, 0.0, -20.0))
	var demon: Variant = _warp_demon(points, Vector3.ZERO)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	demon.force_chase()
	await _run(1.0)
	var c_position: Vector3 = points[2].global_position
	var here: Vector3 = demon.global_position
	var state_before: Variant = demon.current_state
	demon.warp_call_to(points[2], true)
	_assert(demon.current_state == state_before and _name(demon).begins_with("Chase") and demon.global_position == here, "with ignore_while_chase the order is refused: same state object ('%s'), no movement" % _name(demon))
	demon.warp_call_to(points[2], false)
	await _run(_ticks(2))
	var chase_log: Array = []
	for entry: Variant in watch.chase:
		chase_log.append(entry[0])
	_assert(_name(demon) == "Wandering" and Arena.planar(demon.global_position, c_position) < 0.2, "without the flag the chase ends at the point: name '%s', %.3f m from C" % [_name(demon), Arena.planar(demon.global_position, c_position)])
	_assert(chase_log == [true, false] and demon.current_target == null and int(demon._travel.command) != COMMAND_PURSUE, "chase_changed log %s (expected [true, false]), current_target null (%s), command %d is not PURSUE" % [chase_log, demon.current_target, int(demon._travel.command)])
	await _end()


# --- harness -----------------------------------------------------------------------------------

func _begin(case_name: String, navmesh: String = "quad") -> void:
	if not _arena.is_empty():
		# The previous case ended without its _end() (a script error cut it short): leave nothing behind.
		_assert(false, "the previous case ('%s') did not reach its end" % _case)
		_drop_arena()
	_case = case_name
	print("\n--- %s ---" % case_name)
	_tap_mark = _tap.mark()
	_arena = Arena.build(self, navmesh)


func _end() -> void:
	_assert_no_errors()
	_drop_arena()
	await _step()


## Every case ends with this: its assertions are worth nothing on top of a script error, and an engine error
## (a transform read outside the tree, a freed object) is a defect even when every value still looks right.
func _assert_no_errors() -> void:
	var logged: Vector2i = _tap.mark() - _tap_mark
	_assert(logged == Vector2i.ZERO, "no script error (%d) and no engine error (%d) was logged during the case%s" % [logged.x, logged.y, _tap.describe_since(_tap_mark)])


## After the last case: it has no _begin() behind it that would notice that it was cut short. And one check
## over the whole run: an error logged by a case that was cut short, or between two cases, belongs to no
## case's own check.
func _finish_cases() -> void:
	if not _arena.is_empty():
		_assert(false, "the last case ('%s') did not reach its end" % _case)
		_drop_arena()
	var logged: Vector2i = _tap.mark()
	_case = "whole run"
	_assert(logged == Vector2i.ZERO, "no script error (%d) and no engine error (%d) was logged from the first case to the last%s" % [logged.x, logged.y, _tap.describe_since(Vector2i.ZERO)])
	OS.remove_logger(_tap)


func _drop_arena() -> void:
	_hooks.clear()
	_watches.clear()
	Arena.free_arena(_arena)


func _spawn(at: Vector3, yaw: float = 0.0, room: String = "", place_first: bool = true,
		configure: Callable = Callable()) -> Variant:
	var demon: Variant = Arena.add_demon(_arena, at, yaw, room, place_first, configure)
	if demon == null:
		_assert(false, "the demon scene instantiates with an Enemy root")
	return demon


func _watch(demon: Variant) -> Variant:
	var watch: Variant = Arena.Watch.new(demon, _sim)
	_watches.append(watch)
	if not watch.missing_signals.is_empty():
		_assert(false, "the demon has the signals the tests observe; missing: %s" % ", ".join(PackedStringArray(watch.missing_signals)))
	return watch


func _await_active(demon: Variant, budget: float = ACTIVATION_BUDGET) -> bool:
	var started_at := _sim
	var is_active := func() -> bool:
		return demon.active
	var active: bool = await _until(is_active, budget)
	_assert(active, "the demon became active %.3f s after its spawn (budget %.1f)" % [_sim - started_at, budget])
	return active


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


## Process-frame stepping for the presentation case: bone poses are written in the idle frame.
func _run_process(seconds: float) -> void:
	var waited := 0.0
	while waited < seconds - 0.000001:
		await get_tree().process_frame
		waited += get_process_delta_time()
		_unstepped = 0.0


func _until_process(condition: Callable, max_seconds: float) -> bool:
	if condition.call():
		return true
	var waited := 0.0
	while waited < max_seconds - 0.000001:
		await get_tree().process_frame
		waited += get_process_delta_time()
		_unstepped = 0.0
		if condition.call():
			return true
	return false


func _ticks(count: int) -> float:
	return count * get_physics_process_delta_time()


func _in_window(value: float, low: float, high: float) -> bool:
	return value >= low - TIME_EPS and value <= high + TIME_EPS


## Simulated seconds from an order the test issued at `order_sim` (between two ticks) to the END of
## the tick that the observer logged as `event_time`.
func _since_order(event_time: float, order_sim: float) -> float:
	return event_time + get_physics_process_delta_time() - order_sim


func _name(demon: Variant) -> String:
	return String(demon.get_state_name())


## current_state._state when the wandering state is current, else -1.
func _wander_state(demon: Variant) -> int:
	if not is_instance_valid(demon) or demon.current_state == null or _name(demon) != "Wandering":
		return -1
	return int(demon.current_state._state)


## current_state.current_point.source_point when the wandering state is current, else null (also for a
## point that was freed: a freed object cannot be cast).
func _point_source(demon: Variant) -> Node:
	if _wander_state(demon) < 0:
		return null
	var data: Variant = demon.current_state.current_point
	if data == null:
		return null
	var source: Variant = data.source_point
	return source as Node if is_instance_valid(source) else null


func _assert(condition: bool, message: String) -> void:
	var text := "[%s] %s" % [_case, message]
	if condition:
		print("  ok   ", text)
	else:
		_failed = true
		push_error("ASSERT FAILED: " + text)
		print("  FAIL ", text)
