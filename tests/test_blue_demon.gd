extends Node
## Blue demon, core behaviour cases T01-T15 (plan section 11.3). Runner: tests/test_blue_demon.tscn.
## Cases with a letter after the number that the plan does not list (T03b, T05b, T06b, T08b, T09 controls
## b' to f, T10b, T15e) pin behaviour the plan's cases only passed through: the broken stare, the parked
## stare, the blind chase that hears, the arrival grace, the hearing and cone limits as the states apply them.
##
## Rules this runner keeps (plan 11.1):
## - no blue demon class is named in code: the scene and the scripts are loaded by path and driven
##   through untyped variables, so a stale class cache or a missing asset is a clean failure;
## - time is simulated time: every wait is a budget in simulated seconds and every assertion is on a
##   state reached, metres travelled, a measured speed or a simulated duration, never on render frames;
## - bodies are positioned before add_child (spike P8), except in T02, which adds first on purpose;
## - each case builds a fresh arena, frees it and unsubscribes what it subscribed on the event bus;
## - each case ends by checking that no script error and no engine error was logged while it ran;
## - without the ripped assets the runner SKIPs: exit 0, no OK banner.
##
## Times in assertions come from the per-demon observer (Arena.Watch): the simulated time at the start
## of the physics tick in which a thing happened. Time windows are compared with TIME_EPS (a third of
## a tick) of float slack; angles and "== 0" on Euler rotations with small epsilons.

const Arena := preload("res://tests/blue_demon_test_arena.gd")

const ROOT_SCRIPT := "res://scenes/enemies/blue_demon.gd"
const OK_BANNER := "=== BLUE DEMON TESTS OK ==="
const SKIP_LINE := "SKIP: blue demon assets not present (ripped assets are not committed)"

# SeType { FIND, LOOK, CHASE, NONE } of the demon root.
const SE_FIND := 0
const SE_LOOK := 1
const SE_CHASE := 2
# State { INIT, MOVE, THINKING, NONE } of the wandering state.
const WANDER_MOVE := 1
const WANDER_THINKING := 2
const WANDER_NONE := 3

const TIME_EPS := 0.005
const ROTATION_EPS := 0.0001
const ACTIVATION_BUDGET := 2.0
const WATCHDOG_SECONDS := 10.0

const REQUIRED_NODES: Array[String] = [
	"KillZone", "EnemyMotorComponent", "NavigationAgent3D", "Timers/FindPathTimer",
	"EnemyTransitionComponent", "EnemyRuntimeCoordinator", "Graphics/Model", "Graphics/AnimationTree",
	"Graphics/DummyLookTarget", "BlueDemonBody", "BlueDemonFoot", "SePlayer", "FootL", "FootR",
]

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
var _subscribed: Array[StringName] = []
var _bus_events: Array = []


func _ready() -> void:
	print("=".repeat(60))
	print("BLUE DEMON TESTS (core, T01-T15)")
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

	await _t01_scene_contract()
	await _t01_model_scale_variant()
	await _t02_spawn_order()
	await _t02b_spawner_target()
	await _t02c_sleep_before_activation()
	await _t03_stare_and_ramp()
	await _t03b_stare_parks_a_walking_demon()
	await _t04_behind_doubling()
	await _t05_crouched_stare()
	await _t05b_stare_broken()
	await _t06_t07_lose_player_and_empty_graph()
	await _t06b_blind_chase_hears()
	await _t08_patrol_traversal()
	await _t08b_arrival_grace()
	await _t09_hearing_investigate()
	await _t09_control("a: a silent stub 6 m behind is not heard", 6.0, 0.0, false, false)
	await _t09_control("b: crouched at 3 m/s, 4 m behind, is not heard (range 2.9 m)", 4.0, 3.0, true, false)
	await _t09_control("b': standing at 3 m/s, 4 m behind, is heard (range 5.1 m)", 4.0, 3.0, false, true)
	await _t09_control("c: sprinting 11 m behind is heard (range 12 m)", 11.0, 8.0, false, true)
	await _t09_control("d: sprinting 12.5 m behind is not heard", 12.5, 8.0, false, false)
	await _t09_control("e: crouched sprint 5.5 m behind is heard (range 6 m)", 5.5, 8.0, true, true)
	await _t09_control("f: crouched sprint 6.5 m behind is not heard", 6.5, 8.0, true, false)
	await _t10_sight_rules()
	await _t10b_wander_cone("distance: 26 m ahead is not seen, 24 m is", Vector3(0.0, 0.0, -26.0), Vector3(0.0, 0.0, -24.0), false)
	await _t10b_wander_cone("angle: 80 deg off the axis is not seen, 70 deg is",
		Arena.turned_right(Vector3.FORWARD, 80.0) * 10.0, Arena.turned_right(Vector3.FORWARD, 70.0) * 10.0, false)
	await _t10b_wander_cone("light: 30 m / 85 deg is seen only once the light is on",
		Arena.turned_right(Vector3.FORWARD, 85.0) * 30.0, Arena.turned_right(Vector3.FORWARD, 85.0) * 30.0, true)
	await _t11_kill_and_afterwards()
	await _t12_sleep_and_wake()
	await _t12ab_start_asleep_and_injected_target()
	await _t12c_double_off_nav_mesh()
	await _t13a_ignore_player_until_touch_here()
	await _t13b_force_chase_when_touch_here()
	await _t13c_wait_until_call(true)
	await _t13c_wait_until_call(false)
	await _t14_point_types_and_call_to()
	await _t15a_stop_force_chase()
	await _t15b_lost_reacquire()
	await _t15e_chase_cone_edges()
	await _t15c_orders_while_chasing()
	await _t15d_look_target_after_kill()

	_finish_cases()
	await get_tree().process_frame
	_finished = true
	print("\nsimulated %.1f s" % _sim)
	if _failed:
		print("=== BLUE DEMON TESTS FAILED ===")
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


# --- T01 ---------------------------------------------------------------------------------------

func _t01_scene_contract() -> void:
	_begin("T01 scene contract")
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return

	# Before any physics frame: _ready has run, the boot gate has not.
	# That the root is an Enemy is asserted by _spawn(): the arena returns null for any other root.
	var root_script := demon.get_script() as Script
	_assert(root_script != null and root_script.resource_path == ROOT_SCRIPT, "the root runs %s, got %s" % [ROOT_SCRIPT, root_script.resource_path if root_script != null else "<no script>"])
	_assert(demon.visible == true and demon.collision_layer == 2 and demon.collision_mask == 55,
		"before the first physics frame an awake demon is visible (%s) and solid: collision_layer == 2 (%d), collision_mask == 55 (%d)" % [demon.visible, demon.collision_layer, demon.collision_mask])
	for path in REQUIRED_NODES:
		_assert(demon.get_node_or_null(path) != null, "node '%s' exists" % path)
	_assert(demon.active == false, "before the first physics frame: active == false")
	_assert(demon.current_state == null, "before the first physics frame: current_state == null")
	var kill_zone: Variant = demon.get_node_or_null("KillZone")
	if kill_zone != null:
		_assert(kill_zone.enabled == false, "before the first physics frame: KillZone.enabled == false (armed at activation, spike P8)")
		_assert(kill_zone.position.is_equal_approx(Vector3.ZERO), "KillZone.position == ZERO, got %s (the kill position is the feet: stock death throw, D7)" % kill_zone.position)
		var kill_shape: Variant = kill_zone.get_node_or_null("CollisionShape3D")
		var shape_y: float = kill_shape.position.y if kill_shape != null else NAN
		_assert(is_equal_approx(shape_y, 1.0), "KillZone/CollisionShape3D.position.y == 1.0, got %.4f" % shape_y)
	_assert(is_zero_approx(demon._motor_component.speed), "before the first physics frame: _motor_component.speed == 0, got %.3f" % demon._motor_component.speed)
	_assert(demon._ai_component != null and demon._ai_component.chase_player == false, "_ai_component.chase_player == false (the stock AI is neutralised)")
	var animation_component: Variant = demon.get_node_or_null("EnemyAnimationComponent")
	_assert(animation_component != null and animation_component.animation_player == null and animation_component.animated_sprite == null,
		"EnemyAnimationComponent bound neither an AnimationPlayer nor an AnimatedSprite3D")

	var watch: Variant = _watch(demon)
	var active: bool = await _await_active(demon)
	if active:
		_assert(kill_zone != null and kill_zone.enabled == true, "after activation: KillZone.enabled == true")
		_assert(_name(demon) == "Wandering", "after activation the state name is 'Wandering', got '%s'" % _name(demon))
		_assert(watch.first_name() == "Wandering", "the first state name is 'Wandering' (log: %s)" % watch.names_text())
		await _check_model(demon, 0.714286, 0.0771, 1.414, 0.137)
	await _end()


func _t01_model_scale_variant() -> void:
	_begin("T01 scene contract, model_scale = 1.0")
	var full_size := func(node: Variant) -> void:
		node.model_scale = 1.0
	var demon: Variant = _spawn(Vector3.ZERO, 0.0, "", true, full_size)
	if demon == null:
		await _end()
		return
	if await _await_active(demon):
		await _check_model(demon, 1.0, 0.108, 1.98, 0.192)
	await _end()


func _check_model(demon: Variant, model_scale: float, model_y: float, eye_y: float, foot_height: float) -> void:
	var model := demon.get_node_or_null("Graphics/Model") as Node3D
	_assert(model != null, "Graphics/Model is a Node3D")
	if model == null:
		return
	_assert(absf(model.scale.x - model_scale) <= 0.001, "Graphics/Model.scale.x = %.6f (expected %.6f +- 0.001)" % [model.scale.x, model_scale])
	_assert(model.basis.get_rotation_quaternion().is_equal_approx(Quaternion.IDENTITY), "Graphics/Model basis has no rotation (the glb already faces -Z)")
	_assert(absf(model.position.y - model_y) <= 0.001, "Graphics/Model.position.y = %.4f (expected %.4f +- 0.001: the sole offset)" % [model.position.y, model_y])
	var root_scale: Vector3 = demon.scale
	_assert(root_scale.is_equal_approx(Vector3.ONE), "root scale == ONE, got %s" % root_scale)
	var eyes := demon.get_node_or_null("EyesDetection3D") as Node3D
	var eyes_y: float = eyes.position.y if eyes != null else NAN
	_assert(absf(eyes_y - eye_y) <= 0.01, "EyesDetection3D.position.y = %.4f (expected %.3f +- 0.01)" % [eyes_y, eye_y])

	var players: Array = model.find_children("*", "AnimationPlayer", true, false)
	_assert(not players.is_empty(), "the model has an AnimationPlayer")
	if not players.is_empty():
		var player := players[0] as AnimationPlayer
		for clip: String in ["idle", "walk", "run"]:
			var looping := player.has_animation(clip) and player.get_animation(clip).loop_mode == Animation.LOOP_LINEAR
			_assert(looping, "clip '%s' exists with loop_mode == Animation.LOOP_LINEAR" % clip)
	var tree := demon.get_node_or_null("Graphics/AnimationTree") as AnimationTree
	_assert(tree != null and tree.active, "Graphics/AnimationTree is active")

	var material: Variant = demon.body_material
	_assert(material is BaseMaterial3D and is_zero_approx((material as BaseMaterial3D).metallic), "body_material is set and has metallic == 0")
	var meshes: Array = model.find_children("*", "MeshInstance3D", true, false)
	_assert(not meshes.is_empty(), "the model has MeshInstance3D nodes (%d)" % meshes.size())
	for found: Variant in meshes:
		var mesh := found as MeshInstance3D
		_assert(mesh.material_override == material, "mesh '%s' has material_override == demon.body_material" % mesh.name)

	var skeletons: Array = model.find_children("*", "Skeleton3D", true, false)
	_assert(not skeletons.is_empty(), "the model has a Skeleton3D")
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	for bone: String in ["Neck", "LeftFoot", "RightFoot"]:
		_assert(skeleton.find_bone(bone) >= 0, "the skeleton has the bone '%s'" % bone)

	# Soles on the floor, measured on the skeleton (idle pose, tree active for at least 2 process frames).
	# A mesh AABB must not be used: the meshes hang under the glb node kim_004r_0000_00, whose -0.1 m
	# translation is cancelled by the skin but not by MeshInstance3D.get_aabb(), so
	# mesh.global_transform * mesh.get_aabb() reads -0.0715 m on a correctly placed model.
	for i in 3:
		await get_tree().process_frame
	_unstepped = 0.0
	for bone: String in ["LeftFoot", "RightFoot"]:
		var index := skeleton.find_bone(bone)
		if index < 0:
			continue
		var bone_y: float = (skeleton.global_transform * skeleton.get_bone_global_pose(index)).origin.y
		var height: float = bone_y - float(demon.global_position.y)
		_assert(absf(height - foot_height) <= 0.02, "%s bone is %.4f m above the demon origin (expected %.3f +- 0.02: soles on the floor)" % [bone, height, foot_height])


# --- T02 ---------------------------------------------------------------------------------------

func _t02_spawn_order() -> void:
	_begin("T02 spawn order")
	Services.enemy_context.set_players_node(null)          # registered 5 physics frames late, on purpose
	var a1: Variant = Arena.add_point(_arena, "A1", Vector3(-20.0, 0.0, -20.0), 0.0, 2.0, 0.0, "A")
	var b1: Variant = Arena.add_point(_arena, "B1", Vector3(2.0, 0.0, 2.0), 0.0, 2.0, 0.0, "B")
	# The stub stands ON the spawn origin and the demon is added there, unplaced: one physics frame passes
	# with the two overlapping before the placement (a body that is added and then moved still counts at its
	# old place for one physics step, spike P8). Moved in the frame they are added, no physics step would
	# ever see them overlap and the kill assertion below could not fail.
	var stub: Variant = Arena.add_stub(_arena, Vector3.ZERO)
	var demon: Variant = _spawn(Vector3.ZERO, 0.0, "", false)      # add_child at the origin ...
	if demon == null or a1 == null or b1 == null:
		_assert(false, "set-up: demon and both points exist")
		await _end()
		return
	var watch: Variant = _watch(demon)
	var added_at := _sim
	await _step()                                                  # ... one physics frame there ...
	_assert(demon.active == false, "after its first physics tick, still at the spawn origin, the demon is not active (the boot gate waits 2 ticks and for the floor)")
	demon.global_position = Vector3(-18.0, 0.05, -18.0)            # ... and only then the placement
	demon.current_room = "A"
	var seen := {"active_at": -1.0, "first_destination": Vector3.INF, "went_to_b1": false}
	var b1_position: Vector3 = b1.global_position
	var recorder := func() -> void:
		var destination: Vector3 = demon._travel.destination
		if demon.active and seen["active_at"] < 0.0:
			seen["active_at"] = watch.tick_sim
			seen["first_destination"] = destination
		if destination.distance_to(b1_position) < 0.01:
			seen["went_to_b1"] = true
	_hooks.append(recorder)

	await _run(_ticks(4))                                          # 5 physics frames after the add_child
	Services.enemy_context.set_players_node(_arena["players"])
	var registered_at := _sim
	var has_target := func() -> bool:
		return demon.target == stub
	var resolved: bool = await _until(has_target, 0.6)
	_assert(resolved, "demon.target == stub within 0.6 s of the Players registration (%.3f s waited, target=%s)" % [_sim - registered_at, demon.target])

	await _run(maxf(0.0, added_at + 1.0 - _sim))
	_assert(stub.kill_calls == 0, "1 s after the spawn stub.kill_calls == 0, got %d (no spawn-origin kill although the stub stood on the origin)" % stub.kill_calls)
	await _run(maxf(0.0, added_at + 4.0 - _sim))
	_hooks.clear()

	var active_after: float = seen["active_at"] - added_at
	_assert(seen["active_at"] >= 0.0 and active_after <= 2.5 + TIME_EPS, "active %.3f s after add_child (expected within 2.5)" % active_after)
	_assert(demon.home_room == "A", "home_room == 'A', got '%s' (captured after the placement)" % demon.home_room)
	var first: Vector3 = seen["first_destination"]
	_assert(first.distance_to(a1.global_position) < 0.01, "the first _travel.destination is A1 %s, got %s" % [a1.global_position, first])
	_assert(not seen["went_to_b1"], "_travel.destination was never B1 (a point of room 'B') in 4 s")
	await _end()


func _t02b_spawner_target() -> void:
	_begin("T02b a target supplied right after add_child (spawner idiom)")
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, 20.0))
	var demon: Variant = _spawn(Vector3(0.0, 0.05, 0.0), 0.0, "", false)
	if demon == null:
		await _end()
		return
	demon.current_target = stub
	var watch: Variant = _watch(demon)
	await _await_active(demon, 2.5)
	_assert(watch.first_name() == "Chase.FORCE_CHASE", "the first state name is 'Chase.FORCE_CHASE', got '%s' (log: %s)" % [watch.first_name(), watch.names_text()])
	await _end()


func _t02c_sleep_before_activation() -> void:
	_begin("T02c sleep() right after add_child")
	var demon: Variant = _spawn(Vector3(0.0, 0.05, 0.0), 0.0, "", false)
	if demon == null:
		await _end()
		return
	demon.sleep()
	var watch: Variant = _watch(demon)
	await _await_active(demon, 2.5)
	_assert(watch.first_name() == "Sleeping", "the first state name is 'Sleeping', got '%s' (log: %s)" % [watch.first_name(), watch.names_text()])
	_assert(_name(demon) == "Sleeping" and demon.visible == false, "at activation the demon is STILL asleep and hidden: name '%s', visible %s (log: %s)" % [_name(demon), demon.visible, watch.names_text()])
	await _end()


# --- T03 - T05 ---------------------------------------------------------------------------------

## T03 set-up: idle demon at (0, 0, 26) facing -Z, stub 10 m ahead at (0, 0, 16).
func _stare_setup(stub_yaw: float, standing: bool) -> Dictionary:
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, 16.0), stub_yaw)
	if not standing:
		stub.set_stance(false)
	var demon: Variant = _spawn(Vector3(0.0, 0.0, 26.0))
	var watch: Variant = _watch(demon) if demon != null else null
	return {"demon": demon, "stub": stub, "watch": watch}


func _t03_stare_and_ramp() -> void:
	_begin("T03 Wandering -> Chase.LOOK -> Chase.CHASE, ramp visible")
	_subscribe(GameEventTypes.ENEMY_TARGET_ACQUIRED)
	var setup := _stare_setup(PI, true)                  # the stub faces the demon
	var demon: Variant = setup["demon"]
	var stub: Variant = setup["stub"]
	var watch: Variant = setup["watch"]
	if demon == null:
		await _end()
		return

	var is_look := func() -> bool:
		return _name(demon) == "Chase.LOOK"
	var seen_look: bool = await _until(is_look, 4.0)
	var t_wander: float = watch.time_of("Wandering")
	var t_look: float = watch.time_of("Chase.LOOK")
	_assert(watch.first_name() == "Wandering", "the first state name is 'Wandering' (log: %s)" % watch.names_text())
	_assert(seen_look and _in_window(t_look - t_wander, 0.9, 1.3), "Chase.LOOK %.3f s after the Wandering init (expected 0.9-1.3: the 1 s sense cadence)" % (t_look - t_wander))
	_assert(watch.se_count(SE_FIND) == 1, "se_requested(FIND) once, got %d" % watch.se_count(SE_FIND))
	var acquired := _bus_from(GameEventTypes.ENEMY_TARGET_ACQUIRED, demon)
	_assert(acquired == 1, "one ENEMY_TARGET_ACQUIRED bus event with source == demon, got %d" % acquired)
	if not seen_look:
		await _end()
		return

	var look_position: Vector3 = demon.global_position
	var stare := {"max_speed": 0.0}
	var stare_probe := func() -> void:
		if _name(demon) == "Chase.LOOK":
			stare["max_speed"] = maxf(stare["max_speed"], demon.desired_speed)
	_hooks.append(stare_probe)
	var is_chase := func() -> bool:
		return _name(demon) == "Chase.CHASE"
	var seen_chase: bool = await _until(is_chase, 3.0)
	_hooks.clear()
	var t_chase: float = watch.time_of("Chase.CHASE")
	_assert(seen_chase and _in_window(t_chase - t_look, 1.9, 2.2), "Chase.CHASE %.3f s after LOOK (expected 1.9-2.2: stare rate 1.5 for a standing prey)" % (t_chase - t_look))
	var stare_drift: float = Arena.planar(demon.global_position, look_position)
	_assert(stare_drift < 0.1, "displacement during the stare %.3f m (expected < 0.1)" % stare_drift)
	_assert(is_zero_approx(stare["max_speed"]), "desired_speed == 0 during the stare, max %.3f" % stare["max_speed"])
	_assert(watch.se_count(SE_LOOK) == 1, "se_requested(LOOK) once at the stare expiry, got %d" % watch.se_count(SE_LOOK))
	if not seen_chase:
		await _end()
		return

	var entry_speed: float = demon.desired_speed
	var entry_motor: float = demon._motor_component.speed
	_assert(entry_speed >= 1.0 - 0.0001 and entry_speed <= 1.05, "desired_speed at CHASE entry %.4f SRC (expected 1.0-1.05)" % entry_speed)
	_assert(entry_motor >= 1.39 and entry_motor <= 1.48, "_motor_component.speed at CHASE entry %.4f m/s (expected 1.39-1.48)" % entry_motor)

	# From CHASE entry on the stub stays 10 m ahead, still facing the demon, zero velocity.
	var ramp := {"target_at": -1.0, "cap_at": -1.0, "cap_motor": 0.0}
	var keep_ahead := func() -> void:
		stub.global_position = demon.global_position + Vector3(0.0, 0.0, -10.0)
		if ramp["target_at"] < 0.0 and demon.current_target == stub:
			ramp["target_at"] = watch.tick_sim
		if ramp["cap_at"] < 0.0 and is_equal_approx(demon.desired_speed, 5.0):
			ramp["cap_at"] = watch.tick_sim
			ramp["cap_motor"] = demon._motor_component.speed
	keep_ahead.call()
	_hooks.append(keep_ahead)
	var windows: Array[float] = []
	var speed_at_2 := 0.0
	var speed_at_5 := 0.0
	var path_before: float = watch.path_length
	for i in 9:
		await _run(1.0)
		var path_now: float = watch.path_length
		windows.append(path_now - path_before)
		path_before = path_now
		if i == 1:
			speed_at_2 = demon.desired_speed
		elif i == 4:
			speed_at_5 = demon.desired_speed
	_hooks.clear()
	print("  metres per 1 s window after CHASE entry: ", windows)

	var target_after: float = ramp["target_at"] - t_chase
	_assert(ramp["target_at"] >= 0.0 and target_after <= 0.1 + TIME_EPS, "current_target == stub %.3f s after CHASE entry (expected within 0.1: the first search tick)" % target_after)
	_assert(windows[0] >= 1.2 and windows[0] <= 2.2, "ramp window 1: %.3f m (expected 1.2-2.2, analytic 1.75)" % windows[0])
	_assert(windows[3] >= 3.3 and windows[3] <= 4.4, "ramp window 4: %.3f m (expected 3.3-4.4, analytic 3.85)" % windows[3])
	for i in range(1, 8):
		_assert(windows[i] > windows[i - 1], "ramp window %d (%.3f m) is longer than window %d (%.3f m)" % [i + 1, windows[i], i, windows[i - 1]])
	_assert(windows[8] >= 6.5 and windows[8] <= 7.4, "ramp window 9: %.3f m (expected 6.5-7.4: the 7.0 m/s cap)" % windows[8])
	_assert(absf(speed_at_2 - 2.0) <= 0.06, "desired_speed 2 s after CHASE entry %.3f SRC (expected 2.0 +- 0.06)" % speed_at_2)
	_assert(absf(speed_at_5 - 3.5) <= 0.06, "desired_speed 5 s after CHASE entry %.3f SRC (expected 3.5 +- 0.06)" % speed_at_5)
	var cap_after: float = ramp["cap_at"] - t_chase
	_assert(ramp["cap_at"] >= 0.0 and _in_window(cap_after, 7.8, 8.3), "desired_speed reached 5.0 %.3f s after CHASE entry (expected 7.8-8.3)" % cap_after)
	_assert(absf(ramp["cap_motor"] - 7.0) <= 0.05, "_motor_component.speed at the cap %.3f m/s (expected 7.0 +- 0.05)" % ramp["cap_motor"])
	var sting_offset: float = absf(watch.se_time(SE_CHASE) - ramp["cap_at"])
	_assert(watch.se_count(SE_CHASE) == 1 and sting_offset <= 0.035, "se_requested(CHASE) exactly once (%d), at the moment the cap is reached (%.3f s apart)" % [watch.se_count(SE_CHASE), sting_offset])
	_assert(stub.kill_calls == 0, "stub.kill_calls == 0 while it stays 10 m ahead, got %d" % stub.kill_calls)
	await _end()


## "Park where you stand" (SRC aooni_chase_state.gd:84-86): T03 starts every stare from a standing demon.
## Here the demon is walking a leg when it sees the prey, and the prey then steps out of the 75 deg face
## cone, so the stare goes through LOOK_ROTATE, which runs at desired_speed 1 ("leans into the turn").
func _t03b_stare_parks_a_walking_demon() -> void:
	_begin("T03b the stare parks a demon that was walking")
	var p: Variant = Arena.add_point(_arena, "P", Vector3(0.0, 0.0, 0.0), 0.0, 2.0)
	var q: Variant = Arena.add_point(_arena, "Q", Vector3(0.0, 0.0, -20.0), 0.0, 2.0)
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, 40.0))    # behind the walking demon, silent
	var demon: Variant = _spawn(Vector3(0.0, 0.0, 3.0))
	if demon == null or p == null or q == null:
		_assert(false, "set-up: demon and both points exist")
		await _end()
		return
	Arena.link(p, [q])
	Arena.link(q, [p])
	var watch: Variant = _watch(demon)
	var is_mid_leg := func() -> bool:
		return _point_source(demon) == p and _wander_state(demon) == WANDER_MOVE and demon.global_position.z <= -4.0
	var on_leg: bool = await _until(is_mid_leg, 15.0)
	_assert(on_leg and demon._motor_component.speed > 2.0, "set-up: walking the leg P -> Q at %.2f m/s (log: %s)" % [demon._motor_component.speed, watch.names_text()])
	if not on_leg:
		await _end()
		return
	# 30 deg to the right, 12 m away: still inside the 75 deg cone after another second of walking.
	var seen_at: Vector3 = demon.global_position + Arena.turned_right(demon.facing_forward(), 30.0) * 12.0
	seen_at.y = 0.0
	stub.global_position = seen_at
	var is_look := func() -> bool:
		return _name(demon) == "Chase.LOOK"
	var looked: bool = await _until(is_look, 1.4)
	_assert(looked, "set-up: the stub 30 deg to the right gives Chase.LOOK within 1.4 s (log: %s)" % watch.names_text())
	if not looked:
		await _end()
		return
	var look_position: Vector3 = demon.global_position
	var parked: Vector3 = demon._travel.destination
	_assert(Arena.planar(parked, look_position) < 0.1, "on the first Chase.LOOK sample _travel.destination %s is where the demon stands %s (not Q)" % [parked, look_position])
	var turn_to: Vector3 = look_position + Arena.turned_right(demon.facing_forward(), 110.0) * 8.0
	turn_to.y = 0.0
	stub.global_position = turn_to                       # 110 deg off the facing: the body has to turn
	var stare := {"max_drift": 0.0, "rotate_ticks": 0, "rotate_speed": 0.0}
	var stare_probe := func() -> void:
		var state_name := _name(demon)
		if state_name == "Chase.LOOK" or state_name == "Chase.LOOK_ROTATE":
			stare["max_drift"] = maxf(stare["max_drift"], Arena.planar(demon.global_position, look_position))
		if state_name == "Chase.LOOK_ROTATE":
			stare["rotate_ticks"] += 1
			stare["rotate_speed"] = maxf(stare["rotate_speed"], demon.desired_speed)
	_hooks.append(stare_probe)
	var is_chase := func() -> bool:
		return _name(demon) == "Chase.CHASE"
	var charged: bool = await _until(is_chase, 3.0)
	_hooks.clear()
	_assert(charged, "set-up: the stare ends in Chase.CHASE (log: %s)" % watch.names_text())
	_assert(stare["rotate_ticks"] >= 30 and is_equal_approx(stare["rotate_speed"], 1.0), "set-up: Chase.LOOK_ROTATE ran for %d ticks at desired_speed %.2f (expected >= 30 ticks at 1.0: a real turn)" % [stare["rotate_ticks"], stare["rotate_speed"]])
	_assert(stare["max_drift"] < 0.1, "displacement through LOOK and LOOK_ROTATE %.3f m (expected < 0.1: parked where it stood)" % stare["max_drift"])
	await _end()


func _t04_behind_doubling() -> void:
	_begin("T04 behind-doubling")
	var setup := _stare_setup(0.0, true)                 # the stub faces away from the demon
	var demon: Variant = setup["demon"]
	var stub: Variant = setup["stub"]
	var watch: Variant = setup["watch"]
	if demon == null:
		await _end()
		return
	var is_chase := func() -> bool:
		return _name(demon) == "Chase.CHASE"
	var seen_chase: bool = await _until(is_chase, 6.0)
	_assert(seen_chase, "the demon reached Chase.CHASE (log: %s)" % watch.names_text())
	if seen_chase:
		var keep_ahead := func() -> void:
			stub.global_position = demon.global_position + Vector3(0.0, 0.0, -10.0)
		keep_ahead.call()
		_hooks.append(keep_ahead)
		var entered_at := _sim
		var at_cap := func() -> bool:
			return is_equal_approx(demon.desired_speed, 5.0)
		var doubled: bool = await _until(at_cap, 1.4)
		_hooks.clear()
		_assert(doubled, "desired_speed == 5.0 within 1.4 s of CHASE entry with the prey's back turned (%.3f SRC after %.3f s)" % [demon.desired_speed, _sim - entered_at])
	await _end()


func _t05_crouched_stare() -> void:
	_begin("T05 crouched stare")
	var setup := _stare_setup(PI, false)
	var demon: Variant = setup["demon"]
	var watch: Variant = setup["watch"]
	if demon == null:
		await _end()
		return
	var is_chase := func() -> bool:
		return _name(demon) == "Chase.CHASE"
	var seen_chase: bool = await _until(is_chase, 7.0)
	var stare_time: float = watch.time_of("Chase.CHASE") - watch.time_of("Chase.LOOK")
	_assert(seen_chase and watch.index_of("Chase.LOOK") >= 0 and _in_window(stare_time, 2.9, 3.3), "LOOK -> CHASE takes %.3f s for a crouched prey (expected 2.9-3.3; log: %s)" % [stare_time, watch.names_text()])
	await _end()


## The other outcome of the stare (SRC aooni_chase_state.gd:159-161, DST C4): the prey is out of sight when
## the stare expires. T06's wall; the stub steps behind it 1.0 s into the 2.0 s stare.
func _t05b_stare_broken() -> void:
	_begin("T05b the stare is broken: prey out of sight when it expires")
	Arena.add_wall(_arena, Vector3(6.0, 1.5, 0.0), Vector3(0.4, 3.0, 16.0))
	var stub_at := Vector3(-2.0, 0.0, 0.0)
	var demon_at := Vector3(0.0, 0.0, 10.0)
	var hidden_at := Vector3(10.0, 0.0, 0.0)
	var stub: Variant = Arena.add_stub(_arena, stub_at, Arena.yaw_towards(stub_at, demon_at))
	var demon: Variant = _spawn(demon_at)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	var is_look := func() -> bool:
		return _name(demon) == "Chase.LOOK"
	var looked: bool = await _until(is_look, 4.0)
	_assert(looked, "set-up: the demon reached Chase.LOOK (log: %s)" % watch.names_text())
	if not looked:
		await _end()
		return
	await _run(1.0)
	stub.global_position = hidden_at                     # behind the wall
	var mark: int = watch.names.size()
	var is_wandering := func() -> bool:
		return watch.index_of("Wandering", mark) >= 0
	var broke: bool = await _until(is_wandering, 2.0)
	var stare_time: float = watch.time_of("Wandering", mark) - watch.time_of("Chase.LOOK")
	_assert(broke and _in_window(stare_time, 1.9, 2.2), "Wandering %.3f s after LOOK began (expected 1.9-2.2: the stare runs its full time, then gives up; log: %s)" % [stare_time, watch.names_text()])
	_assert(watch.count_prefix("Chase.CHASE") == 0, "no Chase.CHASE name: a prey that is out of sight at the expiry is not charged (log: %s)" % watch.names_text())
	_assert(watch.se_count(SE_LOOK) == 1 and watch.se_count(SE_CHASE) == 0, "se_requested(LOOK) once at the expiry (%d) and never CHASE (%d)" % [watch.se_count(SE_LOOK), watch.se_count(SE_CHASE)])
	_assert(demon.is_chase == false and watch.chase_logged(false) and not watch.se_stops.is_empty(), "is_chase == false (%s), chase_changed(false) and se_stopped logged (%d)" % [demon.is_chase, watch.se_stops.size()])
	_assert(_wander_state(demon) == WANDER_MOVE and is_equal_approx(demon.desired_speed, 2.0), "the demon walks: current_state._state is MOVE (%d) at desired_speed 2.0 (%.2f)" % [_wander_state(demon), demon.desired_speed])
	var destination: Vector3 = demon._travel.destination
	_assert(destination.distance_to(hidden_at) < 0.01, "_travel.destination is where the prey stands, (10, 0, 0), got %s" % destination)
	if broke:
		var transient: Variant = demon.current_state._next_point
		var is_transient: bool = transient != null and transient.source_point == null
		var dwell: float = transient.thinking_time if transient != null else NAN
		_assert(is_transient and is_equal_approx(dwell, 15.0), "it goes to a transient point (%s) with a 15 s dwell, got %.2f" % [is_transient, dwell])
	await _end()


# --- T06, T07 ----------------------------------------------------------------------------------

## T06 set-up, up to the moment the stub is moved behind the wall. Empty when it did not get there.
func _lose_player() -> Dictionary:
	Arena.add_wall(_arena, Vector3(6.0, 1.5, 0.0), Vector3(0.4, 3.0, 16.0))
	var stub_at := Vector3(-2.0, 0.0, 0.0)
	var demon_at := Vector3(0.0, 0.0, 10.0)
	var stub: Variant = Arena.add_stub(_arena, stub_at, Arena.yaw_towards(stub_at, demon_at))
	var demon: Variant = _spawn(demon_at)
	if demon == null:
		return {}
	var watch: Variant = _watch(demon)
	var is_pursuing := func() -> bool:
		return _name(demon) == "Chase.CHASE" and demon.current_target == stub
	var pursuing: bool = await _until(is_pursuing, 6.0)
	_assert(pursuing, "set-up: Chase.CHASE with current_target == stub (log: %s)" % watch.names_text())
	if not pursuing:
		return {}
	stub.global_position = Vector3(10.0, 0.0, 0.0)       # behind the wall
	stub.velocity = Vector3.ZERO
	return {"demon": demon, "stub": stub, "watch": watch, "last_seen": stub_at}


func _t06_t07_lose_player_and_empty_graph() -> void:
	_begin("T06 lose the player -> LOST -> Wandering")
	var setup: Dictionary = await _lose_player()
	if setup.is_empty():
		await _end()
		return
	var demon: Variant = setup["demon"]
	var stub: Variant = setup["stub"]
	var watch: Variant = setup["watch"]
	var last_seen: Vector3 = setup["last_seen"]

	var is_blind := func() -> bool:
		return demon.current_target == null and demon.waypoints.size() == 1 \
			and is_equal_approx(demon.desired_speed, 5.0) and _name(demon) == "Chase.CHASE"
	var blind: bool = await _until(is_blind, 0.6)
	_assert(blind, "within 0.6 s of losing sight: current_target == null (%s), waypoints.size() == 1 (%d), desired_speed == 5.0 (%.2f), still Chase.CHASE (%s)" % [
		demon.current_target, demon.waypoints.size(), demon.desired_speed, _name(demon)])

	var is_lost := func() -> bool:
		return _name(demon) == "Chase.LOST"
	var lost: bool = await _until(is_lost, 6.0)
	_assert(lost, "the demon reached Chase.LOST (log: %s)" % watch.names_text())
	if not lost:
		await _end()
		return
	var lost_position: Vector3 = demon.global_position
	var end_distance: float = Arena.planar(lost_position, last_seen)
	_assert(end_distance <= 0.7, "the demon ends %.3f m from the last-seen position (-2, 0, 0) (expected <= 0.7)" % end_distance)

	# The probe runs from the sample AFTER the one that showed LOST first: the tick that switches the sub-state
	# still carries the commit speed (SRC :176-178), _update_lost() zeroes it from the next tick on.
	var drift := {"max": 0.0, "max_speed": 0.0, "samples": 0}
	var drift_probe := func() -> void:
		if _name(demon) == "Chase.LOST":
			drift["max"] = maxf(drift["max"], Arena.planar(demon.global_position, lost_position))
			drift["max_speed"] = maxf(drift["max_speed"], demon.desired_speed)
			drift["samples"] += 1
	_hooks.append(drift_probe)
	var lost_index: int = watch.index_of("Chase.LOST")
	var is_back := func() -> bool:
		return watch.index_of("Wandering", lost_index) >= 0
	var gave_up: bool = await _until(is_back, 4.5)
	_hooks.clear()
	var t_lost: float = watch.time_of("Chase.LOST")
	var t_back: float = watch.time_of("Wandering", lost_index)
	_assert(gave_up and _in_window(t_back - t_lost, 3.0, 3.6), "LOST lasts %.3f s (expected 3.0-3.6)" % (t_back - t_lost))
	_assert(drift["max"] < 0.2, "displacement while LOST %.3f m (expected < 0.2)" % drift["max"])
	_assert(drift["samples"] > 150 and is_zero_approx(drift["max_speed"]), "desired_speed == 0 on each of the %d LOST samples after the first, max %.3f (it does not run on the spot)" % [drift["samples"], drift["max_speed"]])
	var chase_index: int = watch.index_of("Chase.CHASE")
	_assert(chase_index >= 0 and lost_index > chase_index and watch.index_of("Wandering", lost_index) > lost_index,
		"the name sequence contains Chase.CHASE, Chase.LOST, Wandering in that order (log: %s)" % watch.names_text())
	_assert(demon.is_chase == false, "is_chase == false after the give-up")
	_assert(not watch.se_stops.is_empty(), "se_stopped was logged (%d)" % watch.se_stops.size())
	_assert(watch.chase_logged(false), "chase_changed(false) was logged")
	if not gave_up:
		await _end()
		return

	_case = "T07 empty-graph safety (V9)"
	print("\n--- %s ---" % _case)
	await _run(maxf(0.0, t_back + 11.5 - _sim))          # 1 s idling + 9 s dwell + slack
	_assert(_wander_state(demon) == WANDER_NONE, "11.5 s after the Wandering init current_state._state is NONE, got %d ('%s')" % [_wander_state(demon), _name(demon)])
	_assert(is_zero_approx(demon.desired_speed), "desired_speed == 0 while standing guard, got %.3f" % demon.desired_speed)
	_assert(is_instance_valid(demon) and demon.is_physics_processing(), "the demon is valid and physics-processing")
	var reveal: Vector3 = demon.global_position + demon.facing_forward() * 8.0
	reveal.y = 0.0
	stub.global_position = reveal                        # 8 m in front of the demon's facing
	var is_look := func() -> bool:
		return _name(demon) == "Chase.LOOK"
	var revealed_at := _sim
	var noticed: bool = await _until(is_look, 1.4)
	_assert(noticed, "the revealed stub produces Chase.LOOK within 1.4 s (%.3f s waited, name '%s'): the update loop is alive" % [_sim - revealed_at, _name(demon)])
	await _end()


## SRC aooni_chase_state.gd:187-188: a blind chase that HEARS the prey commits to where the prey is now,
## not to where it was last seen (T06 is the silent control: there the demon ends at the last-seen place).
func _t06b_blind_chase_hears() -> void:
	_begin("T06b blind chase: a loud hidden prey redirects the commit")
	var setup: Dictionary = await _lose_player()
	if setup.is_empty():
		await _end()
		return
	var demon: Variant = setup["demon"]
	var stub: Variant = setup["stub"]
	var last_seen: Vector3 = setup["last_seen"]
	var hidden_at := Vector3(8.0, 0.0, 4.0)              # behind the wall, 10 m from the demon
	stub.global_position = hidden_at
	stub.velocity = Vector3(8.0, 0.0, 0.0)               # sprint-loud (range 12 m), never moved
	var range_now: float = demon.global_position.distance_to(hidden_at)
	var is_redirected := func() -> bool:
		var destination: Vector3 = demon._travel.destination
		return demon.current_target == null and demon.waypoints.size() == 1 and destination.distance_to(hidden_at) < 0.1
	var redirected: bool = await _until(is_redirected, 0.6)
	var destination_now: Vector3 = demon._travel.destination
	_assert(range_now < 11.5, "set-up: the hidden stub is %.2f m from the demon (inside the 12 m sprint range)" % range_now)
	_assert(redirected and _name(demon) == "Chase.CHASE", "within 0.6 s: blind (current_target %s, waypoints %d), still '%s', and _travel.destination is the heard position (8, 0, 4), got %s (last seen %s)" % [
		demon.current_target, demon.waypoints.size(), _name(demon), destination_now, last_seen])
	_assert(is_equal_approx(demon.desired_speed, 5.0), "desired_speed == 5.0 on the blind commit, got %.2f" % demon.desired_speed)
	await _end()


# --- T08 ---------------------------------------------------------------------------------------

func _t08_patrol_traversal() -> void:
	_begin("T08 patrol traversal with a dwell")
	var a_yaw := deg_to_rad(90.0)
	var a: Variant = Arena.add_point(_arena, "A", Vector3(0.0, 0.0, 0.0), a_yaw, 2.0, 1.5)
	var b: Variant = Arena.add_point(_arena, "B", Vector3(8.0, 0.0, 0.0), 0.0, 2.0, 0.0)
	var c: Variant = Arena.add_point(_arena, "C", Vector3(8.0, 0.0, 8.0), 0.0, 2.0, 0.0)
	# The demon starts FACING A (yaw 180 deg = +Z), so it arrives facing +Z and the turn to A's yaw is 90 deg:
	# 1.0 s at 90 deg/s, inside the 1.5 s dwell. The dwell clock runs while the demon turns and its expiry
	# ends the turn (SRC aooni_wandering_state.gd:167, :179-192, :216-224, ported as is), so a dwell of
	# 1.5 s can turn at most 135 deg. With the harness default (yaw 0, back to A) the U-turn at 120 deg/s
	# is not finished on the 1 s leg: the demon arrives at -118 deg, 152 deg off A's yaw, and leaves
	# 17 deg short. The plan's T08 row gives the demon a position only; the yaw is this set-up's choice.
	var demon: Variant = _spawn(Vector3(0.0, 0.0, -3.0), PI)
	if demon == null or a == null or b == null or c == null:
		_assert(false, "set-up: demon and the three points exist")
		await _end()
		return
	# The ring is linked AGAINST nearest-point order: A -> C -> B -> A. From A the nearest other point is B
	# (8 m; C is 11.3 m), so a demon that ignored next_points and fell back to the nearest point would arrive
	# A, B, C, A; only the authored edge A -> C gives A, C, B, A.
	Arena.link(a, [c])
	Arena.link(c, [b])
	Arena.link(b, [a])
	var watch: Variant = _watch(demon)

	var record := {
		"arrivals": [], "last": null,
		"a_arrive": -1.0, "a_leave": -1.0, "a_position": Vector3.ZERO, "a_drift": 0.0, "a_facing": 0.0,
		"a_facing_arrive": 0.0, "a_turned": -1.0,
		"motor_min": INF, "motor_max": -INF,
		"leg_start_time": -1.0, "leg_start_path": 0.0, "leg_end_time": -1.0, "leg_end_path": 0.0,
	}
	var recorder := func() -> void:
		var source := _point_source(demon)
		var state := _wander_state(demon)
		if source != null and source != record["last"]:
			record["last"] = source
			record["arrivals"].append([source, Arena.planar(demon.global_position, (source as Node3D).global_position), watch.tick_sim])
			if record["arrivals"].size() == 2:
				record["leg_end_time"] = watch.tick_sim
				record["leg_end_path"] = watch.path_length
		if record["arrivals"].size() != 1:
			return
		# Between the first arrival (A) and the second one (C): the dwell at A, then the leg A -> C.
		if state == WANDER_THINKING and record["a_leave"] < 0.0:
			if record["a_arrive"] < 0.0:
				record["a_arrive"] = watch.tick_sim
				record["a_position"] = demon.global_position
				record["a_facing_arrive"] = demon.facing_yaw
			record["a_drift"] = maxf(record["a_drift"], Arena.planar(demon.global_position, record["a_position"]))
			record["a_facing"] = demon.facing_yaw
			if record["a_turned"] < 0.0 and absf(angle_difference(demon.facing_yaw, a_yaw)) < deg_to_rad(1.0):
				record["a_turned"] = watch.tick_sim
		elif state == WANDER_MOVE and record["a_arrive"] >= 0.0:
			if record["a_leave"] < 0.0:
				record["a_leave"] = watch.tick_sim
				record["leg_start_time"] = watch.tick_sim
				record["leg_start_path"] = watch.path_length
			record["motor_min"] = minf(record["motor_min"], demon._motor_component.speed)
			record["motor_max"] = maxf(record["motor_max"], demon._motor_component.speed)
	_hooks.append(recorder)
	var lap_done := func() -> bool:
		return record["arrivals"].size() >= 4
	var lapped: bool = await _until(lap_done, 30.0)
	_hooks.clear()

	var arrivals: Array = record["arrivals"]
	var order: PackedStringArray = []
	for arrival: Variant in arrivals:
		order.append(String((arrival[0] as Node).name))
	_assert(lapped and arrivals.size() >= 4 and arrivals[0][0] == a and arrivals[1][0] == c and arrivals[2][0] == b and arrivals[3][0] == a,
		"arrival order of current_point.source_point is A, C, B, A within 30 s (the authored edges; nearest-point order would be A, B, C, A), got [%s]" % ", ".join(order))
	for arrival: Variant in arrivals:
		_assert(arrival[1] <= 0.65, "at the arrival at %s d(demon, point) = %.3f m (expected <= 0.65)" % [(arrival[0] as Node).name, arrival[1]])
	var dwell: float = record["a_leave"] - record["a_arrive"]
	_assert(record["a_arrive"] >= 0.0 and record["a_leave"] >= 0.0 and _in_window(dwell, 1.5, 2.0), "dwell at A %.3f s (expected 1.5-2.0)" % dwell)
	_assert(record["a_drift"] < 0.1, "displacement during the dwell at A %.3f m (expected < 0.1)" % record["a_drift"])
	var turn_at_a: float = absf(angle_difference(record["a_facing_arrive"], a_yaw))
	_assert(turn_at_a > deg_to_rad(45.0) and turn_at_a < deg_to_rad(120.0),
		"set-up: the demon arrives at A facing %.3f deg, %.3f deg off A's yaw (expected 45-120: a real turn that fits the dwell, 1.5 s x 90 deg/s = 135)" % [rad_to_deg(record["a_facing_arrive"]), rad_to_deg(turn_at_a)])
	var facing_error: float = absf(angle_difference(record["a_facing"], a_yaw))
	_assert(facing_error < deg_to_rad(1.0), "before leaving A the facing is %.3f deg from A's yaw (expected < 1)" % rad_to_deg(facing_error))
	var turn_time: float = record["a_turned"] - record["a_arrive"]
	var turn_rate: float = rad_to_deg(turn_at_a) / turn_time if turn_time > 0.0 else INF
	_assert(record["a_turned"] >= 0.0 and turn_rate >= 80.0 and turn_rate <= 100.0, "the turn at A takes %.3f s for %.2f deg: %.1f deg/s (expected 80-100: the 90 deg/s thinking turn)" % [turn_time, rad_to_deg(turn_at_a), turn_rate])
	_assert(watch.max_tilt < ROTATION_EPS, "rotation.x == 0 and rotation.z == 0 throughout, max |tilt| %.6f rad" % watch.max_tilt)
	_assert(absf(record["motor_min"] - 2.8) <= 0.01 and absf(record["motor_max"] - 2.8) <= 0.01,
		"_motor_component.speed on the leg A -> C in [%.4f, %.4f] m/s (expected 2.8 +- 0.01)" % [record["motor_min"], record["motor_max"]])
	var leg_time: float = record["leg_end_time"] - record["leg_start_time"]
	var leg_speed: float = (record["leg_end_path"] - record["leg_start_path"]) / leg_time if leg_time > 0.0 else 0.0
	_assert(leg_speed >= 2.3 and leg_speed <= 3.0, "mean speed of the leg A -> C %.3f m/s over %.3f s (expected 2.3-3.0)" % [leg_speed, leg_time])
	_assert(watch.path_length >= 20.0, "total path length %.2f m (expected >= 20)" % watch.path_length)
	await _end()


## MOVE_IDLING_TIME (SRC aooni_wandering_state.gd:35-37, :165): for 1 s after a new destination an arrival
## is not trusted. The demon stands ON its first point, so only that grace keeps it in MOVE.
func _t08b_arrival_grace() -> void:
	_begin("T08b an arrival is not trusted for 1 s after a new destination")
	var p: Variant = Arena.add_point(_arena, "P", Vector3(0.0, 0.0, 0.0), 0.0, 2.0, 5.0)
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null or p == null:
		_assert(false, "set-up: demon and the point exist")
		await _end()
		return
	var watch: Variant = _watch(demon)
	var is_thinking := func() -> bool:
		return _wander_state(demon) == WANDER_THINKING
	var thinking: bool = await _until(is_thinking, 4.0)
	var waited: float = watch.tick_sim - watch.time_of("Wandering")
	_assert(thinking and _point_source(demon) == p and _in_window(waited, 1.0, 1.1), "current_state._state becomes THINKING at P %.3f s after the Wandering init (expected 1.0-1.1, although the demon stood on the point all along)" % waited)
	_assert(watch.path_length < 0.05, "the demon did not move meanwhile (%.3f m)" % watch.path_length)
	await _end()


# --- T09 ---------------------------------------------------------------------------------------

func _t09_hearing_investigate() -> void:
	_begin("T09 hearing -> investigate")
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, 6.0))    # behind the demon
	stub.velocity = Vector3(8.0, 0.0, 0.0)                               # sprint-loud, never moved
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	var has_heard := func() -> bool:
		return watch.se_count(SE_LOOK) >= 1
	var active_at := _sim
	var heard: bool = await _until(has_heard, 1.2)
	_assert(heard, "se_requested(LOOK) within 1.2 s (%.3f s waited)" % (_sim - active_at))
	_assert(_name(demon) == "Wandering", "the name is still 'Wandering', got '%s'" % _name(demon))
	_assert(is_equal_approx(demon.desired_speed, 2.0), "desired_speed == 2.0 (INVESTIGATE_SPEED), got %.3f" % demon.desired_speed)
	var destination: Vector3 = demon._travel.destination
	_assert(destination.distance_to(stub.global_position) < 0.1, "d(_travel.destination, stub) = %.3f m (expected < 0.1)" % destination.distance_to(stub.global_position))

	stub.velocity = Vector3.ZERO
	stub.global_position = Vector3(0.0, 0.0, 60.0)
	var is_thinking := func() -> bool:
		return _wander_state(demon) == WANDER_THINKING
	var arrived: bool = await _until(is_thinking, 6.0)
	var heard_position := Vector3(0.0, 0.0, 6.0)
	var arrive_distance: float = Arena.planar(demon.global_position, heard_position)
	_assert(arrived and arrive_distance <= 0.7, "the demon arrives %.3f m from (0, 0, 6) within 6 s (expected <= 0.7) and current_state._state is THINKING (%d)" % [arrive_distance, _wander_state(demon)])
	if arrived:
		var dwell_point: Variant = demon.current_state._current_point
		var dwell_time: float = dwell_point.thinking_time if dwell_point != null else NAN
		_assert(is_equal_approx(dwell_time, 15.0), "_current_point.thinking_time == 15.0, got %.2f" % dwell_time)
		var dummy: Variant = demon.dummy_look_target
		_assert(dummy != null and is_equal_approx(dummy.position.z, -10.0), "dummy_look_target.position.z == -10 at the arrival")
		if dummy != null:
			var swept := func() -> bool:
				return is_equal_approx(dummy.position.x, 10.0)
			var sweeping: bool = await _until(swept, 3.2)
			_assert(sweeping, "dummy_look_target.position.x becomes +10 within 3.2 s (head sweep), is %.2f" % dummy.position.x)
	await _end()


## Controls for the hearing range: 1 + (limit - 1) x min(speed x 0.125, 1) metres, limit 12 standing and
## 6 crouched, nothing beyond 12 m (SRC aooni.gd:596-614). The stub stands `distance` metres behind the idle
## demon and is never moved; `heard` is what the next seconds must show.
## b and b' stand at the same 4 m and 3 m/s: only the stance separates 2.9 m (crouched) from 5.1 m (standing).
func _t09_control(label: String, distance: float, speed: float, crouched: bool, heard: bool) -> void:
	_begin("T09 control %s" % label)
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, distance))
	if crouched:
		stub.set_stance(false)
	stub.velocity = Vector3(speed, 0.0, 0.0)
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	if await _await_active(demon):
		var start: Vector3 = demon.global_position
		if heard:
			var has_heard := func() -> bool:
				return watch.se_count(SE_LOOK) >= 1
			var active_at := _sim
			var was_heard: bool = await _until(has_heard, 1.2)
			var destination: Vector3 = demon._travel.destination
			_assert(was_heard, "se_requested(LOOK) within 1.2 s (%.3f s waited)" % (_sim - active_at))
			_assert(_name(demon) == "Wandering" and destination.distance_to(stub.global_position) < 0.1, "the demon investigates: name '%s', d(_travel.destination, stub) = %.3f m (expected < 0.1)" % [_name(demon), destination.distance_to(stub.global_position)])
		else:
			await _run(3.0)
			var moved: float = Arena.planar(demon.global_position, start)
			_assert(watch.se.is_empty(), "no se_requested for 3 s, got %d" % watch.se.size())
			_assert(moved < 0.05 and _name(demon) == "Wandering", "no movement for 3 s (%.3f m), name '%s'" % [moved, _name(demon)])
	await _end()


# --- T10 ---------------------------------------------------------------------------------------

func _t10_sight_rules() -> void:
	_begin("T10 sight rules")
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, -10.0))
	var asleep := func(node: Variant) -> void:
		node.start_asleep = true
	var demon: Variant = _spawn(Vector3.ZERO, 0.0, "", true, asleep)      # asleep: nothing reacts
	if demon == null:
		await _end()
		return
	if not await _await_active(demon):
		await _end()
		return
	var has_target := func() -> bool:
		return demon.target == stub
	var targeted: bool = await _until(has_target, 1.0)
	_assert(targeted and _name(demon) == "Sleeping", "set-up: asleep ('%s') with target == stub" % _name(demon))
	var front := Vector3(0.0, 0.0, -10.0)
	var origin: Vector3 = demon.global_position
	origin.y = 0.0

	await _settle()
	_assert(demon.is_find_player(25.0, 75.0) == true, "is_find_player(25, 75) is true for a stub at (0, 0, -10)")

	var wall: Variant = Arena.add_wall(_arena, Vector3(0.0, 1.5, -5.0), Vector3(4.0, 3.0, 0.3))
	await _settle()
	_assert(demon.is_find_player(25.0, 75.0) == false, "false behind a 3 m wall (fails closed, mask 5)")
	wall.free()

	stub.global_position = Vector3(0.0, 0.0, -25.5)
	await _settle()
	_assert(demon.is_find_player(25.0, 75.0) == false, "false at (0, 0, -25.5): the distance test is a strict <")

	stub.global_position = origin + Arena.turned_right(Vector3.FORWARD, 100.0) * 10.0
	await _settle()
	_assert(demon.is_find_player(25.0, 75.0) == false, "false at 100 deg off the axis (75 deg half-angle)")

	stub.global_position = front
	stub.current_room = "B"
	demon.current_room = "A"
	await _settle()
	_assert(demon.is_find_player(25.0, 75.0) == false, "false when the stub is in room 'B' and the demon in room 'A'")
	stub.current_room = ""
	demon.current_room = ""
	await _settle()
	_assert(demon.is_find_player(25.0, 75.0) == true, "true again once both rooms are cleared")

	# Light cone: 30 m away, 85 deg off the axis.
	stub.global_position = origin + Arena.turned_right(Vector3.FORWARD, 85.0) * 30.0
	await _settle()
	_assert(demon.is_find_player(40.0, 90.0) == true, "is_find_player(40, 90) is true at 30 m / 85 deg (the light cone)")
	_assert(demon.is_find_player(25.0, 75.0) == false, "is_find_player(25, 75) is false at 30 m / 85 deg (the plain cone)")
	stub.is_flash_light_on = true
	_assert(demon.is_target_light_on() == true, "is_target_light_on() is true with is_flash_light_on = true")
	stub.is_flash_light_on = false

	# Low wall, 0.8 m: hides a crouched prey, not a standing one.
	stub.global_position = front
	wall = Arena.add_wall(_arena, Vector3(0.0, 0.4, -9.0), Vector3(4.0, 0.8, 0.3))
	await _settle()
	_assert(demon.is_find_player(25.0, 75.0) == true, "0.8 m wall: a standing stub is visible")
	stub.set_stance(false)
	await _settle()
	_assert(demon.is_find_player(25.0, 75.0) == false, "0.8 m wall: a crouched stub is hidden")
	wall.free()
	stub.set_stance(true)

	# Lower wall, 0.45 m: lower than the crouched stub (0.55 m). The crouched aim is the centre of the
	# crouch capsule (0.275 m), so the ray passes the wall at 0.41 m and is blocked (m6); an aim at the
	# top of the collider would pass it at 0.60 m and see the stub.
	wall = Arena.add_wall(_arena, Vector3(0.0, 0.225, -9.0), Vector3(4.0, 0.45, 0.3))
	await _settle()
	_assert(demon.is_find_player(25.0, 75.0) == true, "0.45 m wall: a standing stub is visible")
	stub.set_stance(false)
	await _settle()
	_assert(demon.is_find_player(25.0, 75.0) == false, "0.45 m wall: a crouched stub is still hidden (the aim is the crouch-collider centre)")
	wall.free()
	stub.set_stance(true)

	# Last, because a dead -> alive edge starts the revive grace.
	await _settle()
	_assert(demon.is_find_player(25.0, 75.0) == true, "visible again without walls, standing")
	stub.dead = true
	await _settle()
	_assert(demon.is_find_player(25.0, 75.0) == false, "false when stub.dead")
	await _end()


## The patrol cone as the WANDERING STATE applies it (T10 hands literals to is_find_player): 25 m / 75 deg,
## and 40 m / 90 deg while the prey's light is on. The silent stub stands at `hidden_at` for 3 s (three sense
## ticks) unnoticed; then it is moved to `shown_at` (or its light goes on) and must be noticed.
func _t10b_wander_cone(label: String, hidden_at: Vector3, shown_at: Vector3, with_light: bool) -> void:
	_begin("T10b wander cone, %s" % label)
	var stub: Variant = Arena.add_stub(_arena, hidden_at)
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	if await _await_active(demon):
		await _run(3.0)
		_assert(watch.count_prefix("Chase") == 0 and watch.se.is_empty(), "for 3 s the stub at %s causes no 'Chase' name and no SE (log: %s)" % [hidden_at, watch.names_text()])
		stub.global_position = shown_at
		if with_light:
			stub.is_flash_light_on = true
		var is_look := func() -> bool:
			return _name(demon) == "Chase.LOOK"
		var shown_at_time := _sim
		var looked: bool = await _until(is_look, 1.4)
		_assert(looked, "%s %s gives Chase.LOOK within 1.4 s (%.3f s waited, name '%s')" % [
			"the light switched on at" if with_light else "the stub moved to", shown_at, _sim - shown_at_time, _name(demon)])
	await _end()


# --- T11 ---------------------------------------------------------------------------------------

func _t11_kill_and_afterwards() -> void:
	_begin("T11 kill through the KillZone and afterwards")
	_subscribe(GameEventTypes.ENEMY_KILLED_PLAYER)
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, -6.0))
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	demon.force_chase()
	_assert(_name(demon) == "Chase.FORCE_CHASE", "after force_chase() the name is 'Chase.FORCE_CHASE', got '%s'" % _name(demon))
	var ordered_at := _sim
	var is_killed := func() -> bool:
		return stub.kill_calls == 1
	var killed: bool = await _until(is_killed, 3.0)
	_assert(killed, "stub.kill_calls == 1 within 3 s (%.3f s waited, kill_calls %d, distance %.2f m)" % [_sim - ordered_at, stub.kill_calls, Arena.planar(demon.global_position, stub.global_position)])
	if not killed:
		await _end()
		return
	var events := _bus_of(GameEventTypes.ENEMY_KILLED_PLAYER)
	_assert(events.size() == 1, "the enemy_killed_player event arrived once, got %d" % events.size())
	if not events.is_empty():
		var killer: Variant = events[0].payload.get("enemy")
		_assert(killer == demon and killer is Enemy, "payload['enemy'] is the demon and is an Enemy")
	var is_calm := func() -> bool:
		return demon.current_target == null and demon.is_chase == false and _name(demon) == "Wandering" \
			and not watch.se_stops.is_empty() and Vector2(demon.velocity.x, demon.velocity.z).length() < 0.05
	var calm: bool = await _until(is_calm, 0.3)
	_assert(calm, "within 0.3 s of the kill: current_target == null (%s), is_chase == false (%s), name 'Wandering' ('%s'), se_stopped logged (%d), planar speed < 0.05 (%.3f)" % [
		demon.current_target, demon.is_chase, _name(demon), watch.se_stops.size(), Vector2(demon.velocity.x, demon.velocity.z).length()])

	# Dead but present: thrown at 7 m/s for 1.2 s, then lying there.
	var mark: int = watch.names.size()
	stub.velocity = Vector3(7.0, 0.0, 0.0)
	await _run(1.2)
	stub.velocity = Vector3.ZERO
	await _run(5.0)
	_assert(watch.count_prefix("Chase", mark) == 0, "dead but present: no name starting with 'Chase' (log: %s)" % watch.names_text())
	_assert(stub.kill_calls == 1, "dead but present: kill_calls == 1, got %d" % stub.kill_calls)

	# Revive in place, 3 m in front of the demon's facing.
	var in_front: Vector3 = demon.global_position + demon.facing_forward() * 3.0
	in_front.y = 0.0
	stub.global_position = in_front
	stub.revive()
	var revived_at := _sim
	mark = watch.names.size()
	await _run(2.8)
	_assert(watch.count_prefix("Chase", mark) == 0, "no 'Chase' name for 2.8 s after the revive (revive grace; log: %s)" % watch.names_text())
	var is_look_again := func() -> bool:
		return watch.index_of("Chase.LOOK", mark) >= 0
	var looked: bool = await _until(is_look_again, 1.6)
	var look_after: float = watch.time_of("Chase.LOOK", mark) - revived_at
	_assert(looked and _in_window(look_after, 2.9, 4.3), "Chase.LOOK %.3f s after the revive (expected 2.9-4.3)" % look_after)
	_assert(stub.kill_calls == 1, "kill_calls == 1 after the revive in place, got %d" % stub.kill_calls)

	# Re-entry: a fresh entry into the stock, edge-triggered zone kills again.
	var touching: Vector3 = demon.global_position + demon.facing_forward() * 0.3
	touching.y = 0.0
	stub.global_position = touching
	var is_killed_again := func() -> bool:
		return stub.kill_calls == 2
	var rekilled: bool = await _until(is_killed_again, 0.5)
	_assert(rekilled, "re-entry at 0.3 m: kill_calls == 2 within 0.5 s, got %d" % stub.kill_calls)
	var is_wandering := func() -> bool:
		return _name(demon) == "Wandering"
	var wandering: bool = await _until(is_wandering, 0.1)
	_assert(wandering, "the name is 'Wandering' again after the second kill, got '%s'" % _name(demon))
	await _end()


# --- T12 ---------------------------------------------------------------------------------------

func _t12_sleep_and_wake() -> void:
	_begin("T12 Sleeping and waking")
	var p: Variant = Arena.add_point(_arena, "P", Vector3(0.0, 0.0, 0.0), 0.0, 2.0)
	var q: Variant = Arena.add_point(_arena, "Q", Vector3(10.0, 0.0, 0.0), 0.0, 2.0)
	var demon: Variant = _spawn(Vector3(0.0, 0.0, -3.0))
	if demon == null or p == null or q == null:
		_assert(false, "set-up: demon and both points exist")
		await _end()
		return
	Arena.link(p, [q])
	Arena.link(q, [p])
	var watch: Variant = _watch(demon)
	# Mid-leg P -> Q, past the middle: on waking the nearest point is Q, straight ahead.
	var is_mid_leg := func() -> bool:
		return _point_source(demon) == p and _wander_state(demon) == WANDER_MOVE and demon.global_position.x >= 6.0
	var on_leg: bool = await _until(is_mid_leg, 15.0)
	_assert(on_leg, "set-up: patrolling on the leg P -> Q (log: %s)" % watch.names_text())
	if not on_leg:
		await _end()
		return
	var kill_zone: Variant = demon.get_node_or_null("KillZone")
	var tree := demon.get_node_or_null("Graphics/AnimationTree") as AnimationTree
	var speed_before: float = demon.desired_speed
	var blend_before := _moving_blend(tree)

	demon.sleep()
	var asleep_at: Vector3 = demon.global_position
	_assert(_name(demon) == "Sleeping", "after sleep() the name is 'Sleeping', got '%s'" % _name(demon))
	_assert(demon.visible == false, "asleep: visible == false")
	_assert(demon.collision_layer == 0, "asleep: collision_layer == 0, got %d" % demon.collision_layer)
	_assert(kill_zone != null and kill_zone.enabled == false, "asleep: KillZone.enabled == false")
	_assert(demon.waypoints.is_empty(), "asleep: waypoints.is_empty() (%d)" % demon.waypoints.size())
	await _run(0.5)
	# Variant d: the body is ticked while asleep, as in SRC, so the gait blend settles to idle.
	var blend_after := _moving_blend(tree)
	_assert(speed_before > 0.0 and is_zero_approx(blend_after), "T12d: sleep() at desired_speed %.2f (blend_amount %.2f); 0.5 s later parameters/moving/blend_amount is %.4f (expected 0)" % [speed_before, blend_before, blend_after])
	await _run(1.5)
	var sleep_drift: float = asleep_at.distance_to(demon.global_position)
	_assert(sleep_drift < 0.001, "asleep: position unchanged to 1 mm over 2 s, moved %.5f m (no fall, no drift)" % sleep_drift)

	# A stub walks through the sleeping demon's position.
	var walk_from: Vector3 = asleep_at + Vector3(-4.0, 0.0, 0.0)
	walk_from.y = 0.0
	var stub: Variant = Arena.add_stub(_arena, walk_from)
	stub.velocity = Vector3(8.0 / 3.0, 0.0, 0.0)
	var mark: int = watch.names.size()
	var walk := {"time": 0.0}
	var walker := func() -> void:
		walk["time"] += get_physics_process_delta_time()
		stub.global_position = walk_from + Vector3(8.0, 0.0, 0.0) * minf(walk["time"] / 3.0, 1.0)
	_hooks.append(walker)
	await _run(3.0)
	_hooks.clear()
	stub.velocity = Vector3.ZERO
	_assert(stub.is_alive() and stub.kill_calls == 0, "a stub walked through the sleeper stays alive (kill_calls %d)" % stub.kill_calls)
	_assert(watch.count_prefix("Chase", mark) == 0 and _name(demon) == "Sleeping", "the walk-through causes no 'Chase' name for 3 s (log: %s)" % watch.names_text())

	demon.wake()
	_assert(_name(demon) == "Wandering", "after wake() the name is 'Wandering', got '%s'" % _name(demon))
	_assert(demon.visible == true, "awake: visible")
	_assert(demon.collision_layer == 2, "awake: collision_layer == 2, got %d" % demon.collision_layer)
	_assert(kill_zone != null and kill_zone.enabled == true, "awake: KillZone.enabled == true")
	var ahead: Vector3 = demon.global_position + demon.facing_forward() * 8.0
	ahead.y = 0.0
	stub.global_position = ahead
	var is_look := func() -> bool:
		return _name(demon) == "Chase.LOOK"
	var woke_at := _sim
	var noticed: bool = await _until(is_look, 1.4)
	_assert(noticed, "awake: the stub 8 m in front produces Chase.LOOK within 1.4 s (%.3f s waited, name '%s')" % [_sim - woke_at, _name(demon)])
	await _end()


## The tree parameter `parameters/moving/blend_amount`; NAN when the tree or the parameter is missing.
func _moving_blend(tree: AnimationTree) -> float:
	if tree == null:
		return NAN
	var value: Variant = tree.get("parameters/moving/blend_amount")
	if value is float or value is int:
		return float(value)
	return NAN


func _t12ab_start_asleep_and_injected_target() -> void:
	_begin("T12a start_asleep / T12b an injected target wakes the sleeper")
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, -8.0))
	var asleep := func(node: Variant) -> void:
		node.start_asleep = true
	var demon: Variant = _spawn(Vector3.ZERO, 0.0, "", true, asleep)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	if await _await_active(demon):
		_assert(watch.first_name() == "Sleeping", "T12a: with start_asleep the first state name is 'Sleeping', got '%s'" % watch.first_name())
		await _run(0.5)
		demon.current_target = stub
		demon.makepath()
		await _step()
		_assert(_name(demon) == "Chase.FORCE_CHASE", "T12b: current_target = stub; makepath() gives 'Chase.FORCE_CHASE' on the next tick, got '%s'" % _name(demon))
		_assert(demon.visible == true, "T12b: the woken demon is visible")
	await _end()


func _t12c_double_off_nav_mesh() -> void:
	_begin("T12c off_nav_mesh() twice, then wake() (D9)")
	var asleep := func(node: Variant) -> void:
		node.start_asleep = true
	var demon: Variant = _spawn(Vector3.ZERO, 0.0, "", true, asleep)
	if demon == null:
		await _end()
		return
	if await _await_active(demon):
		_assert(_name(demon) == "Sleeping", "set-up: asleep, name '%s'" % _name(demon))
		demon.off_nav_mesh()
		demon.wake()
		_assert(demon.collision_layer == 2 and demon.collision_mask == 55, "after the second off_nav_mesh() and wake(): collision_layer == 2 (%d) and collision_mask == 55 (%d)" % [demon.collision_layer, demon.collision_mask])
	await _end()


# --- T13 ---------------------------------------------------------------------------------------

func _t13a_ignore_player_until_touch_here() -> void:
	_begin("T13a ignore_player_until_touch_here")
	var a: Variant = Arena.add_point(_arena, "A", Vector3(0.0, 0.0, 0.0), 0.0, 2.0)
	var b: Variant = Arena.add_point(_arena, "B", Vector3(0.0, 0.0, -20.0), 0.0, 2.0, 3.0, "", {"ignore_player_until_touch_here": true})
	var stub: Variant = Arena.add_stub(_arena, Vector3(2.0, 0.0, -27.0))   # in plain view from the start, silent
	var demon: Variant = _spawn(Vector3(0.0, 0.0, 3.0))
	if demon == null or a == null or b == null:
		_assert(false, "set-up: demon and both points exist")
		await _end()
		return
	Arena.link(a, [b])
	var watch: Variant = _watch(demon)
	var is_at_b := func() -> bool:
		return _point_source(demon) == b
	var arrived: bool = await _until(is_at_b, 20.0)
	_assert(arrived, "the demon arrived at B (current_point.source_point == B; log: %s)" % watch.names_text())
	var range_at_b: float = Arena.planar(demon.global_position, stub.global_position)
	_assert(watch.count_prefix("Chase") == 0, "no 'Chase' name before the arrival at B although the stub is inside the 25 m / 75 deg cone from z = -2 on (now %.1f m away; log: %s)" % [range_at_b, watch.names_text()])
	if arrived:
		var is_look := func() -> bool:
			return _name(demon) == "Chase.LOOK"
		var arrived_at := _sim
		var looked: bool = await _until(is_look, 1.2)
		_assert(looked, "Chase.LOOK within 1.2 s of the arrival at B (%.3f s waited, name '%s')" % [_sim - arrived_at, _name(demon)])
	await _end()


func _t13b_force_chase_when_touch_here() -> void:
	_begin("T13b force_chase_when_touch_here")
	var a: Variant = Arena.add_point(_arena, "A", Vector3(0.0, 0.0, 0.0), 0.0, 2.0)
	var f: Variant = Arena.add_point(_arena, "F", Vector3(0.0, 0.0, -8.0), 0.0, 2.0, 1.0, "", {"force_chase_when_touch_here": true})
	var stub: Variant = Arena.add_stub(_arena, Vector3(20.0, 0.0, 10.0))   # behind the walking demon, silent
	var demon: Variant = _spawn(Vector3(0.0, 0.0, 3.0))
	if demon == null or a == null or f == null:
		_assert(false, "set-up: demon and both points exist")
		await _end()
		return
	Arena.link(a, [f])
	var watch: Variant = _watch(demon)
	var is_forced := func() -> bool:
		return _name(demon) == "Chase.FORCE_CHASE"
	var entered: bool = await _until(is_forced, 15.0)
	_assert(entered, "on arrival at F the name is 'Chase.FORCE_CHASE' (log: %s)" % watch.names_text())
	if not entered:
		await _end()
		return
	var entry_index: int = watch.index_of("Chase.FORCE_CHASE")
	_assert(watch.count_prefix("Chase") == 1 and entry_index >= 0, "no 'Chase' name on the legs: the forced chase at F is the first one (log: %s)" % watch.names_text())
	var entry_position: Vector3 = demon.global_position
	var f_distance: float = Arena.planar(entry_position, f.global_position)
	_assert(f_distance <= 0.65, "the forced chase starts at F (%.3f m from it, expected <= 0.65)" % f_distance)
	_assert(watch.se_count(SE_FIND) == 1, "se_requested(FIND) logged once, got %d" % watch.se_count(SE_FIND))

	var waiting := {"max_speed": 0.0, "max_drift": 0.0}
	var wait_probe := func() -> void:
		waiting["max_speed"] = maxf(waiting["max_speed"], demon.desired_speed)
		waiting["max_drift"] = maxf(waiting["max_drift"], Arena.planar(demon.global_position, entry_position))
	_hooks.append(wait_probe)
	await _run(1.0)
	_hooks.clear()
	_assert(is_zero_approx(waiting["max_speed"]), "desired_speed == 0 for the 1.0 s wait (thinking_time reused as the delay), max %.3f" % waiting["max_speed"])
	_assert(waiting["max_drift"] < 0.1, "displacement during the wait %.3f m (expected < 0.1)" % waiting["max_drift"])
	var is_running := func() -> bool:
		return is_equal_approx(demon.desired_speed, 5.0) and demon.current_target == stub
	var running: bool = await _until(is_running, 0.1)
	_assert(running, "between 1.0 and 1.1 s after the entry: desired_speed == 5.0 (%.2f) and current_target == stub (%s); the search clock accrues during the wait" % [demon.desired_speed, demon.current_target])
	var sting_offset: float = absf(watch.se_time(SE_CHASE) - watch.tick_sim)
	_assert(watch.se_count(SE_CHASE) == 1 and sting_offset <= 0.035, "se_requested(CHASE) exactly once (%d), at that moment (%.3f s apart)" % [watch.se_count(SE_CHASE), sting_offset])
	await _end()


## (c) wait_until_call AND ignore_player_until_call: no senses while waiting. (c2) wait_until_call only.
func _t13c_wait_until_call(both_flags: bool) -> void:
	_begin("T13c wait_until_call + ignore_player_until_call" if both_flags else "T13c2 wait_until_call only")
	var flags := {"wait_until_call": true}
	if both_flags:
		flags["ignore_player_until_call"] = true
	var w: Variant = Arena.add_point(_arena, "W", Vector3(0.0, 0.0, 0.0), 0.0, 2.0, 1.0, "", flags)
	var r: Variant = Arena.add_point(_arena, "R", Vector3(10.0, 0.0, 0.0), 0.0, 2.0)
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, 60.0))    # out of every sense until placed
	var demon: Variant = _spawn(Vector3(0.0, 0.0, 3.0))
	if demon == null or w == null or r == null:
		_assert(false, "set-up: demon and both points exist")
		await _end()
		return
	Arena.link(w, [r])
	var watch: Variant = _watch(demon)
	var is_at_w := func() -> bool:
		return _point_source(demon) == w
	var arrived: bool = await _until(is_at_w, 10.0)
	_assert(arrived, "the demon arrived at W (log: %s)" % watch.names_text())
	if not arrived:
		await _end()
		return
	stub.global_position = Vector3(0.0, 0.0, -8.0)       # standing in plain view of the waiting demon
	var placed_at := _sim

	if not both_flags:
		var is_look := func() -> bool:
			return _name(demon) == "Chase.LOOK"
		var looked: bool = await _until(is_look, 1.4)
		_assert(looked, "Chase.LOOK within 1.4 s of placing the stub (%.3f s waited, name '%s'): the two flags are ANDed" % [_sim - placed_at, _name(demon)])
		await _end()
		return

	await _run(4.0)
	_assert(_wander_state(demon) == WANDER_THINKING, "4 s after the arrival current_state._state is still THINKING (the 1 s dwell is over: the point waits for a call), got %d ('%s')" % [_wander_state(demon), _name(demon)])
	_assert(watch.count_prefix("Chase") == 0, "no 'Chase' name while waiting with both flags (senses off; log: %s)" % watch.names_text())
	stub.global_position = Vector3(0.0, 0.0, 60.0)
	var signals_before: int = watch.state_signal_count("Wandering")
	demon.call_to(r)
	var r_position: Vector3 = r.global_position
	var is_called := func() -> bool:
		var destination: Vector3 = demon._travel.destination
		return watch.state_signal_count("Wandering") == signals_before + 1 and _wander_state(demon) == WANDER_MOVE \
			and destination.distance_to(r_position) < 0.01
	var called: bool = await _until(is_called, _ticks(2))
	_assert(called, "call_to(R): within 2 ticks one more state_changed('Wandering') (%d -> %d), _state MOVE (%d), _travel.destination %s == R %s" % [
		signals_before, watch.state_signal_count("Wandering"), _wander_state(demon), demon._travel.destination, r_position])
	await _end()


# --- T14 ---------------------------------------------------------------------------------------

func _t14_point_types_and_call_to() -> void:
	_begin("T14 point types and call_to")
	var s: Variant = Arena.add_point(_arena, "S", Vector3(1.0, 0.0, 0.0), 0.0, 2.0, 0.0, "", {"type": 2})     # ONLY_START
	var c: Variant = Arena.add_point(_arena, "C", Vector3(0.0, 0.0, 2.0), 0.0, 2.0, 0.0, "", {"type": 3})     # ONLY_CALL
	var n: Variant = Arena.add_point(_arena, "N", Vector3(6.0, 0.0, 0.0), 0.0, 2.0, 30.0)                     # NORMAL
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null or s == null or c == null or n == null:
		_assert(false, "set-up: demon and the three points exist")
		await _end()
		return
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	var s_position: Vector3 = s.global_position
	var c_position: Vector3 = c.global_position
	var n_position: Vector3 = n.global_position
	var first: Vector3 = demon._travel.destination
	_assert(first.distance_to(n_position) < 0.01, "the first _travel.destination is N %s, got %s" % [n_position, first])
	var seen := {"skipped_point": false}
	var destination_probe := func() -> void:
		var destination: Vector3 = demon._travel.destination
		if destination.distance_to(s_position) < 0.01 or destination.distance_to(c_position) < 0.01:
			seen["skipped_point"] = true
	_hooks.append(destination_probe)
	await _run(3.0)
	_hooks.clear()
	_assert(not seen["skipped_point"], "for 3 s _travel.destination is never S (ONLY_START) or C (ONLY_CALL)")

	var signals_before: int = watch.state_signals.size()
	demon.call_to(null)
	await _step()
	_assert(watch.state_signals.size() == signals_before, "call_to(null): no state_changed (%d -> %d)" % [signals_before, watch.state_signals.size()])

	demon.call_to(c)
	var is_redirected := func() -> bool:
		var destination: Vector3 = demon._travel.destination
		return destination.distance_to(c_position) < 0.01
	var redirected: bool = await _until(is_redirected, _ticks(2))
	_assert(redirected, "call_to(C): within 2 ticks _travel.destination is C %s, got %s" % [c_position, demon._travel.destination])
	var is_at_c := func() -> bool:
		return _point_source(demon) == c
	var arrived: bool = await _until(is_at_c, 6.0)
	var c_distance: float = Arena.planar(demon.global_position, c_position)
	_assert(arrived and c_distance <= 0.7, "the demon arrives at the ONLY_CALL point within 6 s: current_point.source_point == C (%s), %.3f m from it (expected <= 0.7)" % [arrived, c_distance])
	await _end()


# --- T15 ---------------------------------------------------------------------------------------

func _t15a_stop_force_chase() -> void:
	_begin("T15a stop_force_chase")
	var stub_at := Vector3(0.0, 0.0, -20.0)
	var stub: Variant = Arena.add_stub(_arena, stub_at, Arena.yaw_towards(stub_at, Vector3.ZERO))
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null:
		await _end()
		return
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	demon.force_chase()
	await _run(1.0)
	demon.stop_force_chase()
	stub.global_position = Vector3(0.0, 0.0, -80.0)
	stub.velocity = Vector3.ZERO
	await _step()
	_assert(_name(demon) == "Chase.CHASE", "after stop_force_chase() the name is 'Chase.CHASE' on the next sample, got '%s'" % _name(demon))
	var is_blind := func() -> bool:
		return demon.current_target == null and demon.waypoints.size() == 1
	var blind: bool = await _until(is_blind, 0.6)
	_assert(blind, "within 0.6 s: current_target == null (%s) and waypoints.size() == 1 (%d): the pursuit became 'go to where it was last seen'" % [demon.current_target, demon.waypoints.size()])
	var is_lost := func() -> bool:
		return _name(demon) == "Chase.LOST"
	var lost: bool = await _until(is_lost, 6.0)
	var end_distance: float = Arena.planar(demon.global_position, stub_at)
	_assert(lost and end_distance <= 0.7, "the demon ends %.3f m from (0, 0, -20) (expected <= 0.7), then Chase.LOST (log: %s)" % [end_distance, watch.names_text()])
	if lost:
		var lost_index: int = watch.index_of("Chase.LOST")
		var is_back := func() -> bool:
			return watch.index_of("Wandering", lost_index) >= 0
		var gave_up: bool = await _until(is_back, 4.5)
		var lost_time: float = watch.time_of("Wandering", lost_index) - watch.time_of("Chase.LOST")
		_assert(gave_up and _in_window(lost_time, 3.0, 3.6), "Wandering %.3f s after LOST began (expected 3.0-3.6)" % lost_time)
	await _end()


func _t15b_lost_reacquire() -> void:
	_begin("T15b LOST re-acquire")
	var setup: Dictionary = await _lose_player()
	if setup.is_empty():
		await _end()
		return
	var demon: Variant = setup["demon"]
	var stub: Variant = setup["stub"]
	var watch: Variant = setup["watch"]
	var is_lost := func() -> bool:
		return _name(demon) == "Chase.LOST"
	var lost: bool = await _until(is_lost, 8.0)
	_assert(lost, "set-up: the demon reached Chase.LOST (log: %s)" % watch.names_text())
	if lost:
		await _run(1.0)
		var spot: Vector3 = demon.global_position + demon.facing_forward() * 6.0
		spot.y = 0.0
		stub.global_position = spot                      # 6 m in front of the facing, standing
		stub.rotation.y = Arena.yaw_towards(spot, demon.global_position)
		var revealed_at := _sim
		var is_chase := func() -> bool:
			return _name(demon) == "Chase.CHASE"
		var reacquired: bool = await _until(is_chase, 0.6)
		_assert(reacquired, "within 0.6 s of the reveal the name is 'Chase.CHASE' (%.3f s waited, name '%s')" % [_sim - revealed_at, _name(demon)])
		_assert(is_equal_approx(demon.desired_speed, 5.0), "desired_speed == 5.0 on that very sample (no ramp), got %.3f" % demon.desired_speed)
		_assert(demon.current_target == stub, "current_target == stub on that sample, got %s" % demon.current_target)
	await _end()


## The chase cone (50 m / 120 deg, SRC aooni_chase_state.gd:213) as the chase state applies it. A LOST demon
## stands still and searches every 0.5 s, so the stub can be shown at three places in turn.
func _t15e_chase_cone_edges() -> void:
	_begin("T15e chase cone edges while LOST")
	var setup: Dictionary = await _lose_player()
	if setup.is_empty():
		await _end()
		return
	var demon: Variant = setup["demon"]
	var stub: Variant = setup["stub"]
	var watch: Variant = setup["watch"]
	var is_lost := func() -> bool:
		return _name(demon) == "Chase.LOST"
	var lost: bool = await _until(is_lost, 8.0)
	_assert(lost, "set-up: the demon reached Chase.LOST (log: %s)" % watch.names_text())
	if lost:
		var origin: Vector3 = demon.global_position
		origin.y = 0.0
		var forward: Vector3 = demon.facing_forward()
		stub.global_position = origin + forward * 52.0                   # straight ahead, beyond 50 m
		await _run(0.7)
		_assert(_name(demon) == "Chase.LOST", "a stub 52 m straight ahead is not seen (0.7 s, one search): name '%s'" % _name(demon))
		stub.global_position = origin + Arena.turned_right(forward, -130.0) * 6.0
		await _run(0.5)
		_assert(_name(demon) == "Chase.LOST", "a stub 6 m away, 130 deg off the facing, is not seen (0.5 s, one search): name '%s'" % _name(demon))
		stub.global_position = origin + Arena.turned_right(forward, -110.0) * 30.0
		var shown_at := _sim
		var is_chase := func() -> bool:
			return _name(demon) == "Chase.CHASE"
		var reacquired: bool = await _until(is_chase, 0.6)
		_assert(reacquired and demon.current_target == stub, "a stub 30 m away, 110 deg off the facing, is seen: 'Chase.CHASE' within 0.6 s (%.3f s waited, name '%s') with current_target == stub" % [_sim - shown_at, _name(demon)])
	await _end()


func _t15c_orders_while_chasing() -> void:
	_begin("T15c orders while chasing")
	var p: Variant = Arena.add_point(_arena, "P", Vector3(20.0, 0.0, 20.0), 0.0, 2.0, 0.0, "", {"type": 3})   # ONLY_CALL: the demon idles
	var setup := _stare_setup(PI, true)
	var demon: Variant = setup["demon"]
	var watch: Variant = setup["watch"]
	if demon == null or p == null:
		_assert(false, "set-up: demon and the point exist")
		await _end()
		return
	var is_chase := func() -> bool:
		return _name(demon) == "Chase.CHASE"
	var chasing: bool = await _until(is_chase, 6.0)
	_assert(chasing, "set-up: the demon reached Chase.CHASE (log: %s)" % watch.names_text())
	if chasing:
		var before: Variant = demon.current_state
		var finds: int = watch.se_count(SE_FIND)
		demon.force_chase()
		_assert(demon.current_state == before, "force_chase() while chasing keeps the state object")
		demon.call_to_position(Vector3(10.0, 0.0, 10.0))
		_assert(demon.current_state == before, "call_to_position() while chasing keeps the state object")
		demon.call_to(p, true)
		_assert(demon.current_state == before, "call_to(P, true) while chasing keeps the state object")
		await _step()
		_assert(demon.current_state == before and _name(demon) == "Chase.CHASE", "one tick later the state is still the same Chase.CHASE object ('%s')" % _name(demon))
		_assert(watch.se_count(SE_FIND) == finds, "no further se_requested(FIND) was logged (%d -> %d)" % [finds, watch.se_count(SE_FIND)])
		demon.call_to(p)
		_assert(_name(demon) == "Wandering", "call_to(P) without the flag gives the name 'Wandering', got '%s'" % _name(demon))
		var destination: Vector3 = demon._travel.destination
		var p_position: Vector3 = p.global_position
		_assert(destination.distance_to(p_position) < 0.01, "after call_to(P) _travel.destination is P %s, got %s" % [p_position, destination])
	await _end()


func _t15d_look_target_after_kill() -> void:
	_begin("T15d look target after a kill (m2)")
	var h: Variant = Arena.add_point(_arena, "H", Vector3(0.0, 0.0, 12.0), 0.0, 2.0, 0.0)
	var stub: Variant = Arena.add_stub(_arena, Vector3(0.0, 0.0, -6.0))
	var demon: Variant = _spawn(Vector3.ZERO)
	if demon == null or h == null:
		_assert(false, "set-up: demon and the point exist")
		await _end()
		return
	var watch: Variant = _watch(demon)
	if not await _await_active(demon):
		await _end()
		return
	demon.force_chase()                                  # right after activation
	var is_killed := func() -> bool:
		return stub.kill_calls == 1
	var killed: bool = await _until(is_killed, 4.0)
	_assert(killed, "set-up: the forced chase killed the stub (kill_calls %d; log: %s)" % [stub.kill_calls, watch.names_text()])
	if killed:
		var is_reset := func() -> bool:
			return _name(demon) == "Wandering" and _wander_state(demon) == WANDER_MOVE \
				and demon.is_looking_at_something() == false and demon.look_target == demon.dummy_look_target
		var reset: bool = await _until(is_reset, 0.3)
		_assert(reset, "within 0.3 s of the kill: name 'Wandering' ('%s'), _state MOVE (%d), is_looking_at_something() == false (%s), look_target == dummy_look_target (%s)" % [
			_name(demon), _wander_state(demon), demon.is_looking_at_something(), demon.look_target == demon.dummy_look_target])
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
	for event_type in _subscribed:
		Services.event_bus.unsubscribe(event_type, _on_bus_event)
	_subscribed.clear()
	_bus_events.clear()
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


## "3 physics frames after each move": the physics server has the stub's new place and shape.
func _settle() -> void:
	await _run(_ticks(3))


func _ticks(count: int) -> float:
	return count * get_physics_process_delta_time()


func _in_window(value: float, low: float, high: float) -> bool:
	return value >= low - TIME_EPS and value <= high + TIME_EPS


func _name(demon: Variant) -> String:
	return String(demon.get_state_name())


## current_state._state when the wandering state is current, else -1.
func _wander_state(demon: Variant) -> int:
	if not is_instance_valid(demon) or demon.current_state == null or _name(demon) != "Wandering":
		return -1
	return int(demon.current_state._state)


## current_state.current_point.source_point when the wandering state is current, else null.
func _point_source(demon: Variant) -> Node:
	if _wander_state(demon) < 0:
		return null
	var data: Variant = demon.current_state.current_point
	if data == null:
		return null
	return data.source_point as Node


func _subscribe(event_type: StringName) -> void:
	Services.event_bus.subscribe(event_type, _on_bus_event)
	_subscribed.append(event_type)


func _on_bus_event(event: RefCounted) -> void:
	_bus_events.append(event)


func _bus_of(event_type: StringName) -> Array:
	var found: Array = []
	for event: Variant in _bus_events:
		if event.event_type == event_type:
			found.append(event)
	return found


func _bus_from(event_type: StringName, source: Variant) -> int:
	var count := 0
	for event: Variant in _bus_of(event_type):
		if event.source == source:
			count += 1
	return count


func _assert(condition: bool, message: String) -> void:
	var text := "[%s] %s" % [_case, message]
	if condition:
		print("  ok   ", text)
	else:
		_failed = true
		push_error("ASSERT FAILED: " + text)
		print("  FAIL ", text)
