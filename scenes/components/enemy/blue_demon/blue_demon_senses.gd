class_name BlueDemonSenses
extends RefCounted

## Sight and hearing of the blue demon — port of the senses block of `u823.Aooni`
## (blue-demon-escape `scripts/characters/aooni/aooni.gd:504-614`).
##
## Senses are the interesting part. [method is_find_player] is a cone test plus a line
## of sight raycast, with the cone supplied by the *state* — patrolling uses a narrow
## 25 m / 75 degree cone, chasing a 50 m / 120 degree one. [method is_feel_player_sound]
## is a pure radius test that shrinks when the player crouches.
##
## DST: owned by the [BlueDemon] root, which forwards the SRC member names to it; the states never
## see this object. Everything the demon may know about its prey goes through [BlueDemonPrey].

var _demon: BlueDemon


func setup(demon: BlueDemon) -> void:
	_demon = demon


## Can the demon see the player right now? Port of
## `Aooni.IsFindPlayer(lookDistance, lookAngle)`, decompiled from 0x1806B74A0.
##
## The original is, in order:
##   1. `lookDistance > InGame.Instance.distanceToPlayer` — note the strict inequality,
##      and that the distance is the full 3D distance InGame caches each frame.
##   2. `Vector3.Angle(transform.forward, normalize(playerPos - myPos)) <= lookAngle`.
##      [param look_angle] is therefore measured FROM FORWARD — it is a half-angle, so
##      the shipped 75 and 120 are 150 and 240 degree cones. The demon chasing you can
##      see very nearly all the way around itself.
##   3. A raycast from the *head* towards `PlayerController.FacePosToAooni` whose first
##      hit must be the player's own transform. Anything in between blocks it.
##
## DST: "forward" is [method BlueDemon.facing_forward] (the 120 deg/s facing), not the snapped root:
## SRC turns the whole body at 120 deg/s on a path (aooni.gd:472-482), so the cone sweeps round a
## corner with the visible body instead of flipping with the velocity.
func is_find_player(look_distance: float, look_angle: float) -> bool:
	if _demon.are_senses_blocked():                                  # DST 6.3: no target / dead / revive grace / other room (G6, 8.5)
		return false
	var target: CharacterBody3D = _demon.target                      # DST 6.3: the senses live outside the root
	var distance := _demon.global_position.distance_to(target.global_position)
	if look_distance <= distance:
		return false

	var to_target := (target.global_position - _demon.global_position).normalized()
	var forward := _demon.facing_forward()                           # DST 6.3: the visible facing, not -basis.z (G9, 7.4)
	if rad_to_deg(forward.angle_to(to_target)) > look_angle:
		return false

	return has_line_of_sight(look_distance)


## Unobstructed line from the demon's eyes to `PlayerController.FacePosToAooni`,
## limited to the same distance as the cone that asked.
##
##     Physics.Raycast(Ray(eyebrowPos, dir), out hit, (float)lookDistance)
##     if (!hit) return false
##     return hit.transform == Target.transform
##
## Two details are easy to get backwards and both make the demon wrong in the player's
## favour. The test **fails closed**: a ray that hits nothing means not visible, not
## visible-through-everything, because the original requires a hit *on the player*. And
## the aim point is higher while the player is standing than while crouched, which
## is the entire reason crouching behind low cover works.
##
## DST: the ray starts at the `EyesDetection3D` marker on the capsule axis instead of the eyebrow
## bone (the face overhangs the 0.2 m body by 0.5-0.7 m and would start the ray beyond a door leaf,
## G11); the aim point comes from [method BlueDemonPrey.face_position] (G3); the mask is the root's
## `sight_mask` (5: Player + Walls/doors) and only bodies are tested (V5).
func has_line_of_sight(max_distance: float) -> bool:
	var target: CharacterBody3D = _demon.target                      # DST 6.3: the senses live outside the root
	if target == null:
		return false
	var from := _demon.get_eye_position()                            # DST 6.3: EyesDetection3D, not the eyebrow bone (G11)
	var aim: Vector3 = BlueDemonPrey.face_position(target)           # DST 6.3: aim point inside the live collider (G3)
	var direction := aim - from
	if direction.length_squared() < 0.000001:
		return true
	var space := _demon.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		from, from + direction.normalized() * max_distance, _demon.sight_mask
	)                                                                # DST 6.3: mask 5 = Player + Walls/doors (SRC: 129)
	query.exclude = [_demon.get_rid()]
	# DST 6.3 (V5): bodies only. SRC also lets trigger volumes block the ray (Unity's
	# `Physics.queriesHitTriggers`); in dark-chasers other enemies' KillZones are monitorable areas
	# and would blind the demon.
	query.collide_with_areas = false                                 # DST 6.3: V5
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	var collider: Object = hit.get("collider")
	return collider == target or (collider is Node and target.is_ancestor_of(collider as Node))


## Can the demon hear the player? Port of `Aooni.IsFeelPlayerSound`, decompiled from
## 0x1806B7260.
##
## This is far more interesting than a flat radius. The audible range scales with how
## hard the player is exerting themselves:
##
##     limit  = IsStandUp ? 12 : 6            # standing vs crouched
##     range  = 1 + (limit - 1) * clamp(exerciseIntensity, 0, 1)
##     heard  = range >= distance
##
## So a stationary player is audible only within 1 m; a sprinting player within 12 m;
## a sprinting crouched player within 6 m. The whole test is skipped when the player is
## more than 12 m away. No line of sight is involved.
##
## DST: the locker line of the original is not ported (dark-chasers has no hiding spots, porting
## decision 1); exertion is `velocity.length() * hearing_intensity_per_speed` (0.125: 1.0 at the
## DST sprint speed 8.0), read through [BlueDemonPrey].
func is_feel_player_sound() -> bool:
	if _demon.are_senses_blocked():                                  # DST 6.3: no target / dead / revive grace / other room (G6, 8.5)
		return false
	var target: CharacterBody3D = _demon.target                      # DST 6.3: the senses live outside the root
	var distance := _demon.global_position.distance_to(target.global_position)
	if distance > BlueDemonTuning.HEARABLE_DISTANCE_LIMIT:
		return false

	var limit: float = BlueDemonTuning.HEARABLE_DISTANCE_LIMIT
	if not BlueDemonPrey.is_stand_up(target):                        # DST 6.3: stance through the player adapter (6.2)
		limit = BlueDemonTuning.HEARABLE_DISTANCE_LIMIT_WHILE_BEND_DOWN

	# DST 6.3: exertion through the player adapter (6.2); clamped here, as SRC :613.
	var intensity := clampf(BlueDemonPrey.exercise_intensity(target, _demon.hearing_intensity_per_speed), 0.0, 1.0)   # DST 6.3
	return 1.0 + (limit - 1.0) * intensity >= distance
