class_name BlueDemonPrey
extends RefCounted

## What the blue demon may know about its prey (the Player, or a test double).
##
## The single file that knows what a dark-chasers [Player] is. The demon's root script, its
## states and its helpers touch the prey only through these functions, `global_position`
## and `global_transform`; `player.gd` is not edited for the demon.
##
## It replaces the duck-typed reads of the original actor (blue-demon-escape
## `aooni.gd:575-643`: `is_stand_up`, `exercise_intensity`, `is_flash_light_on`,
## `face_position`). A test double answers through plain properties of those names
## (`is_stand_up: bool`, `is_flash_light_on: bool`), a `velocity`, a `current_room` and the
## [Mortal] / [Aimable] methods.
##
## Every function takes a valid node or null; a previously freed instance must be filtered
## by the caller with [method @GlobalScope.is_instance_valid] before the call (typed
## parameters reject freed objects).

const STANDING_AIM_HEIGHT := 1.0        # player.tscn: camera at feet + 1.0
const CROUCHED_AIM_HEIGHT := 0.27       # fallback without a collider: the centre of the DST crouch capsule (0..0.545)
const SIGHT_POINT_MARGIN := 0.05
const LIGHTER_LIT_ENERGY := 0.3         # PlayerOmniLight3D: 0.06 idle, 0.6 lit (player_omni_light_3d.gd:13-21)
const PLAYER_LIGHT_NODE := ^"PlayerOmniLight3D"


## Alive, as the framework defines it: [Mortal] (mortal.gd:21-25 -> player.gd:266-275).
## False for null, for a freed node and for a node that is not Mortal.
static func is_alive(node: Node) -> bool:
	return node != null and is_instance_valid(node) and Mortal.is_alive(node)


## SRC `is_stand_up`. Standing shortens the stare (rate 1.5) and doubles the hearing range.
## Player: not crouching; `is_crouching()` is false while sliding
## (player_movement_component.gd:365), so a slide counts as standing.
## Anything else: its `is_stand_up` property if that is a bool, otherwise TRUE — SRC read an
## absent flag as crouched; here a double that forgets the flag must not get the easy mode.
static func is_stand_up(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return true
	var player := node as Player
	if player != null:
		return player.movement_component == null or not player.movement_component.is_crouching()
	var flag: Variant = node.get(&"is_stand_up")
	if flag is bool:
		var standing: bool = flag
		return standing
	return true


## SRC `is_flash_light_on`: widens the patrol sight cone to 40 m / 90 degrees.
## Player: the lit lighter. WeaponManager only exposes signals, so the pollable trace is the
## light itself: the PlayerOmniLight3D child at 0.06 (idle) or 0.6 (lit) energy.
## Anything else: its `is_flash_light_on` property, if that is `true`.
static func is_flash_light_on(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node is Player:
		var light := node.get_node_or_null(PLAYER_LIGHT_NODE) as OmniLight3D
		return light != null and light.visible and light.light_energy >= LIGHTER_LIT_ENERGY
	var flag: Variant = node.get(&"is_flash_light_on")
	return flag is bool and flag == true


## SRC `exercise_intensity` = `abs(v) * 0.2`: how loud the prey is. 3-D speed times
## [param per_speed] (the demon's `hearing_intensity_per_speed`, 1 / sprint speed).
## Unclamped — the senses clamp to 0..1. 0.0 for anything that is not a CharacterBody3D.
static func exercise_intensity(node: Node, per_speed: float) -> float:
	if node == null or not is_instance_valid(node):
		return 0.0
	var body := node as CharacterBody3D
	if body == null:
		return 0.0
	return body.velocity.length() * per_speed


## SRC `face_position`: the point the sight ray is aimed at, on the body axis.
## Crouched: the CENTRE of the enabled collider — SRC aims at the crouched body centre
## (player_controller.gd:505-520), which is what makes cover half as tall as the crouched
## prey work. Standing: the [Aimable] aim point (the camera, feet + 1.0) clamped into the
## enabled collider. The colliders swap at once while the camera lerps, so the stance flag,
## not the camera, picks the rule; either way the point lies inside the live collider and an
## unobstructed ray always hits the prey.
static func face_position(node: Node3D) -> Vector3:
	if node == null or not is_instance_valid(node):
		return Vector3.ZERO
	var origin := node.global_position
	var span := get_collider_span(node)
	var has_span := span.y > span.x
	var y := 0.0
	if not is_stand_up(node):
		y = (span.x + span.y) * 0.5 if has_span else origin.y + CROUCHED_AIM_HEIGHT
	else:
		y = Aimable.get_aim_point(node).y if Aimable.check(node) else origin.y + STANDING_AIM_HEIGHT
		if has_span:
			y = clampf(y, span.x + SIGHT_POINT_MARGIN, span.y - SIGHT_POINT_MARGIN)
	return Vector3(origin.x, y, origin.z)


## World (bottom_y, top_y) of the first enabled CollisionShape3D child that carries a
## Capsule / Cylinder / Box / Sphere shape (assumed upright); Vector2.ZERO when there is none.
static func get_collider_span(node: Node3D) -> Vector2:
	if node == null or not is_instance_valid(node):
		return Vector2.ZERO
	for child in node.get_children():
		var collider := child as CollisionShape3D
		if collider == null or collider.disabled or collider.shape == null:
			continue
		var shape := collider.shape
		var half := 0.0
		if shape is CapsuleShape3D:
			half = (shape as CapsuleShape3D).height * 0.5
		elif shape is CylinderShape3D:
			half = (shape as CylinderShape3D).height * 0.5
		elif shape is BoxShape3D:
			half = (shape as BoxShape3D).size.y * 0.5
		elif shape is SphereShape3D:
			half = (shape as SphereShape3D).radius
		else:
			continue
		half *= collider.global_basis.y.length()
		var centre_y := collider.global_position.y
		return Vector2(centre_y - half, centre_y + half)
	return Vector2.ZERO


## The node's room id ([RoomAware], room_aware.gd:18-22); "" when it has none.
static func room_of(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	return RoomAware.get_current_room(node)


## Rooms equal, or either one empty — the framework's own rule
## (enemy_transition_component.gd:64-81). Senses and stored positions are only valid inside
## one room: rooms are disjoint world regions joined by teleports.
static func same_room(a: Node, b: Node) -> bool:
	var room_a := room_of(a)
	var room_b := room_of(b)
	return room_a == "" or room_b == "" or room_a == room_b
