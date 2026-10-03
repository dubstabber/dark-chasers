class_name BlueDemonWanderingState
extends BlueDemonState

## Patrol behaviour — port of `u823.AooniWanderingState`.
##
## Reconstructed from Hex-Rays pseudocode and the raw instruction stream; the full
## derivation, with addresses for every constant, is in
## `extract-absolute-aooni/extracted/reverse-engineering/spec-wandering-state.md`.
##
## The demon walks a directed graph of [BlueDemonPatrolPoint]s: travel to a point at that
## point's speed, stand and think for its dwell time — turning to the point's own
## rotation, sweeping its head every 3 seconds — then move on. Two details do most of
## the work for how it *feels*:
##
## - It only checks its senses [b]once per second[/b] ([member _search_player_time]).
##   Sprinting across a doorway can genuinely go unnoticed.
## - Its patrol sight cone is a 25 m / 75 degree half-angle — but the half-angle means
##   150 degrees wide, and switching on a flashlight opens it to 40 m and a full 180.
##
## Only two of the four declared sub-states are ever live at runtime: `Move` and
## `Thinking`. `Init` is just the zero value before [method init] runs, and `None` is
## never assigned anywhere in the binary.

enum State { INIT, MOVE, THINKING, NONE }

## Arrival threshold on the agent's remaining path length.
const ARRIVE_EPSILON: float = 0.01

## Grace period after a new destination is set, before remaining distance is trusted —
## a path still being computed reports zero and would read as "arrived".
const MOVE_IDLING_TIME: float = 1.0

## Seconds between sense checks.
const SEARCH_INTERVAL: float = 1.0

## Seconds between head sweeps while thinking at a swing-head point.
const HEAD_SWING_INTERVAL: float = 3.0

## Lateral offset of the look target during a sweep, at 10 m forward — about 45 degrees.
##
## The original writes `dummyLookTarget.localPosition = (x, 0, 10)` with `x` in
## `{0, +10, -10}`, and Unity's local +Z is forward. Godot's is backward, so the distance
## has to be negative or the demon sweeps its head 135 degrees off, behind itself. `x`
## keeps its sign: local +X is "right" in both engines.
const HEAD_SWING_OFFSET: float = 10.0
const HEAD_SWING_DISTANCE: float = -10.0

## Yaw tolerance, in degrees, for "facing the point's rotation".
const FACING_EPSILON: float = 0.1

## Dwell time and speed of the transient point created when a sound is investigated.
const INVESTIGATE_THINKING_TIME: float = 15.0
const INVESTIGATE_SPEED: float = 2.0

## DST W10: seconds between two attempts to find a patrol point (or a way home) while idle.
const IDLE_RETRY_INTERVAL: float = 5.0  # DST W10: SRC's State.NONE is a dead end (V9)

## DST W10: a return-home gate is taken only when the demon stopped within this distance of it.
const HOP_TAKE_DISTANCE: float = 1.5  # DST W10: gate origins lie up to 0.81 m off the navmesh (8.6)

var _state: State = State.INIT
var _before_point: BlueDemonPatrolPointData
var _current_point: BlueDemonPatrolPointData
var _next_point: BlueDemonPatrolPointData

var _thinking_time: float = 0.0
var _move_idling_time: float = 0.0
var _head_swing_time: float = 0.0
var _head_forward_index: int = 0
var _search_player_time: float = 0.0

var _warp_position: Vector3 = Vector3.INF

var _idle_retry_time: float = 0.0  # DST W10: idle (State.NONE) re-resolve clock


## Mirrors the original's four constructors: an explicit first point, a warp position,
## both, or neither (in which case the nearest field point is chosen in [method init]).
func _init(
	first_point: BlueDemonPatrolPoint = null,
	first_data: BlueDemonPatrolPointData = null,
	warp_position: Vector3 = Vector3.INF,
) -> void:
	if first_data != null:
		_next_point = first_data
	elif first_point != null:
		_next_point = BlueDemonPatrolPointData.from_point(first_point)
	_warp_position = warp_position


func get_state_name() -> String:
	return "Wandering"


func init(demon: BlueDemon) -> void:
	demon.is_chase = false
	demon.is_sleeping = false
	if _warp_position != Vector3.INF:
		# A hard teleport, with no navigation sampling — as in the original.
		demon.warp_to(_warp_position)                                # DST W7: own warp, not an external teleport (aooni_wandering_state.gd:94)
	if _next_point == null:
		_next_point = _resolve_next_point(demon)                     # DST W3: nearest point of this room, else a homeward hop
	if _next_point == null:
		# No usable graph. Stand still rather than crashing, but say so: the original
		# would throw here, which means the level data is wrong.
		demon.warn_once(&"no_patrol_points", "BlueDemonWanderingState: no usable BlueDemonPatrolPoint for room '%s'; standing guard" % demon.current_room)  # DST W3: once per demon, names the room
		_idle(demon)                                                 # DST W3 (SRC: speed 0, State.NONE)
		return
	_go_to(demon)


## `AooniWanderingState.Finished` writes exactly four things and deliberately leaves
## `LookTarget` alone — clearing it here would snap the head to the dummy target for the
## one frame before the next state's `init` re-points it.
func finished(demon: BlueDemon) -> void:
	demon.desired_speed = 0.0
	_next_point = null
	_current_point = null
	_before_point = null


func update(demon: BlueDemon, delta: float) -> void:
	match _state:
		State.MOVE:
			if not _update_move(demon, delta):
				return
		State.THINKING:
			_update_thinking(demon, delta)
		State.NONE:                                                  # DST W9: idle re-resolves every 5 s
			_update_idle(demon, delta)                               # DST W9
		_:
			pass
	_sense(demon, delta)


## DST W10: the body was teleported (room change, or a jump of more than 4 m). Every stored
## position is void: forget the points and re-plan in the room the demon is in now.
func on_teleported(demon: BlueDemon) -> void:                    # DST W10
	_current_point = null                                        # DST W10
	_before_point = null                                         # DST W10
	demon.set_look_target(null)                                  # DST W10
	_next_point = _resolve_next_point(demon)                     # DST W10
	if _next_point == null:                                      # DST W10
		_idle(demon)                                             # DST W10
		return                                                   # DST W10
	_go_to(demon)                                                # DST W10


# --- moving ------------------------------------------------------------------------

## Returns false when this frame must not run the sense pass.
func _update_move(demon: BlueDemon, delta: float) -> bool:
	if _move_idling_time > 0.0 or demon.remaining_distance > ARRIVE_EPSILON:
		_move_idling_time -= delta
		# A point flagged ignore-until-touched suppresses sensing for the whole leg.
		return not _next_point.ignore_player_until_touch_here

	# --- arrival ---
	if _next_point.hop_transition != "":                             # DST W6: arrived (or blocked) at a return-home gate
		_finish_hop(demon)                                           # DST W6
		return false                                                 # DST W6
	if demon.was_travel_blocked() and _next_point.source_point != null:   # DST W8: an authored point that cannot be reached is loud
		demon.warn_unreachable_point(_next_point.source_point)       # DST W8
	if _next_point.force_chase_when_touch_here:
		# The point's dwell time is reused as the forced chase's start delay.
		demon.set_state(BlueDemonChaseState.new(true, _next_point.thinking_time))
		return false

	_state = State.THINKING
	_thinking_time = 0.0
	_head_forward_index = 0
	# Deliberately not resetting _head_swing_time: the original carries it across
	# points, so a point can inherit up to 3 s and snap its head almost at once.
	_current_point = _next_point

	var successor := _current_point.pick_next()
	_next_point = (
		BlueDemonPatrolPointData.from_point(successor) if successor
		else _resolve_next_point(demon)                              # DST W3: may be null; the dwell still runs
	)

	if _current_point.swing_head:
		demon.set_look_target(demon.dummy_look_target)
		if demon.dummy_look_target:
			demon.dummy_look_target.position = Vector3(0.0, 0.0, HEAD_SWING_DISTANCE)
	return true


# --- thinking ----------------------------------------------------------------------

func _update_thinking(demon: BlueDemon, delta: float) -> void:
	_thinking_time += delta

	if _current_point and _current_point.head_to_forward:
		var wanted := _current_point.rotation
		# `IsHeadToFoward` compares two yaws that Unity has already normalised into
		# [0, 360), and does it with a plain absolute difference — so at the 0/360 seam a
		# 0.07 degree misalignment reads as 359.93 and the demon keeps its walk cycle
		# playing for another frame or two. `RotateTowards` still takes the short arc, so
		# it self-corrects; the quirk is reproduced rather than smoothed over because it
		# is visible in the animation.
		var my_yaw := fposmod(rad_to_deg(demon.facing_yaw), 360.0)                    # DST W2: the demon's facing, not the root basis
		var target_yaw := fposmod(rad_to_deg(wanted.get_euler().y), 360.0)
		if absf(my_yaw - target_yaw) > FACING_EPSILON:
			# Speed 1 while turning on the spot is not for movement — nothing reads it
			# for that here. It keeps the animator's Blend parameter above the idle
			# threshold so the walk cycle plays through the turn.
			demon.desired_speed = BlueDemonTuning.AOONI_WANDERING_SPEED
			demon.turn_towards_yaw(wanted.get_euler().y, delta)                       # DST W2: yaw only (G9)
			_advance_check(demon)
			return

	if demon.desired_speed > 0.0:
		demon.desired_speed = 0.0

	if _current_point and _current_point.swing_head:
		_head_swing_time += delta
		if _head_swing_time > HEAD_SWING_INTERVAL:
			_head_forward_index += 1
			_head_swing_time = 0.0
			if _head_forward_index > 2:
				_head_forward_index = 1
			var x := 0.0
			match _head_forward_index:
				1:
					x = HEAD_SWING_OFFSET
				2:
					x = -HEAD_SWING_OFFSET
			if demon.dummy_look_target:
				demon.dummy_look_target.position = Vector3(x, 0.0, HEAD_SWING_DISTANCE)

	_advance_check(demon)


func _advance_check(demon: BlueDemon) -> void:
	if _current_point == null:
		return
	if _current_point.wait_until_call:
		return
	if _thinking_time < _current_point.thinking_time:
		return
	demon.set_look_target(null)
	if _next_point == null:                                          # DST W4
		_next_point = _resolve_next_point(demon)                     # DST W4
	if _next_point == null:                                          # DST W4
		_idle(demon)                                                 # DST W4 (V9)
		return                                                       # DST W4
	go_to_next(demon)


# --- senses ------------------------------------------------------------------------

func _sense(demon: BlueDemon, delta: float) -> void:
	if _state == State.THINKING and _current_point:
		# Note this is an AND, not an OR: a point must be both call-gated and
		# player-ignoring to suppress senses entirely.
		if _current_point.wait_until_call and _current_point.ignore_player_until_call:
			return

	_search_player_time += delta
	if _search_player_time <= SEARCH_INTERVAL:
		return
	_search_player_time = 0.0

	var flash_on := demon.is_target_light_on()
	var look_distance := (
		BlueDemonTuning.WANDER_LIGHT_LOOK_DISTANCE if flash_on else BlueDemonTuning.WANDER_LOOK_DISTANCE
	)
	var look_angle := (
		BlueDemonTuning.WANDER_LIGHT_LOOK_ANGLE if flash_on else BlueDemonTuning.WANDER_LOOK_ANGLE
	)

	if demon.is_find_player(look_distance, look_angle):
		demon.set_state(BlueDemonChaseState.new())
		return

	if not demon.is_feel_player_sound():
		return

	# Heard something: walk over to investigate, then stand there for 15 seconds
	# sweeping its head.
	demon.play_se(BlueDemon.SeType.LOOK)
	var at := demon.target.global_position if demon.target else demon.global_position
	_next_point = BlueDemonPatrolPointData.make_transient(
		at, INVESTIGATE_THINKING_TIME, INVESTIGATE_SPEED
	)
	go_to_next(demon)


# --- graph traversal ---------------------------------------------------------------

## Port of `AooniWanderingState.GoToNext`. Note it does not advance `currentPoint` —
## that happens on arrival — so during a leg P to N, `beforePoint == currentPoint == P`.
func go_to_next(demon: BlueDemon) -> void:
	_before_point = _current_point
	_go_to(demon)


func _go_to(demon: BlueDemon) -> void:
	if _next_point.source_point != null and not demon.is_point_in_my_room(_next_point.source_point):   # DST W5: a graph edge must not lead across a teleport
		_next_point = _resolve_next_point(demon)                     # DST W5
		if _next_point == null:                                      # DST W5
			_idle(demon)                                             # DST W5
			return                                                   # DST W5
	demon.desired_speed = _next_point.moving_speed
	demon.set_destination(_next_point.position)
	_move_idling_time = MOVE_IDLING_TIME
	_state = State.MOVE


## DST W10: nearest usable point of this room, else one hop towards the home room, else null.
func _resolve_next_point(demon: BlueDemon) -> BlueDemonPatrolPointData:   # DST W10
	var nearest := find_most_close_field_point(demon)                # DST W10
	if nearest != null:                                              # DST W10
		return nearest                                               # DST W10
	return demon.make_homeward_hop()                                 # DST W10


## DST W10: SRC's own no-graph behaviour (aooni_wandering_state.gd:97-103): stand, keep sensing.
func _idle(demon: BlueDemon) -> void:                            # DST W10
	demon.desired_speed = 0.0                                    # DST W10
	demon.set_look_target(null)                                  # DST W10
	demon.end_pursuit()                                          # DST W10
	_idle_retry_time = 0.0                                       # DST W10
	_state = State.NONE                                          # DST W10


## DST W9: State.NONE is not a dead end here: every IDLE_RETRY_INTERVAL the graph (or a way home) is looked up again.
func _update_idle(demon: BlueDemon, delta: float) -> void:       # DST W9 / W10
	_idle_retry_time += delta                                    # DST W10
	if _idle_retry_time < IDLE_RETRY_INTERVAL:                   # DST W10
		return                                                   # DST W10
	_idle_retry_time = 0.0                                       # DST W10
	_current_point = null                                        # DST W10
	_before_point = null                                         # DST W10
	_next_point = _resolve_next_point(demon)                     # DST W10
	if _next_point != null:                                      # DST W10
		_go_to(demon)                                            # DST W10


## DST W6: arrived (or blocked) at a return-home gate.
func _finish_hop(demon: BlueDemon) -> void:                      # DST W6 / W10
	var hop := _next_point                                       # DST W6
	_next_point = null                                           # DST W6
	_current_point = null                                        # DST W6
	_before_point = null                                         # DST W6
	_idle(demon)                                  # DST W6: never leave MOVE with a null _next_point
	var close := demon.global_position.distance_to(hop.position) <= HOP_TAKE_DISTANCE   # DST W6
	if demon.current_room == hop.hop_from_room and close:        # DST W6
		demon.take_transition(hop.hop_transition)                # DST W6
		# DST W6: no re-plan here: teleport checkpoint B of this very tick (4.2 step 4c') calls on_teleported(), which
		# re-plans in the new room. If nothing moved (no arrival marker: the framework warns), _update_idle retries in 5 s.


## Nearest usable point, excluding the two spawn/call-only types and, where possible,
## the point the demon is standing on and the one it came from. Port of
## `AooniWanderingState.FindMostCloseFieldPoint`.
func find_most_close_field_point(demon: BlueDemon) -> BlueDemonPatrolPointData:
	# DST W1: always the registry, then scoped to the demon's patrol_root when one is set
	# (`FloorArranger.FieldPoints` is per-scene in the original) and to the demon's room; without
	# the scoping, two instanced graphs would cross-contaminate. Both filters live in
	# BlueDemon.get_patrol_points() (8.3).
	# [BlueDemonPatrolPoint] self-registers, so the registry is complete by construction.
	var pool: Array[BlueDemonPatrolPoint] = demon.get_patrol_points()   # DST W1: registry, patrol_root and room filters
	var candidates: Array[BlueDemonPatrolPoint] = []
	for point in pool:                                               # DST W1: the pool is typed, no cast
		if point == null:
			continue
		if point.type == BlueDemonPatrolPoint.PointType.ONLY_START:
			continue
		if point.type == BlueDemonPatrolPoint.PointType.ONLY_CALL:
			continue
		candidates.append(point)
	if candidates.is_empty():
		return null

	# Squared distance from the demon, ascending. The original's OrderBy is a stable
	# sort, so ties keep source order; sort_custom is not stable, hence the index
	# tie-break.
	var indexed: Array = []
	for i in candidates.size():
		indexed.append([
			demon.global_position.distance_squared_to(candidates[i].global_position), i
		])
	indexed.sort_custom(func(a, b): return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
	var ordered: Array[BlueDemonPatrolPoint] = []
	for entry in indexed:
		ordered.append(candidates[entry[1]])

	# Both exclusions are guarded by "only if more than one candidate survives", so the
	# demon is allowed to revisit somewhere rather than end up with nothing.
	ordered = _exclude(ordered, _current_point)
	ordered = _exclude(ordered, _before_point)
	return BlueDemonPatrolPointData.from_point(ordered[0])


func _exclude(
	points: Array[BlueDemonPatrolPoint], banned: BlueDemonPatrolPointData
) -> Array[BlueDemonPatrolPoint]:
	if points.size() < 2 or banned == null:
		return points
	var kept: Array[BlueDemonPatrolPoint] = []
	for point in points:
		if not banned.matches(point):
			kept.append(point)
	return kept if not kept.is_empty() else points


## Summoned by a CallAooniTrigger / CallAooniObject.
func call_to(demon: BlueDemon, point: BlueDemonPatrolPoint) -> void:
	if point == null:
		return
	_next_point = BlueDemonPatrolPointData.from_point(point)
	go_to_next(demon)


var current_point: BlueDemonPatrolPointData:
	get:
		return _current_point
