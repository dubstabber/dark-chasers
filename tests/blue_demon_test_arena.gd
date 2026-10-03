extends RefCounted
## Shared harness for the blue demon tests. Loaded with
## `const Arena := preload("res://tests/blue_demon_test_arena.gd")`. Names no BlueDemon* class.
##
## It builds a flat arena with a hand-authored navigation mesh (valid on entering the tree, no bake),
## a stub prey, mock room transitions and patrol points, and it carries the per-demon observer
## ([Watch]) the three behaviour runners sample after every physics frame and the error tap
## ([ErrorTap]) they check at the end of every case.

const DEMON_SCENE := "res://scenes/enemies/blue_demon.tscn"
const POINT_SCRIPT := "res://scenes/components/enemy/blue_demon/blue_demon_patrol_point.gd"
const DEMON_GLB := "res://models/blue_demon/blue_demon.glb"

const NAVMESH_HALF_EXTENT := 28.0
const FLOOR_SIZE := Vector3(80.0, 1.0, 80.0)
const LAYER_PLAYER := 1
const LAYER_WALLS := 4


## Test double for the player: satisfies Mortal, Aimable, RoomAware, the demon's prey adapter and the
## KillZone's group test. It is never simulated: tests move it by writing `global_position` and make
## noise by writing `velocity`.
class StubPrey extends CharacterBody3D:
	var current_room: String = ""
	var is_stand_up := true
	var is_flash_light_on := false
	var dead := false
	var kill_calls := 0

	var _collider: CollisionShape3D
	var _capsule: CapsuleShape3D


	func _init() -> void:
		_capsule = CapsuleShape3D.new()
		_capsule.radius = 0.25
		_capsule.height = 1.2
		_collider = CollisionShape3D.new()
		_collider.name = "CollisionShape3D"
		_collider.shape = _capsule
		_collider.position = Vector3(0.0, 0.6, 0.0)
		add_child(_collider)


	func is_dead() -> bool:
		return dead


	func is_alive() -> bool:
		return not dead


	func kill(_pos = null, _msg: String = "") -> void:
		dead = true
		kill_calls += 1


	func revive() -> void:
		dead = false


	func get_aim_point() -> Vector3:
		return global_position + Vector3.UP * (1.0 if is_stand_up else 0.5)


	## Standing: capsule h 1.2 centred at y 0.6. Crouched: h 0.55 centred at y 0.275.
	func set_stance(standing: bool) -> void:
		is_stand_up = standing
		_capsule.height = 1.2 if standing else 0.55
		_collider.position = Vector3(0.0, 0.6 if standing else 0.275, 0.0)


## TransitionsData interface (pattern: tests/test_enemy_navigation_modes.gd:20-31).
class MockTransitions extends Node3D:
	var map_transitions := {}
	var enemy_exceptions: Array = []


	func get_map_transitions() -> Dictionary:
		return map_transitions


	func get_enemy_exceptions() -> Array:
		return enemy_exceptions


## Observer of one demon (plan 11.1 rule 9). The runner calls [method sample] after every physics
## frame; signal logs are filled as the signals fire.
##
## Every logged time is the simulated time at the START of the physics tick in which the thing
## happened: a signal fired in a tick and a state name first seen right after the same tick carry the
## same time, and an order a test issues at time `_sim` is executed in the tick logged as `_sim`.
class Watch extends RefCounted:
	var demon: Node3D
	## Simulated time of the tick that is about to run (signals of that tick are stamped with it).
	var sim := 0.0
	## Simulated time of the tick whose results the last [method sample] call looked at.
	var tick_sim := 0.0
	var names: Array = []            # [state name, time]; only changes are logged
	var state_signals: Array = []    # [state name, time] from state_changed
	var se: Array = []               # [se type, time] from se_requested
	var se_stops: Array = []         # time, from se_stopped
	var chase: Array = []            # [is_chasing, time] from chase_changed
	var blocked: Array = []          # [destination, time] from travel_blocked
	var stamps: Array = []           # [foot index, volume, pitch, time] from the foot's stamped signal
	var missing_signals: Array = []  # signal names the demon (or its foot) does not have
	var path_length := 0.0           # planar metres, accumulated per sampled tick
	var max_tilt := 0.0              # max |rotation.x| / |rotation.z| over all samples, radians
	var max_scale_error := 0.0       # max |scale - ONE| component over all samples

	var _last_position := Vector3.ZERO
	var _has_last_position := false


	func _init(watched: Node3D, start_sim: float) -> void:
		demon = watched
		sim = start_sim
		tick_sim = start_sim
		_connect(demon, &"state_changed", _on_state_changed)
		_connect(demon, &"se_requested", _on_se_requested)
		_connect(demon, &"se_stopped", _on_se_stopped)
		_connect(demon, &"chase_changed", _on_chase_changed)
		_connect(demon, &"travel_blocked", _on_travel_blocked)
		var foot := demon.get_node_or_null(^"BlueDemonFoot")
		if foot != null:
			_connect(foot, &"stamped", _on_stamped)
		else:
			missing_signals.append("stamped (no foot node)")
		_observe()


	func sample(new_sim: float) -> void:
		tick_sim = sim
		if is_instance_valid(demon):
			_observe()
		sim = new_sim


	func current_name() -> String:
		return String(names[-1][0]) if not names.is_empty() else ""


	## First state name that is not empty (the demon has no state before its boot gate passes).
	func first_name() -> String:
		for entry in names:
			if String(entry[0]) != "":
				return String(entry[0])
		return ""


	## Index of the first log entry with this name at or after `from_index`; -1 when absent.
	func index_of(state_name: String, from_index: int = 0) -> int:
		for i in range(maxi(from_index, 0), names.size()):
			if String(names[i][0]) == state_name:
				return i
		return -1


	## Time of the first log entry with this name at or after `from_index`; -1.0 when absent.
	func time_of(state_name: String, from_index: int = 0) -> float:
		var index := index_of(state_name, from_index)
		return float(names[index][1]) if index >= 0 else -1.0


	## Number of log entries from `from_index` on whose name starts with `prefix`.
	func count_prefix(prefix: String, from_index: int = 0) -> int:
		var count := 0
		for i in range(maxi(from_index, 0), names.size()):
			if String(names[i][0]).begins_with(prefix):
				count += 1
		return count


	func names_text() -> String:
		var parts: PackedStringArray = []
		for entry in names:
			parts.append("%s@%.2f" % [entry[0], entry[1]])
		return ", ".join(parts)


	func se_count(se_type: int) -> int:
		var count := 0
		for entry in se:
			if int(entry[0]) == se_type:
				count += 1
		return count


	## Time of the first request of this sting; -1.0 when it was never requested.
	func se_time(se_type: int) -> float:
		for entry in se:
			if int(entry[0]) == se_type:
				return float(entry[1])
		return -1.0


	func state_signal_count(state_name: String) -> int:
		var count := 0
		for entry in state_signals:
			if String(entry[0]) == state_name:
				count += 1
		return count


	func chase_logged(is_chasing: bool) -> bool:
		for entry in chase:
			if bool(entry[0]) == is_chasing:
				return true
		return false


	func _observe() -> void:
		var current := String(demon.call(&"get_state_name")) if demon.has_method(&"get_state_name") else "<no get_state_name>"
		if names.is_empty() or String(names[-1][0]) != current:
			names.append([current, tick_sim])
		var here := demon.global_position
		if _has_last_position:
			path_length += Vector2(here.x - _last_position.x, here.z - _last_position.z).length()
		_last_position = here
		_has_last_position = true
		max_tilt = maxf(max_tilt, maxf(absf(demon.rotation.x), absf(demon.rotation.z)))
		var scale_error := (demon.scale - Vector3.ONE).abs()
		max_scale_error = maxf(max_scale_error, maxf(scale_error.x, maxf(scale_error.y, scale_error.z)))


	func _connect(source: Node, signal_name: StringName, callback: Callable) -> void:
		if source.has_signal(signal_name):
			source.connect(signal_name, callback)
		else:
			missing_signals.append(String(signal_name))


	func _on_state_changed(state_name: String) -> void:
		state_signals.append([state_name, sim])


	func _on_se_requested(se_type: int) -> void:
		se.append([se_type, sim])


	func _on_se_stopped() -> void:
		se_stops.append(sim)


	func _on_chase_changed(is_chasing: bool) -> void:
		chase.append([is_chasing, sim])


	func _on_travel_blocked(destination: Vector3) -> void:
		blocked.append([destination, sim])


	func _on_stamped(foot_index: int, volume: float, pitch: float) -> void:
		stamps.append([foot_index, volume, pitch, sim])


## Counts what the engine logs as an error while the cases run (a Logger registered with OS.add_logger):
## script errors (a runtime error in GDScript, in the demon's code or in a test) and engine errors (failed
## engine checks such as a global transform read outside the tree). A script error only ends the function it
## happens in, the game goes on; without this tap a case could pass all its assertions on top of one.
## The runners' own "ASSERT FAILED" push_error lines are not counted. Logger callbacks may come from any
## thread, hence the mutex.
class ErrorTap extends Logger:
	const ASSERT_PREFIX := "ASSERT FAILED"

	var script_errors := 0
	var engine_errors := 0
	var last_script_error := ""
	var last_engine_error := ""

	var _lock := Mutex.new()


	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var text := "%s%s at %s (%s:%d)" % [code, "" if rationale.is_empty() else " | " + rationale, function, file.get_file(), line]
		_lock.lock()
		if error_type == ERROR_TYPE_SCRIPT:
			script_errors += 1
			last_script_error = text
		elif error_type == ERROR_TYPE_ERROR and not code.begins_with(ASSERT_PREFIX) and not rationale.begins_with(ASSERT_PREFIX):
			engine_errors += 1
			last_engine_error = text
		_lock.unlock()


	func _log_message(_message: String, _error: bool) -> void:
		pass


	## (script errors, engine errors) so far.
	func mark() -> Vector2i:
		_lock.lock()
		var counts := Vector2i(script_errors, engine_errors)
		_lock.unlock()
		return counts


	## " (last script error: ...; last engine error: ...)" for the counts that grew since `from`, else "".
	func describe_since(from: Vector2i) -> String:
		var parts: PackedStringArray = []
		_lock.lock()
		if script_errors > from.x:
			parts.append("last script error: " + last_script_error)
		if engine_errors > from.y:
			parts.append("last engine error: " + last_engine_error)
		_lock.unlock()
		return "" if parts.is_empty() else " (%s)" % "; ".join(parts)


static func assets_present() -> bool:
	return FileAccess.file_exists(DEMON_GLB)


## Builds a fresh arena under `host` and registers its Players node with the enemy context.
## keys: root, players, enemies, points, transitions (null until set_graph).
## `navmesh`: "quad" (one 56 x 56 m polygon), "u" (a U-shaped corridor of five quads) or "none"
## (no NavigationRegion3D at all).
static func build(host: Node, navmesh: String = "quad") -> Dictionary:
	var root := Node3D.new()
	root.name = "Arena"

	# Layer 3 ("Walls", value 4): the demon's sight mask is 5 (Player + Walls).
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.collision_layer = LAYER_WALLS
	floor_body.collision_mask = 0
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = FLOOR_SIZE
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0.0, -FLOOR_SIZE.y * 0.5, 0.0)   # top at y 0
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)

	if navmesh != "none":
		var region := NavigationRegion3D.new()
		region.name = "NavigationRegion3D"
		region.navigation_mesh = _make_navigation_mesh(navmesh)
		root.add_child(region)

	var players := Node3D.new()
	players.name = "Players"
	root.add_child(players)
	var enemies := Node3D.new()
	enemies.name = "Enemies"
	root.add_child(enemies)
	var points := Node3D.new()
	points.name = "Points"
	root.add_child(points)

	host.add_child(root)
	Services.enemy_context.set_transitions_node(null)
	Services.enemy_context.set_players_node(players)
	return {
		"root": root,
		"players": players,
		"enemies": enemies,
		"points": points,
		"transitions": null,
	}


static func free_arena(arena: Dictionary) -> void:
	Services.enemy_context.set_players_node(null)
	Services.enemy_context.set_transitions_node(null)
	var root: Variant = arena.get("root")
	if root != null and is_instance_valid(root):
		(root as Node).free()
	arena.clear()


## Stub prey: capsule r 0.25 / h 1.2 at y 0.6, layer 1, in group "player"; positioned, then added.
## `registered = false` adds it beside the Players node instead of under it: the enemy context does
## not list it, so the demon can only learn of it when a test hands it over.
static func add_stub(arena: Dictionary, at: Vector3, yaw: float = 0.0, room: String = "",
		registered: bool = true) -> StubPrey:
	var stub := StubPrey.new()
	stub.name = "StubPrey"
	stub.collision_layer = LAYER_PLAYER
	stub.collision_mask = 0
	stub.add_to_group("player")
	stub.current_room = room
	stub.position = at
	stub.rotation.y = yaw
	(arena["players" if registered else "root"] as Node3D).add_child(stub)
	return stub


static func add_wall(arena: Dictionary, centre: Vector3, size: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = "Wall"
	wall.collision_layer = LAYER_WALLS
	wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	wall.position = centre
	(arena["root"] as Node3D).add_child(wall, true)
	return wall


## Instantiates the demon scene. `configure` (if valid) is called with the instance before it enters
## the tree (exports such as start_asleep, model_scale, return_home). With `place_first` the
## position, yaw and room are written before add_child (spike P8); without it add_child comes first,
## which is what every DST spawn path does. Returns null when the scene does not load or its root is
## not an Enemy.
static func add_demon(arena: Dictionary, at: Vector3, yaw: float = 0.0, room: String = "",
		place_first: bool = true, configure: Callable = Callable()) -> Node:
	var packed := load(DEMON_SCENE) as PackedScene
	if packed == null:
		push_error("[arena] %s does not load" % DEMON_SCENE)
		return null
	var instance := packed.instantiate()
	var demon := instance as Enemy
	if demon == null:
		push_error("[arena] the root of %s is not an Enemy" % DEMON_SCENE)
		if instance != null:
			instance.free()
		return null
	if configure.is_valid():
		configure.call(demon)
	var enemies := arena["enemies"] as Node3D
	if place_first:
		demon.position = at
		demon.rotation.y = yaw
		demon.current_room = room
		enemies.add_child(demon)
	else:
		enemies.add_child(demon)
		demon.global_position = at
		demon.rotation.y = yaw
		demon.current_room = room
	return demon


## A patrol point: a Node3D with the point script. `src_speed` is the SRC-scale moving_speed, `dwell`
## the thinking_time; `props` are further exports by name, e.g. {"wait_until_call": true}, {"type": 3}.
static func add_point(arena: Dictionary, point_name: String, at: Vector3, yaw: float = 0.0,
		src_speed: float = 2.0, dwell: float = 0.0, room: String = "", props: Dictionary = {}) -> Node3D:
	var point_script := load(POINT_SCRIPT) as Script
	if point_script == null:
		push_error("[arena] %s does not load" % POINT_SCRIPT)
		return null
	var point := Node3D.new()
	point.set_script(point_script)
	point.name = point_name
	point.position = at
	point.rotation.y = yaw
	_set_point_property(point, &"moving_speed", src_speed)
	_set_point_property(point, &"thinking_time", dwell)
	_set_point_property(point, &"room", room)
	for key: Variant in props:
		_set_point_property(point, StringName(String(key)), props[key])
	(arena["points"] as Node3D).add_child(point)
	return point


## from.next_points.append(each)
static func link(from: Node3D, successors: Array) -> void:
	var listed: Variant = from.get(&"next_points")
	if not (listed is Array):
		push_error("[arena] patrol point '%s' has no next_points array" % from.name)
		return
	var list: Array = listed
	for successor: Variant in successors:
		list.append(successor)


## Creates the mock Transitions node, assigns the room graph and registers it with the enemy context.
static func set_graph(arena: Dictionary, graph: Dictionary) -> MockTransitions:
	var transitions := MockTransitions.new()
	transitions.name = "Transitions"
	transitions.map_transitions = graph
	(arena["root"] as Node3D).add_child(transitions)
	arena["transitions"] = transitions
	Services.enemy_context.set_transitions_node(transitions)
	return transitions


## A gate under the transitions node at `at`, with a TransitionArrivalMarker child at global
## `marker_at` (the runtime finds markers by class, enemy_transition_component.gd:182-195).
static func add_gate(arena: Dictionary, gate_name: String, at: Vector3, marker_at: Vector3) -> Node3D:
	var transitions := arena.get("transitions") as Node3D
	if transitions == null:
		push_error("[arena] add_gate('%s') needs set_graph() first" % gate_name)
		return null
	var gate := Node3D.new()
	gate.name = gate_name
	gate.position = at
	var marker := TransitionArrivalMarker.new()
	marker.name = "ArrivalMarker"
	marker.position = marker_at - at
	gate.add_child(marker)
	transitions.add_child(gate)
	return gate


## Planar (x, z) distance in metres.
static func planar(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Yaw that makes a node standing at `from` face `towards` (local -Z along the planar direction).
static func yaw_towards(from: Vector3, towards: Vector3) -> float:
	return atan2(from.x - towards.x, from.z - towards.z)


## The planar direction `degrees_right` to the right of `forward` (looking down, clockwise).
static func turned_right(forward: Vector3, degrees_right: float) -> Vector3:
	var flat := Vector3(forward.x, 0.0, forward.z).normalized()
	var right := Vector3(-flat.z, 0.0, flat.x)
	var angle := deg_to_rad(degrees_right)
	return (flat * cos(angle) + right * sin(angle)).normalized()


static func _set_point_property(point: Node3D, property: StringName, value: Variant) -> void:
	point.set(property, value)
	if point.get(property) != value:
		push_error("[arena] patrol point '%s' did not take %s = %s (reads back %s)" % [
			point.name, property, value, point.get(property)])


static func _make_navigation_mesh(kind: String) -> NavigationMesh:
	var mesh := NavigationMesh.new()
	var e := NAVMESH_HALF_EXTENT
	if kind == "u":
		# Left strip x -28..-20 / z -28..20, right strip x 20..28 / z -28..20, bottom strip z 20..28
		# across x -28..28 split at x = -20 and x = 20. Five quads sharing vertices, each listed as
		# (min x, min z), (max x, min z), (max x, max z), (min x, max z): the vertex order of the
		# "quad" mesh, which is the winding of room_1.tscn:30-35.
		mesh.vertices = PackedVector3Array([
			Vector3(-e, 0.0, -e), Vector3(-20.0, 0.0, -e), Vector3(-20.0, 0.0, 20.0), Vector3(-e, 0.0, 20.0),
			Vector3(-20.0, 0.0, e), Vector3(-e, 0.0, e),
			Vector3(20.0, 0.0, 20.0), Vector3(20.0, 0.0, e),
			Vector3(e, 0.0, 20.0), Vector3(e, 0.0, e),
			Vector3(20.0, 0.0, -e), Vector3(e, 0.0, -e),
		])
		mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))      # left strip
		mesh.add_polygon(PackedInt32Array([3, 2, 4, 5]))      # bottom strip, left corner
		mesh.add_polygon(PackedInt32Array([2, 6, 7, 4]))      # bottom strip, middle
		mesh.add_polygon(PackedInt32Array([6, 8, 9, 7]))      # bottom strip, right corner
		mesh.add_polygon(PackedInt32Array([10, 11, 8, 6]))    # right strip
		return mesh
	if kind != "quad":
		push_warning("[arena] unknown navmesh kind '%s'; using 'quad'" % kind)
	mesh.vertices = PackedVector3Array([
		Vector3(-e, 0.0, -e), Vector3(e, 0.0, -e), Vector3(e, 0.0, e), Vector3(-e, 0.0, e),
	])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	return mesh
