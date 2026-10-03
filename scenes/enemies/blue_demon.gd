class_name BlueDemon
extends Enemy

## The 3D blue demon (port of blue-demon-escape `Aooni`). Stalks a patrol graph, stares, chases with a
## speed ramp, loses the player, sleeps. The kill is the inherited KillZone.
##
## Port of `u823.Aooni` (blue-demon-escape `scripts/characters/aooni/aooni.gd`). In the original the
## demon is a CharacterController driven by a NavMeshAgent, with sub-components handling animation
## and footstep audio, and a swappable `IAooniState` holding the actual behaviour. That structure is
## preserved here: [BlueDemonBody] and [BlueDemonFoot] are child nodes, and [member current_state]
## is one of the [BlueDemonState] subclasses, which talk to this class through SRC's member names.
##
## DST: the body is moved by the Enemy framework (EnemyRuntimeCoordinator); this class only decides
## where to go ([BlueDemonTravel]) and how fast (one motor write per tick). Sight and hearing live in
## [BlueDemonSenses]; everything known about the prey goes through [BlueDemonPrey].

signal state_changed(state_name: String)          ## SRC: emitted by set_state only ("Wandering", "Chase.LOOK", "Sleeping")
signal chase_changed(is_chasing: bool)            ## SRC fear_chase_changed, renamed (PlayerFear is not ported)
signal se_requested(se_type: int)                 ## SRC se_requested; emitted before the playback guards
signal se_stopped()
signal travel_blocked(destination: Vector3)       ## DST: a destination could not be reached (authoring error, locked door, off-mesh gate)

## SRC Aooni.SeType without GAME_OVER (kill cutscene, not ported).
enum SeType { FIND = 0, LOOK = 1, CHASE = 2, NONE = 3 }

const SPAWN_SETTLE_TICKS := 2          # SRC game_level.gd:129-132 waits two physics frames
const BOOT_TIMEOUT_TICKS := 120        # start anyway after 2 s without floor / navigation map
const TELEPORT_JUMP_DISTANCE := 4.0    # metres between two checkpoints; a 7 m/s body covers 0.12 per tick
const TARGET_REFRESH_INTERVAL := 0.5
const FACING_MIN_SPEED := 0.05         # below it the motor's snapped yaw is not trusted

@export_group("Blue Demon")
## Visual height = 2.80 m x this. Applied to Graphics/Model together with the sole offset and the eye height.
@export_range(0.2, 2.0, 0.001) var model_scale: float = 0.714286
## World speed = SRC-unit speed x this. 1.4 gives the 7.0 m/s chase cap (SRC cap 5.0). It is the ONLY
## speed knob: stats.speed is not used by this enemy.
@export_range(0.1, 4.0, 0.01) var speed_scale: float = 1.4
@export var body_material: Material
@export var start_asleep: bool = false:
	set(value):
		start_asleep = value
		_sync_boot_absence()                # DST R2: also when a spawn_setup sets it after add_child
## Optional: only patrol points below this node are used (two demons, two graphs in one room).
@export var patrol_root: Node3D
## After ending up in a room without patrol points, walk back to the start room through transitions.
@export var return_home: bool = true
## Room transitions the demon may follow blind per sighting. 0 = stairs are always safe.
@export_range(0, 8) var chase_room_hops: int = 1
## Seconds after a revive during which the demon neither sees nor hears the player.
@export var revive_grace_time: float = 3.0

@export_group("Senses")
@export_flags_3d_physics var sight_mask: int = 5              ## Player (layer 1) + Walls/doors (layer 3)
@export var hearing_intensity_per_speed: float = 0.125        ## 1 / player sprint speed (8.0)
@export var lighter_counts_as_flashlight: bool = true

@export_group("Travel")
@export var arrive_radius: float = 0.5                        ## horizontal metres
@export var arrive_max_height_delta: float = 1.0
@export var blocked_grace: float = 0.5                        ## s of "navigation finished but not there" before BLOCKED
@export var stall_timeout: float = 3.0                        ## s inside a 0.3 m circle while commanded to move

# --- state the SRC states read and write (SRC member names) ---
## SRC target; resolved lazily by the demon itself (4.5).
## DST R1: always null or a live node inside the tree. A freed object compares equal to null but is rejected by
## every typed parameter, and a node outside the tree has no global transform, so the reference is dropped on the
## first read after the prey was freed or removed (_refresh_target() re-resolves it). The states, the senses, the
## travel layer, the foot and map scripts all read the prey through here.
var target: CharacterBody3D:
	get:
		if not is_instance_valid(target) or not target.is_inside_tree():
			target = null
		return target
var current_state: BlueDemonState
## DST R1: null once the tracked node was freed; the next tick then falls back to dummy_look_target (4.6).
var look_target: Node3D:
	get: return look_target if is_instance_valid(look_target) else null
var is_chase: bool = false
var is_sleeping: bool = false
var dummy_look_target: Node3D
var body: BlueDemonBody
var foot: BlueDemonFoot
var se_player: BlueDemonSe

## SRC `speed` (rw), renamed: Enemy.speed is getter-only (enemy.gd:54-55). SRC units.
var desired_speed: float:
	get: return _desired_speed
	set(value): _desired_speed = maxf(value, 0.0)
## SRC remaining_distance: exactly 0.0 once arrived / parked / blocked, otherwise >= 1.0.
var remaining_distance: float:
	get: return _travel.remaining_distance()

# --- DST additions ---
var facing_yaw: float = 0.0                 ## the demon's facing for cone, stare, neck and model (7.4)
var active: bool = false                    ## false until the boot gate has passed (4.5)
var home_room: String = ""

# --- private (the names are fixed: the tests read them) ---
var _desired_speed: float = 0.0
var _travel: BlueDemonTravel
var _senses: BlueDemonSenses
var _eyes: Node3D
var _model_ok: bool = false
var _movement_frozen: bool = false
var _boot_ticks: int = 0
var _pending_state: BlueDemonState
var _last_position: Vector3 = Vector3.ZERO
var _last_room: String = ""
var _target_was_alive: bool = false
var _revive_grace_left: float = 0.0
var _target_refresh_left: float = 0.0
var _blocked_reported: bool = false
var _boot_absent: bool = false              # DST R2: hidden and not solid before the boot gate (the first state will be Sleeping)
var _saved_layer: int = 0
var _saved_mask: int = 0
var _has_explicit_look_target: bool = false
var _look_position_override: Vector3 = Vector3.INF
var _warned: Dictionary = {}


# --- lifecycle (4.5): nothing position-, room- or player-dependent happens in _ready ----------------

func _ready() -> void:
	super._ready()                                                   # Enemy: context + components (enemy.gd:74-104)
	if navigation_mode != NavigationMode.GODOT:
		# AFTER super. is_node_ready() is already true inside _ready() (probe), so this setter always runs
		# Enemy._refresh_navigation_mode_runtime() (enemy.gd:141-157). After super every component it re-wires
		# exists; before super it would build the runtime coordinator with null components (harmless, but pointless).
		push_warning("[BlueDemon] %s: patrol needs the navmesh; forcing GODOT navigation" % name)
		navigation_mode = NavigationMode.GODOT
	body = get_node_or_null(^"BlueDemonBody") as BlueDemonBody
	foot = get_node_or_null(^"BlueDemonFoot") as BlueDemonFoot
	se_player = get_node_or_null(^"SePlayer") as BlueDemonSe
	dummy_look_target = get_node_or_null(^"Graphics/DummyLookTarget") as Node3D
	_eyes = get_node_or_null(^"EyesDetection3D") as Node3D
	look_target = dummy_look_target
	arrive_radius = maxf(arrive_radius, BlueDemonTravel.GOTO_AGENT_RADIUS + 0.05)
	_travel = BlueDemonTravel.new()
	_travel.setup(self, get_node_or_null(^"NavigationAgent3D") as NavigationAgent3D)
	_senses = BlueDemonSenses.new()
	_senses.setup(self)
	_model_ok = body != null and body.init(self)                     # model scale, loop modes, material, tree on (7.1)
	if foot:
		foot.init(self)
	if se_player:                                                    # the wiring SRC's level did (audio_controller.gd:68-76)
		se_requested.connect(se_player.play_se)
		se_stopped.connect(se_player.stop_se)
	if _kill_zone_component:                                         # after the base handler (enemy.gd:180)
		_kill_zone_component.player_killed.connect(_on_prey_killed)
	_desired_speed = 0.0
	_motor_component.speed = 0.0     # Enemy copied stats.speed (enemy.gd:171); nothing may move before activation
	_sync_boot_absence()             # DST R2: a start_asleep demon (or one put to sleep before add_child) is absent from its first frame


# --- the physics tick (4.2: the one place order matters) --------------------------------------------

func _physics_process(delta: float) -> void:      # typed override of an untyped parent compiles (spike P14)
	if not active:
		_boot_tick()                              # 4.5; may call _begin_play()
		super._physics_process(delta)             # gravity + move_and_slide: the body settles on the floor
		return
	_reconcile_external(delta)                    # 0. target, revive edge, teleport checkpoint A, injected orders (4.6)
	if _movement_frozen:                          #    Sleeping
		_tick_frozen(delta)
		return
	_travel.update(delta)                         # 1. SRC _update_path(): arrival status from THIS tick's position
	if _travel.status == BlueDemonTravel.Status.BLOCKED and not _blocked_reported:
		_blocked_reported = true
		travel_blocked.emit(_travel.destination)
	if current_state:
		current_state.update(self, delta)         # 2. the SRC AI (aooni.gd:226-227)
	# 3. No _check_caught(): decision 2 — the inherited KillZone kills (aooni.gd:228, 243-254 not ported).
	if _movement_frozen:                          #    the state just went to sleep
		_tick_frozen(delta)
		return
	_travel.apply()                               # 4a. SINGLE writer of Enemy.waypoints / Enemy.current_target / agent radius
	_motor_component.speed = desired_speed * speed_scale   # 4b. SINGLE writer of the motor speed (G1)
	super._physics_process(delta)                 # 4c. SRC _move(): EnemyRuntimeCoordinator.process_physics
	_checkpoint_teleport()                        # 4c'. teleport checkpoint B: a hop taken inside 4c or in step 2
	_post_move(delta)                             # 4d. facing yaw, Graphics counter-rotation (7.4)
	if body:
		body.on_update(delta)                     # 5. SRC body.on_update (aooni.gd:230-231)
	if foot:
		foot.on_update(delta)                     # 6. footstep clock (SRC: AooniFoot._process)


func _tick_frozen(delta: float) -> void:
	# SRC _move(): frozen -> velocity ZERO, return (aooni.gd:448-450).
	# No coordinator tick: no gravity, no slide, no disappear poll.
	velocity = Vector3.ZERO
	if body:
		body.on_update(delta)                     # SRC ticks the body while frozen (aooni.gd:229-231): the gait blend settles to idle
	if foot:
		foot.on_update(delta)                     # speed 0 -> the phase clock resets, no stamps

# No _process: the neck write lives in BlueDemonBody._process (priority 100).


func _boot_tick() -> void:
	_boot_ticks += 1
	if _boot_ticks < SPAWN_SETTLE_TICKS:
		return
	var nav_ready := NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map) > 0
	if _boot_ticks < BOOT_TIMEOUT_TICKS and not (nav_ready and (is_on_floor() or is_flying)):
		return
	_begin_play(nav_ready)


func _begin_play(nav_ready: bool) -> void:
	active = true
	facing_yaw = rotation.y
	home_room = current_room
	_remember_tick()
	_refresh_target(INF)
	print("[BlueDemon] %s active: room='%s' patrol points %d/%d target=%s nav=%s" % [
		name, current_room, get_patrol_points().size(), BlueDemonPatrolPoint.get_registered().size(),
		target.name if target else "none", "ok" if nav_ready else "TIMEOUT"])
	if NavigationServer3D.map_get_regions(get_world_3d().navigation_map).is_empty():
		# (probe) the map iteration id is > 0 even without a region, so nav_ready cannot tell; and an agent on such a
		# map never reports finished: neither the path nor the framework's direct press moves the body (8.9).
		warn_once(&"no_navmesh", "[BlueDemon] %s: this map has no navigation region. The demon cannot walk: patrol legs end blocked and a chase runs on the spot. Bake a navmesh." % name)
	if not _model_ok:                                                # never an invisible killer
		push_error("[BlueDemon] %s: model / AnimationTree missing; staying dormant" % name)
		off_nav_mesh()
		return
	if _kill_zone_component:
		_kill_zone_component.enabled = true                          # disarmed in the scene until now (spike P8)
	var first := _pending_state
	_pending_state = null
	if first == null and current_target != null:                     # a spawner supplied a target (enemy_spawn_owner_service.gd:41-42)
		target = current_target
		_target_was_alive = BlueDemonPrey.is_alive(target)
		current_target = null
		first = BlueDemonChaseState.new(true, 0.0)
	if first == null:
		first = BlueDemonSleepingState.new() if start_asleep else BlueDemonWanderingState.new()
	if not (first is BlueDemonSleepingState):
		_end_boot_absence()                                          # DST R2: not a sleeper after all (an order, or a spawner's target): visible and solid from here on
	set_state(first)


# --- absent before the boot gate (DST R2) -------------------------------------------------------------

## DST R2: a demon whose first state will be Sleeping is absent from its first frame, not only from the boot
## gate on: hidden and off every collision layer. The collision MASK stays, so the body still settles on the
## floor for the boot gate; the KillZone is disarmed in the scene until activation anyway. Re-evaluated
## whenever the queued first state or start_asleep changes; ended by _begin_play(), or taken over by the
## Sleeping state's off_nav_mesh() without the demon ever being shown.
func _sync_boot_absence() -> void:
	if active or not is_node_ready():
		return
	if not _is_sleep_ordered():
		_end_boot_absence()
	elif not _boot_absent:
		_boot_absent = true
		_saved_layer = collision_layer      # what off_nav_mesh() would save; it keeps this value when it takes over
		visible = false
		collision_layer = 0


func _end_boot_absence() -> void:
	if not _boot_absent:
		return
	_boot_absent = false
	visible = true                          # as on_nav_mesh() does for a woken sleeper
	collision_layer = _saved_layer


# --- reconcile (4.6): nothing the framework or a map script does is silently lost ---------------------

func _reconcile_external(delta: float) -> void:
	if not is_instance_valid(current_target):                     # 0. DST R1: Enemy.current_target is a plain var; a freed prey must not
		current_target = null                                     #    reach a typed parameter (null stays null)
	if _has_explicit_look_target and look_target == null:         #    DST R1: the tracked node was freed -> SRC "LookTarget == null"
		set_look_target(null)
	_refresh_target(delta)                                        # 1. target
	var alive := BlueDemonPrey.is_alive(target)                   # 2. revive edge (G6)
	if alive and not _target_was_alive:
		_revive_grace_left = revive_grace_time
	_target_was_alive = alive
	if alive and _revive_grace_left > 0.0:
		_revive_grace_left -= delta                               #    the clock only runs while alive
	_checkpoint_teleport()                                        # 3. teleport checkpoint A (C4)
	if _travel.is_foreign_target(current_target):                 # 4. injected current_target
		target = current_target
		_target_was_alive = BlueDemonPrey.is_alive(target)
		current_target = null
		force_chase(0.0)                                          #    SRC FORCE_CHASE; no-op while a chase is running; wakes a sleeper
	var injected: Variant = _travel.first_foreign_waypoint(waypoints)   # 5. injected waypoints
	if injected != null:
		waypoints.clear()                                         #    apply() re-asserts the demon's own destination
		warn_once(&"injected_waypoint", "[BlueDemon] %s: a script pushed a waypoint; honoured as call_to_position() (one position, the rest is dropped). Use call_to() / patrol points for scripted paths." % name)
		call_to_position(injected as Vector3)


func _refresh_target(delta: float) -> void:
	_target_refresh_left -= delta
	var usable := target != null and is_instance_valid(target) and target.is_inside_tree()
	if usable and (BlueDemonPrey.is_alive(target) or _target_refresh_left > 0.0):
		return
	_target_refresh_left = TARGET_REFRESH_INTERVAL
	var first_player: CharacterBody3D = null
	var alive_player: CharacterBody3D = null
	for candidate in Services.enemy_context.get_players():        # lazy, never cached in _ready (level.gd:20-26)
		var prey := candidate as CharacterBody3D
		if prey == null:
			continue
		if first_player == null:
			first_player = prey
		if BlueDemonPrey.is_alive(prey):
			alive_player = prey
			break
	var best := alive_player if alive_player != null else (target if usable else first_player)
	if best != target:
		target = best
		_target_was_alive = BlueDemonPrey.is_alive(target)        # a newly resolved target never starts a revive grace


## Teleport detector (C4). Called twice per tick (4.2): at the start (A) and right after the coordinator (B).
## The snapshot is always "the last place this demon was seen by its own code", so a teleport that happens
## anywhere after a checkpoint is caught by the next one.
func _checkpoint_teleport() -> void:
	if current_room != _last_room or global_position.distance_to(_last_position) > TELEPORT_JUMP_DISTANCE:
		_on_teleported()
	_remember_tick()


func _on_teleported() -> void:
	rotation = Vector3(0.0, rotation.y, 0.0)      # yaw only: a MATCH_MARKER_FULL arrival marker may have pitched the body (G9)
	facing_yaw = rotation.y
	graphics.rotation.y = 0.0
	_travel.notify_teleported()                   # consumes a trail hop; HOLD / ARRIVED: no stored position survives
	_blocked_reported = false
	_remember_tick()
	if current_state:
		current_state.on_teleported(self)         # Wandering re-plans in the new room; Chase searches on the next tick


func _post_move(delta: float) -> void:
	var travelling := current_target != null or not waypoints.is_empty()
	if travelling and Vector2(velocity.x, velocity.z).length() > FACING_MIN_SPEED:
		# The motor snapped the root to the velocity (enemy_motor_component.gd:76-79); the facing follows
		# at SRC's path-following turn rate (aooni.gd:472-482, AGENT_ANGULAR_SPEED 120 deg/s).
		facing_yaw = rotate_toward(facing_yaw, rotation.y, deg_to_rad(BlueDemonTuning.AGENT_ANGULAR_SPEED) * delta)
	else:
		rotation = Vector3(0.0, facing_yaw, 0.0)     # hold: the root adopts the facing. Yaw only, pitch/roll flattened (G9)
	graphics.rotation.y = angle_difference(rotation.y, facing_yaw)   # the model shows facing_yaw while the root stays snapped


func _on_prey_killed(_player: Node3D) -> void:    # 4.7
	if active and not _movement_frozen:
		set_look_target(null)                     # SRC: AooniEatingPlayerState.init cleared it (aooni_eating_player_state.gd:110)
		set_state(BlueDemonWanderingState.new())


func _remember_tick() -> void:
	_last_position = global_position
	_last_room = current_room


# --- SRC actor API (same names as aooni.gd; see 4.8) -------------------------------------------------

## Replace the behaviour state, mirroring `Aooni.SetState`.
## DST: no `is_game_over` latch (decision 2); queued until the boot gate has passed (D26).
func set_state(new_state: BlueDemonState) -> void:
	if not active:
		_pending_state = new_state            # DST: nothing position-dependent may run before the boot gate (G4)
		_sync_boot_absence()                  # DST R2: a queued Sleeping hides the demon now, any other queued state shows it
		return
	if current_state:
		current_state.finished(self)
	current_state = new_state
	if current_state:
		current_state.init(self)
		state_changed.emit(current_state.get_state_name())


## The behaviour states live outside this class but their observable events belong to the
## demon, so they are relayed through these three rather than reaching into the signals
## directly — which also keeps the emission and the declaration in one file.
func play_se(se_type: int) -> void:
	se_requested.emit(se_type)


func stop_se() -> void:
	se_stopped.emit()


func notify_chase(chasing: bool) -> void:
	chase_changed.emit(chasing)
	if chasing and target != null:             # DST convention; Enemy._on_target_acquired is never reached (stock AI off)
		Services.event_bus.emit(GameEventTypes.ENEMY_TARGET_ACQUIRED, {"body": target}, self)


## GOTO a point; ends a trail. DST: no navmesh snap (SRC get_destination_point, aooni.gd:408-424, is not
## ported: snapping y recreates the agent limbo on floating navmeshes, D24).
func set_destination(target_position: Vector3) -> void:
	_blocked_reported = false
	_travel.go_to(target_position)


## PURSUE the live target (seen or forced); records last-seen, refills the hop budget.
func pursue_target() -> void:
	if target != null:
		_travel.pursue_seen(target)


## First line of the chase state's blind branch (5.2 C2).
func hold_destination() -> void:
	var was_pursuing := _travel.command == BlueDemonTravel.Command.PURSUE
	_travel.hold_blind()
	if was_pursuing and _travel.command == BlueDemonTravel.Command.GOTO:
		# DST R4: a NEW leg (to the last-seen position) re-arms travel_blocked, as set_destination() does. Not a bare
		# reset: this runs on every blind search tick, also right after BLOCKED was reported for the same leg, and
		# hold_blind() returns at once unless the command is still PURSUE.
		_blocked_reported = false


## HOLD; used by chase finished() and the wander idle.
func end_pursuit() -> void:
	_travel.hold()


## Turn on the spot towards a world position at the demon's rotation speed.
## DST: yaw only, 90 deg/s on facing_yaw; the root adopts it in _post_move (hold branch).
func rotate_towards(point: Vector3, delta: float) -> void:
	var flat := point - global_position
	flat.y = 0.0                               # DST: yaw only (SRC aooni.gd:491-501 pitched the whole body)
	if flat.length_squared() < 0.000001:
		return
	turn_towards_yaw(atan2(-flat.x, -flat.z), delta)


## Yaw only, 90 deg/s (patrol "thinking" turn).
func turn_towards_yaw(yaw: float, delta: float) -> void:
	facing_yaw = rotate_toward(facing_yaw, yaw, deg_to_rad(BlueDemonTuning.AOONI_ROTATE_SPEED) * delta)


## SRC `-global_transform.basis.z` as forward (cone, stare, neck): the visible facing, always planar.
func facing_forward() -> Vector3:
	return Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw))


## Hard teleport that does not trip the teleport checkpoints.
func warp_to(world_position: Vector3) -> void:
	global_position = world_position
	velocity = Vector3.ZERO
	_travel.hold()
	_remember_tick()                           # the demon's own warp is not an external teleport


## Detach from navigation — port of `Aooni.OffNavmesh`. DST: dormant in place (5.3, D12): hidden,
## collision off, KillZone off, coordinator not ticked. Idempotent.
func off_nav_mesh() -> void:
	if _movement_frozen:
		# idempotent, mirror of on_nav_mesh(): a second call would save layer 0 / mask 0
		# and the wake would restore a body without collision (red-team D9)
		return
	# `OffNavmesh` zeroes the agent's speed before disabling it. That matters because
	# [BlueDemonBody] feeds the same value to the animation blend, so a demon frozen at speed
	# 5 would keep running on the spot.
	desired_speed = 0.0
	_movement_frozen = true
	velocity = Vector3.ZERO
	_travel.hold()
	_travel.apply()                         # the tick does not reach step 4a while frozen
	_motor_component.speed = 0.0
	visible = false
	if _boot_absent:
		_boot_absent = false                # DST R2: absent since the first frame; the real layer was saved then
	else:
		_saved_layer = collision_layer      # not solid for the player, bullets, other enemies, transition slabs
	_saved_mask = collision_mask
	collision_layer = 0
	collision_mask = 0
	if _kill_zone_component:
		_kill_zone_component.enabled = false    # SRC _check_caught skipped a sleeping demon (aooni.gd:246)
	stop_se()


## Hand control back to the navigation agent. Port of `Aooni.OnNavMesh`. Idempotent.
func on_nav_mesh() -> void:
	if not _movement_frozen:
		return
	_movement_frozen = false
	visible = true
	collision_layer = _saved_layer
	collision_mask = _saved_mask
	if _kill_zone_component:
		_kill_zone_component.enabled = active and _model_ok
	_remember_tick()


func is_find_player(look_distance: float, look_angle: float) -> bool:
	return _senses.is_find_player(look_distance, look_angle)


func is_feel_player_sound() -> bool:
	return _senses.is_feel_player_sound()


## Does the player have a flashlight on? Widens the patrol sight cone to 40 m / 90 deg.
## DST: the lit lighter counts as the flashlight (D10), switchable.
func is_target_light_on() -> bool:
	return lighter_counts_as_flashlight and target != null and BlueDemonPrey.is_flash_light_on(target)


## `PlayerController.Body.IsStandUp` — standing makes the demon resolve its stare 1.5x
## faster and doubles its hearing range.
func is_target_standing() -> bool:
	return target != null and BlueDemonPrey.is_stand_up(target)


func is_target_alive() -> bool:
	return BlueDemonPrey.is_alive(target)


func distance_to_target() -> float:
	if target == null:
		return INF
	return global_position.distance_to(target.global_position)


## Target position if sensible (valid, alive, same room) else own position.
func target_position_or_own() -> Vector3:
	if target == null or not is_instance_valid(target) or not BlueDemonPrey.is_alive(target) \
			or not BlueDemonPrey.same_room(self, target):
		return global_position
	return target.global_position


func set_look_target(node: Node3D) -> void:
	_has_explicit_look_target = node != null
	look_target = node if node != null else dummy_look_target
	_look_position_override = Vector3.INF


## Aim the head at a bare world position rather than a node — used by the head-swing
## sweep, which has no object to track.
func look_at_point(world_position: Vector3) -> void:
	_look_position_override = world_position


## Where the head should currently point, in world space.
func get_look_position() -> Vector3:
	if _look_position_override != Vector3.INF:
		return _look_position_override
	if look_target != null and look_target.is_inside_tree():      # DST R1: a node outside the tree has no global position
		return look_target.global_position
	return global_position + facing_forward() * 5.0   # DST 4.8: facing_forward() instead of -basis.z (G9)


## Whether the neck has anything real to track. The original's `OnLateUpdate` tests
## `LookTarget == null` and forces the angle to **zero** on null.
## DST: also false while the tracked node is the target and it is in another room (8.5).
func is_looking_at_something() -> bool:
	if _look_position_override == Vector3.INF \
			and (not _has_explicit_look_target or look_target == null or not look_target.is_inside_tree()):
		return false                                 # DST R1: also when the tracked node was freed or left the tree (read from _process, between two ticks)
	return not (look_target == target and not BlueDemonPrey.same_room(self, target))   # DST 4.8: rooms (8.5)


func stop_force_chase() -> void:
	var state := current_state if active else _pending_state    # DST R3: before the boot gate, the queued forced chase (it then starts as a normal one, with the stare)
	if state is BlueDemonChaseState:
		(state as BlueDemonChaseState).stop_force_chase()


# --- DST services for the states and helpers ---------------------------------------------------------

## No target / dead / revive grace running / target in another room.
func are_senses_blocked() -> bool:
	return target == null or not is_instance_valid(target) or not BlueDemonPrey.is_alive(target) \
		or _revive_grace_left > 0.0 or not BlueDemonPrey.same_room(self, target)


## The sight-ray origin: the EyesDetection3D marker on the capsule axis, not the eyebrow bone (G11).
func get_eye_position() -> Vector3:
	return _eyes.global_position if _eyes else global_position + Vector3.UP * 1.414


func get_nav_component() -> EnemyNavigationComponent:
	return _nav_component


func get_transition_component() -> EnemyTransitionComponent:
	return _transition_component


func get_room_pathing_component() -> RoomPathingComponent:
	return _room_pathing_component


## Registry ∩ patrol_root ∩ room (8.3).
func get_patrol_points() -> Array[BlueDemonPatrolPoint]:
	var result: Array[BlueDemonPatrolPoint] = []
	for point in BlueDemonPatrolPoint.get_registered():
		if patrol_root != null and not patrol_root.is_ancestor_of(point):
			continue
		if is_point_in_my_room(point):
			result.append(point)
	return result


func is_point_in_my_room(point: BlueDemonPatrolPoint) -> bool:
	return point.room == "" or current_room == "" or point.room == current_room


func make_homeward_hop() -> BlueDemonPatrolPointData:
	return _travel.make_homeward_hop()


func take_transition(transition_name: String) -> bool:
	return _travel.take_transition(transition_name)


func was_travel_blocked() -> bool:
	return _travel.status == BlueDemonTravel.Status.BLOCKED


func warn_unreachable_point(point: BlueDemonPatrolPoint) -> void:
	warn_once(StringName("unreachable_%d" % point.get_instance_id()),
		"[BlueDemon] %s: patrol point '%s' cannot be reached (off the navmesh, or behind a locked door); dwelling where the demon got to" % [name, point.name])


func warn_once(key: StringName, message: String) -> void:
	if not _warned.has(key):
		_warned[key] = true
		push_warning(message)


# --- orders API (what map scripts call; never construct states from outside) -------------------------

## current_state.get_state_name() or "" (reports chase sub-states).
func get_state_name() -> String:
	return current_state.get_state_name() if current_state else ""


## DST R3: every order is judged against the state it will act on. Before the boot gate that is the queued
## first state (or the start_asleep default), not the live one, so an order given right after add_child is
## applied, refused or ignored exactly as it would be once the demon is active.
func _is_sleep_ordered() -> bool:
	if active:
		return current_state is BlueDemonSleepingState
	return (_pending_state is BlueDemonSleepingState) if _pending_state != null else start_asleep


func _is_chase_ordered() -> bool:           # DST R3
	return is_chase or (not active and _pending_state is BlueDemonChaseState)


func sleep() -> void:
	set_state(BlueDemonSleepingState.new())


## Sleeping -> Wandering (no-op otherwise).
func wake() -> void:
	if _is_sleep_ordered():                 # DST R3: also a start_asleep demon that is not active yet
		set_state(BlueDemonWanderingState.new())


## -> Chase FORCE_CHASE (omniscient); refused while a chase is running.
func force_chase(wait_time: float = 0.0) -> void:
	if _is_chase_ordered():
		# SRC's only caller refuses while a chase is running (force_chase_trigger.gd:30-33,40):
		# a new state object would park the demon for 0.5 s and restart the violin
		return
	set_state(BlueDemonChaseState.new(true, wait_time))     # DST D32: also wakes a sleeper (SRC's trigger refuses a sleeping demon)


## SRC CallAooniTrigger: walk to an authored point (also an ONLY_CALL one).
func call_to(point: BlueDemonPatrolPoint, ignore_while_chase: bool = false) -> void:
	if point == null or not point.is_inside_tree():         # DST R1: a point outside the tree has no position
		return
	if ignore_while_chase and _is_chase_ordered():          # SRC call_aooni_trigger.gd:35 (is_ignore_while_chase)
		return
	set_state(BlueDemonWanderingState.new(point))           # SRC call_aooni_trigger.gd:41: always a fresh state


## SRC CallAooniTrigger with is_warp, the "warp call": appear AT an authored point (also an ONLY_CALL one) and
## resume the patrol there; wakes a sleeper. Refused like SRC's trigger (call_aooni_trigger.gd:35,43-47): while
## chasing if `ignore_while_chase`, and when the demon is already within `min_distance` of the point (SRC
## is_check_dist_for_warp / warp_dist, authored 25 or 12; 0 = always warp). DST R6: same room only.
func warp_call_to(point: BlueDemonPatrolPoint, ignore_while_chase: bool = false, min_distance: float = 0.0) -> void:
	if point == null or not point.is_inside_tree() or (ignore_while_chase and _is_chase_ordered()):
		return
	if not is_point_in_my_room(point):                      # DST R6: a warp does not change current_room (8.5)
		warn_once(StringName("warp_other_room_%d" % point.get_instance_id()),
			"[BlueDemon] %s: warp_call_to('%s') refused: the point is in room '%s', the demon in '%s'" % [name, point.name, point.room, current_room])
		return
	if min_distance > 0.0 and is_inside_tree() and global_position.distance_to(point.global_position) < min_distance:
		return                                              # SRC :43-47: already close, no call and no warp
	set_state(BlueDemonWanderingState.new(                  # SRC :50-54: the point's data AND its position as the warp target
		null, BlueDemonPatrolPointData.from_point(point), point.global_position))


## SRC CallAooniObject, the "summon": run there, stand `dwell` seconds, resume. Refused while chasing.
func call_to_position(world_position: Vector3, dwell: float = 3.0, src_speed: float = 5.0) -> void:
	if _is_chase_ordered():
		return                                              # SRC call_aooni_object.gd:62: refused while chasing
	var data := BlueDemonPatrolPointData.make_transient(world_position, dwell, src_speed)
	data.swing_head = false                                 # SRC call_aooni_object.gd:62-71: both head flags false, speed 5.0, dwell 3.0
	set_state(BlueDemonWanderingState.new(null, data))


## Enemy override -> force_chase(); never re-enables the stock AI.
func start_chasing_players(_force_scan: bool = true) -> void:
	force_chase(0.0)      # never calls super


## Enemy override -> Wandering if chasing.
func stop_chasing_players() -> void:
	if _is_chase_ordered():
		set_state(BlueDemonWanderingState.new())            # never calls super
