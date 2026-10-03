class_name BlueDemonBody
extends Node  # DST B1: SRC extends Node3D; this node needs no transform

## Animation and torso audio for the Ao Oni — port of `u823.AooniBody`.
##
## The original drives an Animator whose Base Layer is a 1D blend tree on a "Blend"
## parameter (walk at 0.05, run at 1.0) plus Idle and ForceIdle states, and separately
## twists the `neck` bone towards whatever the demon is looking at, clamped to
## NECK_ANGLE_LIMIT = 75 degrees. Here the blend tree is an [AnimationTree] and the neck
## twist is a [Skeleton3D] bone pose override applied after animation.
##
## DST B3: the torso-audio half of the SRC class (body_audio, audio_clips, grab_player_se,
## open_mouth_se, _play, _distance_gain) and ForceIdle (force_idle, _force_idle) only serve
## the kill cutscene, which is not ported (porting decision 2). What is left is the gait
## blend and the neck twist, plus the model set-up that SRC kept in its scene, its importer
## and its root script (DST B1, B2, B5).

@export var animation_tree: AnimationTree  ## DST B1: resolved in init() from "Graphics/AnimationTree" when null
@export var skeleton: Skeleton3D  ## DST B1: resolved in init() by type under "Graphics/Model" when null

## Name of the neck bone in the extracted rig.
@export var neck_bone: StringName = &"Neck"

## Below this many degrees of error the neck stops chasing the target, and below the
## second the decay back to straight stops. Both are the original's own dead-bands, which
## exist so the 0.1-per-frame easing terminates instead of asymptoting.
const NECK_DEAD_BAND: float = 0.01
const NECK_DECAY_DEAD_BAND: float = 0.001

var _demon: BlueDemon
var _neck_index: int = -1
var _angle: float = 0.0
var _new_angle: float = 0.0
var _moving: bool = false
var _moving_blend: float = 0.0


## DST B2: SRC's init() only looked the neck bone up and started the tree: its scene carried
## the NodePaths, its importer the loop modes and its root the material. Here init() resolves
## its collaborators itself (B1), applies the model scale, makes the loop modes durable,
## paints the material (B5) and starts the tree. It returns false when the model, the model's
## AnimationPlayer or the AnimationTree is missing; the root then stays dormant.
func init(demon: BlueDemon) -> bool:  # DST B2: returns a bool (SRC: void)
	_demon = demon  # DST rule 5.0.1: rename only (the 5.6 audit recipe does not map a bare `demon`)
	if demon == null:  # DST B2
		return false  # DST B2

	# DST B1: fixed node names, and lookups by type inside the instanced glb. The scene carries
	# no NodePath into the model, so a glTF node-naming difference cannot break the wiring.
	if animation_tree == null:  # DST B1
		animation_tree = demon.get_node_or_null(^"Graphics/AnimationTree") as AnimationTree  # DST B1
	var model := demon.get_node_or_null(^"Graphics/Model") as Node3D  # DST B1
	var player: AnimationPlayer = null  # DST B1
	if model:  # DST B1
		if skeleton == null:  # DST B1
			var skeletons := model.find_children("*", "Skeleton3D", true, false)  # DST B1
			if not skeletons.is_empty():  # DST B1
				skeleton = skeletons[0] as Skeleton3D  # DST B1
		var players := model.find_children("*", "AnimationPlayer", true, false)  # DST B1
		if not players.is_empty():  # DST B1
			player = players[0] as AnimationPlayer  # DST B1
	if model == null or player == null or animation_tree == null:  # DST B2
		push_error("[BlueDemon] %s: body set-up failed (Graphics/Model: %s, its AnimationPlayer: %s, Graphics/AnimationTree: %s)" % [  # DST B2
			demon.name,  # DST B2
			"ok" if model else "MISSING",  # DST B2
			"ok" if player else "MISSING",  # DST B2
			"ok" if animation_tree else "MISSING",  # DST B2
		])  # DST B2
		return false  # DST B2

	# DST B2 (1): one inspector value (BlueDemon.model_scale) sizes the model, keeps the soles
	# on the floor and the sight-ray origin at the brow. The scene's own transform on
	# Graphics/Model is only the editor preview of the default scale.
	model.scale = Vector3.ONE * demon.model_scale  # DST B2
	model.position = Vector3(0.0, BlueDemonTuning.MODEL_SOLE_DROP * demon.model_scale, 0.0)  # DST B2
	var eyes := demon.get_node_or_null(^"EyesDetection3D") as Node3D  # DST B2
	if eyes:  # DST B2
		eyes.position.y = BlueDemonTuning.EYE_HEIGHT_NATIVE * demon.model_scale  # DST B2

	# DST B2 (2): loop modes made durable. SRC's aooni.glb.import was the only place that said
	# `loop_mode = 1`; `*.import` is git-ignored in dark-chasers and a fresh import gives
	# LOOP_NONE. The clips are shared resources, so the write is seen by the AnimationTree and
	# is idempotent across instances. It must happen before the tree is activated.
	for clip: StringName in [&"idle", &"walk", &"run"]:  # DST B2
		if player.has_animation(clip):  # DST B2
			player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR  # DST B2
		else:  # DST B2
			push_error("[BlueDemon] animation '%s' missing in the model" % clip)  # DST B2

	_apply_body_material(model, demon.body_material)  # DST B2 (3), B5

	if skeleton:
		_neck_index = skeleton.find_bone(neck_bone)
	if _neck_index < 0:  # DST B2 (4)
		push_warning("[BlueDemon] %s: neck bone '%s' not found in the model; the neck twist is off" % [demon.name, neck_bone])  # DST B2
	if animation_tree:
		# DST B2 (5): the neck ordering is asserted here, not assumed. The tree mixes in idle
		# (process) time at priority 0; this node's `_process` runs at priority 100.
		animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE  # DST B2
		animation_tree.active = true
	return true  # DST B2


## DST B5: SRC painted every mesh under the demon's root and switched it to dynamic GI
## (`Aooni._use_light_probes`, aooni.gd:171-176). Here only the meshes under Graphics/Model
## are painted and no `gi_mode` is written: dark-chasers has no baked GI. Skipped when the
## root's `body_material` export is null (the imported material then shows).
func _apply_body_material(model: Node, material: Material) -> void:  # DST B5
	if model == null or material == null:  # DST B5
		return  # DST B5
	for node in model.find_children("*", "MeshInstance3D", true, false):  # DST B5
		var mesh := node as MeshInstance3D  # DST B5
		if mesh:  # DST B5
			mesh.material_override = material  # DST B5


## Per-frame locomotion blending.
##
## `Aooni.Update` does exactly one thing besides ticking the state:
## `animator.SetFloat("Blend", meshAgent.speed)`. The blend value is therefore the
## agent's *configured* speed, not its measured velocity, so the demon's gait switches
## the instant a state changes its speed rather than ramping with acceleration.
##
## The speed is remapped onto the tree rather than fed to it raw, so that patrolling walks
## and only a chase or a scripted rush runs — see [constant BlueDemonTuning.LOCOMOTION_WALK_SPEED]
## for why, and for what that costs. The idle gate still reads the raw speed.
##
## The move between Idle and the tree is not instant: the controller's two transitions each
## last 0.25 s, and they have hysteresis (out below 0.01, back in above 0.011). Switching
## `blend_amount` outright instead makes the demon snap into its idle pose the frame it
## stops, which reads as a glitch rather than a stop.
func on_update(delta: float) -> void:
	if animation_tree == null or _demon == null:
		return
	var blend := _demon.desired_speed  # DST B3: no ForceIdle. SRC units (rule 5.0.5): the commanded speed, unscaled
	animation_tree.set(&"parameters/locomotion/blend_position", lerpf(
		BlueDemonTuning.BLEND_WALK_THRESHOLD, BlueDemonTuning.BLEND_RUN_THRESHOLD, BlueDemonTuning.gait_mix(blend)))

	if blend < BlueDemonTuning.BLEND_IDLE_THRESHOLD:
		_moving = false
	elif blend > BlueDemonTuning.BLEND_MOVE_THRESHOLD:
		_moving = true
	_moving_blend = move_toward(
		_moving_blend, 1.0 if _moving else 0.0, delta / BlueDemonTuning.BLEND_TRANSITION_TIME
	)
	animation_tree.set(&"parameters/moving/blend_amount", _moving_blend)


## Twist the neck towards the look target, after the animation pose has been written.
##
## Ordering matters and is easy to get silently wrong: an [AnimationTree] writes bone
## poses from its *internal* process, which is dispatched in tree order, so a parent
## node's `_process` runs before its child mixer and any bone write it makes is
## immediately overwritten.
##
## DST B4: SRC raised the root's `process_priority` (aooni.tscn:52) and called this from the
## root's `_process`. Here the priority (100, blue_demon.tscn) sits on this node, the one that
## writes bones, and [method _process] below makes the call: it runs after the mixer.
func on_late_update(delta: float) -> void:
	if skeleton == null or _neck_index < 0 or _demon == null:
		return

	# `if (LookTarget == null) newAngle = 0` — a demon with nothing to track eases its
	# neck straight, it does not stare at a stand-in point.
	if not _demon.is_looking_at_something():
		_new_angle = 0.0
	else:
		# DST B6: the angle is measured in the horizontal plane. SRC keeps the Y of both
		# vectors on purpose (a look target above or below the demon inflates the angle past
		# the 75-degree gate), which works there because the whole body pitches at the player
		# and the stare test uses the same 3-D measure (aooni_chase_state.gd:114-123). Here the
		# body only yaws and the stare test is planar (DST C3): a Y-inclusive neck would leave
		# a band (player 2 m above at 1.5-3 m) where the body does not turn and the neck gives up.
		var to_look := _demon.get_look_position() - _demon.global_position
		to_look.y = 0.0  # DST B6: planar
		if to_look.length_squared() < 0.00000001:
			_new_angle = 0.0
		else:
			var forward := _demon.facing_forward()  # DST B4: the visible facing (planar, unit length), not the snapped root's -Z
			_new_angle = rad_to_deg(
				forward.signed_angle_to(to_look.normalized(), Vector3.UP)
			)

	# 75 degrees is a *gate*, not a clamp: inside it the neck eases towards the target,
	# outside it the neck eases back to straight. Clamping instead leaves the head locked
	# at a hard 75-degree stare, which reads completely differently.
	var blend := 1.0 - pow(0.9, delta * 60.0)
	if absf(_new_angle) <= BlueDemonTuning.NECK_ANGLE_LIMIT:
		if absf(_new_angle - _angle) > NECK_DEAD_BAND:
			_angle += (_new_angle - _angle) * blend
	elif absf(_angle) > NECK_DECAY_DEAD_BAND:
		_angle -= _angle * blend

	if is_zero_approx(_angle):
		return

	# Rotate about the skeleton's up axis, not the bone's local Y — this rig's bones run
	# along their local X, so a naive Vector3.UP twist tips the head sideways. Expressing
	# the axis in the parent bone's space and pre-multiplying applies the yaw "outside"
	# the animated pose, which is what layering on top of an animation means.
	var parent := skeleton.get_bone_parent(_neck_index)
	var parent_basis := (
		skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
	)
	var axis := (parent_basis.inverse() * Vector3.UP).normalized()
	if axis.is_zero_approx():
		return
	skeleton.set_bone_pose_rotation(
		_neck_index,
		Quaternion(axis, deg_to_rad(_angle)) * skeleton.get_bone_pose_rotation(_neck_index),
	)


## DST B4: the neck write. This node has `process_priority` 100 in blue_demon.tscn, so this
## runs after the AnimationTree (priority 0, idle callback) has written the frame's pose; the
## bone write survives to the end of the frame and does not accumulate (spike P6).
func _process(delta: float) -> void:  # DST B4
	on_late_update(delta)  # DST B4
