class_name BlueDemonChaseState
extends BlueDemonState

## Pursuit behaviour — port of `u823.AooniChaseState`.
##
## Reconstructed from Hex-Rays pseudocode plus the raw instruction stream (Hex-Rays
## discards the float argument of every `NavMeshAgent.set_speed` call, so all speed
## values were read out of the disassembly). Full derivation with addresses lives in
## `extract-absolute-aooni/extracted/reverse-engineering/spec-chase-state.md`.
##
## The signature behaviour is the [b]stare[/b]. Seeing you does not start a chase: the
## demon stops dead, turns to face you, and watches for three seconds — faster if you
## are standing (the clock runs at 1.5x), slower if you crouch. Only then, if it can
## still see you, does it charge. If you broke line of sight in that window it walks to
## where you were, waits, and goes back to patrolling.
##
## Once running, speed ramps from 1 m/s toward a cap of 5 m/s at 0.5 m/s², and
## *doubles* on any search tick where the demon is behind you — losing sight is what
## keeps it slow, and turning your back is what makes it fast. Losing you sets speed to
## 5 immediately, so the moment it cannot see you it commits to your last position at
## full pelt.

# LOCKER is not ported: dark-chasers has no lockers / hiding spots (porting decision 1).
# SRC AooniChaseState.State.LOCKER, set_locker(), _update_locker(), _locker_front()
# (aooni_chase_state.gd:237-314) and Aooni.set_locker() (aooni.gd:678-681) have no counterpart
# here and nothing could ever enter the sub-state.
enum State { LOOK, LOOK_ROTATE, CHASE, LOST, FORCE_CHASE, NONE }  # DST C5: no LOCKER member

## Beyond this angle the demon must turn its body rather than just its neck, so Look
## hands over to LookRotate. It is the same 75 degrees as NECK_ANGLE_LIMIT.
const FACE_ANGLE_LIMIT: float = 75.0

## Body rotation is considered finished within this many degrees.
const ROTATE_DEAD_BAND: float = 5.0

## Speed cap, and the speed used whenever the demon commits to a position blind.
const SPEED_CAP: float = 5.0

## Speed the chase actually begins at, once the stare resolves.
const SPEED_BASE: float = 1.0

## The demon counts as "behind" the player past this angle, which doubles its speed.
const BEHIND_ANGLE: float = 90.0

## Distance under which arriving at the last known position counts as reached.
const ARRIVE_EPSILON: float = 0.1

var _state: State = State.LOOK
var _look_time: float = 0.0
var _lost_time: float = 0.0
var _wait_time: float = 0.0
var _is_chase_bgm: bool = false


func _init(is_force_chase: bool = false, wait_time: float = 0.0) -> void:
	if is_force_chase:
		_wait_time = wait_time
		_state = State.FORCE_CHASE


func get_state_name() -> String:
	return "Chase.%s" % State.keys()[_state]


func init(demon: BlueDemon) -> void:
	demon.is_chase = true
	demon.is_sleeping = false
	demon.set_look_target(demon.target)
	demon.desired_speed = 0.0
	# Park where you stand: the demon must not drift while it stares.
	demon.set_destination(demon.global_position)
	if _state != State.FORCE_CHASE:
		_state = State.LOOK
	demon.notify_chase(true)                                         # DST C7: SRC notify_fear_chase (PlayerFear is not ported)
	demon.play_se(BlueDemon.SeType.FIND)


func finished(demon: BlueDemon) -> void:
	demon.stop_se()
	demon.notify_chase(false)                                        # DST C7
	demon.desired_speed = 0.0
	demon.is_chase = false
	demon.end_pursuit()                                              # DST C7


func update(demon: BlueDemon, delta: float) -> void:
	match _state:
		State.LOOK:
			_update_look(demon, delta)
		State.LOOK_ROTATE:
			_update_look_rotate(demon, delta)
		State.CHASE:
			_update_chase(demon, delta)
		State.LOST:
			_update_lost(demon, delta)
		State.FORCE_CHASE:
			_update_force_chase(demon, delta)
		_:
			pass


func on_teleported(_demon: BlueDemon) -> void:                       # DST C9
	# DST C9: _look_time is the 0.5 s search cadence only in these three sub-states. In LOOK / LOOK_ROTATE the same
	# variable is the stare clock (SRC :147-148) and must not be rewound or advanced.
	if _state == State.CHASE or _state == State.LOST or _state == State.FORCE_CHASE:   # DST C9
		_look_time = BlueDemonTuning.CHASE_LOOK_TARGET_SPAN          # DST C9: search on the very next tick


# --- staring ---------------------------------------------------------------------

func _angle_to_look_target(demon: BlueDemon) -> float:
	var to_target := demon.get_look_position() - demon.global_position
	to_target.y = 0.0                                                # DST C3: planar (G9)
	if to_target.length_squared() < 0.0001:
		return 0.0
	var forward := demon.facing_forward()                            # DST C3
	return rad_to_deg(forward.angle_to(to_target.normalized()))


func _update_look(demon: BlueDemon, delta: float) -> void:
	if _angle_to_look_target(demon) <= FACE_ANGLE_LIMIT:
		demon.desired_speed = 0.0
		_looking_time(demon, delta)
		return
	_state = State.LOOK_ROTATE
	_looking_time(demon, delta)


func _update_look_rotate(demon: BlueDemon, delta: float) -> void:
	if _angle_to_look_target(demon) > ROTATE_DEAD_BAND:
		# Note the speed of 1 while merely turning on the spot: the demon leans into the
		# turn rather than pivoting dead still.
		demon.desired_speed = SPEED_BASE
		if demon.target:
			demon.rotate_towards(demon.target.global_position, delta)
	else:
		_state = State.LOOK
	_looking_time(demon, delta)


## The stare clock. Port of `AooniChaseState.LookingTime`.
func _looking_time(demon: BlueDemon, delta: float) -> void:
	# A standing player is resolved in 2 seconds of real time, a crouching one in 3.
	var rate := 1.5 if demon.is_target_standing() else 1.0
	_look_time += delta * rate
	if _look_time < BlueDemonTuning.CHASE_LOOK_TARGET_TIME:
		return

	demon.play_se(BlueDemon.SeType.LOOK)
	if demon.is_find_player(BlueDemonTuning.CHASE_LOOK_DISTANCE, BlueDemonTuning.CHASE_LOOK_ANGLE):
		_state = State.CHASE
		# Seeded just under the 0.5 s search cadence so the first chase frame retargets.
		_look_time = BlueDemonTuning.CHASE_LOOK_TARGET_SPAN
		demon.desired_speed = SPEED_BASE
		return

	# Lost it during the stare: go and stand where it was, for a good long while.
	var at := demon.target_position_or_own()                         # DST C4: a prey that left the room (or died) has no usable position
	demon.set_state(BlueDemonWanderingState.new(null, BlueDemonPatrolPointData.make_transient(at, 15.0, 2.0)))


# --- pursuit ----------------------------------------------------------------------

func _update_chase(demon: BlueDemon, delta: float) -> void:
	_look_time += delta
	if _look_time >= BlueDemonTuning.CHASE_LOOK_TARGET_SPAN:
		_look_time = 0.0
		if demon.is_find_player(BlueDemonTuning.CHASE_LOOK_DISTANCE, BlueDemonTuning.CHASE_LOOK_ANGLE):
			demon.pursue_target()                                    # DST C1
			if demon.desired_speed < SPEED_CAP and _is_behind_target(demon):
				demon.desired_speed = minf(SPEED_CAP, demon.desired_speed * 2.0)
		else:
			# Cannot see the player: commit to their last position at full speed.
			demon.desired_speed = SPEED_CAP
			demon.hold_destination()                                 # DST C2
			if demon.is_feel_player_sound() and demon.target:
				demon.set_destination(demon.target.global_position)
			if demon.remaining_distance < ARRIVE_EPSILON:
				_lost_time = 0.0
				_state = State.LOST

	# This tail runs every frame, including frames where the search gate did not fire.
	if demon.desired_speed < SPEED_CAP:
		demon.desired_speed = minf(SPEED_CAP, demon.desired_speed + delta * BlueDemonTuning.CHASE_SPEED_UP_DELTA)
	_update_chase_bgm(demon)


## Is the demon behind the player? Doubling the speed here is what makes running away
## without looking back so dangerous.
func _is_behind_target(demon: BlueDemon) -> bool:
	if demon.target == null:
		return false
	var target_forward := -demon.target.global_transform.basis.z
	var to_demon := demon.global_position - demon.target.global_position
	if to_demon.length_squared() < 0.0001:
		return false
	return rad_to_deg(target_forward.angle_to(to_demon.normalized())) > BEHIND_ANGLE


func _update_chase_bgm(demon: BlueDemon) -> void:
	if not _is_chase_bgm and is_equal_approx(demon.desired_speed, SPEED_CAP):
		demon.play_se(BlueDemon.SeType.CHASE)
		_is_chase_bgm = true


func _update_lost(demon: BlueDemon, delta: float) -> void:
	_look_time += delta
	_lost_time += delta
	demon.desired_speed = 0.0

	if _look_time >= BlueDemonTuning.CHASE_LOOK_TARGET_SPAN:
		_look_time = 0.0
		if demon.is_find_player(BlueDemonTuning.CHASE_LOOK_DISTANCE, BlueDemonTuning.CHASE_LOOK_ANGLE):
			_state = State.CHASE
			demon.desired_speed = SPEED_CAP
			demon.pursue_target()                                    # DST C1
			# Deliberately no early return: the original falls through to the give-up
			# test, so a player who steps back into view on the very tick that `lostTime`
			# crosses three still gets away.

	# LOST_LIMIT is three *seconds* after arriving, not three failed searches — the
	# demon gets six searches in during that window.
	if _lost_time < BlueDemonTuning.CHASE_LOST_LIMIT:
		return
	_give_up(demon)                                                  # DST C8


func _give_up(demon: BlueDemon) -> void:                             # DST C8: SRC :227-232 verbatim
	demon.desired_speed = 0.0
	demon.notify_chase(false)                                        # DST C7
	demon.set_state(BlueDemonWanderingState.new(
		null, BlueDemonPatrolPointData.make_transient(demon.global_position, 9.0)
	))
	demon.stop_se()


# --- forced chase -----------------------------------------------------------------

func _update_force_chase(demon: BlueDemon, delta: float) -> void:
	_look_time += delta
	if _wait_time > 0.0:
		# A scripted chase that has not started yet: nothing else runs at all.
		_wait_time -= delta
		return
	if _look_time >= BlueDemonTuning.CHASE_LOOK_TARGET_SPAN:
		_look_time = 0.0
		if not demon.is_target_alive():                              # DST C6
			_give_up(demon)                                          # DST C6
			return                                                   # DST C6
		demon.desired_speed = SPEED_CAP
		if demon.target:
			demon.pursue_target()                                    # DST C1
	_update_chase_bgm(demon)


## An `AooniStopForceChaseTrigger` fired. Unconditional: whatever sub-state the demon is
## in, it drops into a normal chase.
func stop_force_chase() -> void:
	_lost_time = 0.0
	_state = State.CHASE
