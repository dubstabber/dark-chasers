class_name BlueDemonTravel
extends RefCounted

## Where the blue demon is going. The single writer of Enemy.waypoints / Enemy.current_target and of the
## agent's target radius; owner of arrival, "blocked", and of the room rules (trail, return home).

enum Command { HOLD, GOTO, PURSUE }
enum Status { IDLE, MOVING, ARRIVED, BLOCKED }

const GOTO_AGENT_RADIUS := 0.4       # < arrive_radius: the coordinator's waypoint pop can never precede our arrival by more than a tick
const PURSUE_AGENT_RADIUS := 1.0     # engine default = what every stock enemy runs; required for gate origins 0.26-0.81 m off the navmesh
const STALL_RADIUS := 0.3
const TRAIL_TIMEOUT := 8.0           # a blind walk to a gate that takes longer is abandoned

var command: Command = Command.HOLD
var status: Status = Status.IDLE
var destination: Vector3 = Vector3.ZERO
var pursued: CharacterBody3D = null
var trailing: bool = false           # PURSUE kept alive although the prey is not seen: the stock transition component walks to the gate
var hops_left: int = 0               # room transitions the demon may still follow blind; refilled by every sighting
var last_seen_position: Vector3 = Vector3.ZERO
var last_seen_room: String = ""

var _demon: BlueDemon
var _agent: NavigationAgent3D
var _finished_time: float = 0.0
var _stall_time: float = 0.0
var _stall_anchor: Vector3 = Vector3.ZERO
var _trail_time: float = 0.0
var _applied_target: CharacterBody3D = null      # what apply() last wrote to Enemy.current_target
var _applied_waypoint: Vector3 = Vector3.INF     # what apply() last wrote as waypoints[0]; INF = none


func setup(demon: BlueDemon, agent: NavigationAgent3D) -> void:
	_demon = demon
	_agent = agent


func hold() -> void:
	command = Command.HOLD
	status = Status.IDLE
	pursued = null
	trailing = false


func go_to(world_position: Vector3) -> void:
	command = Command.GOTO
	destination = world_position
	pursued = null
	trailing = false
	_finished_time = 0.0
	_stall_time = 0.0
	_stall_anchor = _demon.global_position
	status = Status.ARRIVED if _has_arrived() else Status.MOVING      # "park where you stand" arrives at once


## PURSUE a prey that is seen (or forced): live tracking through Enemy.current_target.
func pursue_seen(prey: CharacterBody3D) -> void:
	if prey == null:
		return
	trailing = false
	hops_left = _demon.chase_room_hops
	last_seen_position = prey.global_position
	last_seen_room = BlueDemonPrey.room_of(prey)
	if command == Command.PURSUE and pursued == prey:
		return
	command = Command.PURSUE
	pursued = prey
	status = Status.MOVING


## The chase state's blind branch (5.2 C2): stop being omniscient.
func hold_blind() -> void:
	if command != Command.PURSUE:
		return                                # already walking to a point, or parked
	var prey := _demon.target
	if trailing:
		if BlueDemonPrey.same_room(_demon, prey) or not can_route_to_room_of(prey):
			hold()                            # the prey came back / the route vanished
		return
	if BlueDemonPrey.same_room(_demon, prey):
		go_to(last_seen_position)             # SRC: the stale destination of the last successful search tick
	elif hops_left > 0 and can_route_to_room_of(prey):
		trailing = true                       # keep Enemy.current_target: the stock transition component walks to the gate
		_trail_time = 0.0
	elif last_seen_room == _demon.current_room or last_seen_room == "" or _demon.current_room == "":
		go_to(last_seen_position)
	else:
		hold()


func update(delta: float) -> void:            # step 1 of the tick
	if trailing:
		_trail_time += delta
		if _trail_time >= TRAIL_TIMEOUT:
			hold()
	match command:
		Command.PURSUE:
			if pursued == null or not is_instance_valid(pursued) or not pursued.is_inside_tree() \
					or not BlueDemonPrey.is_alive(pursued):
				hold()
				status = Status.ARRIVED       # remaining_distance 0.0: the chase goes LOST
		Command.GOTO:
			if status != Status.MOVING:
				return
			if _has_arrived():
				status = Status.ARRIVED
				return
			var nav := _demon.get_nav_component()
			if nav != null and nav.is_navigation_finished():
				_finished_time += delta
			else:
				_finished_time = 0.0
			_update_stall(delta)
			if _finished_time >= _demon.blocked_grace or _stall_time >= _demon.stall_timeout:
				status = Status.BLOCKED


func apply() -> void:                         # step 4a of the tick
	if command == Command.PURSUE:
		_set_agent_radius(PURSUE_AGENT_RADIUS)
		if not _demon.waypoints.is_empty():
			_demon.waypoints.clear()
		_applied_waypoint = Vector3.INF
		if _demon.current_target != pursued:
			_demon.current_target = pursued
			_demon.makepath()
		_applied_target = pursued
		return
	_demon.current_target = null
	_applied_target = null
	if command == Command.GOTO and status == Status.MOVING:
		_set_agent_radius(GOTO_AGENT_RADIUS)
		if _demon.waypoints.size() != 1 or not (_demon.waypoints[0] is Vector3) \
				or not (_demon.waypoints[0] as Vector3).is_equal_approx(destination):
			_demon.waypoints = [destination]
			_demon.makepath()
		_applied_waypoint = destination
		return
	if not _demon.waypoints.is_empty():       # HOLD, or a GOTO that is ARRIVED / BLOCKED
		_demon.waypoints.clear()
	_applied_waypoint = Vector3.INF
	var transition := _demon.get_transition_component()
	if transition != null:
		transition.pending_transition_name = ""   # public var (enemy_transition_component.gd:15): a parked demon keeps no gate armed


func is_done() -> bool:
	return status == Status.ARRIVED or status == Status.BLOCKED


func remaining_distance() -> float:
	if command == Command.HOLD or is_done():
		return 0.0
	var goal := destination
	if command == Command.PURSUE and is_instance_valid(pursued) and pursued.is_inside_tree():   # DST R1: readable between two ticks
		goal = pursued.global_position
	var here := _demon.global_position
	return maxf(Vector2(goal.x - here.x, goal.z - here.z).length(), 1.0)


## A non-null current_target that apply() did not write (a spawner, a map script).
func is_foreign_target(node: CharacterBody3D) -> bool:
	return node != null and is_instance_valid(node) and node != _applied_target


## The first waypoint apply() did not write (a map script's push_back), or null. While the demon travels,
## waypoints[0] is its OWN destination: scripts append, so the foreign entry is behind it (red-team D5).
func first_foreign_waypoint(list: Array) -> Variant:
	for entry in list:
		if entry is Vector3 and (_applied_waypoint == Vector3.INF or not (entry as Vector3).is_equal_approx(_applied_waypoint)):
			return entry
	return null


func notify_teleported() -> void:
	if trailing:
		hops_left -= 1                        # one sighting buys chase_room_hops transitions
	hold()                                    # no stored position survives a teleport (also ends the trail)
	status = Status.ARRIVED


func can_route_to_room_of(node: Node) -> bool:
	var mine := _demon.current_room
	var theirs := BlueDemonPrey.room_of(node)
	var pathing := _demon.get_room_pathing_component()
	return mine != "" and theirs != "" and mine != theirs and pathing != null \
		and not pathing.find_path_to_room(mine, theirs).is_empty()      # honours enemy exceptions, cached per pair


## Teleport through a gate with the framework's own code path (8.6).
func take_transition(transition_name: String) -> bool:
	var transition := _demon.get_transition_component()
	if transition == null:
		return false
	if not is_instance_valid(transition.map_transitions):
		transition.map_transitions = Services.enemy_context.get_transitions_node()
	var room_before := _demon.current_room
	var position_before := _demon.global_position
	transition.pending_transition_name = transition_name      # public var (enemy_transition_component.gd:15)
	transition.handle_target_reached()                        # public; teleports, sets the room, floor-snaps (:84-145)
	return _demon.current_room != room_before or _demon.global_position.distance_to(position_before) > 0.01


func make_homeward_hop() -> BlueDemonPatrolPointData:
	var here := _demon.current_room
	if not _demon.return_home or _demon.home_room == "" or here == "" or here == _demon.home_room:
		return null
	var pathing := _demon.get_room_pathing_component()
	if pathing == null:
		return null
	var hops: Array = pathing.find_path_to_room(here, _demon.home_room)   # room_pathing_component.gd:34-84
	if hops.is_empty():
		return null
	var transitions := Services.enemy_context.get_transitions_node()
	var gate := transitions.get_node_or_null(NodePath(String(hops[0]))) as Node3D if transitions else null
	if gate == null:
		return null
	return BlueDemonPatrolPointData.make_hop(
		gate.global_position, String(hops[0]), here, BlueDemonTuning.RETURN_HOME_SPEED)


func _has_arrived() -> bool:
	var here := _demon.global_position
	var flat := Vector2(destination.x - here.x, destination.z - here.z).length()
	return flat <= _demon.arrive_radius and absf(destination.y - here.y) <= _demon.arrive_max_height_delta


func _update_stall(delta: float) -> void:
	var here := _demon.global_position
	if Vector2(here.x - _stall_anchor.x, here.z - _stall_anchor.z).length() > STALL_RADIUS:
		_stall_anchor = here
		_stall_time = 0.0
	elif _demon.desired_speed > 0.01:
		_stall_time += delta


func _set_agent_radius(radius: float) -> void:
	if _agent != null and not is_equal_approx(_agent.target_desired_distance, radius):
		_agent.target_desired_distance = radius
