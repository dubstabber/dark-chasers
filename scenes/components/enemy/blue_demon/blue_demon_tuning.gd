class_name BlueDemonTuning
extends RefCounted                               # DST: explicit base (SRC has none); the header gate G1 reads it

## Tuning constants recovered from Absolute Fear -AOONI- (LiTMUS, Unity 2022.3.12f1).
##
## Everything here is a literal read out of the shipped IL2CPP metadata — the `const`
## fields of `u823.Aooni`, `u823.AooniChaseState`, `u823.AooniWanderingState`,
## `u823.AooniBody`, `u823.Fear` and `u823.InGameConst` — or a serialised component
## value read out of the `Aooni` GameObject in the `InGame` scene. They are not guesses.
##
## Unity and Godot share metres and seconds, and the extracted model measures 2.80 m
## tall, matching the CharacterController below, so no unit conversion is needed.

# --- u823.Aooni ------------------------------------------------------------------

## Radius within which the demon can hear the player moving.
const HEARABLE_DISTANCE_LIMIT: float = 12.0

## Reduced hearing radius while the player is crouched ("bend down").
const HEARABLE_DISTANCE_LIMIT_WHILE_BEND_DOWN: float = 6.0

# --- u823.AooniWanderingState ----------------------------------------------------

## Sight cone while patrolling: 25 m, and a **half**-angle of 75 degrees from forward —
## a 150 degree cone.
const WANDER_LOOK_DISTANCE: float = 25.0
const WANDER_LOOK_ANGLE: float = 75.0

## Widened sight cone when the player's flashlight is on: 40 m, half-angle 90, i.e. a
## full 180 degrees. Switching the torch on means the demon can see you anywhere in front
## of it out to 40 m.
const WANDER_LIGHT_LOOK_DISTANCE: float = 40.0
const WANDER_LIGHT_LOOK_ANGLE: float = 90.0

# --- u823.AooniChaseState --------------------------------------------------------

## Sight cone while chasing: 50 m, half-angle 120, i.e. a 240 degree cone. A chasing demon
## can see very nearly all the way around itself.
const CHASE_LOOK_DISTANCE: float = 50.0
const CHASE_LOOK_ANGLE: float = 120.0

## Seconds of "look time" the stare takes to resolve before the demon charges. It accrues
## at 1.5x while the player is standing, so two real seconds standing and three crouched.
const CHASE_LOOK_TARGET_TIME: float = 3.0

## How often the pursuit target is refreshed while actively chasing.
const CHASE_LOOK_TARGET_SPAN: float = 0.5

## Seconds — not attempts — spent at the player's last known position before the chase is
## abandoned. The demon gets six 0.5 s searches in during that window.
const CHASE_LOST_LIMIT: float = 3.0

## Speed added per second while chasing, on top of the point's moving speed.
const CHASE_SPEED_UP_DELTA: float = 0.5

# --- u823.AooniBody --------------------------------------------------------------

## Maximum yaw of the neck bone relative to the body, in degrees.
const NECK_ANGLE_LIMIT: float = 75.0

# --- u823.InGameConst ------------------------------------------------------------

const AOONI_WANDERING_SPEED: float = 1.0
const AOONI_ROTATE_SPEED: float = 90.0
const AOONI_FOOT_MIN_PITCH: float = 0.85
const AOONI_FOOT_MAX_PITCH: float = 0.9

# --- u823.AooniFoot.Stamp, disassembled at 0x1806B5630 ----------------------------
#
#     r      = clamp01(meshAgent.speed * 0.2)
#     volume = r * 0.5 + 0.4 + Random.Range(-0.05, 0.05) - abs(yDist) * 0.15
#     pitch  = Random.Range(0.85, 0.9) - yDist * 0.05
#
# so the demon is between 0.45 and 0.55 loud at a patrol crawl and 0.7 to 0.8 at a dead
# run, before the height correction. `yDist` is the player's Y minus the demon's, which
# makes both terms a storey cue rather than a distance falloff — the AudioSource's own
# rolloff already handles distance.

## `meshAgent.speed` is scaled by this and clamped to 0..1, so the volume ramp saturates
## at 5 m/s, exactly the chase speed cap.
const FOOT_VOLUME_PER_SPEED: float = 0.2
const FOOT_VOLUME_SPEED_SCALE: float = 0.5
const FOOT_VOLUME_BASE: float = 0.4
const FOOT_VOLUME_JITTER: float = 0.05

## Linear volume lost, and pitch shifted, per metre of height difference to the player.
const FOOT_VOLUME_PER_METRE_Y: float = 0.15
const FOOT_PITCH_PER_METRE_Y: float = 0.05

# --- Serialised component values from the `Aooni` GameObject (InGame.unity) -------

## NavMeshAgent: speed 3.5, acceleration 20, angular speed 120, stopping distance 0,
## auto-braking disabled, agent height 2.
const AGENT_ANGULAR_SPEED: float = 120.0

# --- Animator (Aooni.controller) -------------------------------------------------

## The locomotion blend tree is 1D on a "Blend" parameter: walk sits at 0.05 and run at
## 1.0. These are the tree's own thresholds and are not the speeds that map onto them —
## see [constant LOCOMOTION_WALK_SPEED].
const BLEND_WALK_THRESHOLD: float = 0.05
const BLEND_RUN_THRESHOLD: float = 1.0

## Speeds that select each locomotion clip.
##
## [b]Deliberate deviation from the original.[/b] `Aooni.Update` feeds the Blend parameter
## the agent's raw speed, and Unity clamps a 1D tree to its outermost threshold — so with
## every shipped `MovingSpeed` at 2.0 or above, the original is on the run cycle the whole
## time and never plays its own walk. Patrolling should read as walking, with the run kept
## for a chase and for the scripted rushes, so the speed is remapped onto the tree instead
## of being fed to it raw.
##
## The two numbers come from the patrol graphs, whose authored speeds are cleanly bimodal:
## 51 of the 67 points sit at 2.0, 2.5 or 3.0, and the remaining 15 (fourteen at 5.0, one
## at 15.0) are scripted rushes. 5.0 is also the chase speed cap.
##
## Consequence worth knowing: a chase starts at 1.0 and ramps at 0.5 m/s², so the demon
## *walks* after you at first and breaks into a run as it winds up — sooner if you turn
## your back, since that doubles its speed, and instantly if it loses sight of you and
## commits at the cap. Lower [constant LOCOMOTION_WALK_SPEED] if a chase should run at once.
##
## Neither clip matches its speed on the ground: `tools/diag_gait_speed.gd` measures the
## walk at 0.54 m/s and the run at 0.90 m/s, both authored with a ~0.6 m stride. The feet
## slide at any patrol speed and did so in the original too, so there is no choice here
## that avoids it — only one that picks the better-looking cycle.
const LOCOMOTION_WALK_SPEED: float = 3.0
const LOCOMOTION_RUN_SPEED: float = 5.0


## How far between the walk and run cycles a given speed sits, 0 walk and 1 run. Shared so
## that [BlueDemonFoot]'s footstep cadence cannot drift out of step with the visible gait.
static func gait_mix(speed: float) -> float:
	return clampf(
		inverse_lerp(LOCOMOTION_WALK_SPEED, LOCOMOTION_RUN_SPEED, speed), 0.0, 1.0
	)

## The Idle <-> Blend Tree transitions, with the controller's own hysteresis: it leaves the
## tree once Blend drops below 0.01 and re-enters once it passes 0.011. Both crossfade over
## a quarter of a second, so stopping is a fade rather than a pop.
const BLEND_IDLE_THRESHOLD: float = 0.01
const BLEND_MOVE_THRESHOLD: float = 0.011
const BLEND_TRANSITION_TIME: float = 0.25

# --- DST additions ---
const RETURN_HOME_SPEED: float = 2.0             # SRC units
const MODEL_SOLE_DROP: float = 0.108             # soles below the glb origin, model units (critic C1)
const EYE_HEIGHT_NATIVE: float = 1.98            # x 0.714286 = 1.414 m: the eyebrow in the idle pose (1.983 above the soles; walk 1.90-1.94, run 1.86-1.95)
