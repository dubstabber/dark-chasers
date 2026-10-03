class_name BlueDemonFoot
extends Node  # DST F1: SRC extends Node3D; this node needs no transform

## Footstep audio for the Ao Oni — port of `u823.AooniFoot`.
##
## `AooniFoot.Stamp(int i)` is not called by any code: it is an **AnimationEvent**, fired
## twice per cycle by the two locomotion clips, which is why the demon's footsteps stay
## locked to its gait however its speed changes. Read out of the shipped `.anim` assets:
##
## | clip | length | `Stamp(0)` | `Stamp(1)` |
## |---|---|---|---|
## | `Take 001` (walk) | 1.13333 s | 0.10421 s = 9.2 % | 0.68261 s = 60.2 % |
## | `Take 001_0` (run) | 0.66667 s | 0.10421 s = 15.6 % | 0.39987 s = 60.0 % |
##
## Godot cannot fire method tracks reliably out of a blended [AnimationNodeBlendSpace1D],
## so this reproduces the same clock directly: a normalised phase advanced at the blended
## clip's rate, firing each foot as the phase crosses its event time. The cadence is the
## clip's, not the distance travelled — the demon stamping while it turns on the spot is
## correct, and is what the original does.
##
## `Stamp` itself, disassembled at 0x1806B5630:
##
##     if (Time.timeSinceLevelLoad - lastFootStampTime[i] < 0.1f) return;
##     foots[i].Play();
##     foots[i].pitch  = Random.Range(0.85f, 0.9f);
##     r = Mathf.Clamp01(aooni.meshAgent.speed * 0.2f);
##     foots[i].volume = r * 0.5f + 0.4f + Random.Range(-0.05f, 0.05f);
##     yDist = InGame.Instance.Player.transform.position.y - aooni.transform.position.y;
##     foots[i].volume -= Mathf.Abs(yDist) * 0.15f;
##     foots[i].pitch  -= yDist * 0.05f;
##     lastFootStampTime[i] = Time.timeSinceLevelLoad;
##
## The `yDist` terms are the interesting ones. They are a *storey* cue: the demon on the
## floor above you is quieter and lower-pitched, the demon below you quieter and higher,
## and neither is a distance falloff — the AudioSource's own rolloff already does that.
## The volume term uses the absolute height difference and the pitch term the signed one.
##
## DST F1: the sound is played by two stock dark-chasers footstep detectors, the `FootL` and
## `FootR` AudioStreamPlayer3D children of the demon, instead of SRC's FootstepEmitter (the
## SRC footstep system is not copied). Two players, because the detector re-assigns `stream`
## for every step, which stops the player: one shared player would cut each step's tail at
## the run cadence. The distance falloff is the engine's (blue_demon.tscn: `unit_size` 7,
## `max_distance` 70, cutoff 20500 Hz), not SRC's hand-sampled rolloff curve.
## DST F2 / F3: the clock is ticked by the root from the physics tick and the debounce runs
## on that same simulated clock, so the cadence is deterministic under `--fixed-fps`.

signal stamped(foot_index: int, volume: float, pitch: float)

@export var base_volume_db: float = 0.0  ## DST F4: offset on top of the SRC linear volume (0 dB = SRC's unity gain)

@export_group("Stamp")
## Minimum seconds between two stamps of the *same* foot, `0.1` in the original.
@export var min_stamp_interval: float = 0.1

## Length of the walk and run cycles, in seconds. The gait clock interpolates between
## them with the same blend the [BlueDemonBody] feeds the animation tree.
@export var walk_cycle_length: float = 1.13333
@export var run_cycle_length: float = 0.66667

## Normalised times of the two `Stamp` AnimationEvents in each clip, left foot then right.
@export var walk_event_times := Vector2(0.091954, 0.602299)
@export var run_event_times := Vector2(0.156322, 0.599798)

var _demon: BlueDemon
var _feet: Array[DarkChasersFootstepSurfaceDetector] = []  # DST F1: [FootL, FootR] (SRC: `emitter: FootstepEmitter`)
var _last_stamp_time: Array[float] = [-INF, -INF]
var _phase: float = 0.0
var _clock: float = 0.0  # DST F2: simulated seconds; one clock for cadence and debounce


func init(demon: BlueDemon) -> void:
	_demon = demon  # DST rule 5.0.1: rename only (the 5.6 audit recipe does not map a bare `demon`)
	if demon:  # DST F1
		_feet = [  # DST F1: found by fixed node name, left foot then right (index = SRC `Stamp(i)`)
			demon.get_node_or_null(^"FootL") as DarkChasersFootstepSurfaceDetector,  # DST F1
			demon.get_node_or_null(^"FootR") as DarkChasersFootstepSurfaceDetector,  # DST F1
		]  # DST F1
	# Prefer the imported clips' own lengths: the glTF export bakes at a slightly
	# different rate than Unity's 30 fps source, and a re-export can change them again.
	_adopt_clip_length(&"walk", true)
	_adopt_clip_length(&"run", false)


func _adopt_clip_length(clip: StringName, is_walk: bool) -> void:
	if _demon == null or _demon.body == null or _demon.body.animation_tree == null:
		return
	var mixer := _demon.body.animation_tree
	if not mixer.has_animation(clip):
		return
	var length := mixer.get_animation(clip).length
	if length <= 0.0:
		return
	if is_walk:
		walk_cycle_length = length
	else:
		run_cycle_length = length


## DST F2: SRC ran this clock in `_process`. Here the root calls it from its physics tick
## (step 6, and from the frozen tick while the demon sleeps: speed 0 resets the phase).
func on_update(delta: float) -> void:  # DST F2: SRC `_process(delta)`
	_clock += delta  # DST F2: advances while idle too, so the debounce spans a pause
	if _demon == null or _feet.is_empty():  # DST F1: SRC tested `emitter == null`
		return

	# `Aooni.Update` feeds the animator `meshAgent.speed`, so the gait follows the demon's
	# *configured* speed rather than its measured velocity — it switches to the run cycle
	# the instant a state raises the speed, without waiting for acceleration.
	var blend := _demon.desired_speed
	if blend < BlueDemonTuning.BLEND_IDLE_THRESHOLD:
		# Idle: the pose is static and fires no events.
		_phase = 0.0
		return

	# The same walk-to-run mix [BlueDemonBody] gives the blend tree. Sharing it is the point:
	# these are the footfalls of the cycle that is actually on screen, so a private mapping
	# here would put the sound half a step away from the foot landing.
	var mix := BlueDemonTuning.gait_mix(blend)
	var cycle := lerpf(walk_cycle_length, run_cycle_length, mix)
	var events := walk_event_times.lerp(run_event_times, mix)

	var previous := _phase
	_phase += delta / maxf(cycle, 0.01)
	while _phase >= 1.0:
		_phase -= 1.0
		previous -= 1.0
	for foot in 2:
		var at: float = events[foot]
		if previous < at and _phase >= at:
			stamp(foot)


## Play one footstep. Port of `AooniFoot.Stamp(int i)`.
func stamp(index: int) -> void:
	if index < 0 or index >= _last_stamp_time.size() or index >= _feet.size() or _feet[index] == null:  # DST F1: SRC tested `emitter == null`
		return
	var now := _clock  # DST F3: simulated time. A wall-clock debounce (SRC: Time.get_ticks_msec()) drops steps when the simulation runs faster than real time
	if now - _last_stamp_time[index] < min_stamp_interval:
		return
	_last_stamp_time[index] = now

	var speed_ratio := clampf(
		(_demon.desired_speed if _demon else 0.0) * BlueDemonTuning.FOOT_VOLUME_PER_SPEED, 0.0, 1.0
	)
	var volume := (
		speed_ratio * BlueDemonTuning.FOOT_VOLUME_SPEED_SCALE
		+ BlueDemonTuning.FOOT_VOLUME_BASE
		+ randf_range(-BlueDemonTuning.FOOT_VOLUME_JITTER, BlueDemonTuning.FOOT_VOLUME_JITTER)
	)
	var pitch := randf_range(BlueDemonTuning.AOONI_FOOT_MIN_PITCH, BlueDemonTuning.AOONI_FOOT_MAX_PITCH)

	var y_distance := _height_above_target()
	volume -= absf(y_distance) * BlueDemonTuning.FOOT_VOLUME_PER_METRE_Y
	pitch -= y_distance * BlueDemonTuning.FOOT_PITCH_PER_METRE_Y

	volume = maxf(volume, 0.0)
	if volume <= 0.0:
		return
	# DST F4: the detector's `_play_footstep` only does `stream = profile; play()`
	# (footstep_surface_detector.gd:244-246), so the volume and pitch written just before it
	# survive. `max_db` caps the near field at the stamp volume: the engine's inverse-distance
	# model would otherwise boost the sound inside `unit_size` (the default allows +3 dB).
	var player := _feet[index]  # DST F4
	player.volume_db = base_volume_db + linear_to_db(maxf(volume, 0.0001))  # DST F4
	player.max_db = player.volume_db  # DST F4
	player.pitch_scale = maxf(pitch, 0.01)  # DST F4
	player.play_footstep()  # DST F4: surface lookup + play (generic fallback profile = the demon's own thud)
	stamped.emit(index, volume, pitch)  # DST F4 (D30): emitted on the request; the detector returns nothing (SRC: only when a step played)


## `Player.transform.position.y - transform.position.y`, positive when the player is above
## the demon.
func _height_above_target() -> float:
	if _demon == null or _demon.target == null:
		return 0.0
	if not is_instance_valid(_demon.target) or not BlueDemonPrey.is_alive(_demon.target) or not BlueDemonPrey.same_room(_demon, _demon.target):  # DST F4
		return 0.0  # DST F4: no storey cue for a prey that is freed, dead or in another room (8.5)
	return _demon.target.global_position.y - _demon.global_position.y
